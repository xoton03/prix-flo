import 'package:firebase_auth/firebase_auth.dart';

// ──────────────────────────────────────────────────────────────
// AuthService – Service Firebase Authentication centralisé
// ──────────────────────────────────────────────────────────────
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream de l'état de connexion
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur courant (null si non connecté)
  static User? get currentUser => _auth.currentUser;

  /// Connexion par email + mot de passe
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Inscription par email + mot de passe
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Déconnexion
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Message d'erreur lisible en français
  static String friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé pour cet email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion.';
      default:
        return 'Erreur inattendue. Veuillez réessayer.';
    }
  }
}
