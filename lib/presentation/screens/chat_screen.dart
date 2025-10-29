import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nessuna chat attiva',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Le tue conversazioni appariranno qui',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}