import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../main.dart'; // Required to access the themeNotifier
import '../theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    // 1. Show Warning Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text('This action is permanent and cannot be undone. All your matches, messages, and photos will be wiped.'),
          actions: [
            TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context, false)),
            TextButton(child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)),
          ],
        );
      },
    );

    if (confirm != true) return;

    // 2. Execute Deletion
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

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _buildSectionHeader('Appearance', colorScheme),
              SwitchListTile(
                secondary: Icon(Icons.dark_mode_outlined, color: colorScheme.onSurface),
                title: Text('Dark Mode', style: TextStyle(color: colorScheme.onSurface)),
                value: themeNotifier.value == ThemeMode.dark,
                onChanged: (value) {
                  setState(() {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Account', colorScheme),
              _buildListTile(Icons.email_outlined, 'Email Address', colorScheme, trailing: Supabase.instance.client.auth.currentUser?.email ?? 'Unknown'),
              _buildListTile(Icons.security, 'Privacy & Security', colorScheme, onTap: () {}),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Data', colorScheme),
              _buildListTile(Icons.download_outlined, 'Request Data Export', colorScheme, onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data export request sent to your email.')));
              }),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Actions', colorScheme),
              _buildListTile(Icons.logout, 'Sign Out', colorScheme, textColor: colorScheme.onSurface, onTap: _signOut),
              _buildListTile(Icons.delete_forever, 'Delete Account', colorScheme, textColor: Colors.red, onTap: _deleteAccount),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildListTile(IconData icon, String title, ColorScheme colorScheme, {String? trailing, Color? textColor, VoidCallback? onTap}) {
    return Container(
      color: colorScheme.surface,
      child: ListTile(
        leading: Icon(icon, color: textColor ?? colorScheme.onSurface),
        title: Text(title, style: TextStyle(color: textColor ?? colorScheme.onSurface, fontWeight: FontWeight.w500)),
        trailing: trailing != null 
          ? Text(trailing, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)) 
          : Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.6)),
        onTap: onTap,
      ),
    );
  }
}