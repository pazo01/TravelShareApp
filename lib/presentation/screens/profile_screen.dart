import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../data/services/auth_service.dart';
import 'link_phone_screen.dart';
import 'privacy_security_screen.dart';
import 'edit_profile_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _phoneNumber;
  bool _phoneVerified = false;
  Map<String, dynamic>? _userProfile;
  String? _profilePhotoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        setState(() {
          _phoneNumber = user.phone;
          _phoneVerified = user.phone != null;
        });
        print('🔵 [PROFILE] Dati auth: phone=${user.phone}, email=${user.email}');
      }

      try {
        // CARICA DIRETTAMENTE DA user_profiles invece di usare AuthService
        final response = await Supabase.instance.client
            .from('user_profiles')
            .select('full_name, email, phone, bio, languages, avatar_url, reputation_score, total_trips')
            .eq('id', user!.id)
            .maybeSingle();
        
        if (response != null && mounted) {
          setState(() {
            _userProfile = {
              'full_name': response['full_name'],
              'email': response['email'] ?? user.email,
              'phone': response['phone'],
              'phone_verified': (response['phone'] != null && response['phone'].toString().isNotEmpty),
              'reputation_score': response['reputation_score'] ?? 5.0,
              'total_trips': response['total_trips'] ?? 0,
              'bio': response['bio'],
              'languages': response['languages'],
            };
            _phoneNumber = response['phone'];
            _phoneVerified = (response['phone'] != null && response['phone'].toString().isNotEmpty);
            _profilePhotoUrl = response['avatar_url'];
          });
          
          print('🟢 [PROFILE] Profilo caricato completo:');
          print('   - Nome: ${response['full_name']}');
          print('   - Bio: ${response['bio']}');
          print('   - Lingue: ${response['languages']}');
          print('   - Foto: ${response['avatar_url']}');
        } else if (user != null && mounted) {
          // Fallback se il profilo non esiste
          setState(() {
            _userProfile = {
              'full_name': null,
              'email': user.email,
              'phone': user.phone,
              'phone_verified': user.phone != null,
              'reputation_score': 5.0,
              'total_trips': 0,
              'bio': null,
              'languages': [],
            };
          });
        }
      } catch (e) {
        print('⚠️ [PROFILE] Errore DB: $e');
        
        if (user != null && mounted) {
          setState(() {
            _userProfile = {
              'full_name': null,
              'email': user.email,
              'phone': user.phone,
              'phone_verified': user.phone != null,
              'reputation_score': 5.0,
              'total_trips': 0,
              'bio': null,
              'languages': [],
            };
          });
        }
      }
    } catch (e) {
      print('🔴 [PROFILE] Errore: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfilePhoto() async {
    // Questo metodo ora è deprecato perché tutto viene caricato in _loadUserProfile
    // Lo mantengo per compatibilità ma non fa nulla
    print('ℹ️ [PROFILE] _loadProfilePhoto chiamato (ora deprecato)');
  }

  Future<void> _showPhotoOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_profilePhotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Rimuovi foto', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Annulla'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (option == null) return;

    if (option == 'remove') {
      await _removeProfilePhoto();
    } else {
      await _pickAndUploadPhoto(option == 'camera');
    }
  }

  Future<void> _pickAndUploadPhoto(bool fromCamera) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError('Utente non autenticato');
        return;
      }

      // Genera un nome file unico
      final String fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File(image.path);

      print('📤 [PROFILE] Upload foto: $fileName');

      // Upload su Supabase Storage
      final String path = await Supabase.instance.client.storage
          .from('profile-photos')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Ottieni l'URL pubblico
      final String publicUrl = Supabase.instance.client.storage
          .from('profile-photos')
          .getPublicUrl(fileName);

      print('🟢 [PROFILE] Foto caricata: $publicUrl');

      // Se c'era una foto precedente, eliminala
      if (_profilePhotoUrl != null) {
        await _deleteOldPhoto(_profilePhotoUrl!);
      }

      // Aggiorna il database
      await Supabase.instance.client
          .from('user_profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        _profilePhotoUrl = publicUrl;
      });

      _showSuccess('Foto profilo aggiornata!');
    } catch (e) {
      print('🔴 [PROFILE] Errore upload foto: $e');
      _showError('Errore durante il caricamento della foto');
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      setState(() => _isUploadingPhoto = true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Elimina la foto dallo storage
      if (_profilePhotoUrl != null) {
        await _deleteOldPhoto(_profilePhotoUrl!);
      }

      // Aggiorna il database
      await Supabase.instance.client
          .from('user_profiles')
          .update({'avatar_url': null})
          .eq('id', user.id);

      setState(() {
        _profilePhotoUrl = null;
      });

      _showSuccess('Foto profilo rimossa');
    } catch (e) {
      print('🔴 [PROFILE] Errore rimozione foto: $e');
      _showError('Errore durante la rimozione della foto');
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deleteOldPhoto(String photoUrl) async {
    try {
      // Estrai il nome del file dall'URL
      final uri = Uri.parse(photoUrl);
      final fileName = uri.pathSegments.last;

      await Supabase.instance.client.storage
          .from('profile-photos')
          .remove([fileName]);

      print('🗑️ [PROFILE] Vecchia foto eliminata: $fileName');
    } catch (e) {
      print('⚠️ [PROFILE] Errore eliminazione vecchia foto: $e');
      // Non bloccare il processo se l'eliminazione fallisce
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user?.email != null && user!.email!.isNotEmpty) {
        final emailPart = user.email!.split('@')[0];
        if (emailPart.isNotEmpty) {
          return emailPart[0].toUpperCase();
        }
      }
      
      if (user?.phone != null && user!.phone!.isNotEmpty) {
        final phone = user.phone!.replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.length >= 2) {
          return phone.substring(phone.length - 2);
        } else if (phone.isNotEmpty) {
          return phone[0];
        }
      }
      
      return '?';
    }
    
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    
    return trimmed[0].toUpperCase();
  }

  String _getDisplayName() {
    if (_userProfile?['full_name'] != null && 
        _userProfile!['full_name'].toString().trim().isNotEmpty) {
      return _userProfile!['full_name'];
    }
    
    if (_userProfile?['email'] != null && 
        _userProfile!['email'].toString().isNotEmpty) {
      return _userProfile!['email'].toString().split('@')[0];
    }
    
    if (_phoneNumber != null && _phoneNumber!.isNotEmpty) {
      return _formatPhone(_phoneNumber!);
    }
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.email != null) {
      return user!.email!.split('@')[0];
    }
    if (user?.phone != null) {
      return _formatPhone(user!.phone!);
    }
    
    return 'Utente';
  }

  String _formatPhone(String phone) {
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }
    
    if (phone.startsWith('+39') && phone.length == 13) {
      return '+39 ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    }
    return phone;
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: _profilePhotoUrl != null 
                  ? NetworkImage(_profilePhotoUrl!)
                  : null,
              child: _profilePhotoUrl == null
                  ? Text(
                      _getInitials(_userProfile?['full_name']),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _isUploadingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il Mio Profilo'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar e nome
                    Center(
                      child: Column(
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 16),
                          Text(
                            _getDisplayName(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_userProfile?['email'] != null &&
                              _userProfile!['email'].toString().isNotEmpty)
                            Text(
                              _userProfile!['email'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    // Bio
                    if (_userProfile?['bio'] != null && 
                        _userProfile!['bio'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Bio',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userProfile!['bio'].toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Lingue parlate
                    if (_userProfile?['languages'] != null && 
                        (_userProfile!['languages'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, size: 18, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Lingue parlate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_userProfile!['languages'] as List).map<Widget>((code) {
                                final languageMap = {
                                  'it': {'name': 'Italiano', 'flag': '🇮🇹'},
                                  'en': {'name': 'Inglese', 'flag': '🇬🇧'},
                                  'es': {'name': 'Spagnolo', 'flag': '🇪🇸'},
                                  'fr': {'name': 'Francese', 'flag': '🇫🇷'},
                                  'de': {'name': 'Tedesco', 'flag': '🇩🇪'},
                                  'pt': {'name': 'Portoghese', 'flag': '🇵🇹'},
                                  'ro': {'name': 'Rumeno', 'flag': '🇷🇴'},
                                };
                                
                                final lang = languageMap[code.toString()];
                                if (lang == null) return const SizedBox.shrink();
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(lang['flag']!, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(
                                        lang['name']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Statistiche
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.star,
                            label: 'Reputazione',
                            value: (_userProfile?['reputation_score'] ?? 5.0)
                                .toString(),
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.flight_takeoff,
                            label: 'Viaggi',
                            value: (_userProfile?['total_trips'] ?? 0)
                                .toString(),
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Sezione Telefono
                    const _SectionTitle(title: 'Numero di Telefono'),
                    const SizedBox(height: 12),

                    if (_phoneNumber == null || _phoneNumber!.isEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.phone_android,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Nessun numero collegato',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aggiungi un numero di telefono per ricevere notifiche importanti',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _handleAddPhone,
                                icon: const Icon(Icons.add),
                                label: const Text('Aggiungi Numero'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.phone, color: Colors.green),
                          title: Text(_formatPhone(_phoneNumber!)),
                          subtitle: const Text('Numero verificato'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _handleModifyPhone,
                                tooltip: 'Modifica numero',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Impostazioni
                    const _SectionTitle(title: 'Impostazioni'),
                    const SizedBox(height: 12),

                    _SettingsTile(
                      icon: Icons.edit,
                      title: 'Modifica Profilo',
                      onTap: _navigateToEditProfile,
                    ),
                    _SettingsTile(
                      icon: Icons.security,
                      title: 'Privacy e Sicurezza',
                      onTap: _navigateToPrivacySecurity,
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Aiuto e Supporto',
                      onTap: () {
                        // TODO: Implementare help screen
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'Informazioni App',
                      onTap: () {
                        // TODO: Implementare about screen
                      },
                    ),

                    const SizedBox(height: 24),

                    // Logout button
                    OutlinedButton.icon(
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Esci dall\'Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _handleAddPhone() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const LinkPhoneScreen(),
      ),
    );

    if (result != null && result.startsWith('+')) {
      print('🟢 [PROFILE] Numero ricevuto da LinkPhoneScreen: $result');
      
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          _showError('Utente non autenticato');
          return;
        }

        String phoneToSync = result;

        if (phoneToSync.startsWith('+') && phoneToSync.substring(1).replaceAll(RegExp(r'\D'), '').length > 1) {
          phoneToSync = '+${phoneToSync.substring(1).replaceAll(RegExp(r'\D'), '')}';
          print('ℹ️ [PROFILE] Numero pulito in formato E.164: $phoneToSync');
        }

        await Supabase.instance.client
            .from('user_profiles')
            .update({'phone': phoneToSync})
            .eq('id', user.id);
        
        print('🟢 [PROFILE] Sincronizzato user_profiles con auth phone.');
        _showSuccess('Numero aggiunto con successo!');

      } catch (e) {
        print('🔴 [PROFILE] Errore Sincronizzazione Telefono: $e');
        _showError('Errore nell\'aggiornare il profilo.');
      } finally {
        await _loadUserProfile();
      }
    }
  }

  // NUOVA FUNZIONE: Modifica numero di telefono
  Future<void> _handleModifyPhone() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const LinkPhoneScreen(),
      ),
    );

    if (result != null && result.startsWith('+')) {
      print('🟢 [PROFILE] Nuovo numero ricevuto: $result');
      
      // Verifica che il nuovo numero sia diverso da quello attuale
      if (result == _phoneNumber) {
        _showError('Questo è già il tuo numero attuale');
        return;
      }
      
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          _showError('Utente non autenticato');
          return;
        }

        String phoneToSync = result;

        if (phoneToSync.startsWith('+') && phoneToSync.substring(1).replaceAll(RegExp(r'\D'), '').length > 1) {
          phoneToSync = '+${phoneToSync.substring(1).replaceAll(RegExp(r'\D'), '')}';
          print('ℹ️ [PROFILE] Numero pulito in formato E.164: $phoneToSync');
        }

        await Supabase.instance.client
            .from('user_profiles')
            .update({'phone': phoneToSync})
            .eq('id', user.id);
        
        print('🟢 [PROFILE] Numero modificato con successo.');
        _showSuccess('Numero modificato con successo!');

      } catch (e) {
        print('🔴 [PROFILE] Errore modifica telefono: $e');
        _showError('Errore durante la modifica del numero.');
      } finally {
        await _loadUserProfile();
      }
    }
  }


  Future<void> _navigateToEditProfile() async {
    if (_userProfile == null) {
      _showError('Profilo non caricato');
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userProfile: _userProfile!),
      ),
    );
    
    // Se il profilo è stato aggiornato, ricarica i dati
    if (result == true) {
      _loadUserProfile();
    }
  }

  Future<void> _navigateToPrivacySecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacySecurityScreen(),
      ),
    );
    // Ricarica il profilo quando si torna indietro
    _loadUserProfile();
  }
  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
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

    if (confirm != true) return;

    try {
      await AuthService.signOut();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      print('🔴 Errore Sign Out: $e');
      
      try {
        print('! Tentativo logout locale...');
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
        print('✅ Logout locale completato');

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/auth',
            (route) => false,
          );
        }
      } catch (e2) {
        _showError('Errore critico durante il logout: $e2');
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ========================================
// WIDGET HELPER
// ========================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}