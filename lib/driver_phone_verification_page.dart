import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DriverPhoneVerificationPage extends StatefulWidget {
  final String phoneNumber;

  const DriverPhoneVerificationPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<DriverPhoneVerificationPage> createState() =>
      _DriverPhoneVerificationPageState();
}

class _DriverPhoneVerificationPageState
    extends State<DriverPhoneVerificationPage> {
  final _otpController = TextEditingController();

  bool _loading = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendOtp() async {
    final phone = widget.phoneNumber.trim();

    if (phone.isEmpty) {
      _showMessage('Nomor HP belum diisi.');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);

            if (!mounted) return;
            _showMessage('Nomor HP berhasil diverifikasi.');
            Navigator.pop(context, true);
          } catch (e) {
            _showMessage('Verifikasi otomatis gagal: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showMessage(
            'Gagal mengirim OTP [${e.code}]: '
            '${e.message ?? 'Periksa Firebase Phone Authentication.'}',
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _loading = false;
          });

          _showMessage('Kode OTP telah dikirim.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;

          if (mounted) {
            setState(() => _loading = false);
          }
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      _showMessage('Terjadi kesalahan: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (_verificationId == null) {
      _showMessage('Kode verifikasi belum tersedia.');
      return;
    }

    if (otp.length < 6) {
      _showMessage('Masukkan kode OTP 6 digit.');
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      _showMessage('Nomor HP berhasil diverifikasi.');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'Kode OTP salah atau sudah kedaluwarsa.';

      if (e.code == 'invalid-verification-code') {
        message = 'Kode OTP salah.';
      } else if (e.code == 'session-expired') {
        message = 'Kode OTP sudah kedaluwarsa. Kirim ulang kode.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Verifikasi gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _resendToken = null;
      _loading = true;
    });

    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Nomor HP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Verifikasi Nomor HP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kode OTP akan dikirim ke ${widget.phoneNumber}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Kode OTP',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _verifyOtp,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.verified),
                  label: Text(
                    _loading ? 'MEMPROSES...' : 'VERIFIKASI OTP',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _resendOtp,
                child: const Text('KIRIM ULANG OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



