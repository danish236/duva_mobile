import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final dio = Dio();
  final String apiUrl = 'https://backend.duvamobile.workers.dev';

  bool _isLoading = true;
  bool _isSaving = false;

  RangeValues _ageRange = const RangeValues(18, 40);
  double _distance = 50.0;
  String? _selectedGender;
  String _selectedExpectation = 'Any';
  List<int> _selectedInterestIds = [];

  List<Map<String, dynamic>> _masterInterests = [];
  List<Map<String, dynamic>> _masterGenders = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final supabase = Supabase.instance.client;
      final interests = await supabase.from('master_interests').select();
      final genders = await supabase.from('master_genders').select();
      
      if (mounted) {
        setState(() {
          _masterInterests = List<Map<String, dynamic>>.from(interests);
          _masterGenders = List<Map<String, dynamic>>.from(genders);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Options> _getSecureOptions() async {
    final session = Supabase.instance.client.auth.currentSession;
    return Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final options = await _getSecureOptions();
      await dio.post(
        '$apiUrl/preferences', 
        data: {
          'min_age': _ageRange.start.round(), 
          'max_age': _ageRange.end.round(), 
          'max_distance': _distance.round(), 
          'filter_expectation': _selectedExpectation,
          'filter_gender': _selectedGender,
          'filter_interests': _selectedInterestIds,
        }, 
        options: options
      );
      if (mounted) Navigator.pop(context, true); // Returns true to trigger refresh
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save settings.')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('DISCOVERY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRose))
        : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildHeader('AGE RANGE'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_ageRange.start.round()} - ${_ageRange.end.round()} years', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primaryRose,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                        overlayColor: AppTheme.primaryRose.withValues(alpha: 0.2),
                      ),
                      child: RangeSlider(
                        values: _ageRange, min: 18, max: 65, divisions: 47,
                        onChanged: (val) => setState(() => _ageRange = val),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildHeader('MAXIMUM DISTANCE'),
                    Text('${_distance.round()} km away', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.electricCyan,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _distance, min: 5, max: 160, divisions: 31,
                        onChanged: (val) => setState(() => _distance = val),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildHeader('SHOW ME'),
                    Wrap(
                      spacing: 12, runSpacing: 12,
                      children: _masterGenders.map((g) {
                        final isSelected = _selectedGender == g['name'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGender = g['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryRose : AppTheme.surfaceGlass,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppTheme.primaryRose : Colors.white12),
                            ),
                            child: Text(g['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    _buildHeader('MUST HAVE INTERESTS (OPTIONAL)'),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _masterInterests.map((interest) {
                        final isSelected = _selectedInterestIds.contains(interest['id']);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) _selectedInterestIds.remove(interest['id']);
                              else _selectedInterestIds.add(interest['id']);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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
                  ],
                ),
              ),
              
              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGlass,
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRose,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('APPLY FILTERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              )
            ],
          ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white.withValues(alpha: 0.4))),
    );
  }
}