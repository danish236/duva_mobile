import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';

import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String matchImage;

  const ChatScreen({super.key, required this.matchId, required this.matchName, required this.matchImage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Dio dio = Dio();
  final String apiUrl = 'https://backend.duvamobile.workers.dev';
  
  List<dynamic> _messages = [];
  Timer? _pollingTimer;
  String? _myUserId;
  
  // ADDED: Loading state for the shimmer
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _fetchMessages(isPolling: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<Options> _getSecureOptions() async {
    final session = Supabase.instance.client.auth.currentSession;
    return Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
  }

  Future<void> _fetchMessages({bool isPolling = false}) async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/messages/${widget.matchId}', options: options);
      if (mounted) {
        setState(() {
          _messages = response.data;
          _isLoading = false; // Turn off shimmer when data arrives
        });
        if (!isPolling && _messages.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) { 
      debugPrint("Polling error: $e"); 
      if (mounted) setState(() => _isLoading = false); // Failsafe
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    
    setState(() {
      _messages.add({'sender_id': _myUserId, 'content': text, 'created_at': DateTime.now().toIso8601String()});
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    try {
      final options = await _getSecureOptions();
      await dio.post('$apiUrl/messages/${widget.matchId}', data: {'content': text}, options: options);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceGlass,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(widget.matchImage), radius: 18),
            const SizedBox(width: 12),
            Text(widget.matchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
      ),
      body: _isLoading
          // --- THE 2026 CHAT SKELETON LOADER ---
          ? PremiumShimmer(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (context, index) {
                  // Alternate left/right alignment for ghost messages
                  final isMe = index % 2 == 0;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ShimmerBox(
                        width: 150 + (index * 20.0 % 50), // Randomize bubble widths slightly
                        height: 50,
                        borderRadius: 20,
                      ),
                    ),
                  );
                },
              ),
            )
          // --- ACTUAL CHAT UI ---
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _myUserId;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280), 
                          margin: const EdgeInsets.only(bottom: 8), 
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.primaryRose : AppTheme.surfaceGlass,
                            border: isMe ? null : Border.all(color: Colors.white12),
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                              bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(20),
                            ),
                            boxShadow: isMe ? [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                        ),
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppTheme.voidBackground, // Deep contrast for input box
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.electricCyan.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: CircleAvatar(
                backgroundColor: AppTheme.electricCyan,
                radius: 26,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}