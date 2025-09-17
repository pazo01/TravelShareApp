import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  String _status = 'Not authenticated';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Test - Giorno 2')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Google Sign In
            ElevatedButton.icon(
              onPressed: _loading ? null : _testGoogleSignIn,
              icon: const Icon(Icons.account_circle),
              label: const Text('Test Google Sign In'),
            ),

            const SizedBox(height: 20),
            const Text('Email Authentication:'),

            // Email fields
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name (for registration)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Email buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _testEmailSignIn,
                    child: const Text('Sign In'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _testEmailSignUp,
                    child: const Text('Sign Up'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sign Out
            ElevatedButton(
              onPressed: _loading ? null : _testSignOut,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),

            const SizedBox(height: 20),

            // Get Profile
            ElevatedButton(
              onPressed: _loading ? null : _testGetProfile,
              child: const Text('Get User Profile'),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGoogleSignIn() async {
    setState(() {
      _loading = true;
      _status = 'Testing Google Sign In...';
    });

    try {
      final response = await AuthService.signInWithGoogle();
      setState(() {
        _status =
            'Google Sign In Success!\n'
            'User: ${response.user?.email}\n'
            'ID: ${response.user?.id}';
      });
    } catch (e) {
      setState(() {
        _status = 'Google Sign In Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testEmailSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _status = 'Please enter email and password');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Testing Email Sign In...';
    });

    try {
      final response = await AuthService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {
        _status =
            'Email Sign In Success!\n'
            'User: ${response.user?.email}\n'
            'ID: ${response.user?.id}';
      });
    } catch (e) {
      setState(() {
        _status = 'Email Sign In Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testEmailSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      setState(() => _status = 'Please fill all fields for registration');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Testing Email Sign Up...';
    });

    try {
      final response = await AuthService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );
      setState(() {
        _status =
            'Email Sign Up Success!\n'
            'Check your email for verification.\n'
            'User: ${response.user?.email}';
      });
    } catch (e) {
      setState(() {
        _status = 'Email Sign Up Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testSignOut() async {
    setState(() {
      _loading = true;
      _status = 'Signing out...';
    });

    try {
      await AuthService.signOut();
      setState(() {
        _status = 'Signed out successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Sign out error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testGetProfile() async {
    setState(() {
      _loading = true;
      _status = 'Getting user profile...';
    });

    try {
      final profile = await AuthService.getUserProfile();
      if (profile != null) {
        setState(() {
          _status =
              'Profile loaded!\n'
              'Name: ${profile.fullName}\n'
              'Email: ${profile.email}\n'
              'Reputation: ${profile.reputationScore}\n'
              'Total trips: ${profile.totalTrips}';
        });
      } else {
        setState(() {
          _status = 'No profile found or not authenticated';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Get profile error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }
}
