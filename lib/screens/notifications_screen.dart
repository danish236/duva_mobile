import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

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
      final response = await dio.get('$apiUrl/notifications', options: Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'}));
      if (mounted) setState(() { _notifications = response.data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Icon _getIconForType(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'like': return const Icon(Icons.favorite, color: AppTheme.hotPink);
      case 'match': return const Icon(Icons.auto_awesome, color: AppTheme.skySurge);
      default: return Icon(Icons.info, color: colorScheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _notifications.isEmpty
              ? _buildEmptyState(colorScheme)
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                  itemBuilder: (context, index) {
                    final note = _notifications[index];
                    final bool isRead = note['is_read'] ?? false;

                    return Container(
                      color: isRead ? colorScheme.surface : colorScheme.primary.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.background,
                          child: _getIconForType(note['type'], colorScheme),
                        ),
                        title: Text(note['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                        subtitle: Text(note['message'], style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('All Caught Up', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('You have no new notifications right now.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}