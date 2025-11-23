import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  static final _supabase = Supabase.instance.client;
  static const int MAX_GROUP_SIZE = 4;

  /// Crea o unisce a un gruppo con limite di 4 persone
  /// Quando un gruppo raggiunge 4 membri, crea automaticamente un nuovo gruppo
  static Future<String> createOrJoinGroup({
    required List<Map<String, dynamic>> matchedTrips,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      print('👤 User ID: ${currentUser?.id}');
      print('🔍 Checking for existing groups with space...');

      // Raccogli tutti gli user IDs
      final userIds = matchedTrips.map((t) => t['user_id'] as String).toList();

      // Cerca gruppi esistenti per questi utenti
      final existingGroups = await _supabase
          .from('group_members')
          .select('group_id')
          .inFilter('user_id', userIds);

      if (existingGroups.isNotEmpty) {
        // Verifica quanti membri ha ogni gruppo
        final groupIds = existingGroups
            .map((g) => g['group_id'] as String)
            .toSet()
            .toList();

        for (final groupId in groupIds) {
          // Ottieni info del gruppo
          final groupInfo = await _supabase
              .from('groups')
              .select('current_members, chat_id')
              .eq('id', groupId)
              .single();

          final currentMembers = groupInfo['current_members'] as int;
          final chatId = groupInfo['chat_id'] as String?;

          print('📊 Group $groupId has $currentMembers members (max: $MAX_GROUP_SIZE)');

          // Controlla se c'è spazio
          if (currentMembers < MAX_GROUP_SIZE) {
            // Calcola quanti nuovi membri possiamo aggiungere
            final availableSlots = MAX_GROUP_SIZE - currentMembers;
            final existingMembers = await _supabase
                .from('group_members')
                .select('user_id')
                .eq('group_id', groupId);

            final existingUserIds =
                existingMembers.map((m) => m['user_id'] as String).toSet();

            final newMembers = matchedTrips
                .where((t) => !existingUserIds.contains(t['user_id']))
                .take(availableSlots)
                .toList();

            if (newMembers.isNotEmpty) {
              print('➕ Adding ${newMembers.length} members to group $groupId');

              // Incrementa contatore membri
              await _supabase.rpc('increment_group_members', params: {
                'p_group_id': groupId,
                'p_by': newMembers.length,
              });

              // Aggiungi membri al gruppo
              for (final trip in newMembers) {
                await _supabase.from('group_members').insert({
                  'group_id': groupId,
                  'trip_id': trip['trip_id'],
                  'user_id': trip['user_id'],
                });
              }

              // Aggiungi membri alla chat se esiste
              if (chatId != null) {
                for (final trip in newMembers) {
                  await _supabase.from('chat_members').insert({
                    'chat_id': chatId,
                    'user_id': trip['user_id'],
                  });
                }
              }

              print('✅ Successfully added members to existing group: $groupId');
              return groupId;
            }
          } else {
            print('⚠️ Group $groupId is full ($currentMembers/$MAX_GROUP_SIZE)');
          }
        }
      }

      // Se arriviamo qui, dobbiamo creare un nuovo gruppo
      // Prendi solo i primi 4 membri
      final membersForNewGroup = matchedTrips.take(MAX_GROUP_SIZE).toList();

      print('🆕 Creating new group with ${membersForNewGroup.length} members');

      // Crea prima la chat
      final newChat = await _supabase
          .from('chats')
          .insert({
            'is_group': true,
            'name': 'Gruppo Viaggio',
          })
          .select()
          .single();

      final chatId = newChat['id'] as String;
      print('💬 Created chat: $chatId');

      // Crea il gruppo con riferimento alla chat
      final newGroup = await _supabase
          .from('groups')
          .insert({
            'status': 'active',
            'current_members': membersForNewGroup.length,
            'chat_id': chatId,
          })
          .select()
          .single();

      final groupId = newGroup['id'] as String;
      print('🆕 Created new group: $groupId');

      // Aggiungi membri al gruppo e alla chat
      for (final trip in membersForNewGroup) {
        await _supabase.from('group_members').insert({
          'group_id': groupId,
          'trip_id': trip['trip_id'],
          'user_id': trip['user_id'],
        });

        await _supabase.from('chat_members').insert({
          'chat_id': chatId,
          'user_id': trip['user_id'],
        });
      }

      // Invia messaggio di benvenuto automatico
      await _supabase.from('messages').insert({
        'chat_id': chatId,
        'sender_id': currentUser?.id,
        'content': '👋 Benvenuti nel gruppo! Avete un viaggio in comune.',
        'type': 'system',
      });

      print('✅ Successfully created new group with chat: $groupId');

      // Se ci sono più di 4 persone, crea ricorsivamente altri gruppi
      if (matchedTrips.length > MAX_GROUP_SIZE) {
        final remainingTrips = matchedTrips.skip(MAX_GROUP_SIZE).toList();
        print('♻️ Creating additional group for ${remainingTrips.length} remaining members...');
        await createOrJoinGroup(matchedTrips: remainingTrips);
      }

      return groupId;
    } catch (e) {
      print('❌ Error creating/joining group: $e');
      rethrow;
    }
  }

  /// Ottiene la chat associata a un gruppo
  static Future<String?> getChatIdForGroup(String groupId) async {
    try {
      final group = await _supabase
          .from('groups')
          .select('chat_id')
          .eq('id', groupId)
          .single();

      return group['chat_id'] as String?;
    } catch (e) {
      print('❌ Error getting chat for group: $e');
      return null;
    }
  }
}
