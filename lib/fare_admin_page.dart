import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/fare_service.dart';

class FareAdminPage extends StatefulWidget {
  const FareAdminPage({super.key});

  @override
  State<FareAdminPage> createState() => _FareAdminPageState();
}

class _FareAdminPageState extends State<FareAdminPage> {
  final _baseDistanceController =
      TextEditingController(text: '4');

  final _baseFareController =
      TextEditingController(text: '8900');

  final _extraFareController =
      TextEditingController(text: '2300');

  bool _loading = true;
  bool _saving = false;

  FareConfig _config = FareConfig.defaultConfig;

  @override
  void initState() {
    super.initState();
    _loadFare();
  }

  @override
  void dispose() {
    _baseDistanceController.dispose();
    _baseFareController.dispose();
    _extraFareController.dispose();
    super.dispose();
  }

  Future<void> _loadFare() async {
    try {
      final config = await FareService.getConfig();

      if (!mounted) return;

      setState(() {
        _config = config;

        _baseDistanceController.text =
            config.baseDistanceKm.toString();

        _baseFareController.text =
            config.baseFare.round().toString();

        _extraFareController.text =
            config.extraFarePerKm.round().toString();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message('Gagal membaca tarif: $e');
    }
  }

  Future<void> _saveFare() async {
    final baseDistance =
        double.tryParse(_baseDistanceController.text.trim());

    final baseFare =
        double.tryParse(_baseFareController.text.trim());

    final extraFare =
        double.tryParse(_extraFareController.text.trim());

    if (baseDistance == null || baseDistance <= 0) {
      _message('Jarak dasar tidak valid.');
      return;
    }

    if (baseFare == null || baseFare < 0) {
      _message('Tarif dasar tidak valid.');
      return;
    }

    if (extraFare == null || extraFare < 0) {
      _message('Tarif per km tidak valid.');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('fare')
          .set({
        'baseDistanceKm': baseDistance,
        'baseFare': baseFare,
        'extraFarePerKm': extraFare,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      }, SetOptions(merge: true));

      final newConfig = FareConfig(
        baseDistanceKm: baseDistance,
        baseFare: baseFare,
        extraFarePerKm: extraFare,
      );

      if (!mounted) return;

      setState(() {
        _config = newConfig;
      });

      _message(
        'Tarif berhasil diperbarui.\n'
        'Order baru akan menggunakan tarif ini.',
      );
    } catch (e) {
      _message('Gagal menyimpan tarif: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _rupiah(double value) {
    return FareService.formatRupiah(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Tarif'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARIF PERJALANAN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Perubahan tarif berlaku untuk '
                          'pesanan baru. Pesanan yang sudah '
                          'dibuat tidak berubah.',
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller:
                              _baseDistanceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Jarak dasar',
                            suffixText: 'km',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: _baseFareController,
                          keyboardType:
                              TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tarif dasar',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller:
                              _extraFareController,
                          keyboardType:
                              TextInputType.number,
                          decoration: const InputDecoration(
                            labelText:
                                'Tarif setiap km tambahan',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _saving ? null : _saveFare,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _saving
                                  ? 'Menyimpan...'
                                  : 'SIMPAN TARIF',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARIF SAAT INI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '≤ ${_config.baseDistanceKm} km : '
                          '${_rupiah(_config.baseFare)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '> ${_config.baseDistanceKm} km : '
                          '${_rupiah(_config.baseFare)} + '
                          '${_rupiah(_config.extraFarePerKm)} '
                          'per km tambahan',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(Icons.cloud),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Contoh saat hujan: '
                            'admin dapat menaikkan tarif '
                            'sewaktu-waktu tanpa update APK.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
