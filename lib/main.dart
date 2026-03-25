import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:home_widget/home_widget.dart';
import 'database_helper.dart'; // Importe votre classe DatabaseHelper

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prix Flo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Bascule auto
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade700),
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade50,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade700,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212), // Gris foncé premium
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Article> articlesList = [];
  List<Article> filteredList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('group.prix_flo'); // Identifiant unique
    _checkLaunchedFromWidget();
    _loadArticles();
    _searchController.addListener(_filterArticles);
  }

  void _checkLaunchedFromWidget() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri?.host == 'scan') {
        // On attend que l'interface soit prête avant de lancer le scanner
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanBarcode();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      isLoading = true;
    });
    
    final data = await DatabaseHelper().getAllArticles();

    if (mounted) {
      setState(() {
        articlesList = data;
        filteredList = data;
        isLoading = false;
      });
      
      // Applique le filtre si on recharge pendant qu'une recherche est active
      _filterArticles();
    }
  }

  void _filterArticles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredList = articlesList;
      } else {
        filteredList = articlesList.where((article) {
          return article.codeBarres.toLowerCase().contains(query) ||
                 article.reference.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _syncData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // URL de votre API Google Sheets
      const String apiUrl = 'https://script.google.com/macros/s/AKfycbxEmFsduSA5gKfAWDmNWbcLzEZn0TftSxxl2zvyyKFiLw4NRpFj25n6jVWqbITgoB-o/exec'; 
      
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> rows = json.decode(response.body);
        final List<Map<String, dynamic>> typedRows = rows.cast<Map<String, dynamic>>();
        
        await DatabaseHelper().clearAndInsertAll(typedRows);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synchronisation réussie : ${typedRows.length} articles mis à jour.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur serveur: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // VRAIMENT IMPORTANT : Rafraîchir l'écran à la toute fin
      await _loadArticles();
      setState(() {}); 
    }
  }

  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        
        setState(() {
          isLoading = true;
        });

        int count = await DatabaseHelper().importLocalCSV(filePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Importation réussie : $count articles importés.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _loadArticles();
      setState(() {}); 
    }
  }

  Future<void> _scanBarcode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Stack(
            children: [
              // 1. Le Scanner (Vue Caméra)
              AiBarcodeScanner(
                onScan: (String scannedValue) {
                  if (scannedValue.isNotEmpty) {
                    HapticFeedback.heavyImpact();
                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() {
                          _searchController.text = scannedValue;
                        });
                      }
                    });
                  }
                },
              ),
              
              // 2. Overlay de design (Fond sombre avec trou central)
              ColorFiltered(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                  child: Center(
                    child: Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5),
                  BlendMode.srcOut,
                ),
              ),

              // 3. Cadre stylisé et texte
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 4),
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Positionnez le code-barres dans le cadre',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bouton de fermeture
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _importCSV,
            tooltip: 'Importer CSV',
            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncData,
            tooltip: 'Synchroniser',
            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par code-barres ou référence...',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.qr_code_scanner, color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700),
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Corps (Liste des articles)
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700),
      );
    }

    if (articlesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Base de données vide. Appuyez sur Sync.',
              style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun article trouvé.',
              style: TextStyle(fontSize: 18, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Prêt pour le scan !',
              style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredList.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final article = filteredList[index];
        final bool isSoldes = article.prixSolde > 0 || article.remise > 0;
        
        // Logique pour le prix affiché final
        final double finalPrice = article.prixSolde > 0 ? article.prixSolde : article.prix; // Adaptez si 'remise' est un % ou soustraction directe
        final String firstLetter = article.reference.isNotEmpty ? article.reference[0].toUpperCase() : '?';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.blue.shade900.withOpacity(0.3) 
                        : Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      firstLetter,
                      style: TextStyle(
                        color: isDarkMode 
                            ? Colors.blue.shade200 
                            : Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.reference,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.codeBarres,
                        style: TextStyle(
                          color: isDarkMode 
                              ? Colors.grey.shade400 
                              : Colors.grey.shade600, 
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                            ? (isDarkMode ? Colors.green.shade400 : Colors.green.shade700) 
                            : Theme.of(context).colorScheme.primary,
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
}
