import 'package:cloud_firestore/cloud_firestore.dart';
import 'household_expense.dart';

// ─── PurchaseItem ────────────────────────────────────────────────────────────

class PurchaseItem {
  final String productId; // Firestore product document ID
  final int qty;
  final double price;

  PurchaseItem({
    required this.productId,
    required this.qty,
    required this.price,
  });

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'qty': qty,
        'price': price,
      };

  factory PurchaseItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseItem(
      productId: data['productId'] ?? doc.id,
      qty: (data['qty'] as num).toInt(),
      price: (data['price'] as num).toDouble(),
    );
  }
}

// ─── SaleItem ────────────────────────────────────────────────────────────────

class SaleItem {
  final String productId;
  final int qtySold;

  SaleItem({required this.productId, required this.qtySold});

  Map<String, dynamic> toFirestore() => {
        'productId': productId,
        'qtySold': qtySold,
      };

  factory SaleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SaleItem(
      productId: data['productId'] ?? doc.id,
      qtySold: (data['qtySold'] as num).toInt(),
    );
  }
}

// ─── DayEntry ────────────────────────────────────────────────────────────────

class DayEntry {
  final String? firestoreId; // the date string "2026-03-04" is also the doc ID
  final DateTime date;
  final bool complete;
  final double totalRevenue;
  final double totalProfit;
  final double totalExpenses;
  final double netProfit;
  final double totalRestockCost;     // sum of (qty bought × buy price)
  final double netProfitAfterRestock; // netProfit - totalRestockCost

  /// closingStock: productFirestoreId → qty at END of day (written on completeDay)
  /// This is what becomes the next day's openingStock
  final Map<String, int> closingStock;

  /// openingStock: productFirestoreId → qty at start of day
  final Map<String, int> openingStock;
  final List<PurchaseItem> purchases;
  final List<SaleItem> sales;
  final List<HouseholdExpense> expenses;

  DayEntry({
    this.firestoreId,
    required this.date,
    this.complete = false,
    this.totalRevenue = 0,
    this.totalProfit = 0,
    this.totalExpenses = 0,
    this.netProfit = 0,
    this.totalRestockCost = 0,
    this.netProfitAfterRestock = 0,
    this.closingStock = const {},
    this.openingStock = const {},
    this.purchases = const [],
    this.sales = const [],
    this.expenses = const [],
  });

  DayEntry copyWith({
    String? firestoreId,
    DateTime? date,
    bool? complete,
    double? totalRevenue,
    double? totalProfit,
    double? totalExpenses,
    double? netProfit,
    double? totalRestockCost,
    double? netProfitAfterRestock,
    Map<String, int>? closingStock,
    Map<String, int>? openingStock,
    List<PurchaseItem>? purchases,
    List<SaleItem>? sales,
    List<HouseholdExpense>? expenses,
  }) {
    return DayEntry(
      firestoreId: firestoreId ?? this.firestoreId,
      date: date ?? this.date,
      complete: complete ?? this.complete,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalProfit: totalProfit ?? this.totalProfit,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      netProfit: netProfit ?? this.netProfit,
      totalRestockCost: totalRestockCost ?? this.totalRestockCost,
      netProfitAfterRestock: netProfitAfterRestock ?? this.netProfitAfterRestock,
      closingStock: closingStock ?? this.closingStock,
      openingStock: openingStock ?? this.openingStock,
      purchases: purchases ?? this.purchases,
      sales: sales ?? this.sales,
      expenses: expenses ?? this.expenses,
    );
  }

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  factory DayEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // openingStock is stored as Map<String, dynamic> in Firestore,
    // convert values to int safely
    final rawStock = (data['openingStock'] as Map<String, dynamic>?) ?? {};
    final openingStock = rawStock.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    return DayEntry(
      firestoreId: doc.id,
      date: DateTime.parse(data['date'] as String),
      complete: data['complete'] ?? false,
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (data['totalProfit'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (data['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      netProfit: (data['netProfit'] as num?)?.toDouble() ?? 0.0,
      totalRestockCost: (data['totalRestockCost'] as num?)?.toDouble() ?? 0.0,
      netProfitAfterRestock: (data['netProfitAfterRestock'] as num?)?.toDouble() ?? 0.0,
      closingStock: (() {
        final raw = (data['closingStock'] as Map<String, dynamic>?) ?? {};
        return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
      })(),
      openingStock: openingStock,
      // sub-collections loaded separately by the service
    );
  }
}
