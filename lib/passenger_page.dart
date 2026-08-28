import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'services/fare_service.dart';
import 'services/route_service.dart';

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

    var permission = await Geolocator.checkPermission();

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



  String _formatRupiah(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }

    return 'Rp ${buffer.toString()}';
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

      // Ubah alamat/nama tujuan menjadi koordinat.
      List<Location> locations;

      try {
        locations = await locationFromAddress(tujuan);
      } catch (_) {
        locations = [];
      }

      if (locations.isEmpty) {
        setState(() => _loading = false);
        _show(
          'Tujuan tidak ditemukan. Coba masukkan alamat yang lebih lengkap.',
        );
        return;
      }

      final destination = locations.first;

      // Hitung jarak jalan garis lurus sebagai dasar tarif.
      // Nilai ini nantinya dapat dikembangkan menjadi jarak rute jalan.
      // Hitung jarak berdasarkan rute jalan menggunakan OSRM.
      // Jika rute gagal, gunakan jarak garis lurus sebagai cadangan.
      double distanceKm;

      final route = await RouteService.getRoute(
        pickupLat: position.latitude,
        pickupLng: position.longitude,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
      );

      if (route != null) {
        distanceKm = route.distanceKm;
      } else {
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destination.latitude,
          destination.longitude,
        );
        distanceKm = distanceMeters / 1000.0;
      }

      final fare = FareService.calculateFare(distanceKm);

      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .add({
        'passengerId': user.uid,
        'driverId': null,
        'status': 'menunggu',
        'tujuan': tujuan,

        'pickupLat': position.latitude,
        'pickupLng': position.longitude,

        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,

        'distanceKm': distanceKm,
        'fare': fare,

        'paymentMethod': 'tunai',
        'paymentStatus': 'belum_dibayar',

        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _orderId = doc.id;
        _loading = false;
      });

      _show(
        'Pesanan dibuat • ${distanceKm.toStringAsFixed(1)} km • '
        '${FareService.formatRupiah(fare)}',
      );
    } catch (e) {
      setState(() => _loading = false);
      _show('Gagal membuat pesanan: $e');
    }
  }

  Future<void> _batalkanPesanan() async {
    if (_orderId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_orderId)
          .update({
        'status': 'dibatalkan',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _orderId = null);
      _show('Pesanan dibatalkan.');
    } catch (e) {
      _show('Gagal membatalkan pesanan: $e');
    }
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
      case 'tiba':
        return 'Driver sudah tiba';
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
        title: const Text('Darma Ride Penumpang'),
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
            textInputAction: TextInputAction.done,
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
                _loading
                    ? 'Menghitung tarif...'
                    : 'PESAN OJEK',
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.gps_fixed),
                  SizedBox(height: 8),
                  Text(
                    'Lokasi penjemputan diambil dari GPS HP Anda.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tarif dasar sampai 4 km: Rp 9.300\n'
                    'Tambahan di atas 4 km: Rp 2.300/km',
                    textAlign: TextAlign.center,
                  ),
                ],
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
    final distance = (data['distanceKm'] ?? 0).toDouble();
    final fare = (data['fare'] ?? 0).toDouble();

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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Tujuan'),
                  subtitle: Text(tujuan),
                ),
                ListTile(
                  leading: const Icon(Icons.route),
                  title: const Text('Jarak'),
                  subtitle: Text(
                    '${distance.toStringAsFixed(1)} km',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Tarif'),
                  subtitle: Text(
                    _formatRupiah(fare),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.money),
                  title: Text('Pembayaran'),
                  subtitle: Text('TUNAI'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (status == 'menunggu')
            const LinearProgressIndicator(),
          const SizedBox(height: 20),
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
    final distance = (data['distanceKm'] ?? 0).toDouble();
    final fare = (data['fare'] ?? 0).toDouble();

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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (status == 'selesai') ...[
              const SizedBox(height: 20),
              Text(
                'Jarak: ${distance.toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 8),
              Text(
                'Tarif: ${_formatRupiah(fare)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
