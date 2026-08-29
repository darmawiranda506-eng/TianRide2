import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tianride/package_order_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'services/fare_service.dart';
import 'services/route_service.dart';

class PassengerPage extends StatefulWidget {
  const PassengerPage({super.key});

  @override
  State<PassengerPage> createState() => _PassengerPageState();
}

class _PassengerPageState extends State<PassengerPage> {
  final _destinationController = TextEditingController();
  final MapController _mapController = MapController();

  bool _loading = false;
  bool _searchingLocation = false;

  List<Map<String, dynamic>> _locationResults = [];

  double? _selectedDestinationLat;
  double? _selectedDestinationLng;

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



  Future<void> _searchLocation(String query) async {
    final text = query.trim();

    if (text.length < 3) {
      if (mounted) {
        setState(() {
          _locationResults = [];
        });
      }
      return;
    }

    setState(() => _searchingLocation = true);

    try {
      final pos = await _getLocation();
      if (pos == null) return;

      const delta = 0.25;

      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': text,
          'format': 'jsonv2',
          'limit': '8',
          'bounded': '1',
          'viewbox':
              '${pos.longitude-delta},${pos.latitude+delta},${pos.longitude+delta},${pos.latitude-delta}',
          'accept-language': 'id',
        },
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'TianRide/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('Pencarian gagal');
      }

      final results = jsonDecode(response.body) as List;

      if (!mounted) return;

      setState(() {
        _locationResults = results.map<Map<String, dynamic>>((item) {
          return {
            'display_name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          };
        }).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _searchingLocation = false);
      }
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    final lat = location['lat'] as double;
    final lng = location['lon'] as double;
    final name = location['display_name'].toString();

    _destinationController.text = name;

    setState(() {
      _selectedDestinationLat = lat;
      _selectedDestinationLng = lng;
      _locationResults = [];
    });

    _mapController.move(
      LatLng(lat, lng),
      15,
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

    if (_selectedDestinationLat == null ||
        _selectedDestinationLng == null) {
      _show('Silakan pilih lokasi tujuan dari hasil pencarian.');
      return;
    }

    setState(() => _loading = true);

    try {
      final position = await _getLocation();

      if (position == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      var user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;

        if (user == null) {
          _show('Gagal membuat sesi penumpang.');
          if (mounted) {
            setState(() => _loading = false);
          }
          return;
        }
      }

      final destinationLat = _selectedDestinationLat!;
      final destinationLng = _selectedDestinationLng!;

      double distanceKm;

      final route = await RouteService.getRoute(
        pickupLat: position.latitude,
        pickupLng: position.longitude,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );

      if (route != null) {
        distanceKm = route.distanceKm;
      } else {
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destinationLat,
          destinationLng,
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

        'destinationLat': destinationLat,
        'destinationLng': destinationLng,

        'distanceKm': distanceKm,
        'fare': fare,

        'paymentMethod': 'tunai',
        'paymentStatus': 'belum_dibayar',

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _orderId = doc.id;
        _loading = false;
      });

      _show(
        'Pesanan dibuat • ${distanceKm.toStringAsFixed(1)} km • '
        '${FareService.formatRupiah(fare)}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _show('Gagal membuat pesanan: $e');
      }
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
        'cancelledBy': 'passenger',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _orderId = null;
        _selectedDestinationLat = null;
        _selectedDestinationLng = null;
        _destinationController.clear();
      });

      _show('Pesanan berhasil dibatalkan.');
    } catch (e) {
      _show('Gagal membatalkan pesanan: $e');
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

          SizedBox(
            height: 55,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PackageOrderPage(),
                  ),
                );
              },
              icon: const Icon(Icons.inventory_2),
              label: const Text('KIRIM PAKET'),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: _destinationController,
            textInputAction: TextInputAction.search,
            onChanged: _searchLocation,
            decoration: InputDecoration(
              labelText: 'Cari tujuan',
              hintText: 'Contoh: mall, pasar, kantor...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_destinationController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _destinationController.clear();
                            setState(() {
                              _locationResults = [];
                              _selectedDestinationLat = null;
                              _selectedDestinationLng = null;
                            });
                          },
                        )
                      : null),
              border: const OutlineInputBorder(),
            ),
          ),

          if (_locationResults.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 5),
              child: Column(
                children: _locationResults.map((location) {
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(
                      location['display_name'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectLocation(location),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 15),

          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(-1.6101, 103.6131),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tianride',
                  ),
                  if (_selectedDestinationLat != null &&
                      _selectedDestinationLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _selectedDestinationLat!,
                            _selectedDestinationLng!,
                          ),
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            size: 45,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
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

  Widget _buildDriverTrackingMap(Map<String, dynamic> data) {
    final driverId = data['driverId']?.toString();

    if (driverId == null || driverId.isEmpty) {
      return const SizedBox.shrink();
    }

    final pickupLat = (data['pickupLat'] as num?)?.toDouble();
    final pickupLng = (data['pickupLng'] as num?)?.toDouble();
    final destinationLat =
        (data['destinationLat'] as num?)?.toDouble();
    final destinationLng =
        (data['destinationLng'] as num?)?.toDouble();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .snapshots(),
      builder: (context, snapshot) {
        final driverData = snapshot.data?.data();

        final driverLat =
            (driverData?['lat'] as num?)?.toDouble();
        final driverLng =
            (driverData?['lng'] as num?)?.toDouble();

        final points = <LatLng>[];

        if (pickupLat != null && pickupLng != null) {
          points.add(LatLng(pickupLat, pickupLng));
        }

        if (driverLat != null && driverLng != null) {
          points.add(LatLng(driverLat, driverLng));
        }

        if (destinationLat != null && destinationLng != null) {
          points.add(LatLng(destinationLat, destinationLng));
        }

        if (points.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 15),
            const Text(
              'Lokasi Perjalanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tianride',
                    ),
                    MarkerLayer(
                      markers: [
                        if (pickupLat != null && pickupLng != null)
                          Marker(
                            point: LatLng(pickupLat, pickupLng),
                            width: 45,
                            height: 45,
                            child: const Icon(
                              Icons.person_pin_circle,
                              size: 40,
                              color: Colors.blue,
                            ),
                          ),
                        if (driverLat != null && driverLng != null)
                          Marker(
                            point: LatLng(driverLat, driverLng),
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.motorcycle,
                              size: 42,
                              color: Colors.green,
                            ),
                          ),
                        if (destinationLat != null && destinationLng != null)
                          Marker(
                            point: LatLng(
                              destinationLat,
                              destinationLng,
                            ),
                            width: 45,
                            height: 45,
                            child: const Icon(
                              Icons.location_on,
                              size: 42,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (driverLat != null && driverLng != null)
              const Row(
                children: [
                  Icon(Icons.motorcycle, size: 20),
                  SizedBox(width: 6),
                  Text('Driver sedang dilacak secara realtime'),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.location_searching, size: 20),
                  SizedBox(width: 6),
                  Text('Menunggu lokasi driver...'),
                ],
              ),
          ],
        );
      },
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
          _buildDriverTrackingMap(data),
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
