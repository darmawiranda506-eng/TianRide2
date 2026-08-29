import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String? driverId;
  final String? driverName;

  const ChatPage({
    super.key,
    this.driverId,
    this.driverName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String? get _uid =>
      widget.driverId ?? FirebaseAuth.instance.currentUser?.uid;

  String get _name => widget.driverName ?? 'Admin Darma Ride';

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(_uid)
          .collection('messages');

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _uid == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isAdmin = widget.driverId != null;

    await _messages.add({
      'senderId': user.uid,
      'senderEmail': user.email,
      'senderRole': isAdmin ? 'admin' : 'driver',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sesi login belum tersedia.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.driverId == null
              ? 'Pesan Admin'
              : 'Pesan • $_name',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Gagal mengambil pesan:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada pesan.\nSilakan mulai percakapan.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final user = FirebaseAuth.instance.currentUser;
                    final mine =
                        data['senderId'] == user?.uid;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: 310),
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(16),
                          color: mine
                              ? Colors.green.shade700
                              : Colors.grey.shade800,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Text(
                                data['senderRole'] == 'admin'
                                    ? 'ADMIN'
                                    : 'DRIVER',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text(
                              data['text']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
