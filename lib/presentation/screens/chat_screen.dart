import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  late RealtimeChannel _channel;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// All messages in this chat (oldest → newest)
  List<Map<String, dynamic>> messages = [];

  /// Cache of user_id → full_name
  final Map<String, String> _userNames = {};

  /// Cache of user_id → Color (for the name text)
  final Map<String, Color> _userNameColors = {};

  @override
  void initState() {
    super.initState();
    _channel = supabase.channel('messages_${widget.groupId}');
    _loadInitialMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD INITIAL MESSAGES (WITH USER NAMES)
  // ---------------------------------------------------------------------------
  Future<void> _loadInitialMessages() async {
    final res = await supabase
        .from('messages')
        // join with user_profiles to get full_name
        .select('*, user_profiles(full_name)')
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    final list = List<Map<String, dynamic>>.from(res);

    // fill caches for names & colors
    for (final msg in list) {
      final uid = msg['user_id'] as String;
      final profile = msg['user_profiles'] as Map<String, dynamic>?;
      final fullName = profile?['full_name'] as String? ?? 'Utente';

      _userNames[uid] = fullName;
      _userNameColors.putIfAbsent(uid, () => _colorForUserId(uid));
    }

    setState(() {
      messages = list;
    });

    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // REALTIME SUBSCRIPTION
  // ---------------------------------------------------------------------------
  void _setupRealtimeSubscription() {
    _channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord == null) return;

            // fetch full row with joined profile so we also get full_name
            final full = await supabase
                .from('messages')
                .select('*, user_profiles(full_name)')
                .eq('id', newRecord['id'])
                .single();

            final uid = full['user_id'] as String;
            final profile = full['user_profiles'] as Map<String, dynamic>?;
            final fullName = profile?['full_name'] as String? ?? 'Utente';

            _userNames[uid] = fullName;
            _userNameColors.putIfAbsent(uid, () => _colorForUserId(uid));

            setState(() {
              messages.add(full); // newest goes to bottom
            });

            _scrollToBottom();
          },
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('messages').insert({
      'group_id': widget.groupId,
      'user_id': user.id,
      'content': text,
      'message_type': 'text',
    });

    _controller.clear();
    // Realtime will append the new message and scroll to bottom
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  void _scrollToBottom() {
    Future.microtask(() {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  bool _isMyMessage(Map<String, dynamic> msg) {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return false;
    return msg['user_id'] == currentUser.id;
  }

  Color _colorForUserId(String userId) {
    // stable "random" color per user (only for the NAME text)
    const baseColors = [
      Colors.deepPurple,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.red,
      Colors.indigo,
    ];
    final index = userId.hashCode.abs() % baseColors.length;
    return baseColors[index];
  }

  // ---------------------------------------------------------------------------
  // BUBBLE UI (WhatsApp-style, option C)
  // ---------------------------------------------------------------------------
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMine = _isMyMessage(msg);
    final uid = msg['user_id'] as String;
    final fullName = _userNames[uid] ?? 'Utente';
    final nameColor = _userNameColors[uid] ?? Colors.deepPurple;

    final bubbleColor =
        isMine ? Colors.deepPurple[200] : Colors.grey.shade300;
    final textColor = isMine ? Colors.black : Colors.black;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // NAME INSIDE THE BUBBLE, COLORED (WhatsApp group style)
            if (!isMine)
              Text(
                fullName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: nameColor,
                ),
              ),
            if (!isMine) const SizedBox(height: 2),

            // MESSAGE TEXT
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: Column(
        children: [
          // MESSAGES LIST (oldest top → newest bottom)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // INPUT BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: "Scrivi un messaggio...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
