import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart'; // To access the ProfileData class

class EditProfileScreen extends StatefulWidget {
  final ProfileData currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _bioController;
  late TextEditingController _workController;
  late TextEditingController _eduController;
  late TextEditingController _expectationsController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text fields with the user's existing data
    _bioController = TextEditingController(text: widget.currentProfile.bio);
    _workController = TextEditingController(text: widget.currentProfile.work);
    _eduController = TextEditingController(text: widget.currentProfile.education);
    _expectationsController = TextEditingController(text: widget.currentProfile.expectations);
    _locationController = TextEditingController(text: widget.currentProfile.location);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _workController.dispose();
    _eduController.dispose();
    _expectationsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Update the database directly
      await Supabase.instance.client.from('profiles').update({
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'education': _eduController.text.trim(),
        'expectations': _expectationsController.text.trim(),
        'location': _locationController.text.trim(),
      }).eq('id', userId);

      if (!mounted) return;
      
      // Pop the screen and return 'true' to tell ProfileScreen to refresh
      Navigator.pop(context, true); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      
    } catch (e) {
      debugPrint('Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildTextField(
              controller: _bioController,
              label: 'Bio',
              hint: 'A bit about me...',
              maxLines: 4,
              maxLength: 250,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _expectationsController,
              label: 'Expectations',
              hint: 'What are you looking for?',
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _workController,
              label: 'Work',
              hint: 'Job Title / Company',
              maxLength: 40,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _eduController,
              label: 'Education',
              hint: 'University / College',
              maxLength: 40,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'City, Country',
              maxLength: 40,
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}