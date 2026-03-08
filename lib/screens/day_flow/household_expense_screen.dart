import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import '../../widgets/shared_widgets.dart';
import 'summary_screen.dart';

class HouseholdExpenseScreen extends StatelessWidget {
  const HouseholdExpenseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, lang, _) {
      final s = lang.s;
      return Scaffold(
        appBar: AppBar(
          title: Text(s.householdExpenses, style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream)),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.brown, borderRadius: BorderRadius.circular(20)),
            child: Text(s.step(5,6), style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.cream)),
          )))],
        ),
        body: Consumer<AppProvider>(builder: (context, provider, _) {
          final expenses = provider.pendingExpenses;
          return Column(children: [
            const StepIndicator(currentStep: 5, totalSteps: 6),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              ScreenHeader(title: s.householdExpenses, subtitle: s.householdExpensesSub),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFFFF9ED), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.amberLight)),
                child: Row(children: [
                  const Text('🏠', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.expenseInfo, style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown, fontStyle: FontStyle.italic))),
                ]),
              ),
              if (expenses.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(s.noExpenses, textAlign: TextAlign.center,
                      style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown, fontStyle: FontStyle.italic)))),
              ...expenses.asMap().entries.map((entry) {
                final i = entry.key; final exp = entry.value;
                return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.redLight.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('🏠', style: TextStyle(fontSize: 16)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(exp.description, style: AppTheme.sansAmharic(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(formatCurrency(exp.amount), style: AppTheme.serifAmharic(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.red)),
                    ])),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.brown),
                        onPressed: () => _showSheet(context, lang, index: i, existing: exp.description, existingAmount: exp.amount)),
                    IconButton(icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.red.withOpacity(0.7)),
                        onPressed: () => provider.removeExpense(i)),
                  ]),
                ));
              }),
              OutlinedButton.icon(
                onPressed: () => _showSheet(context, lang),
                icon: const Icon(Icons.add),
                label: Text(s.addExpense, style: AppTheme.sansAmharic(fontSize: 14)),
              ),
              const SizedBox(height: 16),
              if (expenses.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                _TotalsPreview(grossProfit: provider.dailyProfit, totalExpenses: provider.totalDailyExpenses, netProfit: provider.dailyNetProfit, s: s),
              ],
              const SizedBox(height: 80),
            ])),
            BottomActionBar(label: s.continueToSummary, onPressed: () async {
              await provider.saveExpenses();
              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryScreen()));
            }),
          ]);
        }),
      );
    });
  }
  void _showSheet(BuildContext context, LanguageProvider lang, {int? index, String? existing, double? existingAmount}) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ChangeNotifierProvider.value(value: lang, child: _ExpenseSheet(index: index, existing: existing, existingAmount: existingAmount)),
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  final int? index; final String? existing; final double? existingAmount;
  const _ExpenseSheet({this.index, this.existing, this.existingAmount});
  @override State<_ExpenseSheet> createState() => _ExpenseSheetState();
}
class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descCtrl, _amountCtrl;
  @override
  void initState() { super.initState(); _descCtrl = TextEditingController(text: widget.existing ?? ''); _amountCtrl = TextEditingController(text: widget.existingAmount?.toStringAsFixed(2) ?? ''); }
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isEditing = widget.index != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEditing ? s.editExpense : s.addExpense, style: AppTheme.serifAmharic(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(s.expenseDetails, style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        if (!isEditing) ...[
          Text(s.quickPick, style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.brown, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: s.expenseCategories.map((pick) => GestureDetector(
            onTap: () => setState(() => _descCtrl.text = pick.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.cream, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.rule)),
              child: Text('${pick.$1} ${pick.$2}', style: AppTheme.sansAmharic(fontSize: 12)),
            ),
          )).toList()),
          const SizedBox(height: 16),
        ],
        TextFormField(controller: _descCtrl, style: AppTheme.sansAmharic(fontSize: 15),
            decoration: InputDecoration(labelText: s.descriptionLabel),
            validator: (v) => (v == null || v.isEmpty) ? s.required : null),
        const SizedBox(height: 12),
        TextFormField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTheme.sansAmharic(fontSize: 15),
            decoration: InputDecoration(labelText: s.amountLabel, prefixText: 'ETB '),
            validator: (v) => (double.tryParse(v ?? '') == null || (double.tryParse(v!) ?? 0) <= 0) ? s.validAmount : null),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _save, child: Text(isEditing ? s.saveChanges : s.addExpense, style: AppTheme.sansAmharic(fontSize: 15, color: AppTheme.cream, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel, style: AppTheme.sansAmharic(fontSize: 15, color: AppTheme.ink))),
      ])),
    );
  }
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    if (widget.index != null) { provider.updateExpense(widget.index!, _descCtrl.text.trim(), double.parse(_amountCtrl.text)); }
    else { provider.addExpense(_descCtrl.text.trim(), double.parse(_amountCtrl.text)); }
    Navigator.pop(context);
  }
  @override void dispose() { _descCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }
}

class _TotalsPreview extends StatelessWidget {
  final double grossProfit, totalExpenses, netProfit;
  final dynamic s;
  const _TotalsPreview({required this.grossProfit, required this.totalExpenses, required this.netProfit, required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        _Row(s.grossProfit, formatCurrency(grossProfit), AppTheme.amberLight, s),
        const SizedBox(height: 8),
        _Row(s.minusExpenses, '- ${formatCurrency(totalExpenses)}', AppTheme.redLight, s),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.white.withOpacity(0.15), thickness: 1)),
        _Row(s.netProfit, formatCurrency(netProfit), netProfit >= 0 ? AppTheme.greenLight : AppTheme.redLight, s, large: true),
      ]),
    );
  }
}
class _Row extends StatelessWidget {
  final String label, value; final Color valueColor; final dynamic s; final bool large;
  const _Row(this.label, this.value, this.valueColor, this.s, {this.large = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: AppTheme.sansAmharic(fontSize: large ? 14 : 13, color: AppTheme.cream.withOpacity(0.7), fontWeight: large ? FontWeight.w600 : FontWeight.normal)),
      Text(value, style: AppTheme.serifAmharic(fontSize: large ? 18 : 14, color: valueColor, fontWeight: large ? FontWeight.w700 : FontWeight.normal)),
    ],
  );
}
