import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/app_provider.dart';
import '../providers/language_provider.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class ProductSetupScreen extends StatefulWidget {
  const ProductSetupScreen({super.key});

  @override
  State<ProductSetupScreen> createState() => _ProductSetupScreenState();
}

class _ProductSetupScreenState extends State<ProductSetupScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch latest closing stock levels for all products
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().loadClosingStockCache();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (_, lang, __) => Text(lang.s.products,
              style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream)),
        ),
        actions: [
          Consumer<LanguageProvider>(
            builder: (ctx, lang, __) => TextButton.icon(
              onPressed: () => _showAddProduct(ctx),
              icon: const Icon(Icons.add, color: AppTheme.amberLight),
              label: Text(lang.s.add,
                  style: AppTheme.sansAmharic(
                      color: AppTheme.amberLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Consumer2<AppProvider, LanguageProvider>(
        builder: (context, provider, lang, _) {
          final s = lang.s;
          final active = provider.products.where((p) => p.active).toList();

          if (active.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(s.noProducts,
                        style: AppTheme.serifAmharic(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(s.noProductsSub,
                        textAlign: TextAlign.center,
                        style: AppTheme.sansAmharic(
                            fontSize: 13,
                            color: AppTheme.brown,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _showAddProduct(context),
                      child: Text(s.addFirstProduct,
                          style: AppTheme.sansAmharic(
                              fontSize: 15,
                              color: AppTheme.cream,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ScreenHeader(title: s.productList, subtitle: s.productListSub),
              ...active.map((p) => _ProductTile(product: p)),
            ],
          );
        },
      ),
    );
  }

  void _showAddProduct(BuildContext context, {Product? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddProductSheet(existing: existing, parentContext: context),
    );
  }
}

// ── Product tile ──────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final provider = context.watch<AppProvider>();
    final s = lang.s;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: AppTheme.sansAmharic(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${s.buy}: ${formatCurrency(product.buyPrice)}  ·  '
                    '${s.sell}: ${formatCurrency(product.sellPrice)}',
                    style:
                        AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown),
                  ),
                  Text(
                    s.openingStockLabel(provider.getProductCurrentStock(product.firestoreId!)),
                    style:
                        AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.brown),
              color: AppTheme.paper,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'edit') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppTheme.paper,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    // Pass outer context so _AddProductSheet can read providers
                    builder: (sheetCtx) => _AddProductSheet(
                      existing: product,
                      parentContext: context,
                    ),
                  );
                } else if (val == 'deactivate') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.paper,
                      title: Text(s.deactivateTitle,
                          style: AppTheme.serifAmharic(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      content: Text(s.deactivateBody,
                          style: AppTheme.sansAmharic(
                              fontSize: 14, color: AppTheme.brown)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.cancel,
                              style: AppTheme.sansAmharic(
                                  fontSize: 14, color: AppTheme.brown)),
                        ),
                        TextButton(
                          onPressed: () {
                            // Use firestoreId — the Firebase document ID
                            context
                                .read<AppProvider>()
                                .deactivateProduct(product.firestoreId!);
                            Navigator.pop(ctx);
                          },
                          child: Text(s.deactivate,
                              style: AppTheme.sansAmharic(
                                  fontSize: 14, color: AppTheme.red)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'edit',
                    child: Text(s.edit,
                        style: AppTheme.sansAmharic(fontSize: 14))),
                PopupMenuItem(
                    value: 'deactivate',
                    child: Text(s.deactivate,
                        style: AppTheme.sansAmharic(
                            fontSize: 14, color: AppTheme.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit product sheet ──────────────────────────
class _AddProductSheet extends StatefulWidget {
  final Product? existing;
  final BuildContext parentContext; // outer context that has Provider
  const _AddProductSheet({this.existing, required this.parentContext});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _buyCtrl, _sellCtrl, _stockCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _buyCtrl = TextEditingController(
        text: widget.existing?.buyPrice.toStringAsFixed(2) ?? '');
    _sellCtrl = TextEditingController(
        text: widget.existing?.sellPrice.toStringAsFixed(2) ?? '');
    _stockCtrl = TextEditingController(
        text: (widget.existing?.openingStock ?? 0).toString());
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final s = lang.s;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? s.editProduct : s.addProduct,
                style: AppTheme.serifAmharic(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(s.productDetails,
                style: AppTheme.sansAmharic(
                    fontSize: 13,
                    color: AppTheme.brown,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _nameCtrl,
              style: AppTheme.sansAmharic(fontSize: 15),
              decoration: InputDecoration(labelText: s.productName),
              validator: (v) =>
                  (v == null || v.isEmpty) ? s.required : null,
            ),
            const SizedBox(height: 12),

            // Buy / Sell prices side by side
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _buyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration:
                      InputDecoration(labelText: s.buyPrice, prefixText: 'ብር '),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? s.invalid : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sellCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration:
                      InputDecoration(labelText: s.sellPrice, prefixText: 'ብር '),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? s.invalid : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Opening stock
            TextFormField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              style: AppTheme.sansAmharic(fontSize: 15),
              decoration:
                  InputDecoration(labelText: s.openingStockUnits),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: _save,
              child: Text(
                  isEditing ? s.saveChanges : s.addProduct,
                  style: AppTheme.sansAmharic(
                      fontSize: 15,
                      color: AppTheme.cream,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel,
                  style: AppTheme.sansAmharic(fontSize: 15, color: AppTheme.ink)),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // Use parentContext — the sheet's own context is a new route and
    // cannot find Provider ancestors above the MaterialApp
    final provider = widget.parentContext.read<AppProvider>();
    final product = Product(
      firestoreId: widget.existing?.firestoreId, // null = new product
      name: _nameCtrl.text.trim(),
      buyPrice: double.parse(_buyCtrl.text),
      sellPrice: double.parse(_sellCtrl.text),
      openingStock: int.tryParse(_stockCtrl.text) ?? 0,
      // FIX: Preserve the original createdAt when editing an existing product.
      // Without this, editing any product resets createdAt to today, which
      // breaks visibleOnDay() and hides the product from all past day entries.
      createdAt: widget.existing?.createdAt,
    );
    if (widget.existing != null) {
      provider.updateProduct(product);
    } else {
      provider.addProduct(product);
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }
}
