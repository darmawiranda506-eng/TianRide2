import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PassengerPage extends StatefulWidget {
  const PassengerPage({super.key});

  @override
  State<PassengerPage> createState() => _PassengerPageState();
}

class _PassengerPageState extends State<PassengerPage> {
  final _destinationController = TextEditingController();

  bool _loading = false;
  String? _orderId;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _show('Aktifkan GPS terlebih dahulu.');
      return null;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _show('Izin lokasi diperlukan.');
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _buatPesanan() async {
    final tujuan = _destinationController.text.trim();

    if (tujuan.isEmpty) {
      _show('Masukkan tujuan perjalanan.');
      return;
    }

    setState(() => _loading = true);

    try {
      final position = await _getLocation();

      if (position == null) {
        setState(() => _loading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _show('Sesi Firebase belum tersedia.');
        setState(() => _loading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .add({
        'passengerId': user.uid,
        'driverId': null,
        'status': 'menunggu',
        'tujuan': tujuan,
        'pickupLat': position.latitude,
        'pickupLng': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _orderId = doc.id;
        _loading = false;
      });

      _show('Pesanan dibuat. Mencari driver...');
    } catch (e) {
      setState(() => _loading = false);
      _show('Gagal membuat pesanan: $e');
    }
  }

  Future<void> _batalkanPesanan() async {
    if (_orderId == null) return;

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(_orderId)
        .update({
      'status': 'dibatalkan',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    setState(() => _orderId = null);
    _show('Pesanan dibatalkan.');
  }

  void _show(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'menunggu':
        return 'Mencari driver...';
      case 'diterima':
        return 'Driver menerima pesanan';
      case 'menuju':
        return 'Driver menuju lokasi Anda';
      case 'perjalanan':
        return 'Perjalanan sedang berlangsung';
      case 'selesai':
        return 'Perjalanan selesai';
      case 'dibatalkan':
        return 'Pesanan dibatalkan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TianRide Penumpang'),
      ),
      body: _orderId == null
          ? _buildOrderForm()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(_orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!.data();

                if (data == null) {
                  return const Center(
                    child: Text('Pesanan tidak ditemukan.'),
                  );
                }

                final status =
                    data['status']?.toString() ?? 'menunggu';

                if (status == 'selesai' ||
                    status == 'dibatalkan') {
                  return _buildFinished(data, status);
                }

                return _buildActiveOrder(data, status);
              },
            ),
    );
  }

  Widget _buildOrderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.location_on,
            size: 80,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 15),
          const Text(
            'Mau pergi ke mana?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(
              labelText: 'Tujuan',
              hintText: 'Contoh: Mall, pasar, kantor...',
              prefixIcon: Icon(Icons.place),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _buatPesanan,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.local_taxi),
              label: Text(
                _loading ? 'Mencari lokasi...' : 'PESAN OJEK',
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Lokasi penjemputan akan diambil dari GPS HP Anda.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrder(
    Map<String, dynamic> data,
    String status,
  ) {
    final tujuan = data['tujuan']?.toString() ?? '-';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.local_taxi,
            size: 80,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 20),
          Text(
            _statusText(status),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Tujuan'),
              subtitle: Text(tujuan),
            ),
          ),
          const SizedBox(height: 15),
          if (status == 'menunggu')
            const LinearProgressIndicator(),
          const Spacer(),
          if (status == 'menunggu')
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _batalkanPesanan,
                icon: const Icon(Icons.close),
                label: const Text('Batalkan Pesanan'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinished(
    Map<String, dynamic> data,
    String status,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'selesai'
                  ? Icons.check_circle
                  : Icons.cancel,
              size: 90,
              color: status == 'selesai'
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              _statusText(status),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                setState(() => _orderId = null);
              },
              child: const Text('Pesan Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
