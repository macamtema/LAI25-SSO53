// lib/ui/tabs/pasca_bencana_tab.dart

import 'package:disaster_reco/models/recommendation_state.dart';
import 'package:disaster_reco/providers/dropdown_provider.dart';
import 'package:disaster_reco/providers/recommendation_provider.dart';
import 'package:disaster_reco/providers/services_provider.dart';
import 'package:disaster_reco/ui/widgets/recommendation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PascaBencanaMode { cariLokasi, cariBencana }

class PascaBencanaTab extends ConsumerStatefulWidget {
  const PascaBencanaTab({super.key});

  @override
  ConsumerState<PascaBencanaTab> createState() => _PascaBencanaTabState();
}

class _PascaBencanaTabState extends ConsumerState<PascaBencanaTab> {
  PascaBencanaMode _selectedMode = PascaBencanaMode.cariLokasi;

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
    if (_selectedMode == PascaBencanaMode.cariLokasi) {
      if (_selectedBencana == null ||
          _selectedProvinsi == null ||
          _selectedKabupaten == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih bencana, provinsi, dan kabupaten'),
          ),
        );
        return;
      }
      ref
          .read(recommendationProvider.notifier)
          .fetchPascaBencanaLokasiByCapacity(
            _selectedBencana!,
            _selectedProvinsi!,
            _selectedKabupaten!,
          );
    } else {
      // cariBencana
      if (_selectedProvinsi == null ||
          _selectedKabupaten == null ||
          _selectedKecamatan == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pilih lokasi lengkap')));
        return;
      }
      ref
          .read(recommendationProvider.notifier)
          .fetchPascaBencanaJenisByCapacity(
            _selectedProvinsi!,
            _selectedKabupaten!,
            _selectedKecamatan!,
          );
    }
  }

  Widget _buildInputs() {
    final bencanaAsync = ref.watch(bencanaListProvider);
    // Untuk mode cariBencana, kita butuh semua provinsi, tidak tergantung bencana
    final provinsiAsync = ref.watch(
      provinsiListProvider("BANJIR"),
    ); // Asumsi BANJIR ada di semua provinsi, atau buat query baru
    final kabupatenAsync = _selectedProvinsi != null
        ? ref.watch(kabupatenListProvider(("BANJIR", _selectedProvinsi!)))
        : null;
    final kecamatanAsync =
        _selectedProvinsi != null && _selectedKabupaten != null
        ? ref.watch(
            kecamatanListProvider((
              "BANJIR",
              _selectedProvinsi!,
              _selectedKabupaten!,
            )),
          )
        : null;

    if (_selectedMode == PascaBencanaMode.cariLokasi) {
      return Column(
        children: [
          _buildDropdown<String>(
            hint: 'Pilih Jenis Bencana',
            value: _selectedBencana,
            items: bencanaAsync,
            onChanged: (v) => setState(() {
              _selectedBencana = v;
              _selectedProvinsi = null;
              _selectedKabupaten = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_selectedBencana != null)
            _buildDropdown<String>(
              hint: 'Pilih Provinsi',
              value: _selectedProvinsi,
              items: ref.watch(provinsiListProvider(_selectedBencana!)),
              onChanged: (v) => setState(() {
                _selectedProvinsi = v;
                _selectedKabupaten = null;
              }),
            ),
          const SizedBox(height: 12),
          if (_selectedProvinsi != null)
            _buildDropdown<String>(
              hint: 'Pilih Kabupaten',
              value: _selectedKabupaten,
              items: ref.watch(
                kabupatenListProvider((_selectedBencana!, _selectedProvinsi!)),
              ),
              onChanged: (v) => setState(() {
                _selectedKabupaten = v;
              }),
            ),
        ],
      );
    } else {
      // cariBencana
      return Column(
        children: [
          _buildDropdown<String>(
            hint: 'Pilih Provinsi',
            value: _selectedProvinsi,
            items: provinsiAsync,
            onChanged: (v) => setState(() {
              _selectedProvinsi = v;
              _selectedKabupaten = null;
              _selectedKecamatan = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_selectedProvinsi != null && kabupatenAsync != null)
            _buildDropdown<String>(
              hint: 'Pilih Kabupaten',
              value: _selectedKabupaten,
              items: kabupatenAsync,
              onChanged: (v) => setState(() {
                _selectedKabupaten = v;
                _selectedKecamatan = null;
              }),
            ),
          const SizedBox(height: 12),
          if (_selectedKabupaten != null && kecamatanAsync != null)
            _buildDropdown<String>(
              hint: 'Pilih Kecamatan',
              value: _selectedKecamatan,
              items: kecamatanAsync,
              onChanged: (v) => setState(() {
                _selectedKecamatan = v;
              }),
            ),
        ],
      );
    }
  }

  Widget _buildResults(RecommendationState state) {
    if (state is RecommendationLoading)
      return const Center(child: CircularProgressIndicator());
    if (state is RecommendationError)
      return Center(
        child: Text(
          'Error: ${state.message}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    if (state is RecommendationSuccess) {
      if (state.data.isEmpty)
        return const Center(
          child: Text('Tidak ada rekomendasi yang ditemukan.'),
        );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Rekomendasi Prioritas Rehabilitasi:",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...state.data.asMap().entries.map((entry) {
            final item = entry.value;
            if (_selectedMode == PascaBencanaMode.cariLokasi) {
              return RecommendationCard(
                index: entry.key,
                title: 'Kecamatan: ${item['kecamatan']}',
                subtitle:
                    'Indeks Kapasitas: ${item['indeks_kapasitas']?.toStringAsFixed(2) ?? 'N/A'} (Lebih rendah lebih prioritas)',
                onDetailsPressed: () => _showDetailsDialog(
                  "Detail Kapasitas: ${item['kecamatan']}",
                  ref
                      .read(databaseProvider)
                      .getKapasitasDetails(item['id'] as int),
                ),
              );
            } else {
              return RecommendationCard(
                index: entry.key,
                title: 'Bencana: ${item['bencana']}',
                subtitle:
                    'Indeks Kapasitas: ${item['indeks_kapasitas']?.toStringAsFixed(2) ?? 'N/A'} (Lebih rendah lebih prioritas)',
                onDetailsPressed: () => _showDetailsDialog(
                  "Detail Kapasitas: ${item['bencana']}",
                  ref
                      .read(databaseProvider)
                      .getKapasitasDetails(item['id'] as int),
                ),
              );
            }
          }).toList(),
        ],
      );
    }
    return const Center(
      child: Text('Pilih mode dan masukkan input untuk melihat rekomendasi.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Rehabilitasi Pasca-Bencana',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Menemukan area atau jenis bencana yang paling membutuhkan dukungan rehabilitasi berdasarkan kapasitas terendah.',
        ),
        const SizedBox(height: 24),
        SegmentedButton<PascaBencanaMode>(
          segments: const <ButtonSegment<PascaBencanaMode>>[
            ButtonSegment(
              value: PascaBencanaMode.cariLokasi,
              label: Text('Cari Lokasi'),
              icon: Icon(Icons.location_on),
            ),
            ButtonSegment(
              value: PascaBencanaMode.cariBencana,
              label: Text('Cari Bencana'),
              icon: Icon(Icons.dangerous),
            ),
          ],
          selected: {_selectedMode},
          onSelectionChanged: (newSelection) => setState(() {
            _selectedMode = newSelection.first;
            ref.read(recommendationProvider.notifier).resetState();
            _selectedBencana = null;
            _selectedProvinsi = null;
            _selectedKabupaten = null;
            _selectedKecamatan = null;
          }),
        ),
        const SizedBox(height: 24),
        _buildInputs(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _getRecommendations,
          icon: const Icon(Icons.analytics),
          label: const Text('Analisis Prioritas'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        _buildResults(ref.watch(recommendationProvider)),
      ],
    );
  }
}
