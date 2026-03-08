import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false; // shows success state after sending

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(_emailCtrl.text);
    if (success && mounted) {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Text(
          lang.isAmharic ? 'የይለፍ ቃል ዳግም ማስጀመር' : 'Reset Password',
          style: AppTheme.serifAmharic(fontSize: 18, color: AppTheme.cream),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.amberLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: _emailSent
              ? _SuccessView(
                  email: _emailCtrl.text.trim(),
                  isAmharic: lang.isAmharic,
                  onBack: () => Navigator.pop(context),
                )
              : _FormView(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  isAmharic: lang.isAmharic,
                  isLoading: auth.isLoading,
                  errorMessage: auth.errorMessage,
                  onSubmit: _submit,
                  onDismissError: () => context.read<AuthProvider>().clearError(),
                  onBack: () => Navigator.pop(context),
                ),
        ),
      ),
    );
  }
}

// ── Form view (before sending) ───────────────────────
class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isAmharic;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onDismissError;
  final VoidCallback onBack;

  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.isAmharic,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
    required this.onDismissError,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.amber.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🔑', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            isAmharic ? 'የይለፍ ቃልዎን ረሱ?' : 'Forgot your password?',
            style: AppTheme.serifAmharic(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            isAmharic
                ? 'ኢሜይልዎን ያስገቡ። የዳግም ማስጀመሪያ ሊንክ ወዲያው ይልካሎታል።'
                : 'Enter your email address and we\'ll send you a password reset link right away.',
            style: AppTheme.sansAmharic(fontSize: 14, color: AppTheme.brown),
          ),

          const SizedBox(height: 32),

          // Error banner
          if (errorMessage != null) ...[
            Container(
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
                      child: Text(errorMessage!,
                          style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.red))),
                  GestureDetector(
                    onTap: onDismissError,
                    child: const Icon(Icons.close, color: AppTheme.red, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Email field
          Text(
            isAmharic ? 'ኢሜይል' : 'Email',
            style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: AppTheme.sansAmharic(fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'you@email.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.brown, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return isAmharic ? 'ኢሜይል ያስፈልጋል' : 'Email is required';
              }
              if (!v.contains('@')) {
                return isAmharic ? 'ትክክለኛ ኢሜይል ያስገቡ' : 'Enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 28),

          // Send button
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cream),
                  )
                : Text(
                    isAmharic ? 'ሊንክ ላክ' : 'Send Reset Link',
                    style: AppTheme.sansAmharic(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.cream),
                  ),
          ),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: onBack,
            child: Text(
              isAmharic ? 'ወደ ግባ ተመለስ' : 'Back to Sign In',
              style: AppTheme.sansAmharic(fontSize: 15, color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success view (after sending) ─────────────────────
class _SuccessView extends StatelessWidget {
  final String email;
  final bool isAmharic;
  final VoidCallback onBack;

  const _SuccessView({
    required this.email,
    required this.isAmharic,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success icon
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppTheme.greenLight.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('✉️', style: TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 24),

        Text(
          isAmharic ? 'ሊንክ ተላከ!' : 'Check your email!',
          style: AppTheme.serifAmharic(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.green),
        ),
        const SizedBox(height: 12),
        Text(
          isAmharic
              ? 'ወደ $email የዳግም ማስጀመሪያ ሊንክ ተልኳል።\nኢሜይልዎን ፈትሸው ሊንኩን ጠቅ ያድርጉ።'
              : 'We sent a password reset link to:\n$email\n\nCheck your inbox and click the link to set a new password.',
          style: AppTheme.sansAmharic(fontSize: 14, color: AppTheme.brown),
        ),

        const SizedBox(height: 16),

        // Tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.amberLight.withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAmharic
                      ? 'ኢሜይሉ ካልታየ Spam/Junk ፎልደርዎን ይፈትሹ።'
                      : "Can't find the email? Check your Spam or Junk folder.",
                  style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: onBack,
          child: Text(
            isAmharic ? 'ወደ ግባ ተመለስ' : 'Back to Sign In',
            style: AppTheme.sansAmharic(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.cream),
          ),
        ),
      ],
    );
  }
}
