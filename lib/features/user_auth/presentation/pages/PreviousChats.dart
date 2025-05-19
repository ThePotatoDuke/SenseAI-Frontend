import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

import '../../data/chat_service.dart';
import 'chat_page.dart';

class PreviousChatsScreen extends StatelessWidget {
  final ChatService _chatService = ChatService();

  PreviousChatsScreen({Key? key}) : super(key: key);

  final DateFormat _dateFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color primaryLightColor =
        Theme.of(context).primaryColorLight; // or a lighter variant
    final Color primaryDarkColor =
        Theme.of(context).primaryColorDark; // or a darker variant

    return Scaffold(
      appBar: AppBar(
        title: const Text("Previous Chats"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade700,
                    Colors.purpleAccent.shade100,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(chatId: randomString()),
                    ),
                  );
                },
                icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                label: const Text('New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          // Wave background fills full body
          WaveWidget(
            config: CustomConfig(
              gradients: [
                [
                  primaryColor.withAlpha((0.6 * 255).round()),
                  // 0.6 opacity
                  primaryLightColor.withAlpha((0.3 * 255).round()),
                  // 0.3 opacity
                ],
                [
                  primaryColor.withAlpha((0.3 * 255).round()),
                  // 0.3 opacity
                  primaryLightColor.withAlpha((0.1 * 255).round()),
                  // 0.1 opacity
                ],
                [
                  primaryDarkColor.withAlpha((0.4 * 255).round()),
                  // 0.4 opacity
                  primaryColor.withAlpha((0.15 * 255).round()),
                  // 0.15 opacity
                ],
              ],
              durations: [35000, 16000],
              heightPercentages: [0.40, 0.43],
              blur: const MaskFilter.blur(BlurStyle.solid, 10),
              gradientBegin: Alignment.bottomLeft,
              gradientEnd: Alignment.topRight,
            ),
            waveAmplitude: 20,
            size: const Size(double.infinity, double.infinity),
          ),

          // Foreground chat list with padding
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getChatSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Center(child: Text("No previous chats."));
                }
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final Timestamp? timestamp =
                        session['createdAt'] as Timestamp?;
                    final DateTime date = timestamp?.toDate() ?? DateTime.now();
                    final String lastMessage =
                        (session['lastMessage'] as String?)?.trim() ??
                            'No messages yet';
                    final String chatId = (session['chatId'] as String?) ?? '';


                    return Column(
                      children: [
                        Slidable(
                          key: Key(chatId),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  // Your existing slidable action (e.g., more options)
                                },
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                icon: Icons.more_vert,
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              // Handle tap here, e.g., open chat screen or any action
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(chatId: chatId),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(15), // matches your message container radius
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  // White message area
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(15),
                                          bottomLeft: Radius.circular(15),
                                          topRight: Radius.circular(0),
                                          bottomRight: Radius.circular(0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            offset: const Offset(-3, 0),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  lastMessage,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _dateFormat.format(date),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                              ],
                                            ),
                                          ),
                                          // Delete button stays independent (so it doesn’t trigger tap on whole row)
                                          Positioned(
                                            bottom: 8,
                                            left: 8,
                                            child: GestureDetector(
                                              onTap: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Confirm Delete'),
                                                    content: const Text('Are you sure you want to delete this chat?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(false),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(true),
                                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  _chatService.deleteChatSession(chatId);
                                                  // Optionally show snackbar here
                                                }
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(6),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Purple icon section (also inside InkWell tappable)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Container(
                                      width: 60,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(15),
                                          bottomRight: Radius.circular(15),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Icon(Icons.mic, color: Colors.white, size: 24),
                                              ),
                                              Expanded(
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 80),
                                                    child: Text(
                                                      'Audio',
                                                      style: TextStyle(color: Colors.white),
                                                      overflow: TextOverflow.visible,
                                                      softWrap: false,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Icon(Icons.chat_bubble, color: Colors.white, size: 24),
                                              ),
                                              Expanded(
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 80),
                                                    child: Text(
                                                      'Chat',
                                                      style: TextStyle(color: Colors.white),
                                                      overflow: TextOverflow.visible,
                                                      softWrap: false,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Icon(Icons.photo_camera, color: Colors.white, size: 24),
                                              ),
                                              Expanded(
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 80),
                                                    child: Text(
                                                      'Photo',
                                                      style: TextStyle(color: Colors.white),
                                                      overflow: TextOverflow.visible,
                                                      softWrap: false,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );

                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
