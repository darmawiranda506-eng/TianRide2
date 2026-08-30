import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'driver_register_page.dart';
import 'driver_page.dart';

class DriverLoginPage extends StatefulWidget {
  const DriverLoginPage({super.key});

  @override
  State<DriverLoginPage> createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends State<DriverLoginPage> {
  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return;
    }

    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      if (!driverDoc.exists) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = driverDoc.data();

      if (data == null) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      final status =
          data['verificationStatus']?.toString() ?? 'menunggu';

      if (status == 'disetujui') {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverPage(),
          ),
        );
      }
    } catch (_) {
      // Jika pemeriksaan gagal, tetap tampilkan halaman login.
    }
  }

  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final driverId = _idController.text.trim().toUpperCase();
    final password = _passwordController.text;

    if (driverId.isEmpty || password.isEmpty) {
      _showMessage('ID Driver dan password wajib diisi.');
      return;
    }

    setState(() => _loading = true);

    try {
      /*
       * Jika belum ada sesi Firebase, gunakan anonymous
       * hanya sementara untuk membaca driver_lookup.
       *
       * Setelah itu sesi anonymous akan diganti dengan
       * login email/password driver.
       */
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      /*
       * Cari email berdasarkan ID Driver.
       */
      final lookup = await FirebaseFirestore.instance
          .collection('driver_lookup')
          .doc(driverId)
          .get();

      if (!lookup.exists) {
        await FirebaseAuth.instance.signOut();
        _showMessage('ID Driver tidak ditemukan.');
        return;
      }

      final lookupData = lookup.data();

      if (lookupData == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage('Data Driver tidak valid.');
        return;
      }

      final email = lookupData['email']?.toString();

      if (email == null || email.isEmpty) {
        await FirebaseAuth.instance.signOut();
        _showMessage('Akun Driver belum dikonfigurasi.');
        return;
      }

      /*
       * Login sebenarnya menggunakan Firebase Auth.
       */
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage('Login gagal.');
        return;
      }

      /*
       * Ambil data Driver berdasarkan UID Auth.
       */
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      if (!driverDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showMessage('Data Driver tidak ditemukan.');
        return;
      }

      final data = driverDoc.data();

      if (data == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage('Data Driver tidak valid.');
        return;
      }

      final status =
          data['verificationStatus']?.toString() ?? 'menunggu';

      /*
       * Driver belum boleh masuk sebelum disetujui Admin.
       */
      if (status != 'disetujui') {
        await FirebaseAuth.instance.signOut();

        if (status == 'ditolak') {
          _showMessage(
            'Pendaftaran Driver ditolak oleh Admin Darma Ride.',
          );
        } else {
          _showMessage(
            'Akun Driver masih menunggu verifikasi Admin.',
          );
        }

        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login gagal.';

      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        message = 'ID Driver atau password salah.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Terlalu banyak percobaan. Coba lagi nanti.';
      } else if (e.code == 'anonymous-auth-disabled') {
        message =
            'Login sementara Firebase belum diaktifkan.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _register() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DriverRegisterPage(),
      ),
    );
  }

  void _forgotPassword() {
    _showMessage(
      'Fitur lupa password akan disambungkan setelah sistem akun Driver selesai.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Driver'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 25),

              const Icon(
                Icons.local_taxi,
                size: 90,
                color: Colors.greenAccent,
              ),

              const SizedBox(height: 15),

              const Text(
                'TIANRIDE DWS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'LOGIN MITRA DRIVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 35),

              TextField(
                controller: _idController,
                textCapitalization:
                    TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'ID Driver',
                  hintText: 'Contoh: DWS-12345678',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _loading
                        ? 'MEMPROSES...'
                        : 'LOGIN DRIVER',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _loading ? null : _register,
                child: const Text(
                  'BELUM PUNYA AKUN? DAFTAR DRIVER',
                ),
              ),

              TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('LUPA PASSWORD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
