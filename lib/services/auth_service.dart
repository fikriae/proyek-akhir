import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Register user
  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // berhasil
    } on FirebaseAuthException catch (e) {
      return _handleRegisterError(e);
    } catch (_) {
      return 'Terjadi kesalahan saat register.';
    }
  }

  /// Login user
  Future<String?> login(String email, String password) async {
    try {
      // Tambahan: jika sudah login, jangan login lagi
      if (_auth.currentUser != null) return null;

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleLoginError(e);
    } catch (_) {
      return 'Terjadi kesalahan saat login.';
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Listen to user state
  Stream<User?> get userStream => _auth.authStateChanges();

  /// Handle register error
  String _handleRegisterError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      default:
        return 'Terjadi kesalahan saat register. (${e.code})';
    }
  }

  /// Handle login error
  String _handleLoginError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email belum terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return e.message ?? 'Terjadi kesalahan saat login.';
    }
  }
}


