import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_profile.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AuthService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = AuthService.currentUser;
    final displayName = _userProfile?.fullName ?? 
                        user?.userMetadata?['full_name'] ?? 
                        user?.email?.split('@').first ?? 
                        'Utente';
    final email = _userProfile?.email ?? user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Implement settings
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundImage: _userProfile?.avatarUrl != null
                    ? NetworkImage(_userProfile!.avatarUrl!)
                    : null,
                child: _userProfile?.avatarUrl == null
                    ? Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              
              // Name
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Email
              Text(
                email,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Reputazione',
                        '${_userProfile?.reputationScore ?? 5.0} ⭐',
                        Icons.star,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      _buildStatItem(
                        'Viaggi',
                        '${_userProfile?.totalTrips ?? 0}',
                        Icons.trip_origin,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Menu Items
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Modifica Profilo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement edit profile
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifiche'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement notifications
                },
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Privacy e Sicurezza'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement privacy settings
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Aiuto e Supporto'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement help
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade600),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}