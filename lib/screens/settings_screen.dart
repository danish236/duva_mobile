import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

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
      
      // Hit the Cloudflare Edge API to wipe data
      await dio.delete('$apiUrl/account', options: options);
      
      // Sign out to clear local session
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _buildSectionHeader('Account'),
              _buildListTile(Icons.email_outlined, 'Email Address', trailing: Supabase.instance.client.auth.currentUser?.email ?? 'Unknown'),
              _buildListTile(Icons.security, 'Privacy & Security', onTap: () {}),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Data'),
              _buildListTile(Icons.download_outlined, 'Request Data Export', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data export request sent to your email.')));
              }),
              
              const SizedBox(height: 24),
              _buildSectionHeader('Actions'),
              _buildListTile(Icons.logout, 'Sign Out', textColor: Colors.black87, onTap: _signOut),
              _buildListTile(Icons.delete_forever, 'Delete Account', textColor: Colors.red, onTap: _deleteAccount),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildListTile(IconData icon, String title, {String? trailing, Color textColor = Colors.black87, VoidCallback? onTap}) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        trailing: trailing != null ? Text(trailing, style: const TextStyle(color: Colors.grey, fontSize: 14)) : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}