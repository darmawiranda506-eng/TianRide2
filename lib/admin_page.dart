import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),
        body: const TabBarView(children: [DriverList(), OrderList()]),
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
