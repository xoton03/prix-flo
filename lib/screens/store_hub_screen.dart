import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tagup_screen.dart';

import 'dart:async';
import 'dart:io';

// ──────────────────────────────────────────────────────────────
// StoreHubScreen – Écran d'accueil "TagUp"
// ──────────────────────────────────────────────────────────────
class StoreHubScreen extends StatefulWidget {
  const StoreHubScreen({super.key});

  @override
  State<StoreHubScreen> createState() => _StoreHubScreenState();
}

class _StoreHubScreenState extends State<StoreHubScreen> {
  bool _isOnline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkInternet();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkInternet());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    bool isOnline = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        isOnline = true;
      }
    } catch (_) {
      isOnline = false;
    }
    if (mounted && _isOnline != isOnline) {
      setState(() => _isOnline = isOnline);
    }
  }

  void _navigate(BuildContext context, TagUpScreen screen) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TagUp',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Outils magasin',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // Indicateur en ligne/hors ligne
                  Tooltip(
                    message: _isOnline ? 'Online : Prix à jour' : 'Hors ligne : Prix en cache',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? Colors.green.withOpacity(isDark ? 0.2 : 0.15)
                            : Colors.red.withOpacity(isDark ? 0.2 : 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: _isOnline
                            ? (isDark ? Colors.green.shade400 : Colors.green.shade600)
                            : (isDark ? Colors.red.shade400 : Colors.red.shade600),
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Grille des cartes ──────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Prix FLO
                    Expanded(
                      child: _StoreCard(
                        isDark: isDark,
                        storeName: 'Prix FLO',
                        subtitle: 'Vérification de prix en temps réel',
                        icon: Icons.local_mall,
                        gradientColors: const [
                          Color(0xFFFF8C00),
                          Color(0xFFFF6000),
                        ],
                        shadowColor: const Color(0xFFFF6000),
                        onTap: () => _navigate(
                          context,
                        const TagUpScreen(
                            storeName: 'Prix FLO',
                            themeColor: Color(0xFFFF8C00),
                            dataSourceId: 'flo',
                            apiUrl: 'https://script.google.com/macros/s/AKfycbxEmFsduSA5gKfAWDmNWbcLzEZn0TftSxxl2zvyyKFiLw4NRpFj25n6jVWqbITgoB-o/exec',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Prix Kiabi
                    Expanded(
                      child: _StoreCard(
                        isDark: isDark,
                        storeName: 'Prix Kiabi',
                        subtitle: 'Vérification de prix en temps réel',
                        icon: Icons.checkroom,
                        gradientColors: const [
                          Color(0xFF1565C0),
                          Color(0xFF0D47A1),
                        ],
                        shadowColor: const Color(0xFF1565C0),
                        onTap: () => _navigate(
                          context,
                        const TagUpScreen(
                            storeName: 'Prix Kiabi',
                            themeColor: Color(0xFF1565C0),
                            dataSourceId: 'kiabi',
                            apiUrl: '', // API non encore configurée
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _StoreCard – Carte générique réutilisable pour chaque outil
// ──────────────────────────────────────────────────────────────
class _StoreCard extends StatefulWidget {
  final bool isDark;
  final String storeName;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _StoreCard({
    required this.isDark,
    required this.storeName,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Couleur du texte "Ouvrir" = première couleur du dégradé
    final Color accentColor = widget.gradientColors.first;

    return ScaleTransition(
      scale: _ctrl,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) => _ctrl.forward(),
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withOpacity(0.40),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color:
                    Colors.black.withOpacity(widget.isDark ? 0.4 : 0.10),
                blurRadius: 36,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Cercles décoratifs
                Positioned(
                  top: -30,
                  right: -30,
                  child: _Circle(size: 180, opacity: 0.07),
                ),
                Positioned(
                  bottom: -50,
                  left: -20,
                  child: _Circle(size: 220, opacity: 0.05),
                ),
                Positioned(
                  top: 20,
                  right: 24,
                  child: _Circle(size: 70, opacity: 0.08),
                ),

                // Contenu
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icône
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Nom du magasin
                        Text(
                          widget.storeName,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                blurRadius: 16,
                                color: Color(0x44000000),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.80),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Bouton "Ouvrir"
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.14),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ouvrir',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: accentColor,
                                size: 17,
                              ),
                            ],
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
      ),
    );
  }
}

// Cercle décoratif utilitaire
class _Circle extends StatelessWidget {
  final double size;
  final double opacity;

  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
