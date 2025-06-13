// lib/providers/dropdown_provider.dart

import 'package:disaster_reco/providers/services_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider untuk daftar bencana
final bencanaListProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getDistinctBencana();
});

// Provider untuk daftar provinsi, tergantung pada bencana yang dipilih
final provinsiListProvider = FutureProvider.family<List<String>, String>((
  ref,
  bencana,
) async {
  final db = ref.watch(databaseProvider);
  return await db.getDistinctProvinsi(bencana);
});

// Provider untuk daftar kabupaten, tergantung pada bencana dan provinsi
// Kita gunakan Record (String, String) sebagai parameter family
final kabupatenListProvider =
    FutureProvider.family<List<String>, (String, String)>((ref, params) async {
      final db = ref.watch(databaseProvider);
      return await db.getDistinctKabupaten(params.$1, params.$2);
    });

// Provider untuk daftar kecamatan
final kecamatanListProvider =
    FutureProvider.family<List<String>, (String, String, String)>((
      ref,
      params,
    ) async {
      final db = ref.watch(databaseProvider);
      return await db.getDistinctKecamatan(params.$1, params.$2, params.$3);
    });
