import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const StepIndicator({super.key, required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.paper,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (i) {
          Color color;
          if (i < currentStep - 1) {
            color = AppTheme.greenLight;
          } else if (i == currentStep - 1) color = AppTheme.amber;
          else color = AppTheme.rule;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
          );
        }),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: AppTheme.sansAmharic(fontSize: 11, color: AppTheme.brown, letterSpacing: 0.5)),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const ScreenHeader({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.serifAmharic(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown, fontStyle: FontStyle.italic)),
        const SizedBox(height: 20),
      ],
    );
  }
}

// FIX: Was a StatelessWidget that created a TextEditingController inside
// build() — leaked on every rebuild because it was never disposed. Converted
// to StatefulWidget so the controller is created once and properly disposed.
class CurrencyField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const CurrencyField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  State<CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<CurrencyField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(CurrencyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external value changes without disturbing the cursor position
    if (oldWidget.value != widget.value) {
      final newText = widget.value.toStringAsFixed(2);
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTheme.sansAmharic(fontSize: 15),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'ብር ',
        prefixStyle: AppTheme.sansAmharic(color: AppTheme.brown, fontSize: 14),
      ),
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? widget.value),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  const BottomActionBar({super.key, required this.label, required this.onPressed, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(top: BorderSide(color: AppTheme.rule)),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.ink,
          foregroundColor: AppTheme.cream,
          textStyle: AppTheme.sansAmharic(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class WarningChip extends StatelessWidget {
  final String text;
  const WarningChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.redLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(text, style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.red)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool dark;
  const StatCard({super.key, required this.label, required this.value, this.dark = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppTheme.ink : AppTheme.paper,
        borderRadius: BorderRadius.circular(12),
        border: dark ? null : Border.all(color: AppTheme.rule, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sansAmharic(fontSize: 11, color: dark ? AppTheme.amberLight : AppTheme.brown, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value, style: AppTheme.serifAmharic(fontSize: 20, fontWeight: FontWeight.w700, color: dark ? AppTheme.cream : AppTheme.ink)),
        ],
      ),
    );
  }
}

class QtyField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const QtyField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  State<QtyField> createState() => _QtyFieldState();
}
class _QtyFieldState extends State<QtyField> {
  late TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.value.toString()); }
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTheme.sansAmharic(fontSize: 15),
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
    );
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}
