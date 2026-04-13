import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

// ──────────────────────────────────────────────────────────────
// TagUpScreen – Vérificateur de prix générique
// Paramétrable par magasin (storeName, themeColor, dataSourceId)
// ──────────────────────────────────────────────────────────────
class TagUpScreen extends StatefulWidget {
  /// Nom affiché dans l'AppBar et le bouton scanner.
  final String storeName;

  /// Couleur thème principale (bouton, icônes, accents).
  final Color themeColor;

  /// Identifiant de la source de données (ex: 'flo', 'kiabi').
  final String dataSourceId;

  /// URL de l'API Google Apps Script pour la synchronisation.
  /// Laisser vide ('') si l'API n'est pas encore configurée pour ce magasin.
  final String apiUrl;

  const TagUpScreen({
    super.key,
    required this.storeName,
    required this.themeColor,
    required this.dataSourceId,
    required this.apiUrl,
  });

  @override
  State<TagUpScreen> createState() => _TagUpScreenState();
}

class _TagUpScreenState extends State<TagUpScreen> {
  // ── État ───────────────────────────────────────────────────
  List<Article> articlesList = [];
  List<Article> filteredList = [];
  bool isLoading = false;
  bool isScanning = false;

  final TextEditingController _searchController = TextEditingController();

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Chargement initial : la liste doit être remplie dès l'ouverture
    _loadArticles();
    _searchController.addListener(_filterArticles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Données ────────────────────────────────────────────────

  /// Lit les articles du magasin [widget.dataSourceId] depuis SQLite.
  Future<void> _loadArticles() async {
    setState(() => isLoading = true);
    final data = await DatabaseHelper().getAllArticles(widget.dataSourceId);
    if (mounted) {
      setState(() {
        articlesList = data;
        // Si une recherche est active, on filtre ; sinon toute la liste
        filteredList = _searchController.text.trim().isEmpty
            ? data
            : data.where((a) {
                final q = _searchController.text.toLowerCase().trim();
                return a.codeBarres.toLowerCase().contains(q) ||
                    a.reference.toLowerCase().contains(q);
              }).toList();
        isLoading = false;
      });
    }
  }

  /// Filtre la liste en fonction du champ de recherche.
  /// Appelé automatiquement par le listener du TextEditingController.
  void _filterArticles() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      // Si champ vide → affiche TOUS les articles (pas d'état vide)
      filteredList = query.isEmpty
          ? articlesList
          : articlesList.where((a) {
              return a.codeBarres.toLowerCase().contains(query) ||
                  a.reference.toLowerCase().contains(query);
            }).toList();
    });
  }

  // ── Scanner (mobile_scanner via route dédiée) ──────────────

  /// Ouvre l'écran scanner en push route.
  /// Navigator.pop depuis _ScannerScreen renvoie uniquement vers TagUpScreen,
  /// jamais vers StoreHubScreen.
  Future<void> _scanBarcode() async {
    setState(() => isScanning = true);

    try {
      final String? result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _ScannerScreen(themeColor: widget.themeColor),
        ),
      );

      // null = utilisateur a annulé → on ne fait rien
      if (result != null && result.isNotEmpty) {
        setState(() => _searchController.text = result);
        
        // On attend que le listener ait filtré la liste avant de vérifier
        Future.microtask(() {
          if (filteredList.isEmpty) {
            HapticFeedback.vibrate();
          }
        });
      }
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  // ── Synchronisation API ────────────────────────────────────
  Future<void> _syncData() async {
    // Garde-fou : API non configurée pour ce magasin
    if (widget.apiUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text("L'API pour ce magasin n'est pas encore configurée."),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return; // ← annulation propre, pas de setState(isLoading)
    }

    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(widget.apiUrl));


      if (response.statusCode == 200) {
        final List<dynamic> rows = json.decode(response.body);
        final List<Map<String, dynamic>> typedRows =
            rows.cast<Map<String, dynamic>>();
        await DatabaseHelper().clearAndInsertAll(typedRows, widget.dataSourceId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Sync réussie : ${typedRows.length} articles mis à jour.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur serveur : ${response.statusCode}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur réseau : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      // CRITIQUE : recharge toujours la liste après la sync, succès ou non
      await _loadArticles();
    }
  }

  // ── Import CSV local ───────────────────────────────────────
  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => isLoading = true);
        int count = await DatabaseHelper()
            .importLocalCSV(result.files.single.path!, widget.dataSourceId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Importation réussie : $count articles.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur importation : $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      // Recharge la liste après importation
      await _loadArticles();
    }
  }

  // ── Formatage ──────────────────────────────────────────────
  String _formatPrice(double price) {
    return price == price.truncateToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
  }

  // ── Build principal ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.storeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _importCSV,
            tooltip: 'Importer CSV',
            color: widget.themeColor,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _syncData,
            tooltip: 'Synchroniser',
            color: widget.themeColor,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche + bouton scanner ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              children: [
                // Champ de recherche manuelle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(isDark ? 0.3 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Code-barres ou référence...',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search,
                          color: widget.themeColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Bouton Scanner
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: isScanning ? null : _scanBarcode,
                    icon: isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 22),
                    label: Text(
                      isScanning ? 'Ouverture...' : 'Scanner un article',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isScanning
                          ? widget.themeColor.withOpacity(0.6)
                          : widget.themeColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: isScanning ? 0 : 4,
                      shadowColor: widget.themeColor.withOpacity(0.4),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Compteur d'articles (informatif)
                if (!isLoading && articlesList.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _searchController.text.isEmpty
                          ? '${articlesList.length} articles en base'
                          : '${filteredList.length} résultat(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Zone de résultats ──────────────────────────────
          Expanded(child: _buildResultsArea(isDark)),
        ],
      ),
    );
  }

  // ── Construction de la zone de résultats ───────────────────
  Widget _buildResultsArea(bool isDark) {
    // 1. Chargement en cours
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.themeColor),
            const SizedBox(height: 16),
            Text(
              'Chargement des articles...',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 2. Base de données vraiment vide
    if (articlesList.isEmpty) {
      return _emptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Base de données vide',
        subtitle:
            'Appuyez sur le bouton Sync (↻) pour charger les articles.',
        isDark: isDark,
      );
    }

    // 3. Recherche active mais aucun résultat
    if (_searchController.text.isNotEmpty && filteredList.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun article trouvé',
        subtitle:
            '"${_searchController.text}"\nVérifiez le code ou synchronisez la base.',
        isDark: isDark,
      );
    }

    // 4. Affiche la liste (recherche vide = tous les articles,
    //    recherche active = articles filtrés)
    return ListView.builder(
      itemCount: filteredList.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final article = filteredList[index];
        final bool isSoldes =
            article.prixSolde > 0 || article.remise > 0;
        final double finalPrice =
            article.prixSolde > 0 ? article.prixSolde : article.prix;

        return Card(
          elevation: 2,
          margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar lettre initiale
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.themeColor.withOpacity(isDark ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.label,
                      color: widget.themeColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Référence + code-barres
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.reference,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.codeBarres,
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Prix
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSoldes)
                      Text(
                        '${_formatPrice(article.prix)} DA',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      '${_formatPrice(finalPrice)} DA',
                      style: TextStyle(
                        color: isSoldes
                            ? (isDark
                                ? Colors.green.shade400
                                : Colors.green.shade700)
                            : widget.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isSoldes ? 20 : 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 72,
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// _ScannerScreen – Écran scanner dédié
//
// Géré comme une route indépendante :
//   - Crée son propre MobileScannerController dans initState
//   - Le dispose proprement dans dispose()
//   - Retourne la valeur via Navigator.pop(context, value)
//     → ce pop retourne vers TagUpScreen UNIQUEMENT, jamais vers StoreHubScreen
// ──────────────────────────────────────────────────────────────
class _ScannerScreen extends StatefulWidget {
  /// Couleur thème transmise depuis TagUpScreen pour le cadre de scan.
  final Color themeColor;

  const _ScannerScreen({required this.themeColor});

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  late final MobileScannerController _controller;
  bool _hasScanned = false; // Verrou anti-double-scan

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose(); // Libération propre de la caméra
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Verrou : on ne traite qu'un seul scan
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;

    if (value != null && value.isNotEmpty) {
      _hasScanned = true;
      print("DEBUG: Vibration déclenchée");
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      _controller.stop(); // Arrête la caméra immédiatement
      // Retourne la valeur vers TagUpScreen (et uniquement TagUpScreen)
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Vue caméra
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Overlay sombre avec fenêtre de scan
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.srcOut,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
              child: Center(
                child: Container(
                  height: 260,
                  width: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),

          // 3. Cadre orange + instructions
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: widget.themeColor, width: 3.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Positionnez le code-barres dans le cadre',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

          // 4. Bouton fermeture (annuler → retourne null à TagUpScreen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context), // retourne null
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.flash_on,
                          color: widget.themeColor, size: 28),
                      onPressed: () => _controller.toggleTorch(),
                      tooltip: 'Lampe torche',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
