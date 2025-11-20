import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  
  const EditProfileScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  List<String> _selectedLanguages = [];
  bool _isLoading = false;

  // Lista di lingue disponibili (puoi espanderla)
  final Map<String, String> _availableLanguages = {
    'it': 'Italiano 🇮🇹',
    'en': 'Inglese 🇬🇧',
    'es': 'Spagnolo 🇪🇸',
    'fr': 'Francese 🇫🇷',
    'de': 'Tedesco 🇩🇪',
    'pt': 'Portoghese 🇵🇹',
    'ro': 'Rumeno 🇷🇴',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.userProfile['full_name'] ?? '',
    );
    _bioController = TextEditingController(
      text: widget.userProfile['bio'] ?? '',
    );
    
    // Inizializza le lingue dall'array di Supabase
    if (widget.userProfile['languages'] != null) {
      _selectedLanguages = List<String>.from(widget.userProfile['languages']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError('Utente non trovato');
        return;
      }
      
      final updates = {
        'id': user.id,
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'languages': _selectedLanguages,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('user_profiles')
          .upsert(updates); 
          // Upsert è comodo: aggiorna se esiste, crea se non esiste.

      _showSuccess('Profilo aggiornato con successo!');
      if (mounted) {
        // Passa 'true' per indicare che il profilo è stato aggiornato
        Navigator.pop(context, true); 
      }

    } catch (e) {
      _showError('Errore durante l\'aggiornamento del profilo');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onLanguageSelected(bool selected, String langCode) {
    setState(() {
      if (selected) {
        // Aggiungi lingua
        if (_selectedLanguages.length < 2) {
          _selectedLanguages.add(langCode);
        } else {
          _showError('Puoi selezionare al massimo 2 lingue');
        }
      } else {
        // Rimuovi lingua
        _selectedLanguages.remove(langCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Profilo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nome Completo
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci il tuo nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'La tua Bio',
                  hintText: 'Parlaci un po\' di te... (visibile agli altri)',
                  prefixIcon: Icon(Icons.edit),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 250,
              ),
              const SizedBox(height: 24),
              
              // Lingue
              Text(
                'Lingue Parlate (Max 2)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _availableLanguages.entries.map((entry) {
                    final code = entry.key;
                    final name = entry.value;
                    final isSelected = _selectedLanguages.contains(code);
                    
                    return FilterChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (selected) {
                        // Impedisce di deselezionare se è l'unica opzione e
                        // la logica di aggiunta è gestita nel tap.
                        _onLanguageSelected(selected, code);
                      },
                      selectedColor: Colors.blue.shade100,
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Pulsante Salva
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salva Modifiche'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}