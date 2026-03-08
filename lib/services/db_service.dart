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

    // Update today's opening stock to reflect the manual correction.
    // This is what getOpeningStock() reads, so the purchase screen
    // shows the corrected value immediately.
    opening[productId] = newOpeningStock;

    // Recompute closing stock using the CORRECTED opening:
    //   closing = newOpeningStock + purchased_today - sold_today
    // This ensures tomorrow's openingStock carries the correct value.
    final purSnap  = await _purchases(dateStr).doc(productId).get();
    final saleSnap = await _sales(dateStr).doc(productId).get();

    final purchased = purSnap.exists
        ? ((purSnap.data() as Map<String, dynamic>)['qty'] as num).toInt()
        : 0;
    final sold = saleSnap.exists
        ? ((saleSnap.data() as Map<String, dynamic>)['qtySold'] as num).toInt()
        : 0;

    // closing = corrected opening + what was bought today - what was sold today
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

  // ─────────────────────────────────────────────────────────────────────────
  // getOrCreateDayEntry
  //
  // Called every time the user taps a day on the calendar — whether the day
  // is new, in-progress, or already completed (client can always re-edit).
  //
  // What it does:
  //   • If the day document does NOT exist → create it with correct openingStock
  //   • If it DOES exist → return it as-is, patching any newly added products
  //
  // openingStock for a new day comes from:
  //   → The most recent previous day's closingStock  (complete OR incomplete)
  //   → Fallback: the product's declared openingStock (first-ever day only)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<DayEntry> getOrCreateDayEntry(
      DateTime date, List<Product> products) async {

    final dateStr = _dateStr(date);

    // ── Get the previous day's closing stock (source of today's opening) ────
    final prevClosing = await _getPreviousClosingStock(dateStr);

    // Build openingStock map for a brand-new day
    Map<String, int> buildOpening() {
      final map = <String, int>{};
      for (final p in products) {
        map[p.firestoreId!] = prevClosing.containsKey(p.firestoreId)
            ? prevClosing[p.firestoreId!]!
            : p.openingStock; // first-ever day for this product
      }
      return map;
    }

    // ── Does today's document already exist? ─────────────────────────────────
    final existingSnap = await _dayEntries.doc(dateStr).get();

    if (!existingSnap.exists) {
      // Brand-new day — create document
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
        'closingStock': opening, // initially equal to opening; updated on completeDay
      });
      return DayEntry(
        firestoreId: dateStr,
        date: date,
        openingStock: opening,
        closingStock: opening,
      );
    }

    // ── Document exists ──────────────────────────────────────────────────────
    final data = existingSnap.data() as Map<String, dynamic>;
    final storedOpening = _toIntMap(data['openingStock']);
    final storedClosing = _toIntMap(data['closingStock']);

    // Check for products added AFTER this day was first opened
    final missingProducts = products
        .where((p) => !storedOpening.containsKey(p.firestoreId))
        .toList();

    if (missingProducts.isEmpty) {
      // Check if all stored opening values are 0 — this means the day was
      // created before products had stock values (corrupted state). Fix it.
      final allZero = storedOpening.isNotEmpty &&
          storedOpening.values.every((v) => v == 0) &&
          prevClosing.isNotEmpty;

      if (allZero) {
        // Recompute opening from prevClosing
        final recomputedOpening = <String, int>{};
        for (final p in products) {
          recomputedOpening[p.firestoreId!] = prevClosing.containsKey(p.firestoreId)
              ? prevClosing[p.firestoreId!]!
              : p.openingStock;
        }
        await _dayEntries.doc(dateStr).update({
          'openingStock': recomputedOpening,
          'closingStock': recomputedOpening,
        });
        final freshSnap = await _dayEntries.doc(dateStr).get();
        return _hydrate(freshSnap);
      }

      return _hydrate(existingSnap);
    }

    // Patch both openingStock and closingStock for newly added products
    final patchOpening = <String, int>{};
    final patchClosing = <String, int>{};
    for (final p in missingProducts) {
      final value = prevClosing.containsKey(p.firestoreId)
          ? prevClosing[p.firestoreId!]!
          : p.openingStock;
      patchOpening[p.firestoreId!] = value;
      patchClosing[p.firestoreId!] = value;
    }

    final updatedOpening = {...storedOpening, ...patchOpening};
    final updatedClosing = {...storedClosing, ...patchClosing};

    await _dayEntries.doc(dateStr).update({
      'openingStock': updatedOpening,
      'closingStock': updatedClosing,
    });

    final freshSnap = await _dayEntries.doc(dateStr).get();
    return _hydrate(freshSnap);
  }

  // ── Get the closing stock from the most recent day before dateStr ─────────
  //
  // Looks at ANY previous day (complete or not) because the client
  // can re-open and edit completed days. The closingStock field is
  // always updated by completeDay(), so it always reflects the latest save.
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
  //
  // Always rewrites closingStock = opening + purchased - sold.
  // This works for first-time completion AND re-completion after editing.
  // The complete flag is set to true; it can be opened again any time —
  // the next completeDay() call will update everything with fresh numbers.

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
      'closingStock': closingStock, // always fresh, always correct
    });
  }

  // ── REOPEN A COMPLETED DAY ───────────────────────
  // Resets complete flag to false so the day can be edited again.
  // closingStock is NOT touched here — it will be rewritten by completeDay().
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

  static String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
