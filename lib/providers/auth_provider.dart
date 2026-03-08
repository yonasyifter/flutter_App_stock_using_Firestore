import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// All possible states the auth flow can be in
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  AuthStatus _status = AuthStatus.unknown;
  String? _errorMessage;
  bool _isLoading = false;

  // ── Getters ──────────────────────────────────────
  User? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// The uid of the signed-in user — used to scope Firestore data
  String? get uid => _user?.uid;
  String? get email => _user?.email;

  AuthProvider() {
    // Listen to Firebase auth state changes — fires immediately on startup
    // and again every time the user signs in or out
    _auth.authStateChanges().listen((user) {
      _user = user;
      _status = user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  // ── Helpers ──────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Converts Firebase error codes into human-readable messages
  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ── Sign Up ──────────────────────────────────────
  /// Creates a new Firebase account. Each user gets their own
  /// Firestore sub-tree scoped to their uid.
  Future<bool> signUp(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
      _setLoading(false);
      return false;
    }
  }

  // ── Sign In ──────────────────────────────────────
  Future<bool> signIn(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
      _setLoading(false);
      return false;
    }
  }

  // ── Sign Out ─────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    // authStateChanges listener above will automatically update status
  }

  // ── Password Reset ───────────────────────────────
  /// Sends a password reset link to the given email address.
  /// Returns true on success, false on failure.
  Future<bool> sendPasswordReset(String email) async {
    _setError(null);
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e));
      _setLoading(false);
      return false;
    }
  }
}
