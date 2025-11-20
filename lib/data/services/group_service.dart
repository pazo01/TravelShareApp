import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  static final _supabase = Supabase.instance.client;

  static Future<void> createOrJoinGroup({
    required List<Map<String, dynamic>> matchedTrips,
  }) async {
    try {
      print('🚀 [GroupService] Creating or joining group...');
      print('➡️ matchedTrips = $matchedTrips');

      if (matchedTrips.isEmpty) {
        print('⚠️ No trips provided. Aborting.');
        return;
      }

      // -----------------------------------------------------------
      // 1️⃣ Get trip_ids from matchedTrips
      // -----------------------------------------------------------
      final tripIds = matchedTrips.map((t) => t['trip_id'] as String).toList();
      print('🆔 tripIds involved: $tripIds');

      // -----------------------------------------------------------
      // 2️⃣ Check if ANY of these trips already belongs to a group
      // -----------------------------------------------------------
      final existingGroups = await _supabase
          .from('group_members')
          .select('group_id, trip_id')
          .inFilter('trip_id', tripIds);

      print('🔎 Existing groups found: $existingGroups');

      String groupId;

      if (existingGroups.isNotEmpty) {
        // ---------------------------------------------------------
        // 3️⃣ Reuse that group (take the first one)
        // ---------------------------------------------------------
        groupId = existingGroups.first['group_id'] as String;

        print('🔁 Reusing existing group: $groupId');

        // ---------------------------------------------------------
        // 4️⃣ Check existing members (based on trip_id)
        // ---------------------------------------------------------
        final existingMembers = await _supabase
            .from('group_members')
            .select('trip_id, user_id')
            .eq('group_id', groupId);

        final existingTripIds =
            existingMembers.map((m) => m['trip_id'] as String).toSet();

        print('👥 Existing trip_ids in group: $existingTripIds');

        // ---------------------------------------------------------
        // 5️⃣ Determine which trips are NEW to this group
        // ---------------------------------------------------------
        final newMembers = matchedTrips
            .where((t) => !existingTripIds.contains(t['trip_id']))
            .toList();

        print('🆕 Trips to add to group: $newMembers');

        // ---------------------------------------------------------
        // 6️⃣ Add new members (if any)
        // ---------------------------------------------------------
        if (newMembers.isNotEmpty) {
          await _supabase.rpc('increment_group_members', params: {
            'p_group_id': groupId,
            'p_by': newMembers.length,
          });

          for (final trip in newMembers) {
            await _supabase.from('group_members').insert({
              'group_id': groupId,
              'trip_id': trip['trip_id'],
              'user_id': trip['user_id'],
            });
          }
        } else {
          print('ℹ️ No new members to add.');
        }
      } else {
        // ---------------------------------------------------------
        // 7️⃣ No groups exist → create new group
        // ---------------------------------------------------------
        print('🆕 Creating new group...');

        final newGroup = await _supabase
            .from('groups')
            .insert({
              'status': 'active',
              'current_members': matchedTrips.length,
            })
            .select()
            .single();

        groupId = newGroup['id'] as String;

        print('🎉 New group created: $groupId');

        // ---------------------------------------------------------
        // 8️⃣ Insert all matched trips into this new group
        // ---------------------------------------------------------
        for (final trip in matchedTrips) {
          await _supabase.from('group_members').insert({
            'group_id': groupId,
            'trip_id': trip['trip_id'],
            'user_id': trip['user_id'],
          });
        }
      }

      print('✅ DONE — group_id = $groupId');
    } catch (e) {
      print('❌ Error in GroupService: $e');
      rethrow;
    }
  }
}
