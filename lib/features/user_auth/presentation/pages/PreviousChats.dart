import 'package:flutter/material.dart';
import 'package:flutter_emoji/flutter_emoji.dart';

class PreviousChatsScreen extends StatelessWidget {
  final List<Chat> chats = [
    Chat(
      title: 'Chat with User1',
      date: DateTime.now().subtract(Duration(days: 1)),
      emotions: ChatEmotions(
        voice: '🙂',
        text: '😁',
        photo: '😎',
      ),
    ),
    Chat(
      title: 'Chat with User2',
      date: DateTime.now().subtract(Duration(days: 2)),
      emotions: ChatEmotions(
        voice: '😔',
        text: '😮',
        photo: '😍',
      ),
    ),
    // Add more chats here
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Previous Chats"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ChatCard(chat: chat);
          },
        ),
      ),
    );
  }
}

class ChatCard extends StatelessWidget {
  final Chat chat;
  const ChatCard({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chat title and date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  '${chat.date.day}/${chat.date.month}/${chat.date.year}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            // Displaying emojis for voice, text, and photo
            Column(
              children: [
                Text(chat.emotions.voice, style: TextStyle(fontSize: 24)),
                Text(chat.emotions.text, style: TextStyle(fontSize: 24)),
                Text(chat.emotions.photo, style: TextStyle(fontSize: 24)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Chat {
  final String title;
  final DateTime date;
  final ChatEmotions emotions;

  Chat({required this.title, required this.date, required this.emotions});
}

class ChatEmotions {
  final String voice;
  final String text;
  final String photo;

  ChatEmotions({required this.voice, required this.text, required this.photo});
}
