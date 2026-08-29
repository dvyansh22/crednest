import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      return UserModel(
        id: credential.user!.uid,
        email: credential.user!.email,
        name: name,
        createdAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      print('FIREBASE ERROR CODE: ${e.code}');
      print('FIREBASE ERROR MESSAGE: ${e.message}');
      throw Exception(_mapFirebaseError(e));
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return UserModel(
        id: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
        createdAt: credential.user!.metadata.creationTime ?? DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      print('FIREBASE ERROR CODE: ${e.code}');
      print('FIREBASE ERROR MESSAGE: ${e.message}');
      throw Exception(_mapFirebaseError(e));
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  UserModel? getCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      email: user.email,
      name: user.displayName,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'network-request-failed':
        return 'No internet connection. Please check your Wi-Fi or cellular network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}