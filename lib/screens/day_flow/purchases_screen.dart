import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import '../../widgets/shared_widgets.dart';
import 'price_check_screen.dart';

class PurchasesScreen extends StatelessWidget {
  final DateTime date;
  const PurchasesScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, lang, _) {
      final s = lang.s;
      return Scaffold(
        appBar: AppBar(
          title: Text(DateFormat('d MMMM yyyy').format(date),
              style: AppTheme.serifAmharic(fontSize: 18, color: AppTheme.cream)),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.brown, borderRadius: BorderRadius.circular(20)),
            child: Text(s.step(2, 6), style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.cream)),
          )))],
        ),
        body: Consumer<AppProvider>(builder: (context, provider, _) {
          final currentDateStr = provider.currentEntry?.dateKey ?? '';

          return Column(children: [
            const StepIndicator(currentStep: 2, totalSteps: 6),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              ScreenHeader(title: s.dailyPurchases, subtitle: s.dailyPurchasesSub),
              ...provider.currentDayProducts.map((p) {
                final pid       = p.firestoreId!;
                final bought    = provider.pendingPurchaseQty[pid] ?? 0;

                // Is this the very first day this product exists?
                final isFirstDay = p.createdAt == currentDateStr;

                // opening:
                //   First day  → the declared initial stock set when product was created
                //   Every other day → yesterday's closingStock = prev_opening + prev_bought - prev_sold
                //   Both cases are already stored correctly in _currentEntry.openingStock[pid]
                //   by getOrCreateDayEntry, so getOpeningStock() returns the right value.
                final opening   = provider.getOpeningStock(pid);

                // available = opening + purchased today (live, updates as user types)
                final available = provider.getAvailableStock(pid);

                // Opening stock label text differs by day
                final openingLabel = isFirstDay
                    ? (lang.isAmharic
                        ? 'መጀመሪያ ክምችት: $opening ፍሬ'
                        : 'Initial stock: $opening units')
                    : (lang.isAmharic
                        ? 'ትናንት ቀሪ: $opening ፍሬ'
                        : 'Carried over: $opening units');

                return Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        style: AppTheme.sansAmharic(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),

                    // Opening line — labelled differently for first day vs subsequent days
                    Text(openingLabel,
                        style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown)),

                    // Available line — only shown once user enters a purchase qty
                    // Shows: opening + purchased = total available to sell today
                    if (bought > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        lang.isAmharic
                            ? 'ለሽያጭ ያለ: $available ፍሬ'
                            : 'Available to sell: $available units',
                        style: AppTheme.sansAmharic(
                            fontSize: 12,
                            color: AppTheme.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],

                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: QtyField(
                          label: s.qtyPurchased,
                          value: bought,
                          onChanged: (v) => provider.setPurchaseQty(pid, v))),
                      const SizedBox(width: 12),
                      Expanded(child: CurrencyField(
                          label: s.buyPrice,
                          value: provider.pendingPurchasePrice[pid] ?? p.buyPrice,
                          onChanged: (v) => provider.setPurchasePrice(pid, v))),
                    ]),
                  ]),
                ));
              }),
            ])),
            BottomActionBar(label: s.saveAndContinue, onPressed: () async {
              await provider.savePurchases();
              if (context.mounted) Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PriceCheckScreen()));
            }),
          ]);
        }),
      );
    });
  }
}
