import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _firebaseUser;
  UserModel? _userModel;
  AuthStatus _status = AuthStatus.unknown;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Constructor ───────────────────────────────────────────────────────────

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadUserModel(user.uid);
        _status = AuthStatus.authenticated;
      } else {
        _userModel = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel(String uid) async {
    try {
      _userModel = await _authService.getUserProfile(uid);

      // If no Firestore doc exists (user pre-dates this app or signed in via
      // a different flow), create one automatically so the app works.
      if (_userModel == null && _firebaseUser != null) {
        final fbUser = _firebaseUser!;
        final newUser = UserModel(
          uid: uid,
          name: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
          email: fbUser.email ?? '',
          role: UserRole.both, // default to both (dual-role)
          createdAt: DateTime.now(),
        );
        await _authService.createUserProfile(newUser);
        _userModel = newUser;
        debugPrint('[AuthProvider] Created missing Firestore user doc for $uid');
      }

      // Start streaming for live updates
      _firestoreService.streamUser(uid).listen((model) {
        if (model != null) {
          _userModel = model;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      _userModel = await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithEmail(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Sign in failed. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
  }

  // ── Update Role ───────────────────────────────────────────────────────────

  Future<void> updateRole(UserRole newRole) async {
    if (_userModel == null) return;
    try {
      await _authService.updateUserRole(_userModel!.uid, newRole);
      _userModel = _userModel!.copyWith(role: newRole);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Error updating role: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication error. Please try again.';
    }
  }
}
