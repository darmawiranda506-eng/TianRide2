import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:geolocator/geolocator.dart';
import 'services/notification_service.dart';
import 'services/driver_background_service.dart';
import 'topup_page.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  StreamSubscription<Position>? _locationSubscription;

  bool _online = false;
  bool _loading = false;

  final Set<String> _notifiedOrderIds = <String>{};

  String? _activeOrderId;
  String? _activePackageOrderId;
  String _driverName = 'Driver Darma Ride';
  String _vehicle = 'Motor • Darma Ride';

  final TextEditingController _nameController =
      TextEditingController(text: 'Driver Darma Ride');

  final TextEditingController _vehicleController =
      TextEditingController(text: 'Motor • Darma Ride');

  final CollectionReference<Map<String, dynamic>> _orders =
      FirebaseFirestore.instance.collection('orders');

  final CollectionReference<Map<String, dynamic>> _packageOrders =
      FirebaseFirestore.instance.collection('package_orders');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _driverDoc =>
      FirebaseFirestore.instance.collection('drivers').doc(_uid);

  @override
  void initState() {
    super.initState();
    initializeDriverBackgroundService();
    _restoreDriverState();
  }

  Future<void> _restoreDriverState() async {
    try {
      final doc = await _driverDoc.get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !mounted) return;

      final online = data['online'] == true;
      final driverName = data['driverName']?.toString();
      final vehicle = data['vehicle']?.toString();

      setState(() {
        _online = online;
        if (driverName != null && driverName.isNotEmpty) {
          _driverName = driverName;
        }
        if (vehicle != null && vehicle.isNotEmpty) {
          _vehicle = vehicle;
        }
      });

      _nameController.text = _driverName;
      _vehicleController.text = _vehicle;

      if (online) {
        _startLocationStream();
        await _showDriverBubble();
      }
    } catch (e) {
      debugPrint('Gagal restore status driver: $e');
    }
  }

  void _startLocationStream() {
    _locationSubscription?.cancel();

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      if (!_online) return;

      try {
        await _driverDoc.update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Gagal update lokasi driver: $e');
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _nameController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline(bool value) async {
    if (value) {
      await _goOnline();
    } else {
      await _goOffline();
    }
  }

  Future<void> _showDriverBubble() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();

      if (!granted) {
        final result = await FlutterOverlayWindow.requestPermission();
        if (result != true) {
          _message('Izin bola mengambang belum diberikan.');
          return;
        }
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'TianRide Driver',
        overlayContent: 'Driver ONLINE',
        width: 90,
        height: 90,
        startPosition: const OverlayPosition(20, 180),
      );

      await FlutterOverlayWindow.resizeOverlay(90, 90, true);
    } catch (e) {
      debugPrint('Gagal menampilkan bubble: $e');
    }
  }

  Future<void> _hideDriverBubble() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('Gagal menutup bubble: $e');
    }
  }

  Future<void> _goOnline() async {
    setState(() => _loading = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('GPS belum aktif.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _driverName = _nameController.text.trim().isEmpty
          ? 'Driver Darma Ride'
          : _nameController.text.trim();

      _vehicle = _vehicleController.text.trim().isEmpty
          ? 'Motor • Darma Ride'
          : _vehicleController.text.trim();

      await _driverDoc.set({
        'driverId': _uid,
        'driverName': _driverName,
        'vehicle': _vehicle,
        'online': true,
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _online = true);
      await startDriverBackgroundService(_uid);
      await _showDriverBubble();

      _locationSubscription?.cancel();

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) async {
        if (!_online) return;

        await _driverDoc.update({
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Driver ONLINE. Menunggu pesanan...');
    } catch (e) {
      setState(() => _online = false);
      _message('Gagal online: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goOffline() async {
    await _hideDriverBubble();
    await stopDriverBackgroundService();
    _locationSubscription?.cancel();
    _locationSubscription = null;

    try {
      await _driverDoc.update({
        'online': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _online = false);
      _message('Driver OFFLINE.');
    }
  }

  Future<void> _acceptOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    if (!_online) {
      _message('Aktifkan status ONLINE terlebih dahulu.');
      return;
    }

    try {
      await _orders.doc(orderId).update({
        'driverId': _uid,
        'driverName': _driverName,
        'vehicle': _vehicle,
        'status': 'diterima',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _activeOrderId = orderId);

      _message('Pesanan diterima.');
    } catch (e) {
      _message('Gagal menerima pesanan: $e');
    }
  }

  Future<void> _acceptPackageOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    if (!_online ||
        _activeOrderId != null ||
        _activePackageOrderId != null) {
      _message('Selesaikan pesanan aktif terlebih dahulu.');
      return;
    }

    try {
      await _packageOrders.doc(orderId).update({
        'driverId': _uid,
        'status': 'driver_menuju_pickup',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activePackageOrderId = orderId;
        });
      }

      _message('Paket diterima. Driver menuju lokasi pickup.');
    } catch (e) {
      _message('Gagal menerima paket: $e');
    }
  }

  Future<void> _verifyPackagePickupOtp(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final controller = TextEditingController();

    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Verifikasi OTP Pickup'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Masukkan OTP dari pengirim',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length == 6) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('VERIFIKASI'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (otp == null || otp.isEmpty) return;

    final correctOtp = data['pickupOtp']?.toString();

    if (correctOtp == null || correctOtp.isEmpty) {
      _message('OTP pickup belum tersedia.');
      return;
    }

    if (otp != correctOtp) {
      _message('❌ OTP salah. Paket belum dianggap diambil.');
      return;
    }

    try {
      await _packageOrders.doc(orderId).update({
        'status': 'paket_diambil',
        'pickupVerified': true,
        'pickupVerifiedBy': _uid,
        'pickupVerifiedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _message('✅ OTP benar. Paket resmi telah diambil.');
      }
    } catch (e) {
      _message('Gagal memverifikasi OTP: $e');
    }
  }

  Future<void> _rejectPackageOrder(String orderId) async {
    _message('Pesanan paket dilewati.');
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await _orders.doc(orderId).update({
        'rejectedBy': FieldValue.arrayUnion([_uid]),
      });

      _message('Pesanan dilewati.');
    } catch (e) {
      _message('Gagal melewati pesanan: $e');
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_activeOrderId == null) return;

    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'menuju') {
      updates['startedHeadingAt'] = FieldValue.serverTimestamp();
    }

    if (status == 'tiba') {
      updates['arrivedAt'] = FieldValue.serverTimestamp();
    }

    if (status == 'perjalanan') {
      updates['tripStartedAt'] = FieldValue.serverTimestamp();
    }

    if (status == 'selesai') {
      updates['completedAt'] = FieldValue.serverTimestamp();
      updates['paymentStatus'] = 'menunggu_tunai';
    }

    try {
      await _orders.doc(_activeOrderId).update(updates);

      if (status == 'selesai') {
        _message('Perjalanan selesai. Menunggu pembayaran tunai.');
      } else {
        _message('Status perjalanan diperbarui.');
      }
    } catch (e) {
      _message('Gagal mengubah status: $e');
    }
  }

  Future<void> _confirmCashPayment() async {
    if (_activeOrderId == null) return;

    try {
      await _orders.doc(_activeOrderId).update({
        'paymentStatus': 'dibayar_tunai',
        'paidAt': FieldValue.serverTimestamp(),
      });

      _message('Pembayaran tunai dikonfirmasi.');

      setState(() => _activeOrderId = null);
    } catch (e) {
      _message('Gagal mengonfirmasi pembayaran: $e');
    }
  }

  Future<void> _cancelActiveOrder() async {
    if (_activeOrderId == null) return;

    try {
      await _orders.doc(_activeOrderId).update({
        'status': 'dibatalkan',
        'cancelledBy': 'driver',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      setState(() => _activeOrderId = null);
      _message('Pesanan dibatalkan.');
    } catch (e) {
      _message('Gagal membatalkan: $e');
    }
  }

  Future<void> _navigateToPassenger(Map<String, dynamic> data) async {
    final lat = (data['pickupLat'] as num?)?.toDouble();
    final lng = (data['pickupLng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      _message('Lokasi penumpang belum tersedia.');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _message('Google Maps tidak dapat dibuka.');
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _statusButton(
    String status,
    String label,
    IconData icon,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : () => _updateStatus(status),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _availablePackageOrders() {
    if (!_online || _activeOrderId != null) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _packageOrders
          .where('status', isEqualTo: 'menunggu')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Gagal mengambil paket: ${snapshot.error}',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 20, 12, 8),
              child: Text(
                '📦 PESANAN PAKET',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();

                final receiver =
                    data['receiverName']?.toString() ?? 'Penerima';

                final address =
                    data['destinationAddress']?.toString() ?? '-';

                final weight =
                    (data['weightKg'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📦 PAKET BARU',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text('Penerima: $receiver'),
                        Text('Alamat: $address'),
                        Text(
                          'Berat: ${weight.toStringAsFixed(1)} kg',
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _acceptPackageOrder(
                                  doc.id,
                                  data,
                                ),
                                icon: const Icon(
                                  Icons.local_shipping,
                                ),
                                label: const Text(
                                  'TERIMA PAKET',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _rejectPackageOrder(doc.id),
                                icon: const Icon(Icons.close),
                                label: const Text('LEWATI'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _activePackageCard() {
    if (_activePackageOrderId == null) {
      return const SizedBox();
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _packageOrders
          .doc(_activePackageOrderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Gagal mengambil data paket: ${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Data paket tidak ditemukan.'),
          );
        }

        final data = snapshot.data!.data()!;
        final status = data['status']?.toString() ?? '';

        final receiver =
            data['receiverName']?.toString() ?? 'Penerima';

        final address =
            data['destinationAddress']?.toString() ?? '-';

        final weight =
            (data['weightKg'] ?? 0).toDouble();

        final pickupVerified =
            data['pickupVerified'] == true;

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '📦 PAKET AKTIF',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),

                const SizedBox(height: 12),

                Text('Penerima: $receiver'),
                Text('Alamat: $address'),
                Text(
                  'Berat: ${weight.toStringAsFixed(1)} kg',
                ),

                const SizedBox(height: 16),

                Text(
                  pickupVerified
                      ? '✅ Paket sudah diverifikasi dan diambil'
                      : '🚚 Driver menuju lokasi pengambilan',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                if (!pickupVerified &&
                    status == 'driver_menuju_pickup')
                  ElevatedButton.icon(
                    onPressed: () =>
                        _verifyPackagePickupOtp(
                      _activePackageOrderId!,
                      data,
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text(
                      'VERIFIKASI OTP PICKUP',
                    ),
                  ),

                if (pickupVerified)
                  const Text(
                    'Paket siap dibawa ke penerima.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _activeOrderCard() {
    if (_activeOrderId == null) {
      return const SizedBox();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _orders.doc(_activeOrderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }

        final data = snapshot.data!.data()!;
        final status = data['status'] ?? 'menunggu';
        final fare = (data['fare'] ?? 0).toDouble();
        final payment = data['paymentStatus'] ?? 'belum_dibayar';

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.local_taxi,
                  size: 45,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pesanan Aktif',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Penumpang: ${data['passengerName'] ?? 'Penumpang'}',
                ),
                Text(
                  'Tarif: Rp ${fare.toStringAsFixed(0)}',
                ),
                const Text('Pembayaran: TUNAI'),
                Text('Status: $status'),
                const SizedBox(height: 14),
                if (status == 'diterima') ...[
                  _statusButton(
                    'menuju',
                    'MENUJU PENUMPANG',
                    Icons.navigation,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToPassenger(data),
                      icon: const Icon(Icons.navigation),
                      label: const Text('NAVIGASI KE PENUMPANG'),
                    ),
                  ),
                ],
                if (status == 'menuju')
                  _statusButton(
                    'tiba',
                    'SUDAH TIBA',
                    Icons.place,
                  ),
                if (status == 'tiba')
                  _statusButton(
                    'perjalanan',
                    'MULAI PERJALANAN',
                    Icons.play_arrow,
                  ),
                if (status == 'perjalanan')
                  _statusButton(
                    'selesai',
                    'SELESAIKAN PERJALANAN',
                    Icons.flag,
                  ),
                if (status == 'selesai' &&
                    payment == 'menunggu_tunai')
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _confirmCashPayment,
                      icon: const Icon(Icons.payments),
                      label: const Text('KONFIRMASI BAYAR TUNAI'),
                    ),
                  ),
                const SizedBox(height: 8),
                if ([
                  'diterima',
                  'menuju',
                  'tiba',
                  'perjalanan',
                ].contains(status))
                  OutlinedButton.icon(
                    onPressed: _cancelActiveOrder,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Batalkan Pesanan'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _availableOrders() {
    if (!_online || _activeOrderId != null) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orders
          .where('status', isEqualTo: 'menunggu')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Gagal mengambil pesanan: ${snapshot.error}',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        for (final doc in docs) {
          if (!_notifiedOrderIds.contains(doc.id)) {
            final data = doc.data();

            _notifiedOrderIds.add(doc.id);

            final distance =
                (data['distanceKm'] ?? 0).toDouble();
            final fare =
                (data['fare'] ?? 0).toDouble();

            NotificationService.showOrderNotification(
              title: 'ORDER BARU',
              body:
                  '${distance.toStringAsFixed(1)} km • '
                  'Rp ${fare.toStringAsFixed(0)} • '
                  'Pembayaran TUNAI',
            );
          }
        }

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Belum ada pesanan masuk.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final fare = (data['fare'] ?? 0).toDouble();
            final distance =
                (data['distanceKm'] ?? 0).toDouble();

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER BARU',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Penumpang: ${data['passengerName'] ?? 'Penumpang'}',
                    ),
                    Text(
                      'Jarak: ${distance.toStringAsFixed(1)} km',
                    ),
                    Text(
                      'Tarif: Rp ${fare.toStringAsFixed(0)}',
                    ),
                    const Text('Pembayaran: TUNAI'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _acceptOrder(doc.id, data),
                            icon: const Icon(Icons.check),
                            label: const Text('TERIMA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _rejectOrder(doc.id),
                            icon: const Icon(Icons.close),
                            label: const Text('LEWATI'),
                          ),
                        ),
                      ],
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

  Widget _driverProfile() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverDoc.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final balance =
            (data['balance'] as num?)?.toDouble() ?? 0.0;

        final balanceText = balance.round().toString();
        final formatted = _formatRupiah(balanceText);

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.greenAccent,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 34,
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'SALDO DRIVER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatted,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Saldo virtual untuk komisi order',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TopUpPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_card),
                    label: const Text(
                      'TOP UP SALDO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const CircleAvatar(
                  radius: 32,
                  child: Icon(
                    Icons.person,
                    size: 35,
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama driver',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(
                    labelText: 'Kendaraan',
                    prefixIcon: Icon(Icons.motorcycle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRupiah(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return 'Rp 0';
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return 'Rp $buffer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Darma Ride Driver'),
        actions: [
          IconButton(
            onPressed: _online ? _goOffline : () => _goOnline(),
            icon: Icon(
              _online ? Icons.power_settings_new : Icons.power,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverHistoryPage(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _driverProfile(),
            Card(
              margin: const EdgeInsets.all(12),
              child: SwitchListTile(
                title: Text(
                  _online ? 'DRIVER ONLINE' : 'DRIVER OFFLINE',
                ),
                subtitle: Text(
                  _online
                      ? 'Menerima pesanan realtime'
                      : 'Tidak menerima pesanan',
                ),
                value: _online,
                onChanged: _loading ? null : _toggleOnline,
                secondary: Icon(
                  _online
                      ? Icons.wifi
                      : Icons.wifi_off,
                ),
              ),
            ),
            _activePackageCard(),
            _activeOrderCard(),
            if (_activeOrderId == null) _availableOrders(),
            if (_activeOrderId == null) _availablePackageOrders(),
          ],
        ),
      ),
    );
  }
}

class DriverHistoryPage extends StatelessWidget {
  const DriverHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Driver'),
      ),
      body: uid == null
          ? const Center(child: Text('Belum login'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('driverId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Belum ada riwayat'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data();
                    final fare =
                        (data['fare'] ?? 0).toDouble();

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_taxi,
                        ),
                        title: Text(
                          'Rp ${fare.toStringAsFixed(0)}',
                        ),
                        subtitle: Text(
                          '${data['status'] ?? '-'} • '
                          '${data['paymentStatus'] ?? '-'}',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}
