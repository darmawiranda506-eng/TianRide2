import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


class DriverRegisterPage extends StatefulWidget {
  const DriverRegisterPage({super.key});

  @override
  State<DriverRegisterPage> createState() => _DriverRegisterPageState();
}

class _DriverRegisterPageState extends State<DriverRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? _selfie;
  File? _ktp;
  File? _sim;
  File? _stnk;

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required String type,
    required ImageSource source,
  }) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null || !mounted) return;

      setState(() {
        final file = File(image.path);

        switch (type) {
          case 'selfie':
            _selfie = file;
            break;
          case 'ktp':
            _ktp = file;
            break;
          case 'sim':
            _sim = file;
            break;
          case 'stnk':
            _stnk = file;
            break;
        }
      });
    } catch (e) {
      _showMessage('Gagal mengambil foto: $e');
    }
  }

  Future<void> _chooseImage(String type) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil dengan Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    type: type,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    type: type,
                    source: ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _normalizePhone(String phone) {
    var value = phone.trim();

    if (value.startsWith('08')) {
      value = '+62${value.substring(1)}';
    } else if (value.startsWith('62')) {
      value = '+$value';
    }

    return value;
  }

  String _generateDriverId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = timestamp.toString();

    return 'DWS-${suffix.substring(suffix.length - 8)}';
  }

  Future<String> _uploadFile({
    required File file,
    required String uid,
    required String name,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();

    final reference = FirebaseStorage.instance
        .ref()
        .child('driver_documents')
        .child(uid)
        .child('$name.$extension');

    await reference.putFile(file);

    return reference.getDownloadURL();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selfie == null ||
        _ktp == null ||
        _sim == null ||
        _stnk == null) {
      _showMessage(
        'Selfie, KTP, SIM, dan STNK wajib dilengkapi.',
      );
      return;
    }

    final phone = _normalizePhone(_phoneController.text);
    final email = _emailController.text.trim();

    setState(() => _loading = true);

    try {
      // Verifikasi dilakukan oleh Admin Darma Ride.
      // Tidak membuat akun Firebase Auth saat pendaftaran.
      final uid = FirebaseFirestore.instance
          .collection('drivers')
          .doc()
          .id;
      final driverId = _generateDriverId();

      final selfieUrl = await _uploadFile(
        file: _selfie!,
        uid: uid,
        name: 'selfie',
      );

      final ktpUrl = await _uploadFile(
        file: _ktp!,
        uid: uid,
        name: 'ktp',
      );

      final simUrl = await _uploadFile(
        file: _sim!,
        uid: uid,
        name: 'sim',
      );

      final stnkUrl = await _uploadFile(
        file: _stnk!,
        uid: uid,
        name: 'stnk',
      );

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .set({
        'uid': uid,
        'driverId': driverId,
        'authEmail': email,
        'name': _nameController.text.trim(),
        'phone': phone,
        'vehicle': _vehicleController.text.trim(),
        'plateNumber':
            _plateController.text.trim().toUpperCase(),
        'selfieUrl': selfieUrl,
        'ktpUrl': ktpUrl,
        'simUrl': simUrl,
        'stnkUrl': stnkUrl,
        'verificationStatus': 'menunggu',
        'online': false,
        'rating': 5.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Pendaftaran Berhasil'),
            content: Text(
              'ID Driver Anda:\n\n'
              '$driverId\n\n'
              'Akun Anda sedang menunggu verifikasi Admin Darma Ride.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('Pendaftaran gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _documentButton({
    required String title,
    required String type,
    required File? file,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          file == null ? icon : Icons.check_circle,
          color: file == null ? null : Colors.greenAccent,
        ),
        title: Text(title),
        subtitle: Text(
          file == null
              ? 'Belum dipilih'
              : 'Foto sudah dipilih',
        ),
        trailing: const Icon(Icons.camera_alt),
        onTap: () => _chooseImage(type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Driver'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_add,
                  size: 70,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 10),
                const Text(
                  'PENDAFTARAN MITRA DRIVER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor HP wajib diisi';
                    }

                    final digits =
                        value.replaceAll(RegExp(r'[^0-9]'), '');

                    if (digits.length < 10) {
                      return 'Nomor HP tidak valid';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'contoh@email.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())) {
                      return 'Email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Kendaraan',
                    hintText: 'Contoh: Honda Beat',
                    prefixIcon: Icon(Icons.two_wheeler),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Jenis kendaraan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _plateController,
                  textCapitalization:
                      TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Polisi',
                    hintText: 'Contoh: BM 1234 XX',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor polisi wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                const Text(
                  'Dokumen Driver',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selfie digunakan sebagai foto profil. '
                  'Tidak perlu memegang KTP saat selfie.',
                ),
                const SizedBox(height: 10),
                _documentButton(
                  title: 'Selfie / Foto Profil',
                  type: 'selfie',
                  file: _selfie,
                  icon: Icons.face,
                ),
                _documentButton(
                  title: 'KTP',
                  type: 'ktp',
                  file: _ktp,
                  icon: Icons.badge,
                ),
                _documentButton(
                  title: 'SIM',
                  type: 'sim',
                  file: _sim,
                  icon: Icons.credit_card,
                ),
                _documentButton(
                  title: 'STNK',
                  type: 'stnk',
                  file: _stnk,
                  icon: Icons.description,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _register,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.app_registration),
                    label: Text(
                      _loading ? 'MEMPROSES...' : 'DAFTAR DRIVER',
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Nomor HP digunakan sebagai kontak driver. Pendaftaran akan diperiksa dan diverifikasi oleh Admin Darma Ride.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
