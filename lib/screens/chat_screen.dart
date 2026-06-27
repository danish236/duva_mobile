import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';

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
  final Dio dio = ApiClient().dio;
  final String apiUrl = ApiClient.apiUrl;
  bool _isPremium = false;
  
  // AI Icebreaker States
  List<String> _icebreakers = [];
  bool _isLoadingIcebreakers = false;
  
  List<dynamic> _messages = [];
  Timer? _pollingTimer;
  String? _myUserId;
  bool _isLoading = true;
  int _pollingFailures = 0;

  String get _messageCacheKey => 'chat_messages_${widget.matchId}';

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser?.id;
    _fetchPremiumStatus();
    _tryLoadCachedMessages();
    _fetchMessages();
    _schedulePolling();
  }

  void _schedulePolling() {
    _pollingTimer?.cancel();
    const int maxBackoff = 60;
    final interval = Duration(seconds: _pollingFailures > 0
        ? (_pollingFailures * 3).clamp(3, maxBackoff)
        : 3);
    _pollingTimer = Timer.periodic(interval, (timer) => _fetchMessages(isPolling: true));
  }

  void _tryLoadCachedMessages() {
    final cached = CacheService().get(_messageCacheKey);
    if (cached != null) {
      setState(() {
        _messages = List<dynamic>.from(cached);
        _isLoading = false;
      });
    }
  }

  // Moved outside of initState
  Future<void> _fetchIcebreakers() async {
    if (_icebreakers.isNotEmpty || _messages.isNotEmpty) return;

    setState(() => _isLoadingIcebreakers = true);
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/matches/${widget.matchId}/icebreakers', options: options);
      
      if (mounted) {
        setState(() {
          _icebreakers = List<String>.from(response.data);
        });
      }
    } catch (e) {
      debugPrint("Icebreakers failed: $e");
    } finally {
      if (mounted) setState(() => _isLoadingIcebreakers = false);
    }
  }

  Future<void> _fetchPremiumStatus() async {
    if (_myUserId == null) return;
    try {
      final cached = await CacheService().getOrFetch<Map<String, dynamic>>(
        'is_premium',
        () async {
          final profile = await Supabase.instance.client.from('profiles').select('is_premium').eq('id', _myUserId!).single();
          return Map<String, dynamic>.from(profile);
        },
        ttl: AppConstants.cacheTtlPremium,
      );
      if (mounted) setState(() => _isPremium = cached['is_premium'] ?? false);
    } catch (e) {
      debugPrint("Failed to load premium status: $e");
    }
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
      _pollingFailures = 0;
      if (mounted) {
        final messages = List.from(response.data.reversed);
        setState(() {
          _messages = messages;
          if (_messages.isEmpty && _icebreakers.isEmpty && !_isLoadingIcebreakers) {
            _fetchIcebreakers();
          }
          _isLoading = false; 
        });
        CacheService().set(_messageCacheKey, messages, ttl: AppConstants.cacheTtlChatMessages);
        _markMessagesAsRead();
        if (!isPolling && _messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    } catch (e) { 
      _pollingFailures++;
      _schedulePolling();
      debugPrint("Polling error: $e"); 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_myUserId == null) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('match_id', widget.matchId)
          .eq('receiver_id', _myUserId!)
          .eq('is_read', false);
      CacheService().remove('unread_messages');
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    
    // Pause polling temporarily
    _pollingTimer?.cancel(); 
    
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
    } finally {
      // Resume polling
      _pollingTimer = Timer.periodic(AppConstants.chatPollingInterval, (timer) => _fetchMessages(isPolling: true));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _sanitizeMessage(String text) {
    return text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
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
          ? PremiumShimmer(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final isMe = index % 2 == 0;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ShimmerBox(
                        width: 150 + (index * 20.0 % 50), 
                        height: 50,
                        borderRadius: 20,
                      ),
                    ),
                  );
                },
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyStateWithIcebreakers()
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true, // Messages array is reversed, ListView displays bottom-up
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
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    Text(_sanitizeMessage(msg['content']), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                    if (isMe && _isPremium) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.done_all, 
                                        size: 16, 
                                        color: msg['is_read'] == true ? AppTheme.electricCyan : Colors.white38
                                      ),
                                    ]
                                  ],
                                ),
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

  // --- THE NEW AI UI ---
  Widget _buildEmptyStateWithIcebreakers() {
    return Center(
      child: SingleChildScrollView( // Prevents overflow if the keyboard pops up
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Start the Alignment', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('No messages yet. Send a message to break the ice.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              
              const SizedBox(height: 40),
              
              if (_isLoadingIcebreakers)
                const Column(
                  children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.electricCyan, strokeWidth: 2)),
                    SizedBox(height: 16),
                    Text('✨ AI generating icebreakers...', style: TextStyle(color: AppTheme.electricCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                )
              else if (_icebreakers.isNotEmpty) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.electricCyan, size: 16),
                    SizedBox(width: 8),
                    Text('AI SUGGESTIONS', style: TextStyle(color: AppTheme.electricCyan, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 16),
                ..._icebreakers.map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _messageController.text = text; // Instantly paste it into the keyboard box!
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.electricCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.3)),
                      ),
                      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ),
                )),
              ]
            ],
          ),
        ),
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
                  fillColor: AppTheme.voidBackground, 
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
                child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 20), onPressed: _sendMessage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}