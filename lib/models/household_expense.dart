import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdExpense {
  final String? firestoreId; // Firestore auto-generated document ID
  final String dateStr;      // which day this belongs to e.g. "2026-03-04"
  final String description;
  final double amount;

  HouseholdExpense({
    this.firestoreId,
    required this.dateStr,
    required this.description,
    required this.amount,
  }) : assert(amount > 0, 'Expense amount must be positive'),
       assert(description.isNotEmpty, 'Description cannot be empty');

  HouseholdExpense copyWith({
    String? firestoreId,
    String? dateStr,
    String? description,
    double? amount,
  }) {
    return HouseholdExpense(
      firestoreId: firestoreId ?? this.firestoreId,
      dateStr: dateStr ?? this.dateStr,
      description: description ?? this.description,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'description': description,
        'amount': amount,
      };

  factory HouseholdExpense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseholdExpense(
      firestoreId: doc.id,
      dateStr: '', // populated by the caller if needed
      description: data['description'] ?? '',
      amount: (data['amount'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HouseholdExpense &&
      other.firestoreId == firestoreId &&
      other.description == description &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(firestoreId, description, amount);
}
