import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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

    final name = _nameController.text.trim();
    final phone = _normalizePhone(_phoneController.text);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final vehicle = _vehicleController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();

    setState(() => _loading = true);

    UserCredential? credential;

    try {
      /*
       * 1. BUAT AKUN FIREBASE AUTH
       */
      credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Akun Firebase tidak berhasil dibuat.');
      }

      /*
       * 2. BUAT ID DRIVER
       */
      final driverId = _generateDriverId();

      /*
       * 3. SIMPAN DATA DRIVER MENGGUNAKAN UID AUTH
       *
       * Sangat penting:
       * drivers/{UID Firebase Auth}
       */
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'driverId': driverId,
        'authEmail': email,
        'name': name,
        'phone': phone,
        'vehicle': vehicle,
        'plateNumber': plate,
        'verificationStatus': 'menunggu',
        'online': false,
        'rating': 5.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

        /*
         * 4. SIMPAN USER ROLE DRIVER
         */
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'driver',
          'createdAt': FieldValue.serverTimestamp(),
        });

        /*
         * 5. SIMPAN MAPPING ID DRIVER → EMAIL
         */
        await FirebaseFirestore.instance
            .collection('driver_lookup')
            .doc(driverId)
            .set({
          'driverId': driverId,
          'email': email,
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        /*
         * 6. DRIVER LANGSUNG SIGN OUT
         * Karena status masih menunggu.
         */
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Pendaftaran Berhasil'),
            content: Text(
              'ID Driver Anda:\n\n'
              '$driverId\n\n'
              'Akun berhasil dibuat dan sedang menunggu '
              'verifikasi Admin Darma Ride.',
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
    } on FirebaseAuthException catch (e) {
      /*
       * Kalau Auth berhasil tetapi penyimpanan Firestore gagal,
       * akun Auth tetap ada. Jangan mencoba membuat akun kedua.
       */
      String message = 'Pendaftaran gagal.';

      if (e.code == 'email-already-in-use') {
        message = 'Email sudah terdaftar.';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid.';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah.';
      }

      _showMessage(message);
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
          file == null ? 'Belum dipilih' : 'Foto sudah dipilih',
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
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
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
                    hintText: 'Motor',
                    prefixIcon: Icon(Icons.two_wheeler),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kendaraan wajib diisi';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Plat',
                    hintText: 'BP 1234 XX',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor plat wajib diisi';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                _documentButton(
                  title: 'Selfie',
                  type: 'selfie',
                  file: _selfie,
                  icon: Icons.person,
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
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _register,
                    icon: const Icon(Icons.app_registration),
                    label: Text(
                      _loading
                          ? 'MENDAFTARKAN...'
                          : 'DAFTAR DRIVER',
                    ),
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
