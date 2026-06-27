import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';
import '../services/cache_service.dart';
import '../constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
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
    
    final data = await CacheService().getOrFetch<List<dynamic>>(
      'notifications',
      () async {
        final response = await dio.get('$apiUrl/notifications', options: options);
        return List<dynamic>.from(response.data);
      },
      ttl: AppConstants.cacheTtlNotifications,
    );
    
    if (mounted) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Backend Fetch Error: $e");
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _markAllAsRead() {
    setState(() {
      for (var notif in _notifications) {
        notif['is_read'] = true;
      }
    });
    // TODO: Send DIO patch request to backend to mark as read
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('NOTIFICATIONS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: Colors.white)),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('MARK READ', style: TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, fontSize: 12)),
            )
        ],
      ),
      body: _isLoading 
        ? _buildShimmer()
        : _notifications.isEmpty 
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppTheme.electricCyan,
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                CacheService().remove('notifications');
                setState(() => _isLoading = true);
                await _fetchNotifications();
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                itemBuilder: (context, index) => _buildNotificationTile(_notifications[index]),
              ),
            ),
    );
  }

  Widget _buildNotificationTile(dynamic notif) {
    final bool isUnread = notif['is_read'] == false;
    
    // FIX: Updated to match the actual strings coming from your index.ts backend
    final bool isAdmirer = notif['type'] == 'like'; 
    final bool isSystem = notif['type'] == 'system';

    return InkWell(
      onTap: () async {
        // 1. Update UI instantly
        if (isUnread) {
          setState(() => notif['is_read'] = true);
          
          // 2. Tell Supabase to mark this SPECIFIC notification as read
          try {
            await Supabase.instance.client
                .from('notifications')
                .update({'is_read': true})
                .eq('id', notif['id']);
          } catch (e) {
            debugPrint("Failed to update read status: $e");
          }
        }

        // 3. Handle Paywall trigger
        if (isAdmirer) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock Premium to see admirers!')));
        }
      },
      child: Container(
        color: isUnread ? AppTheme.electricCyan.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceGlass, border: Border.all(color: Colors.white12)),
              clipBehavior: Clip.antiAlias,
              child: isSystem 
                ? const Icon(Icons.info_outline, color: AppTheme.electricCyan)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Safely handle missing images
                      if (notif['image'] != null) Image.network(notif['image'], fit: BoxFit.cover)
                      else const Icon(Icons.person, color: Colors.white54),
                      
                      // Blur logic now correctly triggers for 'like' types!
                      if (isAdmirer) 
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(color: AppTheme.voidBackground.withValues(alpha: 0.2)),
                        ),
                    ],
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['title'] ?? 'Notification', style: TextStyle(color: Colors.white, fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(notif['message'] ?? '', style: TextStyle(color: AppTheme.textSecondary, fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRose,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.5), blurRadius: 8)],
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          const Text('The Void is Quiet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('No new notifications right now.', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return PremiumShimmer(
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            children: [
              const ShimmerBox(width: 50, height: 50, borderRadius: 25),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 200, height: 16, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerBox(width: 140, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}