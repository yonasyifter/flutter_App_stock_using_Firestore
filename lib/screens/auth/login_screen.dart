import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.signIn(_emailCtrl.text, _passCtrl.text);
    // If successful, AuthWrapper in main.dart automatically navigates
    // to HomeScreen via authStateChanges stream — no manual push needed
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();
    final s = lang.s;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Brand ──────────────────────────────────────
                const SizedBox(height: 24),
                Row(children: [
                  Text('ስቶክ',
                      style: AppTheme.serifAmharic(
                          fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                  Text('ቡክ',
                      style: AppTheme.serifAmharic(
                          fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.amber)),
                ]),
                const SizedBox(height: 6),
                Text(
                  lang.isAmharic
                      ? 'እንኳን ደህና መጡ። ይግቡ።'
                      : 'Welcome back. Sign in to continue.',
                  style: AppTheme.sansAmharic(fontSize: 14, color: AppTheme.brown),
                ),

                const SizedBox(height: 48),

                // ── Error banner ────────────────────────────────
                if (auth.errorMessage != null) ...[
                  _ErrorBanner(
                    message: auth.errorMessage!,
                    onDismiss: () => context.read<AuthProvider>().clearError(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ────────────────────────────────────────
                Text(lang.isAmharic ? 'ኢሜይል' : 'Email',
                    style: AppTheme.sansAmharic(
                        fontSize: 12, color: AppTheme.brown, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'you@email.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.brown, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return lang.isAmharic ? 'ኢሜይል ያስፈልጋል' : 'Email is required';
                    }
                    if (!v.contains('@')) {
                      return lang.isAmharic ? 'ትክክለኛ ኢሜይል ያስገቡ' : 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ── Password ─────────────────────────────────────
                Text(lang.isAmharic ? 'የይለፍ ቃል' : 'Password',
                    style: AppTheme.sansAmharic(
                        fontSize: 12, color: AppTheme.brown, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  style: AppTheme.sansAmharic(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.brown, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppTheme.brown,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return lang.isAmharic ? 'የይለፍ ቃል ያስፈልጋል' : 'Password is required';
                    }
                    return null;
                  },
                ),

                // ── Forgot password ──────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: Text(
                      lang.isAmharic ? 'የይለፍ ቃል ረሳሁ?' : 'Forgot password?',
                      style: AppTheme.sansAmharic(
                          fontSize: 13, color: AppTheme.amber, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Sign in button ───────────────────────────────
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
                          lang.isAmharic ? 'ግባ' : 'Sign In',
                          style: AppTheme.sansAmharic(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cream),
                        ),
                ),

                const SizedBox(height: 32),

                // ── Divider ──────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: AppTheme.rule)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(lang.isAmharic ? 'ወይም' : 'OR',
                        style: AppTheme.sansAmharic(fontSize: 12, color: AppTheme.brown)),
                  ),
                  const Expanded(child: Divider(color: AppTheme.rule)),
                ]),

                const SizedBox(height: 24),

                // ── Sign up link ─────────────────────────────────
                OutlinedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: Text(
                    lang.isAmharic ? 'አዲስ መለያ ፍጠር' : 'Create new account',
                    style: AppTheme.sansAmharic(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Language switcher ────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => context.read<LanguageProvider>().toggle(),
                    child: Text(
                      lang.isAmharic ? 'Switch to English' : 'አማርኛ ቀይር',
                      style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.brown),
                    ),
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
                style: AppTheme.sansAmharic(fontSize: 13, color: AppTheme.red)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: AppTheme.red, size: 16),
          ),
        ],
      ),
    );
  }
}
