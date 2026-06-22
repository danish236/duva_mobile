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

  String? _selectedGender;
  String? _selectedExpectation;
  String? _selectedEducation;

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
        
        // Safety checks for initial dropdown values
        if (_masterExpectations.contains(widget.currentProfile.expectations)) {
          _selectedExpectation = widget.currentProfile.expectations;
        }
        if (_masterEducation.contains(widget.currentProfile.education)) {
          _selectedEducation = widget.currentProfile.education;
        }

        _isLoadingData = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'education': _selectedEducation,
        'expectations': _selectedExpectation,
        'location': _locationController.text.trim(),
        'current_date_bid': _dateBidController.text.trim(),
        'gender': _selectedGender,
      }).eq('id', userId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: colorScheme.background, 
        body: Center(child: CircularProgressIndicator(color: AppTheme.hotPink))
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
          child: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2, color: Colors.white)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionLabel('YOUR DATE BID', colorScheme),
            _buildTextField(_dateBidController, 'Active Date Bid 🥂', 'e.g., Coffee at 4PM'),
            const SizedBox(height: 24),
            
            _buildSectionLabel('PERSONAL INFO', colorScheme),
            _buildDropdown('Gender', _masterGenders, _selectedGender, (val) => setState(() => _selectedGender = val), colorScheme),
            const SizedBox(height: 16),
            _buildDropdown('Expectations', _masterExpectations, _selectedExpectation, (val) => setState(() => _selectedExpectation = val), colorScheme),
            const SizedBox(height: 16),
            _buildDropdown('Education', _masterEducation, _selectedEducation, (val) => setState(() => _selectedEducation = val), colorScheme),
            const SizedBox(height: 16),
            _buildTextField(_workController, 'Work', 'Job Title / Company'),
            const SizedBox(height: 24),

            _buildSectionLabel('ABOUT YOU', colorScheme),
            _buildTextField(_bioController, 'Bio', 'A little bit about me...', maxLines: 4),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: colorScheme.onSurface.withValues(alpha: 0.5))),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label, 
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.skySurge),
      dropdownColor: colorScheme.surface,
      value: value,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, 
        hintText: hint,
      ),
    );
  }
}