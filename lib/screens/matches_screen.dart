import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart'; 
import 'notifications_screen.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _isLoading = true;
  List<dynamic> _matches = [];
  final String apiUrl = 'https://backend.duvamobile.workers.dev';
  final dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
      final response = await dio.get('$apiUrl/matches', options: options);
      
      if (mounted) {
        setState(() {
          _matches = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching matches: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
              child: Image.asset('assets/logo_nobg.png', height: 28, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('MATCHES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: colorScheme.onSurface),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
          ),
        ],
      ),
      body: _isLoading 
        // --- THE NEW 2026 INBOX SKELETON LOADER ---
        ? PremiumShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: ShimmerBox(width: 120, height: 20, borderRadius: 8), // "New Alignments" text
                ),
                // Horizontal avatar circles
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 5, // Show 5 ghost circles
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          ShimmerBox(width: 70, height: 70, borderRadius: 35),
                          SizedBox(height: 8),
                          ShimmerBox(width: 50, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: ShimmerBox(width: 100, height: 20, borderRadius: 8), // "Messages" text
                ),
                // Vertical message lists
                Expanded(
                  child: ListView.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          const ShimmerBox(width: 56, height: 56, borderRadius: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                ShimmerBox(width: 150, height: 16, borderRadius: 6),
                                SizedBox(height: 8),
                                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        // ------------------------------------------
        : _matches.isEmpty 
          ? _buildEmptyState(colorScheme)
          : _buildInbox(colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volunteer_activism, size: 80, color: colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No Alignments Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Keep exploring the pool to find your match.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildInbox(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text('New Alignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryRose)), 
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final String imageUrl = (match['images'] != null && match['images'].isNotEmpty) ? match['images'][0] : 'https://via.placeholder.com/150';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryRose, width: 2), 
                      ),
                      child: CircleAvatar(radius: 35, backgroundImage: NetworkImage(imageUrl)),
                    ),
                    const SizedBox(height: 6),
                    Text(match['firstName'] ?? match['first_name'] ?? 'Match', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  ],
                ),
              );
            },
          ),
        ),

        Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final String imageUrl = (match['images'] != null && match['images'].isNotEmpty) ? match['images'][0] : 'https://via.placeholder.com/150';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(radius: 28, backgroundImage: NetworkImage(imageUrl)),
                title: Text(match['firstName'] ?? match['first_name'] ?? 'Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                subtitle: Text('Matched recently! Say hi.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        matchId: match['id'],
                        matchName: match['firstName'] ?? match['first_name'] ?? 'Match',
                        matchImage: imageUrl,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}