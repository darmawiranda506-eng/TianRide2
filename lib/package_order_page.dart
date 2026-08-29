import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PackageOrderPage extends StatefulWidget {
  const PackageOrderPage({super.key});

  @override
  State<PackageOrderPage> createState() => _PackageOrderPageState();
}

class _PackageOrderPageState extends State<PackageOrderPage> {
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  double _weight = 1;
  bool _loading = false;

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _buatPesananPaket() async {
    final receiverName = _receiverName.text.trim();
    final receiverPhone = _receiverPhone.text.trim();
    final address = _address.text.trim();
    final note = _note.text.trim();

    if (receiverName.isEmpty) {
      _show('Masukkan nama penerima.');
      return;
    }

    if (receiverPhone.isEmpty) {
      _show('Masukkan nomor HP penerima.');
      return;
    }

    if (address.isEmpty) {
      _show('Masukkan alamat tujuan.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _show('Sesi Firebase belum tersedia.');
      return;
    }

    setState(() => _loading = true);

    try {
      final pickupOtp = _generateOtp();
      final deliveryOtp = _generateOtp();

      final doc = await FirebaseFirestore.instance
          .collection('package_orders')
          .add({
        'senderId': user.uid,
        'driverId': null,
        'status': 'menunggu',

        'receiverName': receiverName,
        'receiverPhone': receiverPhone,
        'destinationAddress': address,

        'weightKg': _weight,
        'note': note,

        'pickupOtp': pickupOtp,
        'deliveryOtp': deliveryOtp,

        'pickupVerified': false,
        'deliveryVerified': false,

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _loading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 8),
              Text('Pesanan Paket Dibuat'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simpan kode berikut. Jangan berikan OTP Delivery '
                  'kepada driver sebelum paket sampai.',
                ),
                const SizedBox(height: 20),

                Text(
                  'OTP PICKUP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  pickupOtp,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'OTP DELIVERY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  deliveryOtp,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'ID Pesanan:\n${doc.id}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('SELESAI'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _show('Gagal membuat pesanan paket: $e');
      }
    }
  }

  void _show(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirim Paket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2,
              size: 80,
              color: Colors.greenAccent,
            ),

            const SizedBox(height: 20),

            const Text(
              'Kirim Paket',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Paket lebih aman dengan OTP Pickup & Delivery.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            TextField(
              controller: _receiverName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nama Penerima',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _receiverPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nomor HP Penerima',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _address,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Alamat Tujuan',
                hintText: 'Masukkan alamat lengkap penerima',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.scale),
                        const SizedBox(width: 8),
                        Text(
                          'Berat Paket: ${_weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    Slider(
                      value: _weight,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '${_weight.toStringAsFixed(1)} kg',
                      onChanged: (value) {
                        setState(() => _weight = value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Paket',
                hintText: 'Contoh: jangan dibalik, mudah pecah, dll.',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _buatPesananPaket,
                icon: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.local_shipping),
                label: Text(
                  _loading
                      ? 'MEMBUAT PESANAN...'
                      : 'KIRIM PAKET',
                ),
              ),
            ),

            const SizedBox(height: 15),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OTP Pickup digunakan saat driver mengambil '
                        'paket. OTP Delivery digunakan saat paket '
                        'diterima.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
