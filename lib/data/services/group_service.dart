import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  static final _supabase = Supabase.instance.client;
  static const int MAX_GROUP_SIZE = 4;
  static const int MIN_GROUP_SIZE = 2;

  /// Crea o unisce a un gruppo con limite RIGOROSO di 4 persone
  /// IMPORTANTE: Prima cerca gruppi NON PIENI dove unirsi, POI crea nuovo gruppo
  static Future<String?> createOrJoinGroup({
    required List<Map<String, dynamic>> matchedTrips,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      final currentUserId = currentUser.id;
      print('👤 Current User ID: $currentUserId');
      print('🔍 Processing ${matchedTrips.length} matched trips');

      // Trova il trip dell'utente corrente
      final currentUserTrip = matchedTrips.firstWhere(
        (t) => t['user_id'] == currentUserId,
        orElse: () => throw Exception('Current user trip not found in matches'),
      );

      // STEP 1: Verifica se l'utente corrente è già in un gruppo per questo viaggio
      final myExistingGroups = await _supabase
          .from('group_members')
          .select('group_id')
          .eq('user_id', currentUserId)
          .eq('trip_id', currentUserTrip['trip_id']);
      
      if (myExistingGroups.isNotEmpty) {
        print('⚠️ User already in a group for this trip');
        return myExistingGroups.first['group_id'] as String;
      }

      // STEP 2: Trova TUTTI i gruppi esistenti per questo volo/destinazione
      // IMPORTANTE: Cerca gruppi di QUALSIASI utente con match compatibile
      Set<String> existingGroupIds = {};
      
      for (final trip in matchedTrips) {
        if (trip['user_id'] == currentUserId) continue; // Salta se stesso
        
        final userGroups = await _supabase
            .from('group_members')
            .select('group_id')
            .eq('user_id', trip['user_id'] as String);
        
        for (final group in userGroups) {
          existingGroupIds.add(group['group_id'] as String);
        }
      }

      print('📊 Found ${existingGroupIds.length} existing groups to check');

      // STEP 3: PRIORITÀ 1 - Cerca gruppi NON PIENI dove unirsi
      for (final groupId in existingGroupIds) {
        // Conta REALMENTE i membri
        final actualMembers = await _supabase
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId);
        
        final actualMemberCount = actualMembers.length;
        print('📊 Group $groupId has EXACTLY $actualMemberCount members');
        
        // Se il gruppo ha spazio (meno di 4 membri)
        if (actualMemberCount < MAX_GROUP_SIZE) {
          // Verifica che l'utente non sia già membro
          final isAlreadyMember = actualMembers.any((m) => m['user_id'] == currentUserId);
          if (isAlreadyMember) {
            print('⚠️ User already in group $groupId');
            continue;
          }

          // Verifica che il gruppo sia attivo
          final groupInfo = await _supabase
              .from('groups')
              .select('chat_id, status')
              .eq('id', groupId)
              .maybeSingle();

          if (groupInfo == null || groupInfo['status'] != 'active') {
            print('⚠️ Group $groupId is not active or not found');
            continue;
          }

          final chatId = groupInfo['chat_id'] as String?;

          // UNISCITI A QUESTO GRUPPO!
          print('✅ Group $groupId has space (${actualMemberCount}/$MAX_GROUP_SIZE)! Joining...');
          
          try {
            // Aggiungi ai membri del gruppo
            await _supabase.from('group_members').insert({
              'group_id': groupId,
              'trip_id': currentUserTrip['trip_id'],
              'user_id': currentUserId,
            });

            // Aggiorna il contatore
            await _supabase
                .from('groups')
                .update({'current_members': actualMemberCount + 1})
                .eq('id', groupId);

            print('✅ Joined group_members successfully');

            // Aggiungi alla chat se esiste
            if (chatId != null) {
              try {
                // Verifica se non è già nella chat
                final existingChatMember = await _supabase
                    .from('chat_members')
                    .select('user_id')
                    .eq('chat_id', chatId)
                    .eq('user_id', currentUserId)
                    .maybeSingle();
                
                if (existingChatMember == null) {
                  await _supabase.from('chat_members').insert({
                    'chat_id': chatId,
                    'user_id': currentUserId,
                  });

                  // Messaggio di benvenuto
                  await _supabase.from('messages').insert({
                    'chat_id': chatId,
                    'user_id': currentUserId,
                    'content': '👋 Un nuovo viaggiatore si è unito! Ora siete ${actualMemberCount + 1}/$MAX_GROUP_SIZE',
                    'message_type': 'system',
                  });
                }
              } catch (e) {
                print('⚠️ Error adding to chat: $e');
              }
            }

            print('🎉 Successfully joined existing group $groupId (now ${actualMemberCount + 1}/$MAX_GROUP_SIZE members)');
            return groupId;
            
          } catch (e) {
            print('❌ Error joining group: $e');
            continue;
          }
        } else {
          print('🚫 Group $groupId is FULL (${actualMemberCount}/$MAX_GROUP_SIZE) - CANNOT JOIN!');
        }
      }

      // STEP 4: Nessun gruppo con spazio trovato
      // Ora trova SOLO gli utenti SENZA gruppo per crearne uno nuovo
      print('ℹ️ No existing groups with space found. Checking for users without groups...');
      
      final List<Map<String, dynamic>> usersWithoutGroup = [];
      
      for (final trip in matchedTrips) {
        final userId = trip['user_id'] as String;
        final tripId = trip['trip_id'] as String;
        
        // Verifica se questo utente è già in un gruppo
        final userGroups = await _supabase
            .from('group_members')
            .select('group_id')
            .eq('user_id', userId)
            .eq('trip_id', tripId);
        
        if (userGroups.isEmpty) {
          // Utente SENZA gruppo, può partecipare a nuovo gruppo
          usersWithoutGroup.add(trip);
          print('✅ User $userId is available (no group)');
        } else {
          print('❌ User $userId already in group - excluding from new group');
        }
      }

      print('👥 Users without groups: ${usersWithoutGroup.length}');

      // Verifica se ci sono abbastanza utenti per creare un nuovo gruppo
      if (usersWithoutGroup.length < MIN_GROUP_SIZE) {
        print('⏳ Not enough users without groups (${usersWithoutGroup.length}/$MIN_GROUP_SIZE minimum)');
        print('   Waiting for more users to join...');
        return null; // L'utente aspetta
      }

      // STEP 5: Crea nuovo gruppo SOLO con utenti SENZA gruppo
      final membersForNewGroup = usersWithoutGroup.take(MAX_GROUP_SIZE).toList();
      
      print('🆕 Creating NEW group with ${membersForNewGroup.length} members (all without existing groups)');

      // Crea la chat
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

      // Crea il gruppo
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
      print('🆕 Created group: $groupId with EXACTLY ${membersForNewGroup.length} members');

      // Aggiungi i membri
      for (final member in membersForNewGroup) {
        try {
          await _supabase.from('group_members').insert({
            'group_id': groupId,
            'trip_id': member['trip_id'],
            'user_id': member['user_id'],
          });

          await _supabase.from('chat_members').insert({
            'chat_id': chatId,
            'user_id': member['user_id'],
          });
          
          print('✅ Added user ${member['user_id']}');
        } catch (e) {
          print('⚠️ Error adding member: $e');
        }
      }

      // Messaggio di benvenuto
      await _supabase.from('messages').insert({
        'chat_id': chatId,
        'user_id': currentUserId,
        'content': '👋 Benvenuti! Siete ${membersForNewGroup.length} viaggiatori con destinazioni compatibili.',
        'message_type': 'system',
      });

      print('🎉 New group created successfully');
      return groupId;
      
    } catch (e) {
      print('❌ Fatal error in createOrJoinGroup: $e');
      return null;
    }
  }
}