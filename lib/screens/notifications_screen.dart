import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';

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
    // Simulating backend fetch with dummy data for UI testing until backend is ready
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (mounted) {
      setState(() {
        _notifications = [
          {
            'id': '1', 'type': 'new_admirer', 'is_read': false,
            'title': 'Someone has their eye on you.', 'body': 'Tap to reveal your secret admirer.',
            'image': 'https://via.placeholder.com/150', 'time': '2m ago'
          },
          {
            'id': '2', 'type': 'new_match', 'is_read': false,
            'title': 'Alignment Secured!', 'body': 'You and Sarah just matched. Say hi!',
            'image': 'https://via.placeholder.com/150', 'time': '1h ago'
          },
          {
            'id': '3', 'type': 'system', 'is_read': true,
            'title': 'Welcome to the Void', 'body': 'Your profile is live. Start swiping!',
            'image': null, 'time': '1d ago'
          }
        ];
        _isLoading = false;
      });
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
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
              itemBuilder: (context, index) => _buildNotificationTile(_notifications[index]),
            ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final bool isUnread = !notif['is_read'];
    final bool isAdmirer = notif['type'] == 'new_admirer';
    final bool isSystem = notif['type'] == 'system';

    return InkWell(
      onTap: () {
        setState(() => notif['is_read'] = true);
        if (isAdmirer) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock Premium to see admirers!')));
        }
      },
      child: Container(
        color: isUnread ? AppTheme.electricCyan.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // The Image or Icon Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceGlass, border: Border.all(color: Colors.white12)),
              clipBehavior: Clip.antiAlias,
              child: isSystem 
                ? const Icon(Icons.info_outline, color: AppTheme.electricCyan)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(notif['image'], fit: BoxFit.cover),
                      if (isAdmirer) // Heavy blur for admirers
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(color: AppTheme.voidBackground.withValues(alpha: 0.2)),
                        ),
                    ],
                  ),
            ),
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['title'], style: TextStyle(color: Colors.white, fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(notif['body'], style: TextStyle(color: AppTheme.textSecondary, fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(notif['time'], style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                ],
              ),
            ),

            // Unread Glowing Dot
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