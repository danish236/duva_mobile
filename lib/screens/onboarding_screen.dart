import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form Data - Text
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _workController = TextEditingController();

  DateTime? _selectedDate;

  // Form Data - Selections (Populated from Master Tables)
  String? _selectedGender;
  String? _selectedLookingForGender;
  String? _selectedExpectation;
  String? _selectedEducation;
  final List<int> _selectedInterestIds = [];

  // Master Data Lists (Fetched from Supabase)
  List<Map<String, dynamic>> _masterInterests = [];
  List<String> _masterGenders = [];
  List<String> _masterExpectations = [];
  List<String> _masterEducation = [];

  // Image State
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _selectedImages = [null, null, null];

  @override
  void initState() {
    super.initState();
    _fetchMasterData(); // Fetch all master tables at startup
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _workController.dispose();
    super.dispose();
  }

  // --- FETCH ALL MASTER DATA IN PARALLEL ---
  Future<void> _fetchMasterData() async {
    try {
      final client = Supabase.instance.client;
      
      final interestsFuture = client.from('master_interests').select('id, name').order('name');
      final gendersFuture = client.from('master_genders').select('name').order('id');
      final expectationsFuture = client.from('master_expectations').select('name').order('id');
      final educationFuture = client.from('master_education').select('name').order('id');

      final results = await Future.wait([interestsFuture, gendersFuture, expectationsFuture, educationFuture]);

      if (mounted) {
        setState(() {
          _masterInterests = List<Map<String, dynamic>>.from(results[0]);
          _masterGenders = (results[1] as List).map((e) => e['name'] as String).toList();
          _masterExpectations = (results[2] as List).map((e) => e['name'] as String).toList();
          _masterEducation = (results[3] as List).map((e) => e['name'] as String).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching master data: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Date of Birth.')));
      return;
    }
    if (_selectedInterestIds.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 3 interests.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user found. Please login again.');

      List<String> uploadedImageUrls = [];
      final dio = Dio();
      const String uploadApiUrl = 'https://backend.duvamobile.workers.dev/upload';

      for (var imageFile in _selectedImages) {
        if (imageFile != null) {
          String fileName = p.basename(imageFile.path);
          FormData formData = FormData.fromMap({
            "image": await MultipartFile.fromFile(imageFile.path, filename: fileName),
          });
          final session = Supabase.instance.client.auth.currentSession;
          var response = await dio.post(
            uploadApiUrl,
            data: formData,
            options: Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'}),
          );

          if (response.statusCode == 200 && response.data['success'] == true) {
            uploadedImageUrls.add(response.data['url']);
          } else {
            throw Exception('Failed to upload image.');
          }
        }
      }

      if (uploadedImageUrls.isEmpty) throw Exception('You must upload at least one photo.');

      // --- SAVE WITH NEW MASTER TABLE SELECTIONS ---
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'location': _locationController.text.trim(),
        'dob': _selectedDate!.toIso8601String(),
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'gender': _selectedGender,
        'looking_for_gender': _selectedLookingForGender,
        'education': _selectedEducation,
        'expectations': _selectedExpectation,
        'images': uploadedImageUrls,
        'created_at': DateTime.now().toIso8601String(),
      });

      final interestInserts = _selectedInterestIds.map((interestId) => {'profile_id': user.id, 'interest_id': interestId}).toList();
      await Supabase.instance.client.from('profile_interests').insert(interestInserts);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
      
    } on DioException catch (e) {
      debugPrint('DIO CRASH DATA: ${e.response?.data}');
      if (mounted) {
        String errorMsg = 'Network Error';
        if (e.response?.data != null && e.response?.data is Map) {
          errorMsg = e.response?.data['error'] ?? e.message;
        } else {
          errorMsg = e.message ?? 'Unknown network error';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      debugPrint('Onboarding Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    // Validation for Step 1
    if (_currentPage == 0 && (_firstNameController.text.isEmpty || _selectedDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and DOB are required.')));
      return;
    }
    // Validation for Step 2
    if (_currentPage == 1 && (_selectedGender == null || _selectedLookingForGender == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your gender and preference.')));
      return;
    }

    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 60, maxWidth: 1080, maxHeight: 1080,
    );
    if (image != null) setState(() => _selectedImages[index] = image);
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: _currentPage > 0 ? IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)) : null,
        title: LinearProgressIndicator(
          value: (_currentPage + 1) / 4, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1Basics(),
                  _buildStep2Details(),
                  _buildStep3Interests(),
                  _buildStep4Photos(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Basics() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Let\'s get the basics down.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _firstNameController, textCapitalization: TextCapitalization.words, keyboardType: TextInputType.name, maxLength: 20,
              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController, textCapitalization: TextCapitalization.words, keyboardType: TextInputType.name, maxLength: 20,
              decoration: const InputDecoration(labelText: 'Last Name (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController, textCapitalization: TextCapitalization.words, keyboardType: TextInputType.streetAddress, maxLength: 40,
              decoration: const InputDecoration(labelText: 'City, Country', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[400]!)),
              title: Text(_selectedDate == null ? 'Select Date of Birth' : 'DOB: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                style: TextStyle(fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold, color: _selectedDate == null ? Colors.grey[700] : Colors.black),
              ),
              trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 6570)),
                  builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.blueAccent, onPrimary: Colors.white, onSurface: Colors.black)), child: child!),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are ${_calculateAge(_selectedDate!)} years old.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 4),
                    const Text('⚠️ This cannot be changed later.', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- NEW: DYNAMIC STEP 2 USING MASTER TABLES ---
  Widget _buildStep2Details() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tell us more about you.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),

            // GENDER SELECTION
            const Text('I am a...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _masterGenders.map((gender) => ChoiceChip(
                label: Text(gender),
                selected: _selectedGender == gender,
                selectedColor: Colors.blue[100],
                onSelected: (selected) { if (selected) setState(() => _selectedGender = gender); },
              )).toList(),
            ),
            const SizedBox(height: 24),

            // PREFERENCE SELECTION
            const Text('Looking to meet...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [..._masterGenders, 'Everyone'].map((gender) => ChoiceChip(
                label: Text(gender),
                selected: _selectedLookingForGender == gender,
                selectedColor: Colors.blue[100],
                onSelected: (selected) { if (selected) setState(() => _selectedLookingForGender = gender); },
              )).toList(),
            ),
            const SizedBox(height: 24),

            // EXPECTATIONS DROPDOWN
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'I am looking for', border: OutlineInputBorder()),
              value: _selectedExpectation,
              items: _masterExpectations.map((exp) => DropdownMenuItem(value: exp, child: Text(exp))).toList(),
              onChanged: (val) => setState(() => _selectedExpectation = val),
            ),
            const SizedBox(height: 16),

            // EDUCATION DROPDOWN
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Highest Education', border: OutlineInputBorder()),
              value: _selectedEducation,
              items: _masterEducation.map((edu) => DropdownMenuItem(value: edu, child: Text(edu))).toList(),
              onChanged: (val) => setState(() => _selectedEducation = val),
            ),
            const SizedBox(height: 16),

            // WORK & BIO
            TextField(
              controller: _workController, textCapitalization: TextCapitalization.words, maxLength: 40,
              decoration: const InputDecoration(labelText: 'Work (Job Title/Company)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController, textCapitalization: TextCapitalization.sentences, keyboardType: TextInputType.multiline, maxLines: 3, maxLength: 250,
              decoration: const InputDecoration(labelText: 'Bio', hintText: 'A bit about me...', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3Interests() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick up to 5 interests.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${_selectedInterestIds.length} / 5 selected', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: _masterInterests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 10.0, runSpacing: 12.0,
                      children: _masterInterests.map((interest) {
                        final bool isSelected = _selectedInterestIds.contains(interest['id']);
                        return FilterChip(
                          label: Text(interest['name']), selected: isSelected, selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(context).colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                if (_selectedInterestIds.length < 5) {
                                  _selectedInterestIds.add(interest['id']);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only select up to 5 interests.')));
                                }
                              } else {
                                _selectedInterestIds.remove(interest['id']);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Photos() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add your best photos.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Upload up to 3 images. The first will be your main profile picture.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.7),
              itemCount: 3,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _pickImage(index),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[300]!, width: 2)),
                    clipBehavior: Clip.hardEdge,
                    child: _selectedImages[index] == null
                        ? const Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey))
                        : Image.file(File(_selectedImages[index]!.path), fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)]),
      child: SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: _isLoading ? null : () {
            if (_currentPage < 3) {
              _nextPage();
            } else {
              _completeOnboarding();
            }
          },
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentPage < 3 ? 'Continue' : 'Complete Profile', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}