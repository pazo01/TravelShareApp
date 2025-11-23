import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/chat_service.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    try {
      final chats = await ChatService.getUserChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';

    try {
      final time = DateTime.parse(isoTime);
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays == 0) {
        // Oggi: mostra solo l'ora
        return DateFormat('HH:mm').format(time);
      } else if (difference.inDays == 1) {
        // Ieri
        return 'Ieri';
      } else if (difference.inDays < 7) {
        // Questa settimana: mostra il giorno
        return DateFormat('EEEE', 'it').format(time);
      } else {
        // Più vecchio: mostra la data
        return DateFormat('dd/MM/yy').format(time);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nessuna chat attiva',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea un viaggio per trovare\ncompagni e iniziare a chattare!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.separated(
                    itemCount: _chats.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 80,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      final isGroup = chat['is_group'] as bool? ?? false;
                      final memberCount = chat['member_count'] as int? ?? 0;
                      final lastMessage = chat['last_message'] as String?;
                      final lastMessageTime = chat['last_message_time'] as String?;

                      return Container(
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isGroup ? Icons.group : Icons.person,
                              color: theme.primaryColor,
                              size: 28,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chat['name'] ?? 'Gruppo Viaggio',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (lastMessageTime != null)
                                Text(
                                  _formatTime(lastMessageTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isGroup)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                                  child: Text(
                                    '$memberCount ${memberCount == 1 ? 'membro' : 'membri'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              if (lastMessage != null)
                                Text(
                                  lastMessage,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  chatId: chat['id'],
                                  chatName: chat['name'] ?? 'Gruppo Viaggio',
                                  isGroup: isGroup,
                                ),
                              ),
                            ).then((_) => _loadChats()); // Ricarica dopo il ritorno
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
