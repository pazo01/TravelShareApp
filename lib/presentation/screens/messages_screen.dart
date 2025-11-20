import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/route_observer.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with RouteAware {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  // 🔥 Subscribe to RouteObserver
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  // 🔥 Called automatically when user returns to this page
  @override
  void didPopNext() {
    print("🔄 didPopNext → Refreshing groups...");
    _loadGroups();
  }

  @override
  void dispose() {
    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 📥 LOAD GROUPS THAT HAVE MESSAGES
  // ---------------------------------------------------------------------------
  Future<void> _loadGroups() async {
    final userId = supabase.auth.currentUser!.id;

    print("🟦 DEBUG: Current userId = $userId");

    final memberGroups = await supabase
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    print("🟧 DEBUG: SELECT group_members → $memberGroups");

    List<Map<String, dynamic>> results = [];

    for (var entry in memberGroups) {
      final groupId = entry['group_id'];
      print("🟩 DEBUG: Checking groupId = $groupId");

      // Fetch last message
      final lastMsg = await supabase
          .from('messages')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(1);

      print("🟨 DEBUG: LastMsg for $groupId → $lastMsg");

      // 🚫 Skip empty groups (no messages)
      if (lastMsg.isEmpty) {
        print("⛔ Group $groupId has NO messages → skipping");
        continue;
      }

      final groupName = "Gruppo $groupId"; // or replace later with name

      results.add({
        'group_id': groupId,
        'group_name': groupName,
        'last_message': lastMsg[0]['content'],
        'last_time': DateTime.parse(lastMsg[0]['created_at']),
      });
    }

    print("🟪 DEBUG: Final group list → $results");

    setState(() {
      groups = results;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text(
                "Nessuna chat attiva",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                final groupId = g['group_id'];
                final groupName = g['group_name'];
                final lastMsg = g['last_message'];
                final lastTime = g['last_time'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      groupName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(groupName),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    "${lastTime.hour}:${lastTime.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          groupId: groupId,
                          groupName: groupName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
