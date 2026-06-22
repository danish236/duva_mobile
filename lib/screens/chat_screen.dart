import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

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
        setState(() => _messages = response.data);
        if (!isPolling && _messages.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) { debugPrint("Polling error: $e"); }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add({'sender_id': _myUserId, 'content': text, 'created_at': DateTime.now().toIso8601String()}));
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
    if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(widget.matchImage), radius: 18),
            const SizedBox(width: 12),
            Text(widget.matchName, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
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
                    constraints: const BoxConstraints(maxWidth: 250), 
                    margin: const EdgeInsets.only(bottom: 8), 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primaryRose : colorScheme.surface,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                        bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(20),
                      ),
                    ),
                    child: Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : colorScheme.onSurface, fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: colorScheme.surface),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: colorScheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.electricCyan,
              radius: 24,
              child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
            ),
          ],
        ),
      ),
    );
  }
}