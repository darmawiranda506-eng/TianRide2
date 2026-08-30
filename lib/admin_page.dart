import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'announcement_page.dart';
import 'fare_admin_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Darma Ride Admin\nUID: ${FirebaseAuth.instance.currentUser?.uid ?? '-'}',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Driver'),
              Tab(icon: Icon(Icons.local_taxi), text: 'Order'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Top Up'),
              Tab(icon: Icon(Icons.payments), text: 'Tarif'),
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
              Tab(icon: Icon(Icons.campaign), text: 'Info'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DriverList(),
            OrderList(),
            TopUpAdminList(),
            FareAdminPage(),
            AdminChatListPage(),
            AnnouncementPage(admin: true),
          ],
        ),
      ),
    );
  }
}

class DriverList extends StatelessWidget {
  const DriverList({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('drivers');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal mengambil driver:\n${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada pendaftar driver.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final name = data['name']?.toString() ?? '-';
            final driverId = data['driverId']?.toString() ?? '-';
            final status = data['verificationStatus']?.toString() ?? 'menunggu';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text('ID: $driverId\nStatus: $status'),
                isThreeLine: true,
                trailing: status == 'menunggu'
                    ? const Icon(Icons.pending)
                    : const Icon(Icons.verified),
                onTap: () {
                  _showDriver(context, docs[index].id, data);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showDriver(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['name']?.toString() ?? 'Driver'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID Driver: ${data['driverId'] ?? '-'}'),
              Text('Email: ${data['authEmail'] ?? '-'}'),
              Text('HP: ${data['phone'] ?? '-'}'),
              Text('Kendaraan: ${data['vehicle'] ?? '-'}'),
              Text('Plat: ${data['plateNumber'] ?? '-'}'),
              Text('Status: ${data['verificationStatus'] ?? '-'}'),
            ],
          ),
        ),
        actions: [
          if (data['verificationStatus'] == 'menunggu')
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(docId)
                    .update({'verificationStatus': 'ditolak'});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('TOLAK'),
            ),
          if (data['verificationStatus'] == 'menunggu')
            FilledButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(docId)
                    .update({'verificationStatus': 'disetujui'});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('TERIMA'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }
}

class AdminChatListPage extends StatelessWidget {
  const AdminChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('drivers');

    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Driver')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Gagal mengambil driver:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada driver.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final driverId = docs[index].id;
              final name =
                  data['name']?.toString() ??
                  data['driverName']?.toString() ??
                  'Driver';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name),
                  subtitle: Text(data['driverId']?.toString() ?? driverId),
                  trailing: const Icon(Icons.chat),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatPage(driverId: driverId, driverName: name),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class OrderList extends StatelessWidget {
  const OrderList({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('orders');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal mengambil order:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada pesanan.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_taxi),
                title: Text('Status: ${data['status'] ?? '-'}'),
                subtitle: Text('Tujuan: ${data['tujuan'] ?? '-'}'),
                trailing: Text('Rp ${(data['fare'] ?? 0).toString()}'),
              ),
            );
          },
        );
      },
    );
  }
}


class TopUpAdminList extends StatelessWidget {
  const TopUpAdminList({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('topup_requests')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal mengambil order:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('Belum ada request Top Up.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final amount =
                (data['amount'] as num?)?.toDouble() ?? 0;

            final status =
                data['status']?.toString() ?? 'menunggu';

            final driverName =
                data['driverName']?.toString() ?? 'Driver';

            final method =
                data['method']?.toString() ?? '-';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.account_balance_wallet),
                ),
                title: Text(driverName),
                subtitle: Text(
                  'Nominal: Rp ${amount.toStringAsFixed(0)}\n'
                  'Metode: $method\n'
                  'Status: $status',
                ),
                isThreeLine: true,
                trailing: status == 'menunggu'
                    ? const Icon(Icons.pending)
                    : Icon(
                        status == 'disetujui'
                            ? Icons.verified
                            : Icons.cancel,
                      ),
                onTap: () {
                  _showTopUp(context, doc.id, data);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showTopUp(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) {
    final amount =
        (data['amount'] as num?)?.toDouble() ?? 0;

    final proofBase64 = data['proofBase64']?.toString();

    final status =
        data['status']?.toString() ?? 'menunggu';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request Top Up'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver: ${data['driverName'] ?? '-'}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Email: ${data['driverEmail'] ?? '-'}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Nominal: Rp ${amount.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Metode: ${data['method'] ?? '-'}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Status: $status',
                ),
                const SizedBox(height: 15),
                if (proofBase64 != null && proofBase64.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Image.memory(base64Decode(
                      proofBase64),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Bukti pembayaran tidak dapat ditampilkan.',
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (status == 'menunggu')
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('topup_requests')
                      .doc(requestId)
                      .update({
                    'status': 'ditolak',
                    'reviewedAt':
                        FieldValue.serverTimestamp(),
                    'reviewedBy':
                        FirebaseAuth.instance.currentUser?.uid,
                  });

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('TOLAK'),
              ),

            if (status == 'menunggu')
              FilledButton(
                onPressed: () async {
                  await _approveTopUp(
                    context,
                    requestId,
                    data,
                    amount,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('SETUJUI'),
              ),

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('TUTUP'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveTopUp(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
    double amount,
  ) async {
    final driverId =
        data['driverId']?.toString();

    if (driverId == null || driverId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver ID tidak ditemukan.'),
          ),
        );
      }
      return;
    }

    final firestore =
        FirebaseFirestore.instance;

    final driverRef =
        firestore.collection('drivers').doc(driverId);

    final requestRef =
        firestore.collection('topup_requests').doc(requestId);

    try {
      await firestore.runTransaction((transaction) async {
        final requestSnapshot =
            await transaction.get(requestRef);

        final driverSnapshot =
            await transaction.get(driverRef);

        if (!requestSnapshot.exists) {
          throw Exception('Request Top Up tidak ditemukan.');
        }

        final requestData =
            requestSnapshot.data();

        if (requestData?['status'] != 'menunggu') {
          throw Exception(
            'Request ini sudah diproses.',
          );
        }

        if (!driverSnapshot.exists) {
          throw Exception(
            'Data driver tidak ditemukan.',
          );
        }

        final driverData =
            driverSnapshot.data() ?? {};

        final oldBalance =
            (driverData['balance'] as num?)?.toDouble() ?? 0;

        final newBalance =
            oldBalance + amount;

        transaction.update(driverRef, {
          'balance': newBalance,
          'balanceUpdatedAt':
              FieldValue.serverTimestamp(),
        });

        transaction.update(requestRef, {
          'status': 'disetujui',
          'approvedAmount': amount,
          'approvedAt':
              FieldValue.serverTimestamp(),
          'approvedBy':
              FirebaseAuth.instance.currentUser?.uid,
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Top Up disetujui. Saldo driver bertambah Rp ${amount.toStringAsFixed(0)}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui Top Up: $e'),
          ),
        );
      }
    }
  }
}
