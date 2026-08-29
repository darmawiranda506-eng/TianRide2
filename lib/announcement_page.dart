import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnouncementPage extends StatelessWidget {
  final bool admin;

  const AnnouncementPage({
    super.key,
    this.admin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? 'Kelola Pengumuman' : 'Pengumuman'),
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _createAnnouncement(context),
              icon: const Icon(Icons.add),
              label: const Text('BUAT'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
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
                  'Gagal mengambil pengumuman:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('Belum ada pengumuman.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.campaign),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Pengumuman',
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data['message']?.toString() ?? '',
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createAnnouncement(BuildContext context) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Buat Pengumuman'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Isi pengumuman',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('BATAL'),
              ),
              FilledButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final message = messageController.text.trim();

                  if (title.isEmpty || message.isEmpty) {
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('announcements')
                        .add({
                      'title': title,
                      'message': message,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mengirim pengumuman: $e'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('KIRIM'),
              ),
            ],
          );
        },
      );

      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengumuman berhasil dikirim.'),
          ),
        );
      }
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }
}
