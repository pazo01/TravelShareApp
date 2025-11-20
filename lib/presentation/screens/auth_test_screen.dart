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
  final _otpController = TextEditingController();

  String _status = 'Not authenticated';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Test - With OTP')),
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
                    child: const Text('Sign Up (OTP)'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const Text('OTP Verification:'),
            const SizedBox(height: 10),

            // OTP field
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'OTP Code (6 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 10),

            // OTP buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _testVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Verify OTP'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _testResendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Resend OTP'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),

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
      _status = 'Testing Email Sign Up with OTP...';
    });

    try {
      await AuthService.signUpWithEmailOtp(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );
      setState(() {
        _status =
            'OTP Sent! ✅\n'
            'Check your email for the verification code.\n'
            'Email: ${_emailController.text}\n'
            '\n'
            '📧 Once you receive the code:\n'
            '1. Enter it in the OTP field below\n'
            '2. Click "Verify OTP"\n'
            '3. Then you can sign in normally';
      });
    } catch (e) {
      setState(() {
        _status = 'Email Sign Up Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testVerifyOtp() async {
    if (_emailController.text.isEmpty || _otpController.text.isEmpty) {
      setState(() => _status = 'Please enter email and OTP code');
      return;
    }

    if (_otpController.text.length != 6) {
      setState(() => _status = 'OTP code must be 6 digits');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Verifying OTP...';
    });

    try {
      await AuthService.verifyEmailOtp(
        email: _emailController.text,
        token: _otpController.text,
      );
      setState(() {
        _status =
            'OTP Verified! ✅\n'
            'Registration completed!\n'
            '\n'
            'You can now sign in with:\n'
            'Email: ${_emailController.text}\n'
            'Password: (the one you entered)\n'
            '\n'
            'Click "Sign In" button above to test.';
        _otpController.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'OTP Verification Error: $e\n\nMake sure the code is correct and not expired.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _testResendOtp() async {
    if (_emailController.text.isEmpty) {
      setState(() => _status = 'Please enter email first');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Resending OTP...';
    });

    try {
      await AuthService.resendEmailOtp(email: _emailController.text);
      setState(() {
        _status =
            'New OTP Sent! 📧\n'
            'Check your email: ${_emailController.text}\n'
            '\n'
            'Enter the new code below and click "Verify OTP"';
      });
    } catch (e) {
      setState(() {
        _status = 'Resend OTP Error: $e';
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