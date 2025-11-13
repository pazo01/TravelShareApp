import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  static final _supabase = Supabase.instance.client;

  static Future<void> createOrJoinGroup({
    required List<Map<String, dynamic>> matchedTrips,
  }) async {
    try {
      // 🧩 Check if the user is logged in
      final currentUser = _supabase.auth.currentUser;
      print('User ID: ${currentUser?.id}');

      print('🚀 Checking for existing group...');

      // 🧩 Collect all user IDs involved in the matched trips
      final userIds = matchedTrips.map((t) => t['user_id'] as String).toList();

      // 🧠 See if any of these users already belong to a group
      final existingGroups = await _supabase
          .from('group_members')
          .select('group_id')
          .inFilter('user_id', userIds);

      String groupId;

      if (existingGroups.isNotEmpty) {
        // ✅ Existing group(s) found → reuse the first one
        groupId = existingGroups.first['group_id'] as String;
        print('🔁 Reusing existing group: $groupId');

        // 🧮 Check which user_ids are already in this group
        final existingMembers = await _supabase
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId);

        final existingUserIds =
            existingMembers.map((m) => m['user_id'] as String).toSet();

        // 🔎 Filter to get only *new* users
        final newMembers = matchedTrips
            .where((t) => !existingUserIds.contains(t['user_id']))
            .toList();

        print('Existing members: $existingUserIds');
        print('New members to add: ${newMembers.map((m) => m['user_id']).toList()}');

        // 🧮 Increment member count only by number of *new* members
        if (newMembers.isNotEmpty) {
          await _supabase.rpc('increment_group_members', params: {
            'p_group_id': groupId,
            'p_by': newMembers.length,
          });

          // 🔹 Insert only the new group_members
          for (final trip in newMembers) {
            await _supabase.from('group_members').insert({
              'group_id': groupId,
              'trip_id': trip['trip_id'],
              'user_id': trip['user_id'],
            });
          }
        } else {
          print('ℹ️ All matched users are already in this group.');
        }
      } else {
        // 🆕 No existing group found → create a new one
        final newGroup = await _supabase
            .from('groups')
            .insert({
              'status': 'active',
              'current_members': matchedTrips.length,
            })
            .select()
            .single();

        groupId = newGroup['id'] as String;
        print('🆕 Created new group: $groupId');

        // 🔹 Add all matched trips as initial members
        for (final trip in matchedTrips) {
          await _supabase.from('group_members').insert({
            'group_id': groupId,
            'trip_id': trip['trip_id'],
            'user_id': trip['user_id'],
          });
        }
      }

      print('✅ Successfully created/joined group: $groupId');
    } catch (e) {
      print('❌ Error creating/joining group: $e');
      rethrow;
    }
  }
}
