// lib/services/database_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

/// Kelas ini mengelola semua interaksi dengan database SQLite lokal.
/// Ini menggunakan pola singleton untuk memastikan hanya ada satu instance
/// dari koneksi database di seluruh aplikasi.
class DatabaseHelper {
  // Pola Singleton untuk memastikan hanya ada satu instance helper.
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Mengambil instance database, dan akan melakukan inisialisasi jika ini
  /// adalah kali pertama database diakses.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database.
  /// Metode ini memeriksa apakah file database sudah ada di direktori
  /// penyimpanan aplikasi. Jika tidak, ia akan menyalinnya dari folder assets.
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "data.db");

    // Hanya salin jika database belum ada di direktori aplikasi.
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      debugPrint("Database tidak ditemukan, menyalin dari assets...");
      try {
        ByteData data = await rootBundle.load(join('assets/data.db'));
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
        debugPrint("Database berhasil disalin ke $path");
      } catch (e) {
        debugPrint("Error saat menyalin database: $e");
      }
    } else {
      debugPrint("Database sudah ada di $path");
    }

    return await openDatabase(path);
  }

  // =======================================================================
  // HELPER FUNGSI UNTUK MAPPING & UI
  // =======================================================================

  /// Helper pribadi untuk mengubah hasil query [List<Map>] menjadi [List<String>].
  List<String> _mapToStringList(List<Map<String, dynamic>> result, String key) {
    return result.map((map) => map[key] as String).toList();
  }

  /// Mengambil `lokasi_id` unik berdasarkan kombinasi lokasi yang diberikan.
  Future<int?> getLokasiId(
    String bencana,
    String provinsi,
    String kabupaten,
    String kecamatan,
  ) async {
    final db = await database;
    final result = await db.query(
      'lokasi',
      columns: ['id'],
      where: 'bencana = ? AND provinsi = ? AND kabupaten = ? AND kecamatan = ?',
      whereArgs: [bencana, provinsi, kabupaten, kecamatan],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int?;
    }
    return null;
  }

  /// Mengambil detail nama lokasi (provinsi, kabupaten, kecamatan) berdasarkan `lokasi_id`.
  Future<Map<String, dynamic>?> getLokasiById(int id) async {
    final db = await database;
    final result = await db.query(
      'lokasi',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // =======================================================================
  // FUNGSI UNTUK MENGISI UI DROPDOWN SECARA DINAMIS
  // =======================================================================

  /// Mengambil daftar unik semua jenis bencana dari database.
  Future<List<String>> getDistinctBencana() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'lokasi',
      distinct: true,
      columns: ['bencana'],
    );
    return _mapToStringList(result, 'bencana');
  }

  /// Mengambil daftar unik provinsi berdasarkan jenis bencana yang dipilih.
  Future<List<String>> getDistinctProvinsi(String bencana) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'lokasi',
      distinct: true,
      columns: ['provinsi'],
      where: 'bencana = ?',
      whereArgs: [bencana],
    );
    return _mapToStringList(result, 'provinsi');
  }

  /// Mengambil daftar unik kabupaten berdasarkan bencana dan provinsi.
  Future<List<String>> getDistinctKabupaten(
    String bencana,
    String provinsi,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'lokasi',
      distinct: true,
      columns: ['kabupaten'],
      where: 'bencana = ? AND provinsi = ?',
      whereArgs: [bencana, provinsi],
    );
    return _mapToStringList(result, 'kabupaten');
  }

  /// Mengambil daftar unik kecamatan berdasarkan bencana, provinsi, dan kabupaten.
  Future<List<String>> getDistinctKecamatan(
    String bencana,
    String provinsi,
    String kabupaten,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'lokasi',
      distinct: true,
      columns: ['kecamatan'],
      where: 'bencana = ? AND provinsi = ? AND kabupaten = ?',
      whereArgs: [bencana, provinsi, kabupaten],
    );
    return _mapToStringList(result, 'kecamatan');
  }

  // =======================================================================
  // FUNGSI UNTUK REKOMENDASI & DETAIL
  // =======================================================================

  /// Mengambil semua detail dari tabel 'bahaya' berdasarkan lokasi_id.
  Future<Map<String, dynamic>?> getBahayaDetails(int lokasiId) async {
    final db = await database;
    final result = await db.query(
      'bahaya',
      where: 'lokasi_id = ?',
      whereArgs: [lokasiId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Mengambil semua detail dari tabel 'kerentanan' berdasarkan lokasi_id.
  Future<Map<String, dynamic>?> getKerentananDetails(int lokasiId) async {
    final db = await database;
    final result = await db.query(
      'kerentanan',
      where: 'lokasi_id = ?',
      whereArgs: [lokasiId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Mengambil semua detail dari tabel 'kapasitas' berdasarkan lokasi_id.
  Future<Map<String, dynamic>?> getKapasitasDetails(int lokasiId) async {
    final db = await database;
    final result = await db.query(
      'kapasitas',
      where: 'lokasi_id = ?',
      whereArgs: [lokasiId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // --- FUNGSI REKOMENDASI DENGAN HIRARKI PERINGKAT LENGKAP ---

  /// **[Saat-Bencana]** Merekomendasikan 3 kecamatan teraman untuk evakuasi.
  /// Logika: Dirangking secara hierarkis berdasarkan silsilah Kerentanan, dari atas ke bawah.
  Future<List<Map<String, dynamic>>> getEvacuationRecommendation(
    String bencana,
    String provinsi,
    String kabupaten,
    String kecamatan,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        l.id, l.kecamatan, 
        k.kelas_risiko, k.kelas_kerentanan, k.kelas_penduduk_terpapar,
        k.total_penduduk_terpapar, k.penduduk_miskin, k.penduduk_cacat
      FROM kerentanan k
      JOIN lokasi l ON l.id = k.lokasi_id
      WHERE 
        l.provinsi = ? AND l.kabupaten = ? AND l.kecamatan != ? AND l.bencana = ?
      ORDER BY 
        -- Level 1 (Puncak Silsilah): Prioritaskan Kelas Risiko TERENDAH
        CASE k.kelas_risiko WHEN 'RENDAH' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'TINGGI' THEN 3 ELSE 4 END ASC,
        -- Level 2: Prioritaskan Kelas Kerentanan keseluruhan TERENDAH
        CASE k.kelas_kerentanan WHEN 'RENDAH' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'TINGGI' THEN 3 ELSE 4 END ASC,
        -- Level 3: Prioritaskan Kelas Penduduk Terpapar TERENDAH
        CASE k.kelas_penduduk_terpapar WHEN 'RENDAH' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'TINGGI' THEN 3 ELSE 4 END ASC,
        -- Level 4 (Ujung Silsilah Sosial): Prioritaskan Total Penduduk Terpapar numerik TERENDAH
        k.total_penduduk_terpapar ASC,
        -- Tie-breaker tambahan untuk aspek sosial
        k.penduduk_miskin ASC,
        k.penduduk_cacat ASC,
        -- Tie-breaker untuk aspek lain (Fisik, Ekonomi, Lingkungan)
        k.total_kerugian_fisik_dan_ekonomi ASC,
        k.kerusakan_lingkungan_total ASC
      LIMIT 3
    ''',
      [provinsi, kabupaten, kecamatan, bencana],
    );
  }

  /// **[Pasca-Bencana]** [Mode A]: Mencari kecamatan prioritas rehabilitasi.
  /// Logika: Dirangking secara hierarkis berdasarkan silsilah Kapasitas, dari atas ke bawah.
  Future<List<Map<String, dynamic>>> getLowestCapacityKecamatan(
    String bencana,
    String provinsi,
    String kabupaten,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
        SELECT 
          l.id, l.kecamatan, cap.kelas_risiko, cap.kelas_kapasitas, cap.indeks_kapasitas,
          cap.skor_kabupaten_kota, cap.nilai_ikd_kabupaten_kota, cap.skor_provinsi, cap.nilai_ikd_provinsi
        FROM kapasitas cap
        JOIN lokasi l ON l.id = cap.lokasi_id
        WHERE l.bencana = ? AND l.provinsi = ? AND l.kabupaten = ?
        ORDER BY 
          -- Level 1 (Puncak Silsilah): Prioritaskan Kelas Risiko TERTINGGI
          CASE cap.kelas_risiko WHEN 'TINGGI' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'RENDAH' THEN 3 ELSE 4 END ASC,
          -- Level 2: Prioritaskan Kelas Kapasitas TERENDAH
          CASE cap.kelas_kapasitas WHEN 'RENDAH' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'TINGGI' THEN 3 ELSE 4 END ASC,
          -- Level 3: Prioritaskan Indeks Kapasitas numerik TERENDAH
          cap.indeks_kapasitas ASC,
          -- Level 4: Prioritaskan Skor Kab/Kota TERENDAH
          cap.skor_kabupaten_kota ASC,
          -- Level 5 (Ujung Silsilah): Prioritaskan Nilai IKD Kab/Kota TERENDAH
          cap.nilai_ikd_kabupaten_kota ASC
        LIMIT 5
    ''',
      [bencana, provinsi, kabupaten],
    );
  }

  /// **[Pasca-Bencana]** [Mode B]: Mencari bencana paling berisiko di suatu lokasi.
  /// Logika: Dirangking secara hierarkis berdasarkan silsilah Kapasitas, dari atas ke bawah.
  Future<List<Map<String, dynamic>>> getBencanaByLowestCapacity(
    String provinsi,
    String kabupaten,
    String kecamatan,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
        SELECT 
          l.id, l.bencana, cap.kelas_risiko, cap.kelas_kapasitas, cap.indeks_kapasitas,
          cap.skor_kabupaten_kota, cap.nilai_ikd_kabupaten_kota, cap.skor_provinsi, cap.nilai_ikd_provinsi
        FROM kapasitas cap
        JOIN lokasi l ON l.id = cap.lokasi_id
        WHERE l.provinsi = ? AND l.kabupaten = ? AND l.kecamatan = ?
        ORDER BY 
          -- Level 1 (Puncak Silsilah): Prioritaskan Kelas Risiko TERTINGGI
          CASE cap.kelas_risiko WHEN 'TINGGI' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'RENDAH' THEN 3 ELSE 4 END ASC,
          -- Level 2: Prioritaskan Kelas Kapasitas TERENDAH
          CASE cap.kelas_kapasitas WHEN 'RENDAH' THEN 1 WHEN 'SEDANG' THEN 2 WHEN 'TINGGI' THEN 3 ELSE 4 END ASC,
          -- Level 3: Prioritaskan Indeks Kapasitas numerik TERENDAH
          cap.indeks_kapasitas ASC,
          -- Level 4: Prioritaskan Skor Kab/Kota TERENDAH
          cap.skor_kabupaten_kota ASC,
          -- Level 5 (Ujung Silsilah): Prioritaskan Nilai IKD Kab/Kota TERENDAH
          cap.nilai_ikd_kabupaten_kota ASC
        LIMIT 5
    ''',
      [provinsi, kabupaten, kecamatan],
    );
  }
}
