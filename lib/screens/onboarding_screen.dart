import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../main.dart'; // To navigate to MainLayout upon completion
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _workController = TextEditingController();
  DateTime? _selectedDate;

  // Master Data Lists
  List<Map<String, dynamic>> _masterGenders = [];
  List<Map<String, dynamic>> _masterInterests = [];
  List<Map<String, dynamic>> _masterExpectations = [];
  List<Map<String, dynamic>> _masterEducation = [];

  // User Selections (Storing IDs)
  int? _selectedGenderId;
  int? _selectedExpectationId;
  int? _selectedEducationId;
  final List<int> _selectedInterestIds = [];
  
  final List<File> _images = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      final gendersResponse = await supabase.from('master_genders').select();
      final interestsResponse = await supabase.from('master_interests').select();
      final expectationsResponse = await supabase.from('master_expectations').select();
      final educationResponse = await supabase.from('master_education').select();

      setState(() {
        _masterGenders = List<Map<String, dynamic>>.from(gendersResponse);
        _masterInterests = List<Map<String, dynamic>>.from(interestsResponse);
        _masterExpectations = List<Map<String, dynamic>>.from(expectationsResponse);
        _masterEducation = List<Map<String, dynamic>>.from(educationResponse);
      });
    } catch (e) {
      debugPrint('Error fetching master data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading options. Please restart.'))
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _workController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 6) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least one image')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your date of birth')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final fileExt = file.path.split('.').last;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await Supabase.instance.client.storage.from('avatars').upload(fileName, file);
        final publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        imageUrls.add(publicUrl);
      }

      String city = "Unknown Location";
      double lat = 0.0, lng = 0.0;
      
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
            lat = position.latitude;
            lng = position.longitude;
            List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
            if (placemarks.isNotEmpty) {
              city = "${placemarks.first.locality}, ${placemarks.first.country}";
            }
          }
        }
      } catch (e) {
        debugPrint("Location error during onboarding: $e");
      }

      final String? selectedGenderName = _selectedGenderId != null 
          ? _masterGenders.firstWhere((g) => g['id'] == _selectedGenderId)['name'] 
          : null;
      final String? selectedEducationName = _selectedEducationId != null 
          ? _masterEducation.firstWhere((e) => e['id'] == _selectedEducationId)['name'] 
          : null;
      final String? selectedExpectationName = _selectedExpectationId != null 
          ? _masterExpectations.firstWhere((e) => e['id'] == _selectedExpectationId)['name'] 
          : null;

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'dob': _selectedDate!.toIso8601String(),
        'gender': selectedGenderName, 
        'education': selectedEducationName,
        'expectations': selectedExpectationName,
        'location': city,
        'latitude': lat,
        'longitude': lng,
        'images': imageUrls,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (_selectedInterestIds.isNotEmpty) {
        List<Map<String, dynamic>> profileInterests = _selectedInterestIds.map((interestId) {
          return {
            'profile_id': user.id,
            'interest_id': interestId,
          };
        }).toList();

        await Supabase.instance.client.from('profile_interests').delete().eq('profile_id', user.id);
        await Supabase.instance.client.from('profile_interests').insert(profileInterests);
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    } catch (e) {
      debugPrint("Onboarding error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.hotPink),
              const SizedBox(height: 24),
              Text('Building your profile...', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold))
            ],
          )
        )
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0 
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface), 
              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
            ) 
          : null,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6, width: _currentPage == index ? 24 : 8,
            decoration: BoxDecoration(
              gradient: _currentPage == index ? const LinearGradient(colors: [AppTheme.hotPink, AppTheme.skySurge]) : null,
              color: _currentPage == index ? null : colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              boxShadow: _currentPage == index ? [BoxShadow(color: AppTheme.hotPink.withValues(alpha: 0.5), blurRadius: 6)] : null,
            ),
          )),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) => setState(() => _currentPage = page),
        children: [
          _buildNameStep(colorScheme),
          _buildDobStep(colorScheme),
          _buildGenderStep(colorScheme),
          _buildInterestsStep(colorScheme),
          _buildDetailsStep(colorScheme),
          _buildExpectationsStep(colorScheme),
          _buildPhotosStep(colorScheme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nextPage,
        backgroundColor: AppTheme.hotPink,
        elevation: 10,
        label: Text(_currentPage == 6 ? 'LET\'S GO' : 'NEXT', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)),
        icon: Icon(_currentPage == 6 ? Icons.rocket_launch : Icons.arrow_forward_ios, size: 20, color: Colors.white),
      ),
    );
  }

  // --- STEP 1: NAME ---
  Widget _buildNameStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
            child: const Text('Who are you?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 48),
          TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
          const SizedBox(height: 24),
          TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name (Optional)')),
        ],
      ),
    );
  }

  // --- STEP 2: DOB ---
  Widget _buildDobStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.hotPink, AppTheme.skySurge]).createShader(bounds),
            child: const Text('When is your birthday?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
          ),
          const SizedBox(height: 16),
          Text('You must be at least 18 years old to use Duva.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
          const SizedBox(height: 48),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.skySurge, width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.toLocal()}'.split(' ')[0], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const Icon(Icons.calendar_today, color: AppTheme.skySurge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: GENDER ---
  Widget _buildGenderStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
            child: const Text('I identify as...', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 48),
          ..._masterGenders.map((gender) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () => setState(() => _selectedGenderId = gender['id']),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedGenderId == gender['id'] ? AppTheme.hotPink.withValues(alpha: 0.1) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedGenderId == gender['id'] ? AppTheme.hotPink : Colors.transparent, width: 2),
                  boxShadow: _selectedGenderId == gender['id'] ? [BoxShadow(color: AppTheme.hotPink.withValues(alpha: 0.3), blurRadius: 10)] : null,
                ),
                child: Text(gender['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _selectedGenderId == gender['id'] ? AppTheme.hotPink : colorScheme.onSurface)),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  // --- STEP 4: INTERESTS ---
  Widget _buildInterestsStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.hotPink, AppTheme.skySurge]).createShader(bounds),
            child: const Text('What are you into?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
          ),
          const SizedBox(height: 16),
          Text('Pick up to 5 interests to help us find better alignments.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12.0, runSpacing: 12.0,
                children: _masterInterests.map((interest) {
                  final isSelected = _selectedInterestIds.contains(interest['id']);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterestIds.remove(interest['id']);
                        } else if (_selectedInterestIds.length < 5) {
                          _selectedInterestIds.add(interest['id']);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.skySurge : colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [BoxShadow(color: AppTheme.skySurge.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
                      ),
                      child: Text(
                        interest['name'], 
                        style: TextStyle(color: isSelected ? Colors.white : colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 5: DETAILS ---
  Widget _buildDetailsStep(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
            child: const Text('The Details', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 48),
          
          Text('EDUCATION', style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(hintText: 'Select Education'),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.skySurge),
            value: _selectedEducationId,
            items: _masterEducation.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['name'], style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (val) => setState(() => _selectedEducationId = val),
          ),
          
          const SizedBox(height: 32),
          Text('WORK', style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(controller: _workController, decoration: const InputDecoration(hintText: 'Job Title / Company')),
          
          const SizedBox(height: 32),
          Text('BIO', style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(controller: _bioController, maxLines: 4, decoration: const InputDecoration(hintText: 'A little bit about me...')),
        ],
      ),
    );
  }

  // --- STEP 6: EXPECTATIONS ---
  Widget _buildExpectationsStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.hotPink, AppTheme.skySurge]).createShader(bounds),
            child: const Text('I\'m looking for...', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
          ),
          const SizedBox(height: 48),
          ..._masterExpectations.map((exp) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () => setState(() => _selectedExpectationId = exp['id']),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedExpectationId == exp['id'] ? AppTheme.skySurge.withValues(alpha: 0.1) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedExpectationId == exp['id'] ? AppTheme.skySurge : Colors.transparent, width: 2),
                  boxShadow: _selectedExpectationId == exp['id'] ? [BoxShadow(color: AppTheme.skySurge.withValues(alpha: 0.3), blurRadius: 10)] : null,
                ),
                child: Text(exp['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _selectedExpectationId == exp['id'] ? AppTheme.skySurge : colorScheme.onSurface)),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  // --- STEP 7: PHOTOS ---
  Widget _buildPhotosStep(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
            child: const Text('Show your face', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
          ),
          const SizedBox(height: 16),
          Text('Upload up to 6 photos. The first one will be your main profile picture.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
              itemCount: 6,
              itemBuilder: (context, index) {
                if (index < _images.length) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_images[index], fit: BoxFit.cover)),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.skySurge.withValues(alpha: 0.3), width: 2, style: BorderStyle.solid),
                      ),
                      child: const Center(child: Icon(Icons.add, color: AppTheme.skySurge, size: 32)),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}