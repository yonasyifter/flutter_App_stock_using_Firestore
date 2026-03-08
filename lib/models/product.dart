import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? firestoreId;
  final String name;
  final double buyPrice;
  final double sellPrice;
  final int openingStock;
  final bool active;
  /// Date the product was added — "YYYY-MM-DD".
  /// A product only appears on days ON or AFTER this date.
  final String createdAt;

  Product({
    this.firestoreId,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
    this.openingStock = 0,
    this.active = true,
    String? createdAt,
  }) : createdAt = createdAt ?? _today();

  Product copyWith({
    String? firestoreId,
    String? name,
    double? buyPrice,
    double? sellPrice,
    int? openingStock,
    bool? active,
    String? createdAt,
  }) {
    return Product(
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      openingStock: openingStock ?? this.openingStock,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Is this product visible on the given day?
  /// True only if the day is on or after the product's creation date.
  bool visibleOnDay(String dateStr) => createdAt.compareTo(dateStr) <= 0;

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'openingStock': openingStock,
        'active': active,
        'createdAt': createdAt,
      };

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      firestoreId: doc.id,
      name: data['name'] ?? '',
      buyPrice: (data['buyPrice'] as num).toDouble(),
      sellPrice: (data['sellPrice'] as num).toDouble(),
      openingStock: (data['openingStock'] as num?)?.toInt() ?? 0,
      active: data['active'] ?? true,
      // Older documents that predate this field default to a far-past date
      // so they always show on every day (safe migration behaviour).
      createdAt: data['createdAt'] as String? ?? '2000-01-01',
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
