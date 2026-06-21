import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  final dio = Dio();
  final String apiUrl = 'https://backend.duvamobile.workers.dev';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});

      final response = await dio.get('$apiUrl/notifications', options: options);
      
      if (mounted) {
        setState(() {
          _notifications = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Notifications fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'like':
        return const Icon(Icons.favorite, color: Colors.redAccent);
      case 'match':
        return const Icon(Icons.auto_awesome, color: Colors.purple);
      case 'system':
      default:
        return const Icon(Icons.info, color: Colors.blueAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final note = _notifications[index];
                    final bool isRead = note['is_read'] ?? false;

                    return Container(
                      color: isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          radius: 24,
                          child: _getIconForType(note['type']),
                        ),
                        title: Text(
                          note['title'], 
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 16)
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(note['message'], style: const TextStyle(color: Colors.black87)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('All Caught Up', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('You have no new notifications right now.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}