// lib/ui/tabs/saat_bencana_tab.dart

import 'package:disaster_reco/models/recommendation_state.dart';
import 'package:disaster_reco/providers/dropdown_provider.dart';
import 'package:disaster_reco/providers/recommendation_provider.dart';
import 'package:disaster_reco/providers/services_provider.dart';
import 'package:disaster_reco/ui/widgets/recommendation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SaatBencanaTab extends ConsumerStatefulWidget {
  const SaatBencanaTab({super.key});

  @override
  ConsumerState<SaatBencanaTab> createState() => _SaatBencanaTabState();
}

class _SaatBencanaTabState extends ConsumerState<SaatBencanaTab> {
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

  void _getRecommendations() {
    if (_selectedBencana == null ||
        _selectedProvinsi == null ||
        _selectedKabupaten == null ||
        _selectedKecamatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi lokasi asal Anda')),
      );
      return;
    }

    ref
        .read(recommendationProvider.notifier)
        .fetchSaatBencana(
          _selectedBencana!,
          _selectedProvinsi!,
          _selectedKabupaten!,
          _selectedKecamatan!,
        );
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
          'Rekomendasi Evakuasi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Menemukan 3 kecamatan terdekat yang paling aman (kerentanan terendah) untuk tujuan evakuasi.',
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
            hint: 'Pilih Provinsi Anda',
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
            hint: 'Pilih Kabupaten Anda',
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
            hint: 'Pilih Kecamatan Anda',
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
          icon: const Icon(Icons.directions_run),
          label: const Text('Cari Tujuan Evakuasi'),
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
                  child: Text('Tidak ada rekomendasi evakuasi yang ditemukan.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tujuan Evakuasi Teraman:",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...recommendationState.data.asMap().entries.map((entry) {
                      final item = entry.value;
                      final penduduk =
                          item['total_penduduk_terpapar'] as int? ?? 0;
                      return RecommendationCard(
                        index: entry.key,
                        title: item['kecamatan'] as String? ?? 'N/A',
                        subtitle:
                            'Estimasi Penduduk Terdampak: ${NumberFormat.decimalPattern('id_ID').format(penduduk)} jiwa',
                        onDetailsPressed: () {
                          final db = ref.read(databaseProvider);
                          _showDetailsDialog(
                            "Detail Kerentanan: ${item['kecamatan']}",
                            db.getKerentananDetails(item['id'] as int),
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
            child: Text('Lengkapi lokasi asal untuk melihat rekomendasi.'),
          ),
      ],
    );
  }
}
