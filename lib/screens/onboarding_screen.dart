import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../main.dart'; 
import '../theme.dart';
import '../constants.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/compliance_engine.dart';
import '../services/cache_service.dart';
import '../services/image_service.dart';

enum _ImageState { idle, checking, rejected }

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
  final _weightController = TextEditingController();
  DateTime? _selectedDate;

  // New Lifestyle State
  String? _selectedHeight;
  String? _selectedSmoking;
  String? _selectedDrinking;
  String? _selectedWorkout;
  String? _selectedPets;
  String? _selectedZodiac;
  String? _selectedKids;

  List<Map<String, dynamic>> _masterGenders = [];
  List<Map<String, dynamic>> _masterInterests = [];
  List<Map<String, dynamic>> _masterExpectations = [];
  List<Map<String, dynamic>> _masterEducation = [];

  int? _selectedGenderId;
  int? _selectedExpectationId;
  int? _selectedEducationId;
  final List<int> _selectedInterestIds = [];
  final List<File> _images = [];
  final Map<int, _ImageState> _imageStates = {};

  final List<String> _heightOptions = List.generate(48, (index) => "${4 + (index ~/ 12)}'${index % 12}\"");
  final List<String> _smokingOptions = ['Never', 'Socially', 'Regularly', 'Trying to quit'];
  final List<String> _drinkingOptions = ['Never', 'Socially', 'Regularly'];
  final List<String> _workoutOptions = ['Everyday', 'Sometimes', 'Never'];
  final List<String> _petsOptions = ['Dog', 'Cat', 'Both', 'None', 'Want them'];
  final List<String> _zodiacOptions = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];
  final List<String> _kidsOptions = ['Want someday', 'Don\'t want', 'Have & want more', 'Have & don\'t want more'];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cache = CacheService();
      final supabase = Supabase.instance.client;
      final gendersResponse = await cache.getOrFetchPersistent<List<dynamic>>(
        'master_genders',
        () => supabase.from('master_genders').select().then((r) => List<dynamic>.from(r as List)),
        ttl: AppConstants.cacheTtlMasterData,
      );
      final interestsResponse = await cache.getOrFetchPersistent<List<dynamic>>(
        'master_interests',
        () => supabase.from('master_interests').select().then((r) => List<dynamic>.from(r as List)),
        ttl: AppConstants.cacheTtlMasterData,
      );
      final expectationsResponse = await cache.getOrFetchPersistent<List<dynamic>>(
        'master_expectations',
        () => supabase.from('master_expectations').select().then((r) => List<dynamic>.from(r as List)),
        ttl: AppConstants.cacheTtlMasterData,
      );
      final educationResponse = await cache.getOrFetchPersistent<List<dynamic>>(
        'master_education',
        () => supabase.from('master_education').select().then((r) => List<dynamic>.from(r as List)),
        ttl: AppConstants.cacheTtlMasterData,
      );

      setState(() {
        _masterGenders = List<Map<String, dynamic>>.from(gendersResponse);
        _masterInterests = List<Map<String, dynamic>>.from(interestsResponse);
        _masterExpectations = List<Map<String, dynamic>>.from(expectationsResponse);
        _masterEducation = List<Map<String, dynamic>>.from(educationResponse);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error loading options.')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < 7) {
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
        _imageStates[_images.length - 1] = _ImageState.idle;
      });
    }
  }

  Future<dio_pkg.Options> _getSecureOptions() async { // ✅ Added dio_pkg. prefix
    try { await Supabase.instance.client.auth.refreshSession(); } catch (_) {}
    final session = Supabase.instance.client.auth.currentSession;
    return dio_pkg.Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'}); // ✅ Added dio_pkg. prefix
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
    
    // 🛡️ NEW: CLOUDFLARE AI TEXT MODERATION
    final allTextInputs = [
      _firstNameController.text,
      _lastNameController.text,
      _bioController.text,
      _workController.text
    ].where((t) => t.trim().isNotEmpty).join(" . ");

    if (allTextInputs.isNotEmpty) {
      final isClean = await ComplianceEngine.isTextClean(allTextInputs);
      if (!isClean) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your inputs contain inappropriate language or restricted handles. Please revise them.'),
              backgroundColor: AppTheme.primaryRose,
              duration: Duration(seconds: 4),
            )
          );
        }
        return; // 🚫 Block submission before it hits your backend
      }
    }
    
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final dioClient = dio_pkg.Dio();
      final String apiUrl = dotenv.env['BACKEND_URL'] ?? 'https://backend.duvamobile.workers.dev';

      // 1. Upload images with AI moderation checking states
      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        setState(() => _imageStates[i] = _ImageState.checking);
        try {
          final url = await ImageService.compressAndUploadImage(_images[i], user.id, i);
          if (url != null) {
            imageUrls.add(url);
            setState(() => _imageStates[i] = _ImageState.idle);
          } else {
            throw Exception('Upload returned no URL');
          }
        } catch (e) {
          setState(() => _imageStates[i] = _ImageState.rejected);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image rejected by safety filters. Please upload a different photo.'),
                backgroundColor: AppTheme.primaryRose,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // 2. RESTORED: Geolocation Logic
      String city = "Unknown Location";
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          LocationPermission p = await Geolocator.checkPermission();
          if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
          if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
            Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
            List<Placemark> marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
            if (marks.isNotEmpty) city = "${marks.first.locality}, ${marks.first.country}";
          }
        }
      } catch (_) {}

      // 3. Resolve master data names
      final String? selectedGenderName = _selectedGenderId != null 
          ? _masterGenders.firstWhere((g) => g['id'] == _selectedGenderId, orElse: () => {'name': null})['name'] 
          : null;
      final String? selectedExpectationName = _selectedExpectationId != null 
          ? _masterExpectations.firstWhere((e) => e['id'] == _selectedExpectationId, orElse: () => {'name': null})['name'] 
          : null;

      // 4. Send profile to Gatekeeper
      final options = await _getSecureOptions();
      final response = await dioClient.post(
        '$apiUrl/profile',
        data: {
          'firstName': _firstNameController.text.trim(), 
          'lastName': _lastNameController.text.trim(),
          'bio': _bioController.text.trim(),
          'dob': "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
          'gender': selectedGenderName,
          'lookingFor': null, // Update this if you add a lookingFor controller
          'images': imageUrls,
          'expectations': selectedExpectationName,
        },
        options: options,
      );

      if (response.statusCode != 200) throw Exception('Server rejected profile data');

      // 5. Save interests
      final uniqueInterests = _selectedInterestIds.toSet().toList();
      await Supabase.instance.client.from('profile_interests').delete().eq('profile_id', user.id);
      if (uniqueInterests.isNotEmpty) {
        await Supabase.instance.client.from('profile_interests').insert(
          uniqueInterests.map((id) => {'profile_id': user.id, 'interest_id': id}).toList()
        );
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSinglePicker(String title, List<String> options, String? currentValue, Function(String) onSelect) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.only(top: 24, bottom: 40),
              decoration: BoxDecoration(color: AppTheme.surfaceGlass.withValues(alpha: 0.9)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: options.map((option) {
                        final isSelected = option == currentValue;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                          title: Text(option, style: TextStyle(color: isSelected ? AppTheme.electricCyan : Colors.white, fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.electricCyan) : null,
                          onTap: () { 
                            onSelect(option); 
                            Navigator.pop(context); 
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRose)));
    }

    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: _currentPage > 0 ? IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)) : null,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(8, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4), height: 6, width: _currentPage == index ? 24 : 8,
            decoration: BoxDecoration(
              gradient: _currentPage == index ? const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]) : null,
              color: _currentPage == index ? null : AppTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(4),
              boxShadow: _currentPage == index ? [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.5), blurRadius: 6)] : null,
            ),
          )),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: PageView(
        controller: _pageController, physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) => setState(() => _currentPage = page),
        children: [
          _buildNameStep(), _buildDobStep(), _buildGenderStep(), _buildInterestsStep(),
          _buildDetailsStep(), _buildLifestyleStep(), _buildExpectationsStep(), _buildPhotosStep(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nextPage, backgroundColor: AppTheme.primaryRose, elevation: 10,
        label: Text(_currentPage == 7 ? 'LET\'S GO' : 'NEXT', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)),
        icon: Icon(_currentPage == 7 ? Icons.rocket_launch : Icons.arrow_forward_ios, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds), 
              child: Image.asset('assets/logo_nobg.png', height: 80),
            ),
          ),
          const SizedBox(height: 48),
          TextField(controller: _firstNameController, maxLength: 30, decoration: const InputDecoration(labelText: 'First Name')),
          const SizedBox(height: 24),
          TextField(controller: _lastNameController, maxLength: 30, decoration: const InputDecoration(labelText: 'Last Name (Optional)')),
        ],
      ),
    );
  }

  Widget _buildDobStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]).createShader(bounds), 
            child: const Text('When is your birthday?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2))
          ),
          const SizedBox(height: 16),
          const Text('You must be at least 18 years old to use Duva.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 48),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), firstDate: DateTime(1900), lastDate: DateTime.now());
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.electricCyan, width: 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.toLocal()}'.split(' ')[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Icon(Icons.calendar_today, color: AppTheme.electricCyan),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds), 
            child: const Text('I identify as...', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white))
          ),
          const SizedBox(height: 48),
          ..._masterGenders.map((gender) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedGenderId = gender['id'];
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedGenderId == gender['id'] ? AppTheme.primaryRose.withValues(alpha: 0.1) : AppTheme.surfaceGlass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedGenderId == gender['id'] ? AppTheme.primaryRose : Colors.transparent, width: 2),
                ),
                child: Text(gender['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _selectedGenderId == gender['id'] ? AppTheme.primaryRose : Colors.white)),
              ),
            ),
          )), // Removed the .toList() here
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]).createShader(bounds), 
            child: const Text('What are you into?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1))
          ),
          const SizedBox(height: 16),
          const Text('Pick up to 5 interests to help us find better alignments.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
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
                      duration: AppConstants.imageTransitionDuration, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(color: isSelected ? AppTheme.electricCyan : AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(20)),
                      child: Text(interest['name'], style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds), 
            child: const Text('The Details', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white))
          ),
          const SizedBox(height: 48),
          const Text('EDUCATION', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(hintText: 'Select Education'), 
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.electricCyan),
            initialValue: _selectedEducationId, // FIX: Changed 'value' to 'initialValue'
            items: _masterEducation.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedEducationId = val;
              });
            },
          ),
          const SizedBox(height: 32),
          const Text('WORK', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(controller: _workController, maxLength: 50, decoration: const InputDecoration(hintText: 'Job Title / Company')),
          const SizedBox(height: 32),
          const Text('BIO', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(controller: _bioController, maxLines: 4, maxLength: 300, decoration: const InputDecoration(hintText: 'A little bit about me...')),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildLifestyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]).createShader(bounds), 
            child: const Text('Lifestyle', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white))
          ),
          const SizedBox(height: 16),
          const Text('Help others know your vibe.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(child: _buildSelector('Height', _selectedHeight ?? 'Select', () => _showSinglePicker('Height', _heightOptions, _selectedHeight, (val) => setState(() => _selectedHeight = val)))),
              const SizedBox(width: 16),
              Expanded(child: TextField(controller: _weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'))),
            ],
          ),
          const SizedBox(height: 16),
          _buildSelector('Workout', _selectedWorkout ?? 'Select', () => _showSinglePicker('Workout', _workoutOptions, _selectedWorkout, (val) => setState(() => _selectedWorkout = val))),
          const SizedBox(height: 16),
          _buildSelector('Smoking', _selectedSmoking ?? 'Select', () => _showSinglePicker('Smoking', _smokingOptions, _selectedSmoking, (val) => setState(() => _selectedSmoking = val))),
          const SizedBox(height: 16),
          _buildSelector('Drinking', _selectedDrinking ?? 'Select', () => _showSinglePicker('Drinking', _drinkingOptions, _selectedDrinking, (val) => setState(() => _selectedDrinking = val))),
          const SizedBox(height: 16),
          _buildSelector('Pets', _selectedPets ?? 'Select', () => _showSinglePicker('Pets', _petsOptions, _selectedPets, (val) => setState(() => _selectedPets = val))),
          const SizedBox(height: 16),
          _buildSelector('Zodiac', _selectedZodiac ?? 'Select', () => _showSinglePicker('Zodiac', _zodiacOptions, _selectedZodiac, (val) => setState(() => _selectedZodiac = val))),
          const SizedBox(height: 16),
          _buildSelector('Kids', _selectedKids ?? 'Select', () => _showSinglePicker('Kids', _kidsOptions, _selectedKids, (val) => setState(() => _selectedKids = val))),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSelector(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppTheme.electricCyan),
          ],
        ),
      ),
    );
  }

  Widget _buildExpectationsStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds), 
            child: const Text('I\'m looking for...', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2))
          ),
          const SizedBox(height: 48),
          ..._masterExpectations.map((exp) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedExpectationId = exp['id'];
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedExpectationId == exp['id'] ? AppTheme.electricCyan.withValues(alpha: 0.1) : AppTheme.surfaceGlass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedExpectationId == exp['id'] ? AppTheme.electricCyan : Colors.transparent, width: 2),
                ),
                child: Text(exp['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _selectedExpectationId == exp['id'] ? AppTheme.electricCyan : Colors.white)),
              ),
            ),
          )), // Removed the .toList() here
        ],
      ),
    );
  }

  Widget _buildPhotosStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]).createShader(bounds), 
            child: const Text('Show your face', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1))
          ),
          const SizedBox(height: 16),
          const Text('Upload up to 6 photos. The first one will be your main profile picture.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
              itemCount: 6,
              itemBuilder: (context, index) {
                if (index < _images.length) {
                  final state = _imageStates[index] ?? _ImageState.idle;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_images[index], fit: BoxFit.cover)),
                      if (state == _ImageState.checking)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black54,
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.electricCyan, strokeWidth: 2)),
                              SizedBox(height: 8),
                              Text('AI Checking...', style: TextStyle(color: AppTheme.electricCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      if (state == _ImageState.rejected)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black54,
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.block, color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text('NSFW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      if (state == _ImageState.idle)
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _images.removeAt(index);
                                _imageStates.remove(index);
                              });
                            },
                            child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                          ),
                        ),
                    ],
                  );
                } else {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.3), width: 2, style: BorderStyle.solid)),
                      child: const Center(child: Icon(Icons.add, color: AppTheme.electricCyan, size: 32)),
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