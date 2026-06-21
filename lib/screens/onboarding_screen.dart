import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// We hide MultipartFile from supabase so it doesn't conflict with Dio
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile; 
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form Data
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _workController = TextEditingController();
  final TextEditingController _eduController = TextEditingController();
  final TextEditingController _expectationsController = TextEditingController();
  
  DateTime? _selectedDate;
  
  // Interests State
  List<Map<String, dynamic>> _masterInterests = [];
  final List<int> _selectedInterestIds = [];

  // Image State
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _selectedImages = [null, null, null];

  @override
  void initState() {
    super.initState();
    _fetchMasterInterests();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _workController.dispose();
    _eduController.dispose();
    _expectationsController.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterInterests() async {
    try {
      final data = await Supabase.instance.client
          .from('master_interests')
          .select('id, name')
          .order('name');
      setState(() {
        _masterInterests = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching interests: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      List<String> uploadedImageUrls = [];
      
      final dio = Dio();
      
      // We will replace this URL with the one from your Wrangler terminal
      // The live URL from your Wrangler terminal
      const String uploadApiUrl = 'https://backend.duvamobile.workers.dev/upload';

      // 1. Upload Images to Cloudflare R2
      for (var imageFile in _selectedImages) {
        if (imageFile != null) {
          String fileName = p.basename(imageFile.path);
          FormData formData = FormData.fromMap({
            "image": await MultipartFile.fromFile(imageFile.path, filename: fileName),
          });

          var response = await dio.post(uploadApiUrl, data: formData);

          if (response.statusCode == 200 && response.data['success'] == true) {
            uploadedImageUrls.add(response.data['url']);
          } else {
            throw Exception('Failed to upload an image.');
          }
        }
      }

      if (uploadedImageUrls.isEmpty) {
        throw Exception('You must upload at least one photo.');
      }

      // 2. Save everything to Supabase
      await Supabase.instance.client.from('profiles').insert({
        'id': userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'location': _locationController.text.trim(),
        'dob': _selectedDate!.toIso8601String(),
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'education': _eduController.text.trim(),
        'expectations': _expectationsController.text.trim(),
        'images': uploadedImageUrls, 
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Save Interests
      if (_selectedInterestIds.isNotEmpty) {
        final interestInserts = _selectedInterestIds.map((interestId) => {
          'profile_id': userId,
          'interest_id': interestId,
        }).toList();
        await Supabase.instance.client.from('profile_interests').insert(interestInserts);
      }

      if (!mounted) return;
      Navigator.pop(context); 
      
    } catch (e) {
      debugPrint('Onboarding Error: $e'); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && (_firstNameController.text.isEmpty || _selectedDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and DOB are required.')));
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _selectedImages[index] = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              )
            : null,
        title: LinearProgressIndicator(
          value: (_currentPage + 1) / 4,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
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
            TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()), maxLength: 20),
            const SizedBox(height: 16),
            TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name (Optional)', border: OutlineInputBorder()), maxLength: 20),
            const SizedBox(height: 16),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'City, Country', border: OutlineInputBorder()), maxLength: 40),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_selectedDate == null ? 'Select Date of Birth' : 'DOB: ${_selectedDate!.toLocal().toString().split(' ')[0]}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context, initialDate: DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 6570)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Details() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stand out from the crowd.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(controller: _bioController, maxLines: 4, maxLength: 250, decoration: const InputDecoration(labelText: 'Bio', hintText: 'A bit about me...', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _expectationsController, maxLength: 100, decoration: const InputDecoration(labelText: 'Expectations', hintText: 'What are you looking for?', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _workController, maxLength: 40, decoration: const InputDecoration(labelText: 'Work (Job Title/Company)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _eduController, maxLength: 40, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
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
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10.0,
                runSpacing: 12.0,
                children: _masterInterests.map((interest) {
                  final bool isSelected = _selectedInterestIds.contains(interest['id']);
                  return FilterChip(
                    label: Text(interest['name']),
                    selected: isSelected,
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.7,
              ),
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
        width: double.infinity,
        height: 56,
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