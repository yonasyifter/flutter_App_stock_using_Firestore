import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import '../../widgets/shared_widgets.dart';
import 'household_expense_screen.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, lang, _) {
      final s = lang.s;
      return Scaffold(
        appBar: AppBar(
          title: Text(s.dailySales, style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream)),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.brown, borderRadius: BorderRadius.circular(20)),
            child: Text(s.step(4,6), style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.cream)),
          )))],
        ),
        body: Consumer<AppProvider>(builder: (context, provider, _) {
          return Column(children: [
            const StepIndicator(currentStep: 4, totalSteps: 6),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              ScreenHeader(title: s.logSales, subtitle: s.logSalesSub),
              ...provider.currentDayProducts.map((p) {
                final available = provider.getAvailableStock(p.firestoreId!);
                final currentSold = provider.pendingSalesQty[p.firestoreId] ?? 0;
                final sellPrice = provider.pendingSellPrice[p.firestoreId] ?? p.sellPrice;
                return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: AppTheme.sansAmharic(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s.availableLabel(available, formatCurrency(sellPrice)), style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown)),
                      if (currentSold > 0) ...[
                        const SizedBox(height: 4),
                        Text(s.revenueLabel(formatCurrency(currentSold * sellPrice)), style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600)),
                      ],
                    ])),
                    _StepperWidget(value: currentSold, max: available, onChanged: (v) => provider.setSalesQty(p.firestoreId!, v)),
                  ]),
                ));
              }),
              const SizedBox(height: 8),
              Consumer<AppProvider>(builder: (ctx, p, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.ink.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s.todayRevenue, style: AppTheme.sansAmharic(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(formatCurrency(p.dailyRevenue), style: AppTheme.serifAmharic(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.green)),
                ]),
              )),
            ])),
            BottomActionBar(label: s.nextExpenses, onPressed: () async {
              await provider.saveSales();
              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const HouseholdExpenseScreen()));
            }),
          ]);
        }),
      );
    });
  }
}

class _StepperWidget extends StatefulWidget {
  final int value; final int max; final ValueChanged<int> onChanged;
  const _StepperWidget({required this.value, required this.max, required this.onChanged});
  @override State<_StepperWidget> createState() => _StepperWidgetState();
}
class _StepperWidgetState extends State<_StepperWidget> {
  late int _val;
  late TextEditingController _ctrl;
  late FocusNode _focus;
  @override
  void initState() {
    super.initState();
    _val = widget.value;
    _ctrl = TextEditingController(text: '$_val');
    _focus = FocusNode();
    _focus.addListener(() { if (!_focus.hasFocus) _commitText(); });
  }
  void _set(int newVal) {
    final clamped = newVal.clamp(0, widget.max);
    setState(() { _val = clamped; _ctrl.text = '$clamped'; _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length); });
    widget.onChanged(clamped);
  }
  void _commitText() { _set(int.tryParse(_ctrl.text.trim()) ?? _val); }
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(Icons.remove, () => _set(_val - 1)),
      SizedBox(width: 52, child: TextField(
        controller: _ctrl, focusNode: _focus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppTheme.sansAmharic(fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.rule)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.amber, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.rule)),
        ),
        onChanged: (v) { final p = int.tryParse(v); if (p != null) _set(p); },
        onSubmitted: (_) => _commitText(),
      )),
      _Btn(Icons.add, () => _set(_val + 1)),
    ]);
  }
  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }
}
class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _Btn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppTheme.cream, size: 16)),
  );
}
