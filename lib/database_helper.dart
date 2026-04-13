import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ──────────────────────────────────────────────────────────────
// Modèle Article
// ──────────────────────────────────────────────────────────────
class Article {
  final String codeBarres;
  final String reference;
  final double prix;
  final double remise;
  final double prixSolde;
  /// Identifiant du magasin propriétaire de cet article ('flo', 'kiabi', …)
  final String storeId;

  Article({
    required this.codeBarres,
    required this.reference,
    required this.prix,
    required this.remise,
    required this.prixSolde,
    required this.storeId,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      codeBarres: map['code_barres']?.toString() ?? '',
      reference:  map['reference']?.toString()  ?? '',
      prix:       double.tryParse(map['prix'].toString())      ?? 0.0,
      remise:     double.tryParse(map['remise'].toString())    ?? 0.0,
      prixSolde:  double.tryParse(map['prix_solde'].toString()) ?? 0.0,
      storeId:    map['store_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code_barres': codeBarres,
      'reference':   reference,
      'prix':        prix,
      'remise':      remise,
      'prix_solde':  prixSolde,
      'store_id':    storeId,
    };
  }
}

// ──────────────────────────────────────────────────────────────
// DatabaseHelper – Singleton
// ──────────────────────────────────────────────────────────────
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'articles_v3.db');
    return await openDatabase(
      path,
      // Version 2 : ajout de la colonne store_id + clé primaire composite
      version: 2,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Création initiale (v2) ─────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE articles(
        code_barres TEXT NOT NULL,
        store_id    TEXT NOT NULL,
        reference   TEXT,
        prix        REAL,
        remise      REAL,
        prix_solde  REAL,
        PRIMARY KEY (code_barres, store_id)
      )
    ''');
  }

  // ── Migration v1 → v2 ──────────────────────────────────────
  // (utilisée si quelqu'un avait déjà articles_v2.db)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajoute la colonne avec une valeur par défaut pour les anciennes lignes
      await db.execute(
          "ALTER TABLE articles ADD COLUMN store_id TEXT NOT NULL DEFAULT 'flo'");
    }
  }

  // ──────────────────────────────────────────────────────────
  // CRUD
  // ──────────────────────────────────────────────────────────

  /// Supprime UNIQUEMENT les articles du magasin [storeId], puis insère
  /// les nouvelles lignes. Les autres magasins ne sont pas touchés.
  Future<void> clearAndInsertAll(
    List<Map<String, dynamic>> rows,
    String storeId,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      // Suppression ciblée : seulement ce magasin
      await txn.delete(
        'articles',
        where: 'store_id = ?',
        whereArgs: [storeId],
      );

      final Batch batch = txn.batch();

      for (final row in rows) {
        final String code = (row['code-barres_article'] ??
                row['code_barres_article'] ??
                '')
            .toString()
            .trim();
        final String reference =
            (row['ref'] ?? row['reference'] ?? '').toString().trim();

        if (code.isEmpty) continue;

        final String rawPrice = (row['prix_'] ?? '0')
            .toString()
            .replaceAll(RegExp(r'[^0-9.,]'), '')
            .replaceAll(',', '.');
        final double prix = double.tryParse(rawPrice) ?? 0.0;

        final String rawRemise = (row['remise'] ?? '0')
            .toString()
            .replaceAll(RegExp(r'[^0-9.,]'), '')
            .replaceAll(',', '.');
        final double remise = double.tryParse(rawRemise) ?? 0.0;

        final String rawSolde = (row['prix_solde'] ?? '0')
            .toString()
            .replaceAll(RegExp(r'[^0-9.,]'), '')
            .replaceAll(',', '.');
        final double prixSolde = double.tryParse(rawSolde) ?? 0.0;

        batch.insert(
          'articles',
          {
            'code_barres': code,
            'store_id':    storeId, // ← cloisonnement
            'reference':   reference,
            'prix':        prix,
            'remise':      remise,
            'prix_solde':  prixSolde,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  /// Retourne tous les articles d'un magasin donné.
  Future<List<Article>> getAllArticles(String storeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'articles',
      where: 'store_id = ?',
      whereArgs: [storeId],
    );
    return maps.map(Article.fromMap).toList();
  }

  /// Retourne un article par code-barres ET magasin.
  Future<Article?> getArticleByCode(
      String codeBarres, String storeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'articles',
      where: 'code_barres = ? AND store_id = ?',
      whereArgs: [codeBarres, storeId],
    );
    return maps.isNotEmpty ? Article.fromMap(maps.first) : null;
  }

  /// Importe un fichier CSV local et attache chaque ligne au [storeId].
  Future<int> importLocalCSV(String filePath, String storeId) async {
    final String csvString = await File(filePath).readAsString();

    // Détection automatique du délimiteur
    final String delimiter = csvString.contains(';') ? ';' : ',';

    final List<List<dynamic>> csvTable = CsvToListConverter().convert(
      csvString,
      fieldDelimiter: delimiter,
    );

    if (csvTable.isEmpty) return 0;

    final List<String> headers =
        csvTable.first.map((e) => e.toString().toLowerCase().trim()).toList();

    final List<Map<String, dynamic>> rows = [];

    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length < headers.length) continue;

      final Map<String, dynamic> rowMap = {};
      for (int j = 0; j < headers.length; j++) {
        rowMap[headers[j]] = row[j];
      }
      rows.add(rowMap);
    }

    // Insertion avec le bon storeId
    await clearAndInsertAll(rows, storeId);
    return rows.length;
  }
}
