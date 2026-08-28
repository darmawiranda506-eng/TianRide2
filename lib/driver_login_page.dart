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
    final driverId = _idController.text.trim();
    final password = _passwordController.text;

    if (driverId.isEmpty || password.isEmpty) {
      _showMessage('ID Driver dan password wajib diisi.');
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await FirebaseFirestore.instance
          .collection('drivers')
          .where('driverId', isEqualTo: driverId)
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        _showMessage('ID Driver tidak ditemukan.');
        return;
      }

      final data = result.docs.first.data();
      final email = data['authEmail']?.toString();

      if (email == null || email.isEmpty) {
        _showMessage('Akun Driver belum dikonfigurasi.');
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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
          e.code == 'wrong-password') {
        message = 'ID Driver atau password salah.';
      } else if (e.code == 'too-many-requests') {
        message = 'Terlalu banyak percobaan. Coba lagi nanti.';
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
    _showMessage('Fitur lupa password akan kita sambungkan setelah sistem akun Driver selesai.');
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
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'ID Driver',
                  hintText: 'Contoh: DWS-DRV-0001',
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
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _loading ? 'MEMPROSES...' : 'MASUK',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _register,
                child: const Text('DAFTAR DRIVER'),
              ),
              TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('LUPA PASSWORD?'),
              ),
              const SizedBox(height: 25),
              const Text(
                'Darma Ride DWS • Mitra Driver',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
