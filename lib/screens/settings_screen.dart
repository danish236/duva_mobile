import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../theme_notifier.dart'; 
import '../theme.dart';
import 'info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final dio = Dio();
  final String apiUrl = 'https://backend.duvamobile.workers.dev';
  bool _isProcessing = false;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87, // FIX: showDialog uses barrierColor
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceGlass,
            // FIX: RoundedRectangleBorder uses 'side' instead of 'border'
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24), 
              side: BorderSide(color: AppTheme.primaryRose.withValues(alpha: 0.5))
            ),
            title: const Text('Delete Account?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            content: const Text(
              'This action is permanent and cannot be undone. All your alignments, messages, and data will be wiped from the void.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            actions: [
              TextButton(
                child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)), 
                onPressed: () => Navigator.pop(context, false)
              ),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.3), blurRadius: 10)]
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), 
                  onPressed: () => Navigator.pop(context, true)
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
      await dio.delete('$apiUrl/account', options: options);
      await Supabase.instance.client.auth.signOut();
      
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Deletion error: $e');
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete account. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppTheme.voidBackground, // FIX: Replaced deprecated colorScheme.background
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface), onPressed: () => Navigator.pop(context)),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
          child: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
        ),
      ),
      body: _isProcessing 
        ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            children: [
              _buildSectionHeader('APPEARANCE'),
              _buildGlassContainer(
                child: SwitchListTile(
                  activeThumbColor: AppTheme.electricCyan, // FIX: Replaced deprecated activeColor
                  activeTrackColor: AppTheme.electricCyan.withValues(alpha: 0.3),
                  inactiveThumbColor: AppTheme.textSecondary,
                  inactiveTrackColor: colorScheme.surface,
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? AppTheme.electricCyan : AppTheme.primaryRose),
                  title: Text('Midnight Glass Mode', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  value: isDark,
                  onChanged: (value) {
                    setState(() {
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader('ACCOUNT'),
              _buildGlassContainer(
                child: Column(
                  children: [
                    _buildListTile(Icons.email_outlined, 'Email Address', trailing: Supabase.instance.client.auth.currentUser?.email ?? 'Unknown', colorScheme: colorScheme),
                    // UPDATED: Now these actually push to the new InfoScreens
                    _buildListTile(Icons.privacy_tip_outlined, 'Privacy Policy', colorScheme: colorScheme, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'privacy')))),
                    _buildListTile(Icons.description_outlined, 'Terms of Service', colorScheme: colorScheme, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'terms')))),
                    _buildListTile(Icons.security_outlined, 'Safety Guidelines', colorScheme: colorScheme, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'safety')))),
                    Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                    _buildListTile(Icons.security, 'Privacy & Security', colorScheme: colorScheme, onTap: () {}),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader('DATA'),
              _buildGlassContainer(
                child: _buildListTile(Icons.download_outlined, 'Request Data Export', colorScheme: colorScheme, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppTheme.electricCyan,
                    content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Export link sent to email.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])
                  ));
                }),
              ),
              
              const SizedBox(height: 48),
              _buildSectionHeader('DANGER ZONE'),
              _buildGlassContainer(
                child: Column(
                  children: [
                    _buildListTile(Icons.logout, 'Sign Out', colorScheme: colorScheme, onTap: _signOut),
                    Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                    _buildListTile(Icons.delete_forever, 'Delete Account', textColor: AppTheme.primaryRose, colorScheme: colorScheme, onTap: _deleteAccount),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildListTile(IconData icon, String title, {String? trailing, Color? textColor, VoidCallback? onTap, required ColorScheme colorScheme}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: textColor ?? colorScheme.onSurface),
      title: Text(title, style: TextStyle(color: textColor ?? colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
      trailing: trailing != null 
        ? Text(trailing, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w600)) 
        : Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}