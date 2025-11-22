import 'package:supabase_flutter/supabase_flutter.dart';

class GroupService {
  static final _supabase = Supabase.instance.client;

  /// Creates a new group or joins an existing group with space.
  ///
  /// [matchedTrips] contains the OTHER users' trips (already existing).
  /// [currentTrip] is the ONLY new trip that must be added.
  static Future<void> createOrJoinGroup({
    required List<Map<String, dynamic>> matchedTrips,
    required Map<String, dynamic> currentTrip,   // { trip_id, user_id }
  }) async {
    try {
      print('🚀 GroupService → createOrJoinGroup');
      print('matchedTrips = $matchedTrips');
      print('currentTrip = $currentTrip');

      final String newTripId = currentTrip['trip_id'];
      final String newUserId = currentTrip['user_id'];

      // ---------------------------------------------------------------------
      // 1️⃣ Extract existing trip_ids (from matching results)
      // ---------------------------------------------------------------------
      final matchedTripIds = matchedTrips.map((t) => t['trip_id']).toList();
      print("📦 matchedTripIds: $matchedTripIds");

      if (matchedTripIds.isEmpty) {
        print("ℹ️ No matches → Create new group with ONLY newTrip");
        return await _createNewGroup(
          currentTrip,
          [], // no matched trips
        );
      }

      // ---------------------------------------------------------------------
      // 2️⃣ Get all groups that ANY matched trip already belongs to
      // ---------------------------------------------------------------------
      final existingGroups = await _supabase
          .from('group_members')
          .select('group_id, trip_id')
          .inFilter('trip_id', matchedTripIds);

      print("🔎 Existing groups found: $existingGroups");

      // ---------------------------------------------------------------------
      // 3️⃣ Try to join the FIRST group with available space
      // ---------------------------------------------------------------------
      for (final g in existingGroups) {
        final String gid = g['group_id'];

        print("➡️ Checking group $gid");

        // Get group capacity
        final group = await _supabase
            .from('groups')
            .select('current_members, max_members')
            .eq('id', gid)
            .single();

        final int current = group['current_members'] ?? 0;
        final int max = group['max_members'] ?? 4;

        print("👥 Group $gid → $current / $max");

        if (current < max) {
          print("🟢 Group $gid HAS SPACE → joining");

          // Add the new trip to this group
          await _supabase.from('group_members').insert({
            'group_id': gid,
            'trip_id': newTripId,
            'user_id': newUserId,
          });

          // Update member count by +1
          await _supabase.rpc('increment_group_members', params: {
            'p_group_id': gid,
            'p_by': 1,
          });

          print("✅ Joined existing group $gid");
          return;
        }

        print("❌ Group $gid FULL → checking next...");
      }

      // ---------------------------------------------------------------------
      // 4️⃣ All groups were full → create a single NEW group with ALL trips
      // ---------------------------------------------------------------------
      print("🔴 All groups full → Creating NEW group with ALL matched trips + currentTrip");

      return await _createNewGroup(
        currentTrip,
        matchedTrips,
      );

    } catch (e) {
      print("❌ ERROR createOrJoinGroup: $e");
      rethrow;
    }
  }

  /// -----------------------------------------------------------------------
  /// 🆕 Create a brand new group and insert:
  /// - ALL matchedTrips
  /// - the currentTrip
  /// -----------------------------------------------------------------------
  static Future<void> _createNewGroup(
    Map<String, dynamic> currentTrip, 
    List<Map<String, dynamic>> matchedTrips,
  ) async {
    try {
      final newTripId = currentTrip['trip_id'];
      final newUserId = currentTrip['user_id'];

      final int memberCount = matchedTrips.length + 1;

      print("🎉 Creating NEW group with $memberCount members");

      if (memberCount > 4) {
        print("⚠️ ERROR: Too many trips for one group ($memberCount / max 4)");
        throw Exception("Too many members for one group");
      }

      // 1️⃣ Create the group with correct initial member count
      final newGroup = await _supabase
          .from('groups')
          .insert({
            'status': 'active',
            'current_members': memberCount,
            'max_members': 4,
          })
          .select()
          .single();

      final String groupId = newGroup['id'];

      print("🟢 New group created: $groupId");

      // 2️⃣ Combine all trips: matched + current
      final allTrips = [
        ...matchedTrips,
        currentTrip,
      ];

      // 3️⃣ Insert all members
      final List<Map<String, dynamic>> rows = allTrips.map((t) {
        return {
          'group_id': groupId,
          'trip_id': t['trip_id'],
          'user_id': t['user_id'],
        };
      }).toList();

      await _supabase.from('group_members').insert(rows);

      print("✅ Added ${rows.length} members to new group $groupId");

    } catch (e) {
      print("❌ ERROR _createNewGroup: $e");
      rethrow;
    }
  }
}
