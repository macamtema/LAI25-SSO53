// lib/providers/recommendation_provider.dart

import 'package:disaster_reco/models/recommendation_state.dart';
import 'package:disaster_reco/providers/services_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider utama yang akan ditonton oleh UI.
/// Ini menyediakan instance dari [RecommendationNotifier] dan state-nya.
final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationState>((ref) {
      return RecommendationNotifier(ref);
    });

/// Notifier ini bertindak sebagai jembatan antara UI dan lapisan servis.
/// Ia menangani logika bisnis, memanggil servis yang sesuai,
/// dan mengelola state (loading, success, error) untuk ditampilkan di UI.
class RecommendationNotifier extends StateNotifier<RecommendationState> {
  final Ref _ref;

  RecommendationNotifier(this._ref) : super(const RecommendationInitial());

  /// **[Pra-Bencana]** Mengambil rekomendasi bencana lain dengan profil bahaya serupa.
  ///
  /// Memanggil TFLite service yang membutuhkan dbService sebagai helper.
  Future<void> fetchPraBencana(int lokasiId) async {
    state = const RecommendationLoading();
    try {
      // Baca instance dari tflite service dan database service
      final tfliteService = _ref.read(tfliteProvider);
      final dbService = _ref.read(databaseProvider);

      // Panggil fungsi rekomendasi baru yang memerlukan dbService
      final results = await tfliteService.getPraBencanaRecommendation(
        lokasiId,
        dbService,
      );
      state = RecommendationSuccess(results);
    } catch (e) {
      state = RecommendationError(
        "Gagal mendapatkan rekomendasi pra-bencana: ${e.toString()}",
      );
    }
  }

  /// **[Saat-Bencana]** Mengambil rekomendasi kecamatan teraman untuk evakuasi.
  ///
  /// Logika ini tidak berubah, hanya memanggil database helper.
  Future<void> fetchSaatBencana(
    String bencana,
    String provinsi,
    String kabupaten,
    String kecamatan,
  ) async {
    state = const RecommendationLoading();
    try {
      final dbService = _ref.read(databaseProvider);
      final results = await dbService.getEvacuationRecommendation(
        bencana,
        provinsi,
        kabupaten,
        kecamatan,
      );
      state = RecommendationSuccess(results);
    } catch (e) {
      state = RecommendationError(
        "Gagal mendapatkan rekomendasi evakuasi: ${e.toString()}",
      );
    }
  }

  /// **[Pasca-Bencana - Mode A]** Mengambil daftar kecamatan dengan kapasitas terendah.
  ///
  /// Memanggil fungsi baru di database helper yang fokus pada tabel 'kapasitas'.
  Future<void> fetchPascaBencanaLokasiByCapacity(
    String bencana,
    String provinsi,
    String kabupaten,
  ) async {
    state = const RecommendationLoading();
    try {
      final dbService = _ref.read(databaseProvider);
      final results = await dbService.getLowestCapacityKecamatan(
        bencana,
        provinsi,
        kabupaten,
      );
      state = RecommendationSuccess(results);
    } catch (e) {
      state = RecommendationError(
        "Gagal mencari lokasi kapasitas rendah: ${e.toString()}",
      );
    }
  }

  /// **[Pasca-Bencana - Mode B]** Mengambil daftar bencana paling berisiko berdasarkan kapasitas.
  ///
  /// Memanggil fungsi baru di database helper yang fokus pada tabel 'kapasitas'.
  Future<void> fetchPascaBencanaJenisByCapacity(
    String provinsi,
    String kabupaten,
    String kecamatan,
  ) async {
    state = const RecommendationLoading();
    try {
      final dbService = _ref.read(databaseProvider);
      final results = await dbService.getBencanaByLowestCapacity(
        provinsi,
        kabupaten,
        kecamatan,
      );
      state = RecommendationSuccess(results);
    } catch (e) {
      state = RecommendationError(
        "Gagal mencari bencana berisiko: ${e.toString()}",
      );
    }
  }

  /// Mengembalikan state ke kondisi awal.
  ///
  /// Berguna untuk membersihkan hasil rekomendasi sebelumnya saat pengguna mengubah input.
  void resetState() {
    state = const RecommendationInitial();
  }
}
