import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final _nominalController = TextEditingController();

  String _method = 'Bank Mandiri';
  XFile? _proof;
  bool _loading = false;

  static const paymentAccounts = {
    'Bank Mandiri': {
      'number': '1080018819103',
      'name': 'DARMA WIRANDA',
    },
    'GoPay': {
      'number': '083134666190',
      'name': 'DARMA WIRANDA',
    },
    'DANA': {
      'number': '083134666190',
      'name': 'DARMA WIRANDA',
    },
  };

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      setState(() => _proof = image);
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Sesi login driver tidak tersedia.');
      return;
    }

    final nominal =
        int.tryParse(_nominalController.text.replaceAll('.', '').trim());

    if (nominal == null || nominal < 10000) {
      _message('Minimal top up adalah Rp 10.000.');
      return;
    }

    if (_proof == null) {
      _message('Bukti pembayaran wajib diupload.');
      return;
    }

    setState(() => _loading = true);

    try {
      final requestRef =
          FirebaseFirestore.instance.collection('topup_requests').doc();

      final proofBase64 = base64Encode(await _proof!.readAsBytes());

      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      final driverData = driverDoc.data() ?? {};

      await requestRef.set({
        'requestId': requestRef.id,
        'driverId': user.uid,
        'driverName': driverData['name'] ??
            driverData['driverName'] ??
            'Driver',
        'driverEmail': user.email,
        'amount': nominal,
        'method': _method,
        'paymentNumber': paymentAccounts[_method]!['number'],
        'paymentName': paymentAccounts[_method]!['name'],
        'proofBase64': proofBase64,
        'status': 'menunggu',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nominalController.clear();

      if (mounted) {
        setState(() {
          _proof = null;
        });
      }

      _message('Request top up berhasil dikirim ke Admin Darma Ride.');
    } catch (e) {
      _message('Gagal mengirim top up: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = paymentAccounts[_method]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Up Saldo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SALDO DRIVER',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Saldo ini adalah saldo virtual untuk komisi order.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Top Up',
                hintText: 'Minimal Rp 10.000',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Metode Pembayaran',
                border: OutlineInputBorder(),
              ),
              items: paymentAccounts.keys.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _method = value);
                      }
                    },
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'TRANSFER KE $_method',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      account['number']!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Atas Nama: ${account['name']}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _loading ? null : _pickProof,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _proof == null
                    ? 'UPLOAD BUKTI PEMBAYARAN'
                    : 'BUKTI SUDAH DIPILIH',
              ),
            ),

            if (_proof != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Bukti pembayaran siap dikirim ke Admin.',
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _loading ? 'MENGIRIM...' : 'KIRIM REQUEST TOP UP',
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Saldo baru masuk setelah pembayaran diperiksa dan disetujui Admin Darma Ride.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
