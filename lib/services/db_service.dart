import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/day_entry.dart';
import '../models/household_expense.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirestoreService
//
// STOCK CARRY-FORWARD RULE (single source of truth):
//
//   closingStock[pid] = openingStock[pid] + purchased[pid] - sold[pid]
//
//   • closingStock is recomputed and written every time completeDay() is called.
//   • When a new day is opened, its openingStock = previous day's closingStock.
//   • A completed day CAN be re-opened and edited. completeDay() always
//     rewrites closingStock with fresh numbers.
//
// OPENING STOCK SOURCE PRIORITY (when creating a new day document):
//   1. Previous day's closingStock field  (complete or incomplete — doesn't matter)
//   2. Product's declared openingStock    (only on truly first day for that product)
// ─────────────────────────────────────────────────────────────────────────────

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user');
    return uid;
  }

  static DocumentReference get _userDoc    => _db.collection('users').doc(_uid);
  static CollectionReference get _products  => _userDoc.collection('products');
  static CollectionReference get _dayEntries => _userDoc.collection('dayEntries');
  static CollectionReference _purchases(String d) => _dayEntries.doc(d).collection('purchases');
  static CollectionReference _sales(String d)     => _dayEntries.doc(d).collection('sales');
  static CollectionReference _expenses(String d)  => _dayEntries.doc(d).collection('expenses');

  // ── PRODUCTS ─────────────────────────────────────

  static Future<List<Product>> getProducts({bool activeOnly = false}) async {
    Query q = _products.orderBy('name');
    if (activeOnly) q = q.where('active', isEqualTo: true);
    final snap = await q.get();
    return snap.docs.map((d) => Product.fromFirestore(d)).toList();
  }

  static Future<String> insertProduct(Product p) async {
    final ref = await _products.add(p.toFirestore());
    return ref.id;
  }

  static Future<void> updateProduct(Product p) async {
    await _products.doc(p.firestoreId).update(p.toFirestore());
  }

  static Future<void> deactivateProduct(String id) async {
    await _products.doc(id).update({'active': false});
  }

  // FIX: The original fetched only the single most-recent day and returned -1
  // if that day had no entry for this product (e.g. a newly added product, or
  // a day where the product wasn't traded). Now we scan backwards through up to
  // 60 days until we find one that actually contains a closingStock entry for
  // the given productId — which is the true "current" stock for that product.
  static Future<int> getCurrentClosingStock(String productId) async {
    final snap = await _dayEntries
        .orderBy('date', descending: true)
        .limit(60)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final closing = _toIntMap(data['closingStock']);
      if (closing.containsKey(productId)) {
        return closing[productId]!;
      }
    }
    return -1; // No history — caller falls back to product.openingStock
  }

  // ── Patch a single product's opening stock on an open day entry ───────────
  // Called when the user edits a product's openingStock from the product list.
  // Updates both openingStock and closingStock on the day document so the
  // purchase screen reflects the new value immediately.
  static Future<void> patchDayOpeningStock(
      String dateStr, String productId, int newOpeningStock) async {
    final snap = await _dayEntries.doc(dateStr).get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final opening = Map<String, dynamic>.from(
        (data['openingStock'] as Map<String, dynamic>?) ?? {});
    final closing = Map<String, dynamic>.from(
        (data['closingStock'] as Map<String, dynamic>?) ?? {});

    opening[productId] = newOpeningStock;

    // Recompute closing stock using the CORRECTED opening:
    final purSnap  = await _purchases(dateStr).doc(productId).get();
    final saleSnap = await _sales(dateStr).doc(productId).get();

    final purchased = purSnap.exists
        ? ((purSnap.data() as Map<String, dynamic>)['qty'] as num).toInt()
        : 0;
    final sold = saleSnap.exists
        ? ((saleSnap.data() as Map<String, dynamic>)['qtySold'] as num).toInt()
        : 0;

    closing[productId] = (newOpeningStock + purchased - sold).clamp(0, 99999);

    await _dayEntries.doc(dateStr).update({
      'openingStock': opening,
      'closingStock': closing,
    });
  }

  // ── DAY ENTRIES ──────────────────────────────────

  static Future<DayEntry?> getDayEntry(DateTime date) async {
    final dateStr = _dateStr(date);
    final snap = await _dayEntries.doc(dateStr).get();
    if (!snap.exists) return null;
    return _hydrate(snap);
  }

  // Attach purchases / sales / expenses sub-collections to a day document
  static Future<DayEntry> _hydrate(DocumentSnapshot snap) async {
    final dateStr = snap.id;
    final results = await Future.wait([
      _purchases(dateStr).get(),
      _sales(dateStr).get(),
      _expenses(dateStr).get(),
    ]);
    final purchases = (results[0] as QuerySnapshot).docs.map((d) => PurchaseItem.fromFirestore(d)).toList();
    final sales     = (results[1] as QuerySnapshot).docs.map((d) => SaleItem.fromFirestore(d)).toList();
    final expenses  = (results[2] as QuerySnapshot).docs.map((d) => HouseholdExpense.fromFirestore(d)).toList();
    return DayEntry.fromFirestore(snap)
        .copyWith(purchases: purchases, sales: sales, expenses: expenses);
  }

  static Future<DayEntry> getOrCreateDayEntry(
      DateTime date, List<Product> products) async {

    final dateStr = _dateStr(date);
    final prevClosing = await _getPreviousClosingStock(dateStr);

    Map<String, int> buildOpening() {
      final map = <String, int>{};
      for (final p in products) {
        map[p.firestoreId!] = prevClosing.containsKey(p.firestoreId)
            ? prevClosing[p.firestoreId!]!
            : p.openingStock;
      }
      return map;
    }

    final existingSnap = await _dayEntries.doc(dateStr).get();

    if (!existingSnap.exists) {
      final opening = buildOpening();
      await _dayEntries.doc(dateStr).set({
        'date': dateStr,
        'complete': false,
        'totalRevenue': 0.0,
        'totalProfit': 0.0,
        'totalExpenses': 0.0,
        'netProfit': 0.0,
        'totalRestockCost': 0.0,
        'netProfitAfterRestock': 0.0,
        'openingStock': opening,
        'closingStock': opening,
      });
      return DayEntry(
        firestoreId: dateStr,
        date: date,
        openingStock: opening,
        closingStock: opening,
      );
    }

    final data = existingSnap.data() as Map<String, dynamic>;
    final storedOpening = _toIntMap(data['openingStock']);

    final missingProducts = products
        .where((p) => !storedOpening.containsKey(p.firestoreId))
        .toList();

    // FIX: Removed the "allZero" heuristic that was here previously.
    // It checked storedOpening.values.every((v) => v == 0) and overwrote ALL
    // opening stock values with prevClosing. This silently corrupted any day
    // where products genuinely had zero stock (new shop, sold-out items, etc.).
    // The stored values are authoritative — only patch entries that are missing.
    if (missingProducts.isEmpty) {
      return _hydrate(existingSnap);
    }

    // Patch only products that are missing from this day's opening stock
    // (products added after this day was first created).
    final patchOpening = <String, int>{};
    for (final p in missingProducts) {
      patchOpening[p.firestoreId!] = prevClosing.containsKey(p.firestoreId)
          ? prevClosing[p.firestoreId!]!
          : p.openingStock;
    }

    final updatedOpening = {...storedOpening, ...patchOpening};
    final updatedClosing = {..._toIntMap(data['closingStock']), ...patchOpening};

    await _dayEntries.doc(dateStr).update({
      'openingStock': updatedOpening,
      'closingStock': updatedClosing,
    });

    final freshSnap = await _dayEntries.doc(dateStr).get();
    return _hydrate(freshSnap);
  }

  static Future<Map<String, int>> _getPreviousClosingStock(String dateStr) async {
    final snap = await _dayEntries
        .where('date', isLessThan: dateStr)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return {};

    final raw = (snap.docs.first.data() as Map<String, dynamic>)['closingStock'];
    return raw != null ? _toIntMap(raw) : {};
  }

  static Map<String, int> _toIntMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ── PURCHASES ────────────────────────────────────

  static Future<void> savePurchases(String dateStr, List<PurchaseItem> items) async {
    final batch = _db.batch();
    final existing = await _purchases(dateStr).get();
    for (final d in existing.docs) batch.delete(d.reference);
    for (final item in items) {
      batch.set(_purchases(dateStr).doc(item.productId), item.toFirestore());
    }
    await batch.commit();
  }

  // ── SALES ────────────────────────────────────────

  static Future<void> saveSales(String dateStr, List<SaleItem> items) async {
    final batch = _db.batch();
    final existing = await _sales(dateStr).get();
    for (final d in existing.docs) batch.delete(d.reference);
    for (final item in items) {
      batch.set(_sales(dateStr).doc(item.productId), item.toFirestore());
    }
    await batch.commit();
  }

  // ── EXPENSES ─────────────────────────────────────

  static Future<void> replaceExpenses(String dateStr, List<HouseholdExpense> items) async {
    final batch = _db.batch();
    final existing = await _expenses(dateStr).get();
    for (final d in existing.docs) batch.delete(d.reference);
    for (final item in items) {
      final ref = item.firestoreId != null
          ? _expenses(dateStr).doc(item.firestoreId)
          : _expenses(dateStr).doc();
      batch.set(ref, item.toFirestore());
    }
    await batch.commit();
  }

  // ── COMPLETE DAY ─────────────────────────────────

  static Future<void> completeDayEntry(
    String dateStr,
    double revenue,
    double profit,
    double expenses,
    double netProfit,
    double restockCost,
    double netAfterRestock,
    Map<String, int> closingStock,
  ) async {
    await _dayEntries.doc(dateStr).update({
      'complete': true,
      'totalRevenue': revenue,
      'totalProfit': profit,
      'totalExpenses': expenses,
      'netProfit': netProfit,
      'totalRestockCost': restockCost,
      'netProfitAfterRestock': netAfterRestock,
      'closingStock': closingStock,
    });
  }

  // FIX 1: Added .clamp(0, 99999) when computing updatedCl. The original code
  //        did not clamp, so propagating a stock decrease could produce a
  //        negative closingStock value on downstream days.
  // FIX 2: Replaced the single WriteBatch with chunked batches capped at 499
  //        operations each. Firestore enforces a hard 500-op limit per batch;
  //        the old code would throw and silently drop the entire cascade for
  //        any user with more than ~499 future day entries.
  static Future<void> cascadeOpeningStockForward(
      String startDateStr, Map<String, int> closingStock) async {
    final snap = await _dayEntries
        .where('date', isGreaterThan: startDateStr)
        .orderBy('date')
        .get();

    if (snap.docs.isEmpty) return;

    var currentClosing = Map<String, int>.from(closingStock);

    const int _chunkSize = 499;
    WriteBatch batch = _db.batch();
    int opsInBatch = 0;

    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final op = _toIntMap(d['openingStock']);
      final cl = _toIntMap(d['closingStock']);

      final updatedOp = {...op};
      final updatedCl = {...cl};

      bool changed = false;
      for (final entry in currentClosing.entries) {
        final pid = entry.key;
        final prevCl = entry.value;

        if (updatedOp[pid] != prevCl) {
          final diff = prevCl - (updatedOp[pid] ?? 0);
          updatedOp[pid] = prevCl;
          updatedCl[pid] = ((updatedCl[pid] ?? 0) + diff).clamp(0, 99999);
          changed = true;
        }
      }

      // Always advance the chain regardless of whether this doc changed
      currentClosing = updatedCl;

      if (changed) {
        batch.update(doc.reference, {
          'openingStock': updatedOp,
          'closingStock': updatedCl,
        });
        opsInBatch++;

        if (opsInBatch >= _chunkSize) {
          await batch.commit();
          batch = _db.batch();
          opsInBatch = 0;
        }
      }
    }

    if (opsInBatch > 0) await batch.commit();
  }

  static Future<void> reopenDay(String dateStr) async {
    await _dayEntries.doc(dateStr).update({'complete': false});
  }

  // ── MONTH ENTRIES ────────────────────────────────

  static Future<List<DayEntry>> getMonthEntries(int year, int month) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to   = '$year-${month.toString().padLeft(2, '0')}-31';
    final snap = await _dayEntries
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to)
        .get();
    return snap.docs.map((d) => DayEntry.fromFirestore(d)).toList();
  }

  static Future<List<DayEntry>> getFullMonthEntries(int year, int month) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to   = '$year-${month.toString().padLeft(2, '0')}-31';
    final snap = await _dayEntries
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to)
        .get();

    final futures = snap.docs.map((d) => _hydrate(d));
    return Future.wait(futures);
  }

  static String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
