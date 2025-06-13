// lib/services/tflite_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:disaster_reco/services/database_helper.dart'; // Tambahkan import ini
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Kelas ini mengelola semua interaksi dengan model TensorFlow Lite.
/// Digunakan secara spesifik untuk rekomendasi Pra-Bencana (Awareness)
/// yang berbasis pada kemiripan vektor embedding.
class TfliteService {
  // Pola Singleton untuk memastikan hanya ada satu instance service.
  static final TfliteService _instance = TfliteService._internal();
  static Interpreter? _interpreter;
  static List<List<double>>? _allEmbeddings;
  static Map<String, dynamic>? _locationsMap;

  factory TfliteService() {
    return _instance;
  }

  TfliteService._internal();

  /// Memuat model TFLite dan semua data aset yang diperlukan dari folder assets.
  /// Fungsi ini harus dipanggil sekali saat aplikasi dimulai untuk performa terbaik.
  Future<void> loadModelAndData() async {
    // Hindari memuat ulang jika semua aset sudah ada di memori.
    if (_interpreter != null &&
        _allEmbeddings != null &&
        _locationsMap != null) {
      debugPrint('Model TFLite dan semua aset sudah dimuat sebelumnya.');
      return;
    }

    try {
      debugPrint('Memuat model TFLite dan aset...');
      // 1. Load TFLite Model
      _interpreter = await Interpreter.fromAsset('assets/encoder_model.tflite');
      debugPrint('Model TFLite berhasil dimuat.');

      // 2. Load semua vektor embedding yang sudah dihitung sebelumnya
      final embeddingsString = await rootBundle.loadString(
        'assets/all_embeddings.json',
      );
      final List<dynamic> embeddingsJson = json.decode(embeddingsString);
      _allEmbeddings = embeddingsJson
          .map<List<double>>(
            (e) => (e as List<dynamic>)
                .map<double>((val) => val.toDouble())
                .toList(),
          )
          .toList();
      debugPrint('Database vektor embedding berhasil dimuat.');

      // 3. Load peta dari lokasi_id ke indeks array
      final mapString = await rootBundle.loadString(
        'assets/locations_map.json',
      );
      _locationsMap = json.decode(mapString);
      debugPrint('Peta lokasi berhasil dimuat.');
    } catch (e) {
      debugPrint("Error saat memuat model TFLite atau aset: $e");
      // Jika terjadi error, pastikan semua state kembali null.
      _interpreter = null;
      _allEmbeddings = null;
      _locationsMap = null;
    }
  }

  /// Menghitung Cosine Similarity antara dua vektor.
  /// Mengembalikan nilai antara -1 dan 1, di mana 1 berarti sangat mirip.
  double _cosineSimilarity(List<double> v1, List<double> v2) {
    // Pastikan panjang vektor sama
    if (v1.length != v2.length) {
      throw ArgumentError('Vektor harus memiliki panjang yang sama.');
    }

    double dotProduct = 0.0;
    double normV1 = 0.0;
    double normV2 = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normV1 += v1[i] * v1[i];
      normV2 += v2[i] * v2[i];
    }

    // Hindari pembagian dengan nol jika salah satu vektor adalah vektor nol.
    if (normV1 == 0 || normV2 == 0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normV1) * sqrt(normV2));
  }

  /// **[Model 1 Baru] Kewaspadaan: Cari Bencana dengan Profil Bahaya Mirip.**
  /// Menerima ID lokasi target (yang sudah mencakup info bencana), lalu mencari
  /// jenis bencana lain di lokasi fisik yang sama (prov/kab/kec) dengan profil bahaya paling mirip.
  Future<List<Map<String, dynamic>>> getPraBencanaRecommendation(
    int targetLokasiId,
    DatabaseHelper dbHelper,
  ) async {
    // Pastikan semua aset sudah dimuat.
    if (_interpreter == null ||
        _allEmbeddings == null ||
        _locationsMap == null) {
      debugPrint("Aset belum siap, memuat ulang...");
      await loadModelAndData();
      if (_interpreter == null)
        return []; // Gagal memuat, kembalikan list kosong.
    }

    // 1. Dapatkan detail lokasi target untuk mengetahui lokasi fisiknya.
    final targetLokasiDetail = await dbHelper.getLokasiById(targetLokasiId);
    if (targetLokasiDetail == null) {
      debugPrint(
        "Detail lokasi target dengan ID $targetLokasiId tidak ditemukan.",
      );
      return [];
    }

    // 2. Dapatkan embedding untuk lokasi target dari data yang sudah dimuat.
    final int? targetIndex = _locationsMap![targetLokasiId.toString()];
    if (targetIndex == null) {
      debugPrint(
        "Indeks untuk ID lokasi $targetLokasiId tidak ditemukan di peta.",
      );
      return [];
    }
    final targetEmbedding = _allEmbeddings![targetIndex];

    // 3. Cari semua 'saudara' (ID lokasi lain di tempat fisik yang sama tapi beda jenis bencana).
    final db = await dbHelper.database;
    final siblingLokasi = await db.query(
      'lokasi',
      columns: ['id'],
      where: 'provinsi = ? AND kabupaten = ? AND kecamatan = ? AND id != ?',
      whereArgs: [
        targetLokasiDetail['provinsi'],
        targetLokasiDetail['kabupaten'],
        targetLokasiDetail['kecamatan'],
        targetLokasiId,
      ],
    );

    if (siblingLokasi.isEmpty) {
      debugPrint(
        "Tidak ada jenis bencana lain yang terdaftar di lokasi fisik yang sama.",
      );
      return [];
    }

    // 4. Hitung kemiripan untuk setiap 'saudara'.
    List<Map<String, dynamic>> similarities = [];
    for (final loc in siblingLokasi) {
      final int currentId = loc['id'] as int;
      final int? currentIndex = _locationsMap![currentId.toString()];
      if (currentIndex != null) {
        final similarity = _cosineSimilarity(
          targetEmbedding,
          _allEmbeddings![currentIndex],
        );
        similarities.add({'id': currentId, 'similarity': similarity});
      }
    }

    // 5. Urutkan berdasarkan kemiripan tertinggi (descending) dan ambil 3 teratas.
    similarities.sort(
      (a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double),
    );
    final topSiblings = similarities.take(3).toList();

    // 6. Ambil detail lengkap dari bencana yang direkomendasikan untuk ditampilkan di UI.
    List<Map<String, dynamic>> results = [];
    for (final item in topSiblings) {
      final detail = await dbHelper.getLokasiById(item['id'] as int);
      if (detail != null) {
        // Gabungkan detail lokasi dengan skor kemiripan.
        results.add({...detail, 'similarity': item['similarity']});
      }
    }
    return results;
  }

  /// Membersihkan interpreter saat tidak digunakan lagi untuk membebaskan memori.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    debugPrint("Interpreter TFLite ditutup.");
  }
}
