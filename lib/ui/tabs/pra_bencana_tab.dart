// lib/ui/tabs/pra_bencana_tab.dart

import 'package:disaster_reco/models/recommendation_state.dart';
import 'package:disaster_reco/providers/dropdown_provider.dart';
import 'package:disaster_reco/providers/recommendation_provider.dart';
import 'package:disaster_reco/providers/services_provider.dart';
import 'package:disaster_reco/ui/widgets/recommendation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PraBencanaTab extends ConsumerStatefulWidget {
  const PraBencanaTab({super.key});

  @override
  ConsumerState<PraBencanaTab> createState() => _PraBencanaTabState();
}

class _PraBencanaTabState extends ConsumerState<PraBencanaTab> {
  String? _selectedBencana;
  String? _selectedProvinsi;
  String? _selectedKabupaten;
  String? _selectedKecamatan;

  // Helper untuk menampilkan dialog detail
  void _showDetailsDialog(
    String title,
    Future<Map<String, dynamic>?> detailsFuture,
  ) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>?>(
        future: detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return AlertDialog(
              title: Text(title),
              content: const Text("Gagal memuat detail."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Tutup"),
                ),
              ],
            );
          }
          final details = snapshot.data!;
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((entry) {
                  // Mengabaikan kolom ID agar tidak tampil di dialog
                  if (entry.key == 'id' || entry.key == 'lokasi_id')
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${entry.key.replaceAll('_', ' ').toUpperCase()}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '${entry.value}'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Tutup"),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper untuk membangun dropdown dari FutureProvider
  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required AsyncValue<List<String>> items,
    required void Function(T?) onChanged,
  }) {
    return items.when(
      data: (data) => DropdownButtonFormField<T>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        items: data
            .map(
              (item) => DropdownMenuItem(value: item as T, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  void _getRecommendations() async {
    if (_selectedBencana == null ||
        _selectedProvinsi == null ||
        _selectedKabupaten == null ||
        _selectedKecamatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua pilihan lokasi')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final lokasiId = await db.getLokasiId(
      _selectedBencana!,
      _selectedProvinsi!,
      _selectedKabupaten!,
      _selectedKecamatan!,
    );

    if (lokasiId != null) {
      ref.read(recommendationProvider.notifier).fetchPraBencana(lokasiId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kombinasi lokasi tidak ditemukan di database'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendationState = ref.watch(recommendationProvider);

    final bencanaAsync = ref.watch(bencanaListProvider);
    final provinsiAsync = _selectedBencana != null
        ? ref.watch(provinsiListProvider(_selectedBencana!))
        : null;
    final kabupatenAsync = _selectedBencana != null && _selectedProvinsi != null
        ? ref.watch(
            kabupatenListProvider((_selectedBencana!, _selectedProvinsi!)),
          )
        : null;
    final kecamatanAsync =
        _selectedBencana != null &&
            _selectedProvinsi != null &&
            _selectedKabupaten != null
        ? ref.watch(
            kecamatanListProvider((
              _selectedBencana!,
              _selectedProvinsi!,
              _selectedKabupaten!,
            )),
          )
        : null;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Kewaspadaan Bencana',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih lokasi dan jenis bencana untuk melihat potensi bencana lain dengan profil bahaya serupa.',
        ),
        const SizedBox(height: 24),
        // --- Form Input ---
        _buildDropdown<String>(
          hint: 'Pilih Jenis Bencana',
          value: _selectedBencana,
          items: bencanaAsync,
          onChanged: (value) => setState(() {
            _selectedBencana = value;
            _selectedProvinsi = null;
            _selectedKabupaten = null;
            _selectedKecamatan = null;
            ref.read(recommendationProvider.notifier).resetState();
          }),
        ),
        const SizedBox(height: 12),
        if (_selectedBencana != null && provinsiAsync != null)
          _buildDropdown<String>(
            hint: 'Pilih Provinsi',
            value: _selectedProvinsi,
            items: provinsiAsync,
            onChanged: (value) => setState(() {
              _selectedProvinsi = value;
              _selectedKabupaten = null;
              _selectedKecamatan = null;
              ref.read(recommendationProvider.notifier).resetState();
            }),
          ),
        const SizedBox(height: 12),
        if (_selectedProvinsi != null && kabupatenAsync != null)
          _buildDropdown<String>(
            hint: 'Pilih Kabupaten',
            value: _selectedKabupaten,
            items: kabupatenAsync,
            onChanged: (value) => setState(() {
              _selectedKabupaten = value;
              _selectedKecamatan = null;
              ref.read(recommendationProvider.notifier).resetState();
            }),
          ),
        const SizedBox(height: 12),
        if (_selectedKabupaten != null && kecamatanAsync != null)
          _buildDropdown<String>(
            hint: 'Pilih Kecamatan',
            value: _selectedKecamatan,
            items: kecamatanAsync,
            onChanged: (value) {
              setState(() {
                _selectedKecamatan = value;
              });
              ref.read(recommendationProvider.notifier).resetState();
            },
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _getRecommendations,
          icon: const Icon(Icons.search),
          label: const Text('Cari Rekomendasi'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        // --- Bagian Hasil ---
        if (recommendationState is RecommendationLoading)
          const Center(child: CircularProgressIndicator())
        else if (recommendationState is RecommendationSuccess)
          recommendationState.data.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada bencana lain di lokasi ini untuk dibandingkan.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bencana Lain dengan Profil Mirip:",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...recommendationState.data.asMap().entries.map((entry) {
                      final item = entry.value;
                      final similarity = (item['similarity'] as double? ?? 0.0);
                      return RecommendationCard(
                        index: entry.key,
                        title: item['bencana'] ?? 'N/A',
                        subtitle:
                            'Tingkat kemiripan: ${NumberFormat.percentPattern().format(similarity)}',
                        onDetailsPressed: () {
                          final db = ref.read(databaseProvider);
                          _showDetailsDialog(
                            "Detail Bahaya: ${item['bencana']}",
                            db.getBahayaDetails(item['id'] as int),
                          );
                        },
                      );
                    }).toList(),
                  ],
                )
        else if (recommendationState is RecommendationError)
          Center(
            child: Text(
              'Error: ${recommendationState.message}',
              style: const TextStyle(color: Colors.red),
            ),
          )
        else
          const Center(
            child: Text('Lengkapi pilihan lokasi untuk melihat rekomendasi.'),
          ),
      ],
    );
  }
}
