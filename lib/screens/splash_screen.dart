import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'store_hub_screen.dart';
import 'login_screen.dart';

// ──────────────────────────────────────────────────────────────
// SplashScreen – Écran de démarrage TagUp
// ──────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _creditCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _creditFade;

  @override
  void initState() {
    super.initState();

    // Logo : fade + scale
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );

    // Nom de l'app : fade + slide
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Crédit : fade doux
    _creditCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _creditFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _creditCtrl, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    debugPrint("Splash: Initialisation des animations...");
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _creditCtrl.forward();

    // Navigation conditionnelle après le splash
    debugPrint("Splash: Attente du délai de 2500ms...");
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      debugPrint("Splash: Délai terminé. Vérification de l'état Firebase...");
      bool isLoggedIn = false;
      try {
        isLoggedIn = AuthService.currentUser != null;
        debugPrint("Splash: Statut de connexion Firebase = \$isLoggedIn");
      } catch (e) {
        debugPrint("Splash: Erreur lors de la vérification Firebase: \$e");
        // En cas d'erreur (ex: non initialisé), on force vers le LoginScreen
        isLoggedIn = false;
      }

      debugPrint("Splash: Navigation vers \${isLoggedIn ? 'StoreHubScreen' : 'LoginScreen'}...");
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) =>
              isLoggedIn ? const StoreHubScreen() : const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      debugPrint("Splash: Widget démonté, annulation de la navigation.");
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dégradé de fond : sombre ou clair selon le thème
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9FF), Color(0xFFEEF2FF), Color(0xFFF5F5F5)],
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            // ── Bulles décoratives de fond ─────────────────────
            Positioned(
              top: -80,
              right: -80,
              child: _GlowCircle(
                size: 280,
                color: const Color(0xFFFF8C00),
                opacity: isDark ? 0.06 : 0.08,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: _GlowCircle(
                size: 320,
                color: const Color(0xFF1565C0),
                opacity: isDark ? 0.05 : 0.07,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: -40,
              child: _GlowCircle(
                size: 160,
                color: const Color(0xFFFF6000),
                opacity: isDark ? 0.04 : 0.05,
              ),
            ),

            // ── Contenu centré ─────────────────────────────────
            Column(
              children: [
                // Centre : logo + nom
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo animé
                        ScaleTransition(
                          scale: _logoScale,
                          child: FadeTransition(
                            opacity: _logoFade,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8C00)
                                        .withOpacity(0.30),
                                    blurRadius: 40,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(36),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Nom "TagUp" animé
                        SlideTransition(
                          position: _textSlide,
                          child: FadeTransition(
                            opacity: _textFade,
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFFFF8C00),
                                      Color(0xFFFF4500),
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'TagUp',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Outils magasin',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Crédit en bas ───────────────────────────────
                FadeTransition(
                  opacity: _creditFade,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 52),
                    child: Column(
                      children: [
                        // Ligne décorative
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '✦',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Développé par',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sayah Anis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget décoratif : cercle lumineux ──────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 0.6),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
