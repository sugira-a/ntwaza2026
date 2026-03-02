import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/ai_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final AiAssistantService _aiService = AiAssistantService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_AiMessage> _messages = [];
  bool _isSending = false;
  bool _showChips = true;

  late AnimationController _dotController;

  static const _accent = Color(0xFF1B5E20);
  static const _accentLight = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  Map<String, dynamic> _buildAppContext() {
    try {
      final cartProvider = context.read<CartProvider>();
      final vendorProvider = context.read<VendorProvider>();
      return _aiService.buildContext(
        cartProvider: cartProvider,
        vendorProvider: vendorProvider,
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    if (preset == null) _controller.clear();
    setState(() {
      _messages.add(_AiMessage(text: text, isUser: true));
      _isSending = true;
      _showChips = false;
    });
    _scrollToBottom();

    try {
      final appContext = _buildAppContext();
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .toList()
          .reversed
          .take(8)
          .toList()
          .reversed
          .map((m) => {'text': m.text, 'isUser': m.isUser})
          .toList();

      final reply = await _aiService.sendMessage(
        message: text,
        context: appContext,
        history: history,
      );
      if (!mounted) return;
      setState(() => _messages.add(_AiMessage(text: reply, isUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_AiMessage(
        text: 'Something went wrong. Tap to retry or call +250 790 153 255.',
        isUser: false,
        isError: true,
      )));
    } finally {
      if (!mounted) return;
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final surface = isDark ? const Color(0xFF161616) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final divider = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accentLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ntwaza AI',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _isSending ? Colors.orange : _accentLight,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isSending ? 'Thinking...' : 'Online',
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_messages.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 22),
                      tooltip: 'New chat',
                      onPressed: () => setState(() {
                        _messages.clear();
                        _showChips = true;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(isDark, surface, textPrimary, textSecondary, divider, screenWidth)
                : _buildChat(isDark, surface, textPrimary, textSecondary, divider, screenWidth),
          ),
          _buildInputBar(isDark, surface, textPrimary, textSecondary, divider),
        ],
      ),
    );
  }

  // ─── Welcome screen ───
  Widget _buildWelcome(bool isDark, Color surface, Color textPrimary,
      Color textSecondary, Color divider, double screenWidth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          // Hero icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, _accentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Hi! I\'m your Ntwaza AI',
            style: TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your personal shopping assistant',
            style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 28),

          // Suggestion cards
          _suggestionCard(
            icon: Icons.shopping_cart_rounded,
            title: 'Build me a cart',
            subtitle: 'Get product suggestions for any budget',
            isDark: isDark,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _suggestionCard(
            icon: Icons.inventory_2_rounded,
            title: 'What\'s in my cart?',
            subtitle: 'View your current cart summary',
            isDark: isDark,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _suggestionCard(
            icon: Icons.storefront_rounded,
            title: 'Show open stores',
            subtitle: 'Find available vendors near you',
            isDark: isDark,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _suggestionCard(
            icon: Icons.receipt_long_rounded,
            title: 'My recent orders',
            subtitle: 'Check status of your orders',
            isDark: isDark,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _suggestionCard(
            icon: Icons.support_agent_rounded,
            title: 'Contact support',
            subtitle: 'Get help from the Ntwaza team',
            isDark: isDark,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(title),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accentLight, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Chat view ───
  Widget _buildChat(bool isDark, Color surface, Color textPrimary,
      Color textSecondary, Color divider, double screenWidth) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isSending ? 1 : 0) + (_showChips ? 1 : 0),
      itemBuilder: (ctx, index) {
        // Inline chips row
        if (_showChips && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickChip('Budget cart', Icons.shopping_cart_outlined, isDark),
                  _quickChip('My cart', Icons.list_alt_rounded, isDark),
                  _quickChip('Open stores', Icons.storefront_rounded, isDark),
                  _quickChip('Support', Icons.support_agent_rounded, isDark),
                  _quickChip('Orders', Icons.receipt_long_rounded, isDark),
                ],
              ),
            ),
          );
        }

        final msgIndex = _showChips ? index - 1 : index;

        // Typing indicator
        if (_isSending && msgIndex == _messages.length) {
          return _buildTypingBubble(isDark, surface, textSecondary);
        }

        if (msgIndex < 0 || msgIndex >= _messages.length) return const SizedBox.shrink();
        final msg = _messages[msgIndex];
        return _buildMessageBubble(msg, isDark, surface, textPrimary, textSecondary, screenWidth);
      },
    );
  }

  Widget _quickChip(String label, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _sendMessage(label),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _accent.withOpacity(isDark ? 0.15 : 0.06),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: _accentLight),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accentLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark, Color surface, Color textSecondary) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _aiAvatar(small: true),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _dotController,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i * 0.2;
                      final t = (_dotController.value - delay) % 1.0;
                      final y = sin(t * pi) * 4;
                      return Transform.translate(
                        offset: Offset(0, -y.abs()),
                        child: Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _accentLight.withOpacity(0.6 + 0.4 * (y.abs() / 4)),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_AiMessage msg, bool isDark, Color surface,
      Color textPrimary, Color textSecondary, double screenWidth) {
    final isUser = msg.isUser;
    final time = DateFormat('h:mm a').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _aiAvatar(small: true),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          backgroundColor: _accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    onTap: msg.isError ? () => _retryLast() : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [_accent, Color(0xFF2E7D32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser
                            ? null
                            : msg.isError
                                ? (isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF3F3))
                                : surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? _accent.withOpacity(0.2)
                                : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.isError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 14, color: Colors.red[300]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to retry',
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SelectableText(
                            msg.text,
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : msg.isError
                                      ? (isDark ? Colors.red[200] : Colors.red[700])
                                      : textPrimary,
                              fontSize: 14.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(
                      time,
                      style: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _retryLast() {
    // Find the last user message & retry
    String? lastUserMsg;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserMsg = _messages[i].text;
        break;
      }
    }
    if (lastUserMsg != null) {
      // Remove the error message
      if (_messages.isNotEmpty && _messages.last.isError) {
        setState(() => _messages.removeLast());
      }
      // Remove the last user message too (sendMessage will re-add it)
      if (_messages.isNotEmpty && _messages.last.isUser) {
        setState(() => _messages.removeLast());
      }
      _sendMessage(lastUserMsg);
    }
  }

  Widget _aiAvatar({bool small = false}) {
    final size = small ? 26.0 : 34.0;
    final iconSize = small ? 14.0 : 18.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, _accentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: iconSize),
    );
  }

  // ─── Input bar ───
  Widget _buildInputBar(bool isDark, Color surface, Color textPrimary,
      Color textSecondary, Color divider) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12, 10, 12, 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(color: textPrimary, fontSize: 14.5),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask me anything about Ntwaza...',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSending ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(23),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  _AiMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  }) : timestamp = DateTime.now();
}