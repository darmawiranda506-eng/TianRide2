import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  bool _online = false;
  bool _updatingLocation = false;
  String? _activeOrderId;
  Timer? _locationTimer;

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _setOnline(bool value) async {
    if (_uid.isEmpty) {
      _show('Sesi Firebase belum tersedia.');
      return;
    }

    if (value) {
      final position = await _getLocation();

      if (position == null) return;

      await _db.collection('drivers').doc(_uid).set({
        'online': true,
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _startLocationUpdates();
    } else {
      _locationTimer?.cancel();

      await _db.collection('drivers').doc(_uid).set({
        'online': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (mounted) {
      setState(() => _online = value);
    }
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

  void _startLocationUpdates() {
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    if (!_online || _uid.isEmpty) return;

    if (_updatingLocation) return;

    _updatingLocation = true;

    try {
      final position = await _getLocation();

      if (position != null) {
        await _db.collection('drivers').doc(_uid).set({
          'online': true,
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } finally {
      _updatingLocation = false;
    }
  }

  Future<void> _terimaPesanan(
    String orderId,
  ) async {
    if (_uid.isEmpty) return;

    await _db.collection('orders').doc(orderId).update({
      'driverId': _uid,
      'status': 'diterima',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _activeOrderId = orderId;
    });

    _show('Pesanan diterima.');
  }

  Future<void> _ubahStatus(
    String orderId,
    String status,
  ) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      '${status}At': FieldValue.serverTimestamp(),
    });

    if (status == 'selesai' ||
        status == 'dibatalkan') {
      setState(() {
        _activeOrderId = null;
      });
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'diterima':
        return 'Pesanan diterima';
      case 'menuju':
        return 'Menuju penumpang';
      case 'perjalanan':
        return 'Perjalanan berlangsung';
      case 'selesai':
        return 'Perjalanan selesai';
      default:
        return status;
    }
  }

  void _show(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TianRide Driver'),
      ),
      body: Column(
        children: [
          _buildOnlinePanel(),
          Expanded(
            child: _activeOrderId == null
                ? _buildOrders()
                : _buildActiveOrder(),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlinePanel() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _online
                  ? Icons.circle
                  : Icons.circle_outlined,
              color: _online
                  ? Colors.greenAccent
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _online
                        ? 'Anda sedang ONLINE'
                        : 'Anda sedang OFFLINE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _online
                        ? 'Menerima pesanan di sekitar Anda'
                        : 'Aktifkan untuk menerima pesanan',
                  ),
                ],
              ),
            ),
            Switch(
              value: _online,
              onChanged: _setOnline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders() {
    if (!_online) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power_settings_new,
                size: 70,
              ),
              SizedBox(height: 15),
              Text(
                'Anda sedang offline',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Aktifkan status ONLINE untuk menerima pesanan.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('orders')
          .where('status', isEqualTo: 'menunggu')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal membaca order:\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orders = snapshot.data!.docs;

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 70,
                ),
                SizedBox(height: 15),
                Text(
                  'Belum ada pesanan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('Menunggu order penumpang...'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data();

            return Card(
              margin:
                  const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.local_taxi,
                          color:
                              Colors.greenAccent,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Pesanan Baru',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tujuan: ${data['tujuan'] ?? '-'}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lokasi jemput: '
                      '${data['pickupLat'] ?? '-'}, '
                      '${data['pickupLng'] ?? '-'}',
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _terimaPesanan(doc.id),
                        icon: const Icon(
                          Icons.check,
                        ),
                        label: const Text(
                          'TERIMA PESANAN',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveOrder() {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('orders')
          .doc(_activeOrderId)
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
            child: Text('Order tidak ditemukan.'),
          );
        }

        final status =
            data['status']?.toString() ?? 'diterima';

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.local_taxi,
                size: 85,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 15),
              Text(
                _statusText(status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Tujuan'),
                  subtitle: Text(
                    data['tujuan']?.toString() ?? '-',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (status == 'diterima')
                _actionButton(
                  'SAYA MENUJU PENUMPANG',
                  () => _ubahStatus(
                    _activeOrderId!,
                    'menuju',
                  ),
                ),
              if (status == 'menuju')
                _actionButton(
                  'MULAI PERJALANAN',
                  () => _ubahStatus(
                    _activeOrderId!,
                    'perjalanan',
                  ),
                ),
              if (status == 'perjalanan')
                _actionButton(
                  'SELESAIKAN PERJALANAN',
                  () => _ubahStatus(
                    _activeOrderId!,
                    'selesai',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton(
    String text,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
