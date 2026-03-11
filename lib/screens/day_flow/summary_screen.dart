import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import '../../widgets/shared_widgets.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, lang, _) {
      final s = lang.s;
      return Scaffold(
        appBar: AppBar(
          title: Text(s.dailySummary,
              style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.brown,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(s.step(6, 6),
                      style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.cream)),
                ),
              ),
            )
          ],
        ),
        body: Consumer<AppProvider>(builder: (context, provider, _) {
          final products = provider.currentDayProducts;
          final warnings = <String>[];

          // ── Compute per-product restock costs ──────────────
          // Only products where qty_bought > 0 appear in the restock table
          final restockRows = <({String name, int qty, double buyPrice, double cost})>[];
          double totalRestockCost = 0;
          for (final p in products) {
            final qty      = provider.pendingPurchaseQty[p.firestoreId] ?? 0;
            final buyPrice = provider.pendingPurchasePrice[p.firestoreId] ?? p.buyPrice;
            final cost     = qty * buyPrice;
            totalRestockCost += cost;
            if (qty > 0) {
              restockRows.add((name: p.name, qty: qty, buyPrice: buyPrice, cost: cost));
            }
          }

          return Column(children: [
            const StepIndicator(currentStep: 6, totalSteps: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ScreenHeader(title: s.endOfDay, subtitle: s.endOfDaySub),

                  // ── Stock movement table ──────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 36,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 56,
                          columnSpacing: 14,
                          headingTextStyle: AppTheme.sansAmharic(
                              fontSize: 10, color: AppTheme.brown, letterSpacing: 0.5),
                          dataTextStyle: AppTheme.sansAmharic(fontSize: 12),
                          columns: [
                            DataColumn(label: Text(s.colProduct)),
                            DataColumn(label: Text(s.colOpen), numeric: true),
                            DataColumn(label: Text(s.colBought), numeric: true),
                            DataColumn(label: Text(s.colSold), numeric: true),
                            // colClose = tomorrow's opening stock
                            DataColumn(label: Text(s.colClose), numeric: true),
                            DataColumn(label: Text(s.colRevenue), numeric: true),
                          ],
                          rows: products.map((p) {
                            final opening   = provider.getOpeningStock(p.firestoreId!);
                            final bought    = provider.pendingPurchaseQty[p.firestoreId] ?? 0;
                            final sold      = provider.pendingSalesQty[p.firestoreId] ?? 0;
                            // Use the same helper that completeDay() uses — guaranteed consistent
                            final closing   = provider.getClosingStock(p.firestoreId!);
                            final sellPrice = provider.pendingSellPrice[p.firestoreId] ?? p.sellPrice;
                            if (closing <= 3) warnings.add(s.lowStockMsg(p.name, closing));
                            return DataRow(cells: [
                              DataCell(Text(p.name,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 13, fontWeight: FontWeight.w600))),
                              DataCell(Text('$opening')),
                              DataCell(Text(bought > 0 ? '+$bought' : '0')),
                              DataCell(Text('$sold')),
                              // closing = opening + bought - sold → becomes tomorrow's opening
                              DataCell(Text(
                                '$closing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: closing <= 3 ? AppTheme.red : AppTheme.green,
                                ),
                              )),
                              DataCell(Text(formatCurrency(sold * sellPrice))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // ── Low stock warnings ────────────────────────
                  if (warnings.isNotEmpty) ...[
                    SectionLabel(s.lowStockWarning),
                    ...warnings.map((w) => WarningChip(w)),
                    const SizedBox(height: 8),
                  ],

                  // ── Revenue & Gross Profit cards ──────────────
                  Row(children: [
                    Expanded(
                        child: StatCard(
                            label: s.totalRevenue,
                            value: formatCurrency(provider.dailyRevenue))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: s.grossProfit,
                            value: formatCurrency(provider.dailyProfit))),
                  ]),
                  const SizedBox(height: 12),

                  // ── Household Expenses ────────────────────────
                  if (provider.pendingExpenses.isNotEmpty) ...[
                    SectionLabel(s.householdExpenses),
                    Card(
                      child: Column(children: [
                        ...provider.pendingExpenses.map((exp) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(children: [
                                const Text('🏠', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(exp.description,
                                        style: AppTheme.sansAmharic(fontSize: 15))),
                                Text('- ${formatCurrency(exp.amount)}',
                                    style: AppTheme.serifAmharic(
                                        fontSize: 13,
                                        color: AppTheme.red,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            )),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(s.totalExpenses,
                                    style: AppTheme.sansAmharic(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.brown)),
                                Text('- ${formatCurrency(provider.totalDailyExpenses)}',
                                    style: AppTheme.serifAmharic(
                                        fontSize: 14,
                                        color: AppTheme.red,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Restock Cost (Goods / Assets) ─────────────
                  SectionLabel(s.restockCost),
                  Card(
                    child: Column(children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(children: [
                          Expanded(
                              flex: 3,
                              child: Text(s.colProduct,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 11,
                                      color: AppTheme.brown,
                                      letterSpacing: 0.4))),
                          Expanded(
                              flex: 2,
                              child: Text(s.colBought,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 11,
                                      color: AppTheme.brown,
                                      letterSpacing: 0.4))),
                          Expanded(
                              flex: 2,
                              child: Text(s.buyPrice,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 11,
                                      color: AppTheme.brown,
                                      letterSpacing: 0.4))),
                          Expanded(
                              flex: 3,
                              child: Text(s.colRestockCost,
                                  textAlign: TextAlign.right,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 11,
                                      color: AppTheme.brown,
                                      letterSpacing: 0.4))),
                        ]),
                      ),
                      const Divider(height: 8),

                      // Data rows — only products that were restocked
                      if (restockRows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            lang.isAmharic
                                ? 'ዛሬ ምንም ዕቃ አልተገዛም'
                                : 'No goods purchased today',
                            style: AppTheme.sansAmharic(
                                fontSize: 13,
                                color: AppTheme.brown,
                                fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...restockRows.map((row) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(children: [
                                Expanded(
                                    flex: 3,
                                    child: Text(row.name,
                                        style: AppTheme.sansAmharic(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Expanded(
                                    flex: 2,
                                    child: Text('${row.qty} ${s.units}',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.sansAmharic(
                                            fontSize: 13))),
                                Expanded(
                                    flex: 2,
                                    child: Text(formatCurrency(row.buyPrice),
                                        textAlign: TextAlign.center,
                                        style: AppTheme.sansAmharic(
                                            fontSize: 13))),
                                Expanded(
                                    flex: 3,
                                    child: Text(
                                        '- ${formatCurrency(row.cost)}',
                                        textAlign: TextAlign.right,
                                        style: AppTheme.serifAmharic(
                                            fontSize: 13,
                                            color: AppTheme.red,
                                            fontWeight: FontWeight.w600))),
                              ]),
                            )),

                      // Total restock cost row
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.rule.withOpacity(0.35),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.totalRestockCost,
                                  style: AppTheme.sansAmharic(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.brown)),
                              Text('- ${formatCurrency(totalRestockCost)}',
                                  style: AppTheme.serifAmharic(
                                      fontSize: 15,
                                      color: AppTheme.red,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Final P&L card ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppTheme.ink,
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      // Revenue
                      _NetRow(s.totalRevenue,
                          formatCurrency(provider.dailyRevenue), AppTheme.cream),
                      const SizedBox(height: 6),

                      // Gross profit
                      _NetRow(s.grossProfit,
                          formatCurrency(provider.dailyProfit), AppTheme.amberLight),

                      // Household expenses (if any)
                      if (provider.pendingExpenses.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _NetRow(
                            s.minusExpenses,
                            '- ${formatCurrency(provider.totalDailyExpenses)}',
                            AppTheme.redLight),
                      ],

                      // Net profit (after household expenses)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(
                            color: Colors.white.withOpacity(0.15), thickness: 1),
                      ),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.netProfit,
                                style: AppTheme.serifAmharic(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.cream)),
                            Text(formatCurrency(provider.dailyNetProfit),
                                style: AppTheme.serifAmharic(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: provider.dailyNetProfit >= 0
                                        ? AppTheme.greenLight
                                        : AppTheme.redLight)),
                          ]),

                      // Restock cost deduction
                      if (totalRestockCost > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                              color: Colors.white.withOpacity(0.15),
                              thickness: 1),
                        ),
                        _NetRow(
                            s.minusRestockCost,
                            '- ${formatCurrency(totalRestockCost)}',
                            AppTheme.redLight),
                        const SizedBox(height: 10),

                        // Net profit after restock — the FINAL number
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(s.netAfterRestock,
                                    style: AppTheme.serifAmharic(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.amberLight)),
                                Text(
                                    formatCurrency(
                                        provider.dailyNetProfitAfterRestock),
                                    style: AppTheme.serifAmharic(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: provider
                                                    .dailyNetProfitAfterRestock >=
                                                0
                                            ? AppTheme.greenLight
                                            : AppTheme.redLight)),
                              ]),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            BottomActionBar(
                label: s.markComplete,
                color: AppTheme.green,
                onPressed: () async {
                  await provider.completeDay();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }),
          ]);
        }),
      );
    });
  }
}

// ── Net row widget ─────────────────────────────────────
class _NetRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NetRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: AppTheme.sansAmharic(
                fontSize: 13, color: AppTheme.cream.withOpacity(0.65))),
        Text(value,
            style: AppTheme.serifAmharic(
                fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ]);
}
