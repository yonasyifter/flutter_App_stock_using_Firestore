import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(_emailCtrl.text, _passCtrl.text);
    // On success the authStateChanges stream in main.dart
    // automatically takes the user to HomeScreen
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Text(
          lang.isAmharic ? 'አዲስ መለያ' : 'Create Account',
          style: AppTheme.serifAmharic(fontSize: 20, color: AppTheme.cream),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.amberLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────
                Text(
                  lang.isAmharic ? 'መለያ ፍጠር' : 'Create your account',
                  style: AppTheme.serifAmharic(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  lang.isAmharic
                      ? 'ኢሜይልዎ ለአካውንትዎ ቁልፍ ነው። ዳታዎ ለሌሎች አይታይም።'
                      : 'Your email is your key. Your data is private and separate from all other users.',
                  style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown),
                ),

                const SizedBox(height: 32),

                // ── Error banner ────────────────────────────────
                if (auth.errorMessage != null) ...[
                  _ErrorBanner(
                    message: auth.errorMessage!,
                    onDismiss: () => context.read<AuthProvider>().clearError(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── What they get ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.greenLight),
                  ),
                  child: Column(
                    children: [
                      _BenefitRow(
                        icon: '🔒',
                        text: lang.isAmharic
                            ? 'ዳታዎ ከሌሎች ተጠቃሚዎች ሙሉ በሙሉ የተለየ ነው'
                            : 'Your data is completely separate from all other users',
                      ),
                      const SizedBox(height: 8),
                      _BenefitRow(
                        icon: '☁️',
                        text: lang.isAmharic
                            ? 'ዳታዎ በደመና ተቀምጧል — ስልክ ቢጠፋ አይጠፋም'
                            : 'Data saved in the cloud — safe even if you lose your phone',
                      ),
                      const SizedBox(height: 8),
                      _BenefitRow(
                        icon: '📧',
                        text: lang.isAmharic
                            ? 'የይለፍ ቃል ከረሱ ሊሰርዙ ይችላሉ'
                            : 'Reset your password anytime via email',
                      ),
                    ],
                  ),
                ),

                // ── Email ────────────────────────────────────────
                _FieldLabel(lang.isAmharic ? 'ኢሜይል' : 'Email'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'you@email.com',
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: AppTheme.brown, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return lang.isAmharic ? 'ኢሜይል ያስፈልጋል' : 'Email is required';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return lang.isAmharic ? 'ትክክለኛ ኢሜይል ያስገቡ' : 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── Password ─────────────────────────────────────
                _FieldLabel(lang.isAmharic ? 'የይለፍ ቃል' : 'Password'),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: lang.isAmharic ? 'ቢያንስ 6 ቁምፊዎች' : 'At least 6 characters',
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: AppTheme.brown, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.brown,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return lang.isAmharic ? 'የይለፍ ቃል ያስፈልጋል' : 'Password is required';
                    }
                    if (v.length < 6) {
                      return lang.isAmharic
                          ? 'ቢያንስ 6 ቁምፊዎች ያስፈልጋሉ'
                          : 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── Confirm password ─────────────────────────────
                _FieldLabel(lang.isAmharic ? 'የይለፍ ቃል ያረጋግጡ' : 'Confirm Password'),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: AppTheme.brown, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.brown,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) {
                      return lang.isAmharic
                          ? 'የይለፍ ቃሎቹ አይዛመዱም'
                          : 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // ── Submit ───────────────────────────────────────
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.cream),
                        )
                      : Text(
                          lang.isAmharic ? 'መለያ ፍጠር' : 'Create Account',
                          style: AppTheme.sansAmharic(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cream),
                        ),
                ),

                const SizedBox(height: 16),

                // ── Back to login ────────────────────────────────
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    lang.isAmharic ? 'ወደ ግባ ተመለስ' : 'Back to Sign In',
                    style: AppTheme.sansAmharic(fontSize: 15, color: AppTheme.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: AppTheme.sansAmharic(
              fontSize: 12, color: AppTheme.brown, letterSpacing: 0.5)),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.green))),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.redLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.red))),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppTheme.red, size: 16),
          ),
        ],
      ),
    );
  }
}
