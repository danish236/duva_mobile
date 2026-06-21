import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import '../theme.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileData currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingData = true;

  final _bioController = TextEditingController();
  final _workController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateBidController = TextEditingController();

  // Selections
  String? _selectedGender;
  String? _selectedExpectation;
  String? _selectedEducation;

  // Master Data
  List<String> _masterGenders = [];
  List<String> _masterExpectations = [];
  List<String> _masterEducation = [];

  @override
  void initState() {
    super.initState();
    _bioController.text = widget.currentProfile.bio ?? '';
    _workController.text = widget.currentProfile.work ?? '';
    _locationController.text = widget.currentProfile.location;
    _dateBidController.text = widget.currentProfile.currentDateBid ?? '';
    
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client.from('master_genders').select('name').order('id'),
      client.from('master_expectations').select('name').order('id'),
      client.from('master_education').select('name').order('id'),
    ]);

    if (mounted) {
      setState(() {
        _masterGenders = (results[0] as List).map((e) => e['name'] as String).toList();
        _masterExpectations = (results[1] as List).map((e) => e['name'] as String).toList();
        _masterEducation = (results[2] as List).map((e) => e['name'] as String).toList();
        
        // Initialize dropdowns with existing values
        _selectedGender = _masterGenders.contains(widget.currentProfile.currentDateBid) ? widget.currentProfile.currentDateBid : null; // Logic depends on how you store gender
        _selectedExpectation = _masterExpectations.contains(widget.currentProfile.expectations) ? widget.currentProfile.expectations : null;
        _selectedEducation = _masterEducation.contains(widget.currentProfile.education) ? widget.currentProfile.education : null;
        
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _workController.dispose();
    _locationController.dispose();
    _dateBidController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'education': _selectedEducation, // Using master table selection
        'expectations': _selectedExpectation, // Using master table selection
        'location': _locationController.text.trim(),
        'current_date_bid': _dateBidController.text.trim(),
        'gender': _selectedGender,
      }).eq('id', userId);

      if (!mounted) return;
      Navigator.pop(context, true); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildTextField(_dateBidController, 'Active Date Bid 🥂', 'e.g., Coffee at 4PM'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              value: _selectedGender,
              items: _masterGenders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Expectations', border: OutlineInputBorder()),
              value: _selectedExpectation,
              items: _masterExpectations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedExpectation = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder()),
              value: _selectedEducation,
              items: _masterEducation.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedEducation = val),
            ),
            const SizedBox(height: 16),
            _buildTextField(_workController, 'Work', 'Job Title / Company'),
            const SizedBox(height: 16),
            _buildTextField(_bioController, 'Bio', 'About me...', maxLines: 4),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    );
  }
}