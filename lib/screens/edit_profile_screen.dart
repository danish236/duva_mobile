import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'profile_screen.dart';
import '../theme.dart';
import '../services/image_service.dart';
import '../constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfilePhotoState {
  dynamic image; // Can be a URL string or a File
  bool isChecking;
  bool isRejected;
  
  ProfilePhotoState({required this.image, this.isChecking = false, this.isRejected = false});
}

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
  final _weightController = TextEditingController();

  String? _selectedGender;
  String? _selectedExpectation;
  String? _selectedEducation;
  
  // Lifestyle State
  String? _selectedHeight;
  String? _selectedSmoking;
  String? _selectedDrinking;
  String? _selectedWorkout;
  String? _selectedPets;
  String? _selectedZodiac;
  String? _selectedKids;

  List<String> _masterGenders = [];
  List<String> _masterExpectations = [];
  List<String> _masterEducation = [];
  List<Map<String, dynamic>> _masterInterests = [];

  List<ProfilePhotoState> _currentImages = [];
  final List<int> _selectedInterestIds = []; 

  // Static standard lists for lifestyle
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
    _bioController.text = widget.currentProfile.bio ?? '';
    _workController.text = widget.currentProfile.work ?? '';
    _locationController.text = widget.currentProfile.location;
    _dateBidController.text = widget.currentProfile.currentDateBid ?? '';
    _weightController.text = widget.currentProfile.weight ?? '';
    
    _selectedHeight = widget.currentProfile.height;
    _selectedSmoking = widget.currentProfile.smoking;
    _selectedDrinking = widget.currentProfile.drinking;
    _selectedWorkout = widget.currentProfile.workout;
    _selectedPets = widget.currentProfile.pets;
    _selectedZodiac = widget.currentProfile.zodiac;
    _selectedKids = widget.currentProfile.kids;
    
    // Initialize with ProfilePhotoState wrapper
    _currentImages = widget.currentProfile.images
        .map((url) => ProfilePhotoState(image: url))
        .toList();

    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    final client = Supabase.instance.client;
    try {
      final results = await Future.wait([
        client.from('master_genders').select('name').order('id'),
        client.from('master_expectations').select('name').order('id'),
        client.from('master_education').select('name').order('id'),
        client.from('master_interests').select('id, name').order('id'),
      ]);

      if (!mounted) return;

      setState(() {
        _masterGenders = (results[0] as List).map((e) => e['name'] as String).toList();
        _masterExpectations = (results[1] as List).map((e) => e['name'] as String).toList();
        _masterEducation = (results[2] as List).map((e) => e['name'] as String).toList();
        _masterInterests = List<Map<String, dynamic>>.from(results[3]);
        
        if (_masterExpectations.contains(widget.currentProfile.expectations)) {
          _selectedExpectation = widget.currentProfile.expectations;
        }
        if (_masterEducation.contains(widget.currentProfile.education)) {
          _selectedEducation = widget.currentProfile.education;
        }

        for (String interestName in widget.currentProfile.interests) {
          final match = _masterInterests.firstWhere((m) => m['name'] == interestName, orElse: () => {});
          if (match.isNotEmpty) _selectedInterestIds.add(match['id']);
        }

        _isLoadingData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_currentImages.length >= AppConstants.maxProfilePhotos) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maximum ${AppConstants.maxProfilePhotos} photos allowed.')));
      return;
    }
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // 1. Add to UI instantly as "Checking"
      setState(() {
        _currentImages.add(ProfilePhotoState(image: file, isChecking: true));
      });
      HapticFeedback.mediumImpact();

      final index = _currentImages.length - 1;
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      try {
        // 2. Trigger instant upload & AI moderation via ImageService
        final url = await ImageService.compressAndUploadImage(file, userId, index);
        
        // 3. AI Approved it! Swap the File for the new public URL
        if (mounted) {
          setState(() {
            _currentImages[index].isChecking = false;
            if (url != null) _currentImages[index].image = url;
          });
        }
      } catch (e) {
        // 4. AI Rejected it (or network failed)
        if (mounted) {
          setState(() {
            _currentImages[index].isChecking = false;
            _currentImages[index].isRejected = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image rejected by safety filters.'),
            backgroundColor: AppTheme.primaryRose,
          ));
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _currentImages.removeAt(index));
    HapticFeedback.lightImpact();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must have at least one profile photo.')));
      return;
    }

    final isAnyChecking = _currentImages.any((photo) => photo.isChecking);
    if (isAnyChecking) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait for photos to finish checking.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final session = Supabase.instance.client.auth.currentSession;
      
      String? cleanText(String text) => text.trim().isEmpty ? null : text.trim();
      final bioText = cleanText(_bioController.text);

      // 🧠 1. CLOUDFLARE AI TEXT MODERATION
      if (bioText != null) {
        final dio = Dio();
        final String apiUrl = dotenv.env['BACKEND_URL'] ?? 'https://backend.duvamobile.workers.dev';
        
        final modResponse = await dio.post(
          '$apiUrl/moderate-text',
          data: {'text': bioText},
          options: Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'}),
        );

        if (modResponse.data['isClean'] == false) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your bio contains inappropriate language. Please keep it respectful.'),
              backgroundColor: AppTheme.primaryRose,
              duration: Duration(seconds: 4),
            )
          );
          return; // 🚫 BLOCK THE SAVE OPERATION
        }
      }

      // 2. PROCESS IMAGES
      List<String> finalImageUrls = [];
      for (int i = 0; i < _currentImages.length; i++) {
        final photoState = _currentImages[i];
        if (photoState.isRejected) continue; 
        
        final img = photoState.image;
        if (img is String) {
          finalImageUrls.add(img);
        }
      }

      if (finalImageUrls.isEmpty) throw Exception("No valid images to save.");

      // 3. UPDATE SUPABASE DATABASE
      await Supabase.instance.client.from('profiles').update({
        'bio': bioText,
        'work': cleanText(_workController.text),
        'education': _selectedEducation,
        'expectations': _selectedExpectation,
        'location': cleanText(_locationController.text) ?? 'Unknown Location',
        'current_date_bid': cleanText(_dateBidController.text),
        'gender': _selectedGender,
        'images': finalImageUrls, 
        'height': _selectedHeight,
        'weight': cleanText(_weightController.text),
        'smoking': _selectedSmoking,
        'drinking': _selectedDrinking,
        'workout': _selectedWorkout,
        'pets': _selectedPets,
        'zodiac': _selectedZodiac,
        'kids': _selectedKids,
      }).eq('id', userId);

      // 4. UPDATE INTERESTS
      final uniqueInterests = _selectedInterestIds.toSet().toList();
      await Supabase.instance.client.from('profile_interests').delete().eq('profile_id', userId);
      
      if (uniqueInterests.isNotEmpty) {
        List<Map<String, dynamic>> interestInserts = uniqueInterests.map((id) => {
          'profile_id': userId,
          'interest_id': id
        }).toList();
        await Supabase.instance.client.from('profile_interests').insert(interestInserts);
      }

      if (!mounted) return; 
      Navigator.pop(context, true);
      
    } catch (e) {
      debugPrint("Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.only(top: 24, bottom: 40),
            decoration: BoxDecoration(color: AppTheme.surfaceGlass.withValues(alpha: 0.98)), 
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
                        onTap: () { onSelect(option); Navigator.pop(context); },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showInterestsPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
                decoration: BoxDecoration(color: AppTheme.surfaceGlass.withValues(alpha: 0.98)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('YOUR INTERESTS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Select up to 5 interests.', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8))),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10, runSpacing: 10,
                          children: _masterInterests.map((interest) {
                            final isSelected = _selectedInterestIds.contains(interest['id']);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedInterestIds.remove(interest['id']);
                                  } else if (_selectedInterestIds.length < 5) {
                                    _selectedInterestIds.add(interest['id']);
                                  }
                                });
                                setState(() {}); 
                              },
                              child: AnimatedContainer(
                                duration: AppConstants.imageTransitionDuration,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.electricCyan.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? AppTheme.electricCyan : Colors.white12),
                                ),
                                child: Text(interest['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.electricCyan : AppTheme.textSecondary)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRose)));

    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
          child: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2, color: Colors.white)),
        ),
        actions: [
          _isSaving 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.electricCyan, strokeWidth: 2)))
            : TextButton(onPressed: _saveChanges, child: const Text('SAVE', style: TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildSectionLabel('YOUR PHOTOS'),
            const SizedBox(height: 8),
            const Text('Long press and drag to reorder your photos. Your first photo is your main identity.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            
            // THE NEW DRAG & DROP PHOTO GRID
            _buildDragAndDropGrid(),

            const SizedBox(height: 32),

            _buildSectionLabel('YOUR DATE BID'),
            _buildTextField(_dateBidController, 'Active Date Bid', 'e.g., Coffee at 4PM', maxLength: 60),
            const SizedBox(height: 24),
            
            _buildSectionLabel('PERSONAL INFO'),
            _buildSelector('Gender', _selectedGender ?? 'Select', () => _showSinglePicker('Select Gender', _masterGenders, _selectedGender, (val) => setState(() => _selectedGender = val))),
            const SizedBox(height: 16),
            _buildSelector('Expectations', _selectedExpectation ?? 'Select', () => _showSinglePicker('Looking For', _masterExpectations, _selectedExpectation, (val) => setState(() => _selectedExpectation = val))),
            const SizedBox(height: 16),
            _buildSelector('Education', _selectedEducation ?? 'Select', () => _showSinglePicker('Education', _masterEducation, _selectedEducation, (val) => setState(() => _selectedEducation = val))),
            const SizedBox(height: 16),
            _buildTextField(_workController, 'Work', 'Job Title / Company', maxLength: 50),
            const SizedBox(height: 32),

            // LIFESTYLE SECTION
            _buildSectionLabel('LIFESTYLE'),
            Row(
              children: [
                Expanded(child: _buildSelector('Height', _selectedHeight ?? 'Select', () => _showSinglePicker('Height', _heightOptions, _selectedHeight, (val) => setState(() => _selectedHeight = val)))),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_weightController, 'Weight', 'e.g. 70', keyboardType: TextInputType.number, suffixText: 'kg')),
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
            const SizedBox(height: 32),

            _buildSectionLabel('INTERESTS'),
            if (_selectedInterestIds.isNotEmpty)
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _selectedInterestIds.map((id) {
                  final name = _masterInterests.firstWhere((m) => m['id'] == id)['name'];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppTheme.electricCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.electricCyan)),
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.electricCyan)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showInterestsPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, color: AppTheme.textSecondary, size: 18), SizedBox(width: 8), Text('EDIT INTERESTS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w900, letterSpacing: 1.5))]),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionLabel('ABOUT YOU'),
            _buildTextField(_bioController, 'Bio', 'A little bit about me...', maxLines: 4, maxLength: AppConstants.maxBioLength),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDragAndDropGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, 
        crossAxisSpacing: 12, 
        mainAxisSpacing: 12, 
        childAspectRatio: 0.7 
      ),
      itemCount: 6, 
      itemBuilder: (context, index) {
        bool hasImage = index < _currentImages.length;

        if (!hasImage) {
          return index == _currentImages.length 
              ? _buildAddPhotoSlot() 
              : _buildEmptySlot();
        }

        return DragTarget<int>(
          onAcceptWithDetails: (details) {
            final int draggedIndex = details.data;
            if (draggedIndex != index) {
              HapticFeedback.heavyImpact(); 
              setState(() {
                final item = _currentImages.removeAt(draggedIndex);
                _currentImages.insert(index, item);
              });
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;

            return LongPressDraggable<int>(
              data: index,
              onDragStarted: () => HapticFeedback.selectionClick(), 
              feedback: Material(
                color: Colors.transparent,
                child: Transform.scale(
                  scale: 1.1, 
                  child: SizedBox(
                    width: (MediaQuery.of(context).size.width - 40 - 24) / 3, 
                    height: ((MediaQuery.of(context).size.width - 40 - 24) / 3) / 0.7, 
                    child: _buildPhotoItem(index, isHovered: false),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildPhotoItem(index, isHovered: false),
              ),
              child: _buildPhotoItem(index, isHovered: isHovering),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoItem(int index, {required bool isHovered}) {
    final photoState = _currentImages[index];
    final image = photoState.image;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: AppConstants.imageTransitionDuration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isHovered ? Border.all(color: AppTheme.electricCyan, width: 3) : null,
            image: (photoState.isChecking || photoState.isRejected) 
                ? (image is File ? DecorationImage(image: FileImage(image), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken)) : null)
                : DecorationImage(
                    image: image is File ? FileImage(image) as ImageProvider : NetworkImage(image),
                    fit: BoxFit.cover,
                  ),
          ),
        ),

        // 🕒 THE CHECKING STATE (CLOCK UI)
        if (photoState.isChecking)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.electricCyan, strokeWidth: 2)),
                SizedBox(height: 12),
                Text('AI Checking...', style: TextStyle(color: AppTheme.electricCyan, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

        // 🚫 THE REJECTED STATE
        if (photoState.isRejected)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryRose.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text('NSFW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ],
            ),
          ),

        if (index == 0 && !photoState.isChecking && !photoState.isRejected)
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)),
              child: const Text('MAIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
          
        if (!photoState.isChecking)
          Positioned(
            top: -4, right: -4,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
              onPressed: () => _removeImage(index),
            ),
          ),
      ],
    );
  }

  Widget _buildAddPhotoSlot() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.5), width: 1, style: BorderStyle.solid),
        ),
        child: const Center(child: Icon(Icons.add, color: AppTheme.electricCyan, size: 32)),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.4))),
    );
  }

  Widget _buildSelector(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
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

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, int? maxLength, TextInputType? keyboardType, String? suffixText}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      decoration: InputDecoration(
        labelText: label, 
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surfaceGlass,
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        counterStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}