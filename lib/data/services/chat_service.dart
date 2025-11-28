import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  /// Ottiene tutte le chat dell'utente corrente
  static Future<List<Map<String, dynamic>>> getUserChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ User not logged in');
        return [];
      }

      print('💬 Getting chats for user: $userId');

      // Ottieni le chat di cui l'utente è membro
      final chatMembers = await _supabase
          .from('chat_members')
          .select('chat_id')
          .eq('user_id', userId);

      if (chatMembers.isEmpty) {
        print('ℹ️ No chats found for user');
        return [];
      }

      final chatIds = chatMembers.map((m) => m['chat_id'] as String).toList();

      // Ottieni i dettagli delle chat
      final chats = await _supabase
          .from('chats')
          .select('''
            id,
            name,
            is_group,
            created_at
          ''')
          .inFilter('id', chatIds)
          .order('created_at', ascending: false);

      // Processa ogni chat per ottenere l'ultimo messaggio
      final processedChats = <Map<String, dynamic>>[];
      for (final chat in chats) {
        String? lastMessage;
        DateTime? lastMessageTime;
        
        // Recupera l'ultimo messaggio per questa chat separatamente
        try {
          final messages = await _supabase
              .from('messages')
              .select('content, created_at, message_type')
              .eq('chat_id', chat['id'])
              .order('created_at', ascending: false)
              .limit(1);
          
          if (messages.isNotEmpty) {
            lastMessage = messages.first['content'] as String?;
            lastMessageTime = DateTime.parse(messages.first['created_at']);
          }
        } catch (e) {
          print('⚠️ Error fetching last message for chat ${chat['id']}: $e');
        }

        // Conta i membri - CORREZIONE: uso corretto del count
        int memberCount = 0;
        try {
          final membersList = await _supabase
              .from('chat_members')
              .select('user_id')
              .eq('chat_id', chat['id']);
          
          memberCount = membersList.length;
        } catch (e) {
          print('⚠️ Error counting members for chat ${chat['id']}: $e');
        }

        processedChats.add({
          'id': chat['id'],
          'name': chat['name'],
          'is_group': chat['is_group'],
          'created_at': chat['created_at'],
          'last_message': lastMessage,
          'last_message_time': lastMessageTime?.toIso8601String(),
          'member_count': memberCount,
        });
      }

      // Ordina per ultimo messaggio
      processedChats.sort((a, b) {
        if (a['last_message_time'] == null) return 1;
        if (b['last_message_time'] == null) return -1;
        return DateTime.parse(b['last_message_time'])
            .compareTo(DateTime.parse(a['last_message_time']));
      });

      print('✅ Found ${processedChats.length} chats');
      return processedChats;
    } catch (e) {
      print('❌ Error getting user chats: $e');
      return [];
    }
  }

  /// Ottiene i messaggi di una chat
  static Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    try {
      print('📨 Getting messages for chat: $chatId');

      final messages = await _supabase
          .from('messages')
          .select('''
            id,
            chat_id,
            user_id,
            content,
            message_type,
            created_at,
            user_profiles:user_id(
              full_name,
              avatar_url
            )
          ''')
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      print('✅ Found ${messages.length} messages');
      return List<Map<String, dynamic>>.from(messages);
    } catch (e) {
      print('❌ Error getting chat messages: $e');
      return [];
    }
  }

  /// Invia un messaggio a una chat
  static Future<void> sendMessage({
    required String chatId,
    required String content,
    String type = 'text',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      print('📤 Sending message to chat: $chatId');

      await _supabase.from('messages').insert({
        'chat_id': chatId,
        'user_id': userId,
        'content': content,
        'message_type': type,
      });

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Stream di messaggi in tempo reale per una chat
  static Stream<List<Map<String, dynamic>>> streamChatMessages(String chatId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  /// Ottiene i membri di una chat
  static Future<List<Map<String, dynamic>>> getChatMembers(String chatId) async {
    try {
      print('👥 Getting members for chat: $chatId');

      final members = await _supabase
          .from('chat_members')
          .select('''
            user_id,
            joined_at,
            user_profiles:user_id(
              full_name,
              avatar_url
            )
          ''')
          .eq('chat_id', chatId);

      print('✅ Found ${members.length} members');
      return List<Map<String, dynamic>>.from(members);
    } catch (e) {
      print('❌ Error getting chat members: $e');
      return [];
    }
  }

  /// Aggiorna il nome di una chat di gruppo
  static Future<void> updateChatName(String chatId, String newName) async {
    try {
      await _supabase
          .from('chats')
          .update({'name': newName})
          .eq('id', chatId);

      print('✅ Chat name updated to: $newName');
    } catch (e) {
      print('❌ Error updating chat name: $e');
      rethrow;
    }
  }
}