import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'product_setup_screen.dart';
import 'day_flow/purchases_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _unlockedDay;
  Timer? _unlockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.loadProducts().then((_) {
        provider.loadMonthEntries(_focusedDay);
        if (provider.products.isEmpty) _showSetupModal();
      });
    });
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  // ── Date helpers ───────────────────────────────────────────────────────────

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  bool _isYesterday(DateTime day) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return day.year == yesterday.year &&
        day.month == yesterday.month &&
        day.day == yesterday.day;
  }

  bool _isAllowedDay(DateTime day) => _isToday(day) || _isYesterday(day);

  bool _isUnlocked(DateTime day) =>
      _unlockedDay != null &&
          day.year == _unlockedDay!.year &&
          day.month == _unlockedDay!.month &&
          day.day == _unlockedDay!.day;

  bool _isFuture(DateTime day) => day.isAfter(DateTime.now());

  // ── Unlock a day for 5 minutes ─────────────────────────────────────────────

  void _unlockDay(DateTime day) {
    _unlockTimer?.cancel();
    setState(() => _unlockedDay = day);
    _unlockTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) setState(() => _unlockedDay = null);
    });
  }

  // ── Show countdown dialog then unlock ──────────────────────────────────────

  void _showCountdownAndUnlock(DateTime day) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(
        onComplete: () {
          _unlockDay(day);
          final provider = context.read<AppProvider>();
          _openDay(context, provider, day);
        },
      ),
    );
  }

  // ── Restriction warning dialog ─────────────────────────────────────────────

  void _showRestrictedDialog(DateTime day) {
    final bool isFuture = _isFuture(day);
    final String formattedDate = DateFormat('MMMM d, yyyy').format(day);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            isFuture ? Icons.update_rounded : Icons.history_rounded,
            color: AppTheme.red,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            isFuture ? 'Future Date' : 'Past Date',
            style: AppTheme.serifAmharic(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ]),
        content: Text(
          isFuture
              ? 'You are trying to modify future data for\n$formattedDate.\n\nDo you still want to proceed?'
              : 'You are trying to modify past data for\n$formattedDate.\n\nDo you still want to proceed?',
          style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.sansAmharic(
                    fontSize: 14, color: AppTheme.brown)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showCountdownAndUnlock(day);
            },
            child: Text(
              'Yes, Proceed',
              style: AppTheme.sansAmharic(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.cream),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day tap handler ────────────────────────────────────────────────────────

  void _handleDayTap(
      BuildContext context, AppProvider provider, DateTime day) {
    if (!provider.hasProductsOnDay(day)) return;
    if (_isAllowedDay(day) || _isUnlocked(day)) {
      _openDay(context, provider, day);
    } else {
      _showRestrictedDialog(day);
    }
  }

  // ── Setup modal ────────────────────────────────────────────────────────────

  void _showSetupModal() {
    final s = context.read<LanguageProvider>().s;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.welcomeTitle} 🛒',
                style: AppTheme.serifAmharic(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(s.welcomeBody,
                style: AppTheme.sansAmharic(
                    fontSize: 13,
                    color: AppTheme.brown,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ProductSetupScreen()));
              },
              child: Text(s.setupProducts,
                  style: AppTheme.sansAmharic(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.cream)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.doLater,
                  style:
                  AppTheme.sansAmharic(fontSize: 15, color: AppTheme.ink)),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  // ── Language picker ────────────────────────────────────────────────────────

  void _showLanguagePicker() {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ChangeNotifierProvider.value(
        value: lang,
        child: Consumer<LanguageProvider>(
          builder: (ctx, l, _) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.s.selectLanguage,
                    style: AppTheme.serifAmharic(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _LangOption(
                  flagText: 'ET',
                  label: 'አማርኛ',
                  sublabel: 'Amharic',
                  selected: l.isAmharic,
                  onTap: () {
                    l.setAmharic(true);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 12),
                _LangOption(
                  flagText: 'EN',
                  label: 'English',
                  sublabel: 'English',
                  selected: !l.isAmharic,
                  onTap: () {
                    l.setAmharic(false);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<AppProvider, LanguageProvider>(
        builder: (context, provider, lang, _) {
          final s = lang.s;
          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                title: Row(children: [
                  Text(s.appNamePart1,
                      style: AppTheme.serifAmharic(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.cream)),
                  Text(s.appNamePart2,
                      style: AppTheme.serifAmharic(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.amberLight)),
                ]),
                actions: [
                  // Language toggle pill
                  GestureDetector(
                    onTap: _showLanguagePicker,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.amberLight.withOpacity(0.6)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language,
                              size: 13, color: AppTheme.amberLight),
                          const SizedBox(width: 4),
                          Text(
                            lang.isAmharic ? 'አማርኛ' : 'EN',
                            style: AppTheme.sansAmharic(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.amberLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.inventory_2_outlined),
                    tooltip: s.manageProducts,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProductSetupScreen()))
                        .then((_) =>
                        provider.loadMonthEntries(_focusedDay)),
                  ),
                  // Account popup menu (Firebase Auth — kept from Firebase version)
                  Consumer<AuthProvider>(
                    builder: (ctx, auth, _) =>
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.account_circle_outlined,
                              color: AppTheme.amberLight),
                          color: AppTheme.paper,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        lang.isAmharic
                                            ? 'የተገባው'
                                            : 'Signed in as',
                                        style: AppTheme.sansAmharic(
                                            fontSize: 11,
                                            color: AppTheme.brown)),
                                    const SizedBox(height: 2),
                                    Text(auth.email ?? '',
                                        style: AppTheme.sansAmharic(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    const Divider(height: 16),
                                  ]),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(children: [
                                const Icon(Icons.logout,
                                    size: 18, color: AppTheme.red),
                                const SizedBox(width: 10),
                                Text(
                                    lang.isAmharic ? 'ውጣ' : 'Sign Out',
                                    style: AppTheme.sansAmharic(
                                        fontSize: 14,
                                        color: AppTheme.red)),
                              ]),
                            ),
                          ],
                          onSelected: (val) async {
                            if (val == 'logout') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  backgroundColor: AppTheme.paper,
                                  title: Text(
                                      lang.isAmharic ? 'ይወጡ?' : 'Sign out?',
                                      style: AppTheme.serifAmharic(
                                          fontSize: 20)),
                                  content: Text(
                                    lang.isAmharic
                                        ? 'ዳታዎ ተቀምጧል። ማንኛውም ጊዜ ሊመለሱ ይችላሉ።'
                                        : 'Your data is saved. You can sign back in anytime.',
                                    style: AppTheme.sansAmharic(
                                        fontSize: 13,
                                        color: AppTheme.brown),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, false),
                                      child: Text(
                                          lang.isAmharic ? 'ሰርዝ' : 'Cancel',
                                          style: AppTheme.sansAmharic(
                                              fontSize: 14,
                                              color: AppTheme.brown)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, true),
                                      child: Text(
                                          lang.isAmharic ? 'ውጣ' : 'Sign Out',
                                          style: AppTheme.sansAmharic(
                                              fontSize: 14,
                                              color: AppTheme.red,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && ctx.mounted) {
                                await ctx.read<AuthProvider>().signOut();
                              }
                            }
                          },
                        ),
                  ),
                ],
              ),

              // ── Calendar ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  locale: lang.isAmharic ? 'am' : 'en_US',
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: AppTheme.serifAmharic(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    leftChevronIcon: const Icon(Icons.chevron_left,
                        color: AppTheme.brown),
                    rightChevronIcon: const Icon(Icons.chevron_right,
                        color: AppTheme.brown),
                    headerPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: AppTheme.sansAmharic(
                        fontSize: 12, color: AppTheme.brown),
                    weekendStyle: AppTheme.sansAmharic(
                        fontSize: 12, color: AppTheme.brown),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: AppTheme.sansAmharic(fontSize: 14),
                    weekendTextStyle: AppTheme.sansAmharic(fontSize: 14),
                    todayDecoration: BoxDecoration(
                      border:
                      Border.all(color: AppTheme.amber, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    todayTextStyle: AppTheme.sansAmharic(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    selectedDecoration: BoxDecoration(
                        color: AppTheme.amber,
                        borderRadius: BorderRadius.circular(8)),
                    cellMargin: const EdgeInsets.all(4),
                    outsideDaysVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (ctx, day, _) {
                      final hasProducts = provider.hasProductsOnDay(day);
                      final entry = provider.getEntryForDay(day.day);
                      final isRestricted =
                          !_isAllowedDay(day) && !_isUnlocked(day);

                      // ── No products exist for this day ─────────────────
                      if (!hasProducts) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EDE8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${day.day}',
                                style: AppTheme.sansAmharic(
                                    fontSize: 13,
                                    color: AppTheme.brown
                                        .withOpacity(0.35))),
                          ),
                        );
                      }

                      // ── Locked / restricted day ────────────────────────
                      if (isRestricted) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${day.day}',
                                    style: AppTheme.sansAmharic(
                                        fontSize: 13,
                                        color: AppTheme.brown
                                            .withOpacity(0.3))),
                                Icon(Icons.lock_outline_rounded,
                                    size: 8,
                                    color:
                                    AppTheme.brown.withOpacity(0.25)),
                              ],
                            ),
                          ),
                        );
                      }

                      // ── Temporarily unlocked day ───────────────────────
                      if (_isUnlocked(day)) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.red.withOpacity(0.5),
                                width: 1.5),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${day.day}',
                                    style: AppTheme.sansAmharic(
                                        fontSize: 13,
                                        color: AppTheme.red)),
                                Icon(Icons.lock_open_rounded,
                                    size: 8,
                                    color:
                                    AppTheme.red.withOpacity(0.7)),
                              ],
                            ),
                          ),
                        );
                      }

                      // ── Has products but no entry yet ──────────────────
                      if (entry == null) return null;

                      // ── Entry exists: green = complete, red = in-progress
                      final color = entry.complete
                          ? AppTheme.greenLight
                          : AppTheme.redLight;
                      final bg = entry.complete
                          ? const Color(0xFFEDF7F2)
                          : const Color(0xFFFFF2EE);
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color)),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${day.day}',
                                  style:
                                  AppTheme.sansAmharic(fontSize: 13)),
                              Text(entry.complete ? '✓' : '…',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      height: 1.2)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  onPageChanged: (day) {
                    setState(() => _focusedDay = day);
                    provider.loadMonthEntries(day);
                  },
                  onDaySelected: (selected, focused) {
                    setState(() => _focusedDay = focused);
                    _handleDayTap(context, provider, selected);
                  },
                ),
              ),

              // ── Monthly summary card ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppTheme.ink,
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Row(children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_focusedDay),
                          style: AppTheme.serifAmharic(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.amberLight),
                        ),
                        const Spacer(),
                        Text(
                          '${provider.completedDaysCount} ${s.daysLogged}',
                          style: AppTheme.sansAmharic(
                              fontSize: 11,
                              color: AppTheme.cream.withOpacity(0.5)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: _SummaryItem(
                                label: s.totalRevenue,
                                value: formatCurrency(
                                    provider.monthlyRevenue))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _SummaryItem(
                                label: s.netProfit,
                                value: formatCurrency(
                                    provider.monthlyNetProfit))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _SummaryItem(
                                label: s.expensesLabel,
                                value: formatCurrency(
                                    provider.monthlyExpenses))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _SummaryItem(
                                label: s.monthlyRestockCost,
                                value: formatCurrency(
                                    provider.monthlyRestockCost),
                                valueColor: AppTheme.red)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _SummaryItem(
                                label: s.bestDay,
                                value: provider.bestDay ?? '-')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _SummaryItem(
                                label: s.monthlyNetAfterRestock,
                                value: formatCurrency(provider
                                    .monthlyNetProfitAfterRestock),
                                valueColor:
                                provider.monthlyNetProfitAfterRestock >=
                                    0
                                    ? AppTheme.greenLight
                                    : AppTheme.red)),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ── Yesterday's daily summary ─────────────────────────────
              Builder(builder: (_) {
                final yesterday =
                DateTime.now().subtract(const Duration(days: 1));
                // Use fullMonthEntries which includes purchases/sales/openingStock
                final yesterdayEntry = provider.fullMonthEntries
                    .where((e) =>
                e.date.year == yesterday.year &&
                    e.date.month == yesterday.month &&
                    e.date.day == yesterday.day)
                    .firstOrNull;

                if (yesterdayEntry == null || !yesterdayEntry.complete) {
                  return const SliverToBoxAdapter(
                      child: SizedBox.shrink());
                }

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(children: [
                          Text(s.dailySummary,
                              style: AppTheme.serifAmharic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            DateFormat('MMM d').format(yesterday),
                            style: AppTheme.sansAmharic(
                                fontSize: 12, color: AppTheme.brown),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        // Stock table
                        Card(
                          margin: const EdgeInsets.all(0),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 34,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 52,
                                columnSpacing: 12,
                                headingTextStyle: AppTheme.sansAmharic(
                                    fontSize: 10,
                                    color: AppTheme.brown,
                                    letterSpacing: 0.5),
                                dataTextStyle:
                                AppTheme.sansAmharic(fontSize: 12),
                                columns: [
                                  DataColumn(
                                      label: Text(s.colProduct)),
                                  DataColumn(
                                      label: Text(s.colOpen),
                                      numeric: true),
                                  DataColumn(
                                      label: Text(s.colBought),
                                      numeric: true),
                                  DataColumn(
                                      label: Text(s.colSold),
                                      numeric: true),
                                  DataColumn(
                                      label: Text(s.colClose),
                                      numeric: true),
                                  DataColumn(
                                      label: Text(s.colRevenue),
                                      numeric: true),
                                ],
                                rows: provider.activeProducts.map((p) {
                                  // Use firestoreId for Firebase version
                                  final opening = yesterdayEntry
                                      .openingStock[p.firestoreId] ??
                                      0;
                                  final bought = yesterdayEntry.purchases
                                      .where((x) =>
                                  x.productId == p.firestoreId)
                                      .fold(0,
                                          (sum, x) => sum + x.qty);
                                  final sold = yesterdayEntry.sales
                                      .where((x) =>
                                  x.productId == p.firestoreId)
                                      .fold(
                                      0,
                                          (sum, x) =>
                                      sum + x.qtySold);
                                  final closing =
                                  (opening + bought - sold)
                                      .clamp(0, 99999);
                                  return DataRow(cells: [
                                    DataCell(Text(p.name,
                                        style: AppTheme.sansAmharic(
                                            fontSize: 13,
                                            fontWeight:
                                            FontWeight.w600))),
                                    DataCell(Text('$opening')),
                                    DataCell(Text('+$bought')),
                                    DataCell(Text('$sold')),
                                    DataCell(Text('$closing',
                                        style: TextStyle(
                                            color: closing <= 3
                                                ? AppTheme.red
                                                : AppTheme.ink))),
                                    DataCell(Text(formatCurrency(
                                        sold * p.sellPrice))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ── Open day ───────────────────────────────────────────────────────────────

  void _openDay(
      BuildContext context, AppProvider provider, DateTime day) async {
    if (!provider.hasProductsOnDay(day)) return;
    if (provider.activeProducts.isEmpty) {
      _showSetupModal();
      return;
    }
    await provider.openDay(day);
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PurchasesScreen(date: day)))
        .then((_) => provider.loadMonthEntries(_focusedDay));
  }
}

// ── Self-contained countdown dialog ───────────────────────────────────────────

class _CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;
  const _CountdownDialog({required this.onComplete});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  static const int _totalSeconds = 30;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        Navigator.of(context).pop();
        widget.onComplete();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.paper,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.hourglass_top_rounded,
            color: AppTheme.amber, size: 22),
        const SizedBox(width: 8),
        Text('Please Wait',
            style: AppTheme.serifAmharic(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are about to modify restricted data.\nPlease wait before proceeding.',
            style:
            AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: _secondsLeft / _totalSeconds,
                  strokeWidth: 5,
                  backgroundColor: AppTheme.amber.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.amber),
                ),
              ),
              Text(
                '$_secondsLeft',
                style: AppTheme.serifAmharic(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'seconds remaining',
            style: AppTheme.sansAmharic(
                fontSize: 12,
                color: AppTheme.brown.withOpacity(0.7)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style:
              AppTheme.sansAmharic(fontSize: 14, color: AppTheme.red)),
        ),
      ],
    );
  }
}

// ── Language option tile ───────────────────────────────────────────────────────

class _LangOption extends StatelessWidget {
  final String flagText;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.flagText,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.ink : AppTheme.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.amber : AppTheme.rule,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.amber.withOpacity(0.2)
                  : const Color(0xFFF0EBE3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                flagText,
                style: AppTheme.serifAmharic(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppTheme.amberLight
                        : AppTheme.brown),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.serifAmharic(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                        selected ? AppTheme.cream : AppTheme.ink)),
                Text(sublabel,
                    style: AppTheme.sansAmharic(
                        fontSize: 12,
                        color: selected
                            ? AppTheme.amberLight
                            : AppTheme.brown)),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.amber, size: 22),
        ]),
      ),
    );
  }
}

// ── Summary item ───────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryItem(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.sansAmharic(
                fontSize: 10,
                color: AppTheme.amberLight.withOpacity(0.7),
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: AppTheme.serifAmharic(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppTheme.cream)),
      ],
    );
  }
}