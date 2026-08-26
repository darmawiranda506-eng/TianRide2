import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders =
        FirebaseFirestore.instance.collection('orders');

    return Scaffold(
      appBar: AppBar(
        title: const Text('TianRide Admin'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: orders
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
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
                  'Gagal mengambil data:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 45,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard Admin',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total order: ${docs.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text('Belum ada pesanan.'),
                      )
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.local_taxi,
                              ),
                              title: Text(
                                'Status: ${data['status'] ?? '-'}',
                              ),
                              subtitle: Text(
                                'Tujuan: ${data['tujuan'] ?? '-'}',
                              ),
                              trailing: Text(
                                'Rp ${(data['fare'] ?? 0).toString()}',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
