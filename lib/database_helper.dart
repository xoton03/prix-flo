import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Article {
  final String codeBarres;
  final String reference;
  final double prix;
  final double remise;
  final double prixSolde;

  Article({
    required this.codeBarres,
    required this.reference,
    required this.prix,
    required this.remise,
    required this.prixSolde,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      codeBarres: map['code_barres']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      prix: double.tryParse(map['prix'].toString()) ?? 0.0,
      remise: double.tryParse(map['remise'].toString()) ?? 0.0,
      prixSolde: double.tryParse(map['prix_solde'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code_barres': codeBarres,
      'reference': reference,
      'prix': prix,
      'remise': remise,
      'prix_solde': prixSolde,
    };
  }
}

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
    String path = join(await getDatabasesPath(), 'articles_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE articles(
        code_barres TEXT PRIMARY KEY,
        reference TEXT,
        prix REAL,
        remise REAL,
        prix_solde REAL
      )
    ''');
  }

  Future<void> clearAndInsertAll(List<Map<String, dynamic>> rows) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Vider la table avant la nouvelle insertion
      await txn.delete('articles');
      
      Batch batch = txn.batch();
      
      for (var row in rows) {
        // On inclut la clé avec le tiret en priorité absolue
        String code = (row['code-barres_article'] ?? row['code_barres_article'] ?? '').toString().trim();
        String reference = (row['ref'] ?? row['reference'] ?? '').toString().trim();

        if (code.isEmpty) {
          continue; 
        }

        String rawPrice = (row['prix_'] ?? '0').toString().replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        double prix = double.tryParse(rawPrice) ?? 0.0;

        String rawRemise = (row['remise'] ?? '0').toString().replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        double remise = double.tryParse(rawRemise) ?? 0.0;

        String rawSolde = (row['prix_solde'] ?? '0').toString().replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        double prixSolde = double.tryParse(rawSolde) ?? 0.0;

        batch.insert(
          'articles',
          {
            'code_barres': code,
            'reference': reference,
            'prix': prix,
            'remise': remise,
            'prix_solde': prixSolde,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  Future<List<Article>> getAllArticles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('articles');
    
    return List.generate(maps.length, (i) {
      return Article.fromMap(maps[i]);
    });
  }

  Future<Article?> getArticleByCode(String codeBarres) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'articles',
      where: 'code_barres = ?',
      whereArgs: [codeBarres],
    );

    if (maps.isNotEmpty) {
      return Article.fromMap(maps.first);
    }
    return null;
  }

  Future<int> importLocalCSV(String filePath) async {
    final String csvString = await File(filePath).readAsString();
    
    // Détection basique du délimiteur
    String delimiter = csvString.contains(';') ? ';' : ',';
    
    final List<List<dynamic>> csvTable = CsvToListConverter().convert(
      csvString, 
      fieldDelimiter: delimiter,
    );
    
    if (csvTable.isEmpty) return 0;
    
    final List<String> headers = csvTable.first.map((e) => e.toString().toLowerCase().trim()).toList();
    List<Map<String, dynamic>> rows = [];
    
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length < headers.length) continue; 
      
      Map<String, dynamic> rowMap = {};
      for (int j = 0; j < headers.length; j++) {
        rowMap[headers[j]] = row[j];
      }
      rows.add(rowMap);
    }
    
    // Utilise EXACTEMENT la même logique claire et sécurisée d'insertion
    await clearAndInsertAll(rows);
    return rows.length;
  }
}
