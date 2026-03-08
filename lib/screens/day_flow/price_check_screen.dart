import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import '../../widgets/shared_widgets.dart';
import 'sales_screen.dart';

class PriceCheckScreen extends StatelessWidget {
  const PriceCheckScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, lang, _) {
      final s = lang.s;
      return Scaffold(
        appBar: AppBar(
          title: Text(s.sellingPrices, style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream)),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.brown, borderRadius: BorderRadius.circular(20)),
            child: Text(s.step(3,6), style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.cream)),
          )))],
        ),
        body: Consumer<AppProvider>(builder: (context, provider, _) {
          return Column(children: [
            const StepIndicator(currentStep: 3, totalSteps: 6),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              ScreenHeader(title: s.priceCheck, subtitle: s.priceCheckSub),
              ...provider.currentDayProducts.map((p) => Card(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: AppTheme.sansAmharic(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  CurrencyField(label: s.sellPrice, value: provider.pendingSellPrice[p.firestoreId] ?? p.sellPrice, onChanged: (v) => provider.setSellPrice(p.firestoreId!, v)),
                ]),
              ))),
            ])),
            BottomActionBar(label: s.confirmPrices, onPressed: () async {
              await provider.saveSellPrices();
              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
            }),
          ]);
        }),
      );
    });
  }
}
