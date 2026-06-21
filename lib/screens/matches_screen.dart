import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart'; // This is the crucial import to make onTap work

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _isLoading = true;
  List<dynamic> _matches = [];
  
  // Your deployed Cloudflare Worker URL
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
      final options = Options(headers: {
        'Authorization': 'Bearer ${session?.accessToken}',
      });

      // Hit the Cloudflare Edge API
      final response = await dio.get('$apiUrl/matches', options: options);
      
      if (mounted) {
        setState(() {
          _matches = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching matches: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Matches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.shield, color: Colors.grey), onPressed: () {}), // Safety toolkit icon
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _matches.isEmpty 
          ? _buildEmptyState()
          : _buildInbox(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volunteer_activism, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No Alignments Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Keep exploring the pool to find your match.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HORIZONTAL NEW MATCHES BUBBLES ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text('New Alignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final String imageUrl = (match['images'] != null && match['images'].isNotEmpty) 
                  ? match['images'][0] 
                  : 'https://via.placeholder.com/150';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2), // Match notification ring
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: NetworkImage(imageUrl),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Checking both cases just in case Hono returns different casing
                    Text(match['firstName'] ?? match['first_name'] ?? 'Match', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(height: 1),

        // --- VERTICAL MESSAGES LIST ---
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              final String imageUrl = (match['images'] != null && match['images'].isNotEmpty) 
                  ? match['images'][0] 
                  : 'https://via.placeholder.com/150';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(imageUrl),
                ),
                title: Text(match['firstName'] ?? match['first_name'] ?? 'Match', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Matched recently! Say hi.', style: TextStyle(color: Colors.grey)),
                onTap: () {
                  // THIS OPENS THE CHAT SCREEN
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