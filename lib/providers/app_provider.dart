import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/day_entry.dart';
import '../models/household_expense.dart';
import '../services/db_service.dart';

class AppProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<DayEntry> _monthEntries = [];        // light-weight (no sub-tables)
  List<DayEntry> _fullMonthEntries = [];    // full (with sub-tables, for home screen)
  DayEntry? _currentEntry;
  DateTime _focusedMonth = DateTime.now();

  // ── In-progress day state (String keys = Firestore product IDs) ──────────
  Map<String, int> _pendingPurchaseQty = {};
  Map<String, double> _pendingPurchasePrice = {};
  Map<String, double> _pendingSellPrice = {};
  Map<String, int> _pendingSalesQty = {};
  List<HouseholdExpense> _pendingExpenses = [];

  // Closing stock cache for product setup screen
  Map<String, int> _closingStockCache = {};

  // ── Getters ──────────────────────────────────────────────────────────────
  List<Product> get products => _products;

  /// All active products regardless of date — used in product list screen.
  List<Product> get activeProducts =>
      _products.where((p) => p.active).toList();

  /// Active products that were created on or before [dateStr].
  /// This is what should be shown in daily flow screens.
  List<Product> productsForDay(String dateStr) => _products
      .where((p) => p.active && p.visibleOnDay(dateStr))
      .toList();

  /// Convenience: products for the currently open day.
  /// Falls back to all active products if no day is open.
  List<Product> get currentDayProducts {
    if (_currentEntry == null) return activeProducts;
    return productsForDay(_currentEntry!.dateKey);
  }

  /// True if at least one active product was created on or before [date].
  /// Used by the calendar to grey out days with no applicable products.
  bool hasProductsOnDay(DateTime date) {
    final dateStr = _dateStr(date);
    return _products.any((p) => p.active && p.visibleOnDay(dateStr));
  }

  List<DayEntry> get monthEntries => _monthEntries;
  List<DayEntry> get fullMonthEntries => _fullMonthEntries;
  DayEntry? get currentEntry => _currentEntry;
  DateTime get focusedMonth => _focusedMonth;

  Map<String, int> get pendingPurchaseQty => _pendingPurchaseQty;
  Map<String, double> get pendingPurchasePrice => _pendingPurchasePrice;
  Map<String, double> get pendingSellPrice => _pendingSellPrice;
  Map<String, int> get pendingSalesQty => _pendingSalesQty;
  List<HouseholdExpense> get pendingExpenses =>
      List.unmodifiable(_pendingExpenses);

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> loadProducts() async {
    _products = await FirestoreService.getProducts();
    notifyListeners();
  }

  Future<void> addProduct(Product p) async {
    final id = await FirestoreService.insertProduct(p);
    _products.add(p.copyWith(firestoreId: id));
    notifyListeners();
  }

  Future<void> updateProduct(Product p) async {
    await FirestoreService.updateProduct(p);

    // Patch the currently open day's opening stock (not necessarily today)
    // so getOpeningStock() / getClosingStock() return correct values immediately.
    if (_currentEntry != null) {
      final openDayStr = _currentEntry!.dateKey;

      await FirestoreService.patchDayOpeningStock(
        openDayStr,
        p.firestoreId!,
        p.openingStock,
      );

      // Also update the in-memory current entry so the UI refreshes instantly.
      final updatedOpening =
          Map<String, int>.from(_currentEntry!.openingStock);
      updatedOpening[p.firestoreId!] = p.openingStock;

      // Recompute closing stock in memory:
      // closing = corrected opening + purchased - sold
      final purchased = _pendingPurchaseQty[p.firestoreId] ?? 0;
      final sold = _pendingSalesQty[p.firestoreId] ?? 0;
      final updatedClosing =
          Map<String, int>.from(_currentEntry!.closingStock);
      updatedClosing[p.firestoreId!] =
          (p.openingStock + purchased - sold).clamp(0, 99999);

      _currentEntry = _currentEntry!.copyWith(
        openingStock: updatedOpening,
        closingStock: updatedClosing,
      );
    }

    final idx = _products.indexWhere((x) => x.firestoreId == p.firestoreId);
    if (idx >= 0) _products[idx] = p;
    notifyListeners();
  }

  Future<void> deactivateProduct(String firestoreId) async {
    await FirestoreService.deactivateProduct(firestoreId);
    final idx = _products.indexWhere((x) => x.firestoreId == firestoreId);
    if (idx >= 0) _products[idx] = _products[idx].copyWith(active: false);
    notifyListeners();
  }

  // ── Closing stock cache (for product setup screen) ────────────────────────

  /// Load closing stock for all active products.
  /// Call this when entering the product setup screen.
  Future<void> loadClosingStockCache() async {
    _closingStockCache = {};
    for (final p in activeProducts) {
      _closingStockCache[p.firestoreId!] =
          await FirestoreService.getCurrentClosingStock(p.firestoreId!);
    }
    notifyListeners();
  }

  /// Returns current stock for a product from the cache,
  /// falling back to base opening stock if no history exists.
  int getProductCurrentStock(String firestoreId) {
    final cached = _closingStockCache[firestoreId];
    if (cached == null || cached == -1) {
      final product = _products.firstWhere(
        (p) => p.firestoreId == firestoreId,
        orElse: () => Product(name: '', buyPrice: 0, sellPrice: 0),
      );
      return product.openingStock;
    }
    return cached;
  }

  // ── Month / Calendar ──────────────────────────────────────────────────────

  Future<void> loadMonthEntries(DateTime month) async {
    _focusedMonth = month;
    // Light-weight entries for calendar + monthly totals
    _monthEntries =
        await FirestoreService.getMonthEntries(month.year, month.month);
    // Full entries (with sub-tables) for home screen daily summary
    _fullMonthEntries =
        await FirestoreService.getFullMonthEntries(month.year, month.month);
    notifyListeners();
  }

  DayEntry? getEntryForDay(int day) {
    try {
      return _monthEntries.firstWhere(
        (e) => e.date.day == day && e.date.month == _focusedMonth.month,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get the full hydrated entry for a specific day (for home screen daily summary).
  DayEntry? getFullEntryForDay(int day) {
    try {
      return _fullMonthEntries.firstWhere(
        (e) => e.date.day == day && e.date.month == _focusedMonth.month,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Open a day ────────────────────────────────────────────────────────────

  Future<void> openDay(DateTime date) async {
    await loadProducts();

    // Only pass products visible on this day — products added later must
    // not appear in past day entries.
    final dayProducts = productsForDay(_dateStr(date));
    _currentEntry =
        await FirestoreService.getOrCreateDayEntry(date, dayProducts);

    // If the day was previously completed, reopen it so the user can edit.
    // closingStock will be recomputed correctly when they complete it again.
    if (_currentEntry!.complete) {
      await FirestoreService.reopenDay(_currentEntry!.dateKey);
      _currentEntry = _currentEntry!.copyWith(complete: false);
    }

    // Reset all pending state
    _pendingPurchaseQty = {};
    _pendingPurchasePrice = {};
    _pendingSellPrice = {};
    _pendingSalesQty = {};

    // Seed every product visible on this day with default prices and zero qty.
    for (final p in dayProducts) {
      _pendingPurchasePrice[p.firestoreId!] = p.buyPrice;
      _pendingSellPrice[p.firestoreId!] = p.sellPrice;
      _pendingPurchaseQty[p.firestoreId!] = 0;
      _pendingSalesQty[p.firestoreId!] = 0;
    }

    // Overwrite defaults with values already saved for this day
    for (final pur in _currentEntry!.purchases) {
      _pendingPurchaseQty[pur.productId] = pur.qty;
      _pendingPurchasePrice[pur.productId] = pur.price;
    }
    for (final s in _currentEntry!.sales) {
      _pendingSalesQty[s.productId] = s.qtySold;
    }

    _pendingExpenses = List.from(_currentEntry!.expenses);
    notifyListeners();
  }

  // ── Setters — ALL call notifyListeners so UI updates instantly ────────────

  void setPurchaseQty(String productId, int qty) {
    _pendingPurchaseQty[productId] = qty;
    notifyListeners();
  }

  void setPurchasePrice(String productId, double price) {
    _pendingPurchasePrice[productId] = price;
    notifyListeners();
  }

  void setSellPrice(String productId, double price) {
    _pendingSellPrice[productId] = price;
    notifyListeners();
  }

  void setSalesQty(String productId, int qty) {
    _pendingSalesQty[productId] = qty;
    notifyListeners();
  }

  // ── Expense management ────────────────────────────────────────────────────

  void addExpense(String description, double amount) {
    _pendingExpenses.add(HouseholdExpense(
      dateStr: _currentEntry!.dateKey,
      description: description,
      amount: amount,
    ));
    notifyListeners();
  }

  void removeExpense(int index) {
    _pendingExpenses.removeAt(index);
    notifyListeners();
  }

  void updateExpense(int index, String description, double amount) {
    _pendingExpenses[index] = _pendingExpenses[index].copyWith(
      description: description,
      amount: amount,
    );
    notifyListeners();
  }

  Future<void> saveExpenses() async {
    await FirestoreService.replaceExpenses(
        _currentEntry!.dateKey, _pendingExpenses);
    _currentEntry =
        _currentEntry!.copyWith(expenses: List.from(_pendingExpenses));
    notifyListeners();
  }

  // ── Step saves ────────────────────────────────────────────────────────────

  Future<void> savePurchases() async {
    final items = currentDayProducts
        .map((p) => PurchaseItem(
              productId: p.firestoreId!,
              qty: _pendingPurchaseQty[p.firestoreId] ?? 0,
              price: _pendingPurchasePrice[p.firestoreId] ?? p.buyPrice,
            ))
        .toList();

    await FirestoreService.savePurchases(_currentEntry!.dateKey, items);

    // Only update master buy prices when editing today — not past days —
    // to avoid corrupting the product master record from historical re-edits.
    final todayStr = _dateStr(DateTime.now());
    if (_currentEntry!.dateKey == todayStr) {
      for (final p in currentDayProducts) {
        final qty = _pendingPurchaseQty[p.firestoreId] ?? 0;
        if (qty > 0) {
          final newPrice = _pendingPurchasePrice[p.firestoreId] ?? p.buyPrice;
          if (newPrice != p.buyPrice) {
            await updateProduct(p.copyWith(buyPrice: newPrice));
          }
        }
      }
    }

    _currentEntry = _currentEntry!.copyWith(purchases: items);
    notifyListeners();
  }

  Future<void> saveSellPrices() async {
    // Only update master sell prices when editing today — not past days.
    final todayStr = _dateStr(DateTime.now());
    if (_currentEntry!.dateKey == todayStr) {
      for (final p in currentDayProducts) {
        final newPrice = _pendingSellPrice[p.firestoreId] ?? p.sellPrice;
        if (newPrice != p.sellPrice) {
          await updateProduct(p.copyWith(sellPrice: newPrice));
        }
      }
    }
    notifyListeners();
  }

  Future<void> saveSales() async {
    final items = currentDayProducts
        .map((p) => SaleItem(
              productId: p.firestoreId!,
              qtySold: _pendingSalesQty[p.firestoreId] ?? 0,
            ))
        .toList();
    await FirestoreService.saveSales(_currentEntry!.dateKey, items);
    _currentEntry = _currentEntry!.copyWith(sales: items);
    notifyListeners();
  }

  Future<void> completeDay() async {
    final revenue = dailyRevenue;
    final profit = dailyProfit;
    final expenses = totalDailyExpenses;
    final netProfit = profit - expenses;
    final restockCost = dailyRestockCost;
    final netAfterRestock = netProfit - restockCost;

    // ── Compute closing stock for every product visible on this day ───────
    // closingStock = openingStock + purchased - sold  (clamped ≥ 0)
    // Stored on the Firestore day document and cascaded forward as the
    // next applicable day's openingStock.
    final closingStock = <String, int>{};
    for (final p in currentDayProducts) {
      final opening = getOpeningStock(p.firestoreId!);
      final bought = _pendingPurchaseQty[p.firestoreId] ?? 0;
      final sold = _pendingSalesQty[p.firestoreId] ?? 0;
      closingStock[p.firestoreId!] =
          (opening + bought - sold).clamp(0, 99999);
    }

    await FirestoreService.completeDayEntry(
      _currentEntry!.dateKey,
      revenue,
      profit,
      expenses,
      netProfit,
      restockCost,
      netAfterRestock,
      closingStock,
    );

    // ── Cascade closing stock forward to all later day entries ────────────
    // Mirrors SQLite cascadeOpeningStockForward — completing or re-completing
    // a past day correctly updates all future days' opening stock.
    await FirestoreService.cascadeOpeningStockForward(
        _currentEntry!.dateKey, closingStock);

    _currentEntry = _currentEntry!.copyWith(
      complete: true,
      totalRevenue: revenue,
      totalProfit: profit,
      totalExpenses: expenses,
      netProfit: netProfit,
      totalRestockCost: restockCost,
      netProfitAfterRestock: netAfterRestock,
      closingStock: closingStock,
    );

    await loadMonthEntries(_focusedMonth);
    notifyListeners();
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  int getOpeningStock(String productId) =>
      _currentEntry?.openingStock[productId] ?? 0;

  int getAvailableStock(String productId) {
    final opening = getOpeningStock(productId);
    final bought = _pendingPurchaseQty[productId] ?? 0;
    return opening + bought;
  }

  /// Live closing stock = opening + bought - sold.
  /// Same formula used in completeDay() — shown in summary table.
  int getClosingStock(String productId) {
    final opening = getOpeningStock(productId);
    final bought = _pendingPurchaseQty[productId] ?? 0;
    final sold = _pendingSalesQty[productId] ?? 0;
    return (opening + bought - sold).clamp(0, 99999);
  }

  double get dailyRevenue {
    double total = 0;
    for (final p in currentDayProducts) {
      final sold = _pendingSalesQty[p.firestoreId] ?? 0;
      final price = _pendingSellPrice[p.firestoreId] ?? p.sellPrice;
      total += sold * price;
    }
    return total;
  }

  double get dailyProfit {
    double total = 0;
    for (final p in currentDayProducts) {
      final sold = _pendingSalesQty[p.firestoreId] ?? 0;
      final sellPrice = _pendingSellPrice[p.firestoreId] ?? p.sellPrice;
      final buyPrice = _pendingPurchasePrice[p.firestoreId] ?? p.buyPrice;
      total += sold * (sellPrice - buyPrice);
    }
    return total;
  }

  double get totalDailyExpenses =>
      _pendingExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get dailyNetProfit => dailyProfit - totalDailyExpenses;

  /// Sum of (units bought today × buy price paid today) per product.
  /// This is the cash spent restocking goods.
  double get dailyRestockCost {
    double total = 0;
    for (final p in currentDayProducts) {
      final qty = _pendingPurchaseQty[p.firestoreId] ?? 0;
      final buyPrice = _pendingPurchasePrice[p.firestoreId] ?? p.buyPrice;
      total += qty * buyPrice;
    }
    return total;
  }

  /// Net profit minus what was spent restocking stock today.
  double get dailyNetProfitAfterRestock => dailyNetProfit - dailyRestockCost;

  double get monthlyRevenue =>
      _monthEntries.fold(0, (s, e) => s + e.totalRevenue);
  double get monthlyProfit =>
      _monthEntries.fold(0, (s, e) => s + e.totalProfit);
  double get monthlyExpenses =>
      _monthEntries.fold(0, (s, e) => s + e.totalExpenses);
  double get monthlyNetProfit =>
      _monthEntries.fold(0, (s, e) => s + e.netProfit);
  double get monthlyRestockCost =>
      _monthEntries.fold(0.0, (s, e) => s + e.totalRestockCost);
  double get monthlyNetProfitAfterRestock =>
      _monthEntries.fold(0.0, (s, e) => s + e.netProfitAfterRestock);

  int get completedDaysCount =>
      _monthEntries.where((e) => e.complete).length;

  String? get bestDay {
    final completed = _monthEntries.where((e) => e.complete).toList();
    if (completed.isEmpty) return null;
    final best =
        completed.reduce((a, b) => a.netProfit > b.netProfit ? a : b);
    return best.netProfit > 0 ? 'Day ${best.date.day}' : null;
  }

  static String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}