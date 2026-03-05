import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/theme_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/shopping_list_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Ntwaza AI — Professional Smart Shopping Assistant
// "Shop smart. Eat well. Save more."
// ═══════════════════════════════════════════════════════════════════════════

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

  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _showWelcome = true;
  bool _isSmartCartLoading = false;

  late AnimationController _dotController;
  late AnimationController _fadeController;

  // Brand colors
  static const _brand = Color(0xFF1B5E20);
  static const _brandLight = Color(0xFF4CAF50);

  final _fmt = NumberFormat('#,###', 'en');

  // Recent searches cache (expires after 24 hours)
  static const _recentSearchesKey = 'ai_recent_searches';
  static const _maxRecentSearches = 8;
  static const _cacheHours = 24;
  List<String> _recentSearches = [];

  // Chat history
  static const _historyKey = 'ai_chat_history';
  static const _maxHistorySessions = 30;
  List<Map<String, dynamic>> _history = [];

  // ─── Lifecycle ───

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    // Pre-load all products so AI cart integration works
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchAllProducts();
      _checkProactiveNotifications();
    });
    _loadRecentSearches();
    _loadHistory();
  }

  // ─── Proactive notifications ───

  Future<void> _checkProactiveNotifications() async {
    try {
      final notifications = await _aiService.proactiveCheck();
      if (!mounted || notifications.isEmpty) return;

      // Show most important notification as a banner message
      final top = notifications.first;
      setState(() {
        _messages.add(_ChatMessage(
          text: '${top.title}\n${top.body}',
          isUser: false,
        ));
        _showWelcome = false;
      });
      _scrollToBottom();
    } catch (_) {
      // Silent fail — proactive is optional
    }
  }

  @override
  @override
  void dispose() {
    _saveCurrentChat();
    _dotController.dispose();
    _fadeController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Time awareness ───

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning \u2615';
    if (h >= 12 && h < 17) return 'Good afternoon \u2600\uFE0F';
    if (h >= 17 && h < 21) return 'Good evening \uD83C\uDF19';
    return 'Hi there \uD83D\uDC4B';
  }

  String get _timeContext {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 10) return 'What would you like for breakfast?';
    if (h >= 10 && h < 12) return 'Planning lunch already?';
    if (h >= 12 && h < 14) return 'Lunchtime! Need meal ideas?';
    if (h >= 14 && h < 17) return 'Snack time or planning dinner?';
    if (h >= 17 && h < 21) return 'What\'s for dinner tonight?';
    return 'Late night shopping?';
  }

  // ─── Recent searches cache ───

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentSearchesKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(data['ts'] ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt).inHours >= _cacheHours) {
        await prefs.remove(_recentSearchesKey);
        return;
      }
      final items = (data['items'] as List?)?.cast<String>() ?? [];
      if (mounted) setState(() => _recentSearches = items);
    } catch (_) {
      await prefs.remove(_recentSearchesKey);
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    // Skip internal commands and auto-generated messages (emoji prefixes)
    if (query.startsWith('__') || query.length < 3) return;
    // Also skip if first character is a high surrogate (emoji)
    if (query.isNotEmpty && query.codeUnitAt(0) >= 0xD800 && query.codeUnitAt(0) <= 0xDBFF) return;
    try {
      // Avoid duplicates (case-insensitive)
      _recentSearches.removeWhere((s) => s.toLowerCase() == query.toLowerCase());
      _recentSearches.insert(0, query);
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentSearchesKey, jsonEncode({
        'ts': DateTime.now().toIso8601String(),
        'items': _recentSearches,
      }));
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (mounted) setState(() => _recentSearches.clear());
  }

  // ─── Chat history persistence ───

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _history = list);
    } catch (_) {}
  }

  Future<void> _saveCurrentChat() async {
    // Only save if we have real messages
    final textMessages = _messages.where((m) => m.text.trim().isNotEmpty).toList();
    if (textMessages.length < 2) return;

    // Derive title from first user message
    final firstUser = textMessages.firstWhere((m) => m.isUser, orElse: () => textMessages.first);
    String title = firstUser.text.trim();
    if (title.length > 50) title = '${title.substring(0, 47)}...';

    final session = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'ts': DateTime.now().toIso8601String(),
      'messages': textMessages.map((m) => <String, dynamic>{
        'text': m.text,
        'isUser': m.isUser,
        'isError': m.isError,
        'ts': m.timestamp.toIso8601String(),
      }).toList(),
    };

    _history.insert(0, session);
    if (_history.length > _maxHistorySessions) {
      _history = _history.sublist(0, _maxHistorySessions);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
  }

  Future<void> _deleteHistorySession(String id) async {
    _history.removeWhere((s) => s['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
    if (mounted) setState(() {});
  }

  Future<void> _clearAllHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() {});
  }

  void _restoreSession(Map<String, dynamic> session) {
    final msgs = (session['messages'] as List?) ?? [];
    setState(() {
      _messages.clear();
      for (final m in msgs) {
        _messages.add(_ChatMessage(
          text: m['text'] as String? ?? '',
          isUser: m['isUser'] == true,
          isError: m['isError'] == true,
        ));
      }
      _showWelcome = false;
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  // ─── Recent searches UI section for welcome screen ───

  List<Widget> _buildRecentSearches(bool isDark, Color tp, Color ts) {
    if (_recentSearches.isEmpty) return [];
    return [
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: Text('Recent', style: TextStyle(color: ts, fontSize: 12, fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: _clearRecentSearches,
          child: Text('Clear', style: TextStyle(color: ts.withOpacity(0.5), fontSize: 11)),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6, runSpacing: 6,
        alignment: WrapAlignment.start,
        children: _recentSearches.take(6).map((q) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _sendMessage(q),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_rounded, size: 13, color: ts.withOpacity(0.5)),
                const SizedBox(width: 5),
                Flexible(child: Text(
                  q.length > 35 ? '${q.substring(0, 35)}...' : q,
                  style: TextStyle(fontSize: 12, color: tp, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
          ),
        )).toList(),
      ),
    ];
  }

  List<_QuickAction> get _contextualActions {
    final h = DateTime.now().hour;
    final cartProvider = context.read<CartProvider>();
    final hasCart = cartProvider.items.isNotEmpty;

    final actions = <_QuickAction>[];

    // 1. Smart Cart — flagship feature
    actions.add(_QuickAction('Plan groceries', Icons.psychology_rounded, '__SMART_CART__'));

    // 2. Track order — always useful
    actions.add(_QuickAction('Track order', Icons.local_shipping_rounded, '__TRACK_ORDER__'));

    // 3. Time-aware meal idea (contextual — only 1 shown)
    if (h >= 5 && h < 11) {
      actions.add(_QuickAction('Breakfast ideas', Icons.egg_alt_rounded, '__MEAL_IDEAS__'));
    } else if (h >= 11 && h < 15) {
      actions.add(_QuickAction('Lunch ideas', Icons.lunch_dining_rounded, '__MEAL_IDEAS__'));
    } else {
      actions.add(_QuickAction('Dinner ideas', Icons.dinner_dining_rounded, '__MEAL_IDEAS__'));
    }

    // 4. Cart analysis — only when cart has items
    if (hasCart) {
      actions.add(_QuickAction('Analyze cart', Icons.analytics_rounded, '__ANALYZE_CART__'));
    }

    // 5. Reorder past items
    actions.add(_QuickAction('Reorder favorites', Icons.replay_rounded, '__RECOMMENDATIONS__'));

    return actions;
  }

  // ─── Context builder ───

  Future<Map<String, dynamic>> _buildAppContext() async {
    try {
      return await _aiService.buildContext(
        cartProvider: context.read<CartProvider>(),
        vendorProvider: context.read<VendorProvider>(),
      );
    } catch (_) {
      return {};
    }
  }

  // ─── Send message ───

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    if (preset == null) _controller.clear();
    _saveRecentSearch(text);
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
      _showWelcome = false;
    });
    _scrollToBottom();

    try {
      final appContext = await _buildAppContext();
      final history = _messages
          .where((m) => m.text.isNotEmpty && m.smartCartResult == null && m.cartAnalysis == null && m.mealIdeas == null)
          .toList()
          .reversed
          .take(6)
          .toList()
          .reversed
          .map((m) {
            if (m.isUser) {
              return {'text': m.text, 'isUser': true};
            }
            // For AI replies, include the full note so AI remembers context
            final note = m.aiReply?.note ?? m.text;
            final itemNames = m.aiReply?.items.map((i) => i.name).join(', ') ?? '';
            final fullText = itemNames.isNotEmpty ? '$note\n[Suggested: $itemNames]' : note;
            return {'text': fullText, 'isUser': false};
          })
          .toList();

      final reply = await _aiService.sendMessage(
        message: text,
        context: appContext,
        history: history,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: reply.note, isUser: false, aiReply: reply)));
    } catch (e) {
      if (!mounted) return;
      final errMsg = e.toString().contains('Failed to fetch') || e.toString().contains('Connection')
          ? 'Connection failed. Check your internet and try again.'
          : 'Could not reach AI. Tap to retry.';
      setState(() => _messages.add(_ChatMessage(
        text: errMsg,
        isUser: false,
        isError: true,
      )));
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  // ─── Smart Cart ───

  void _showSmartCartSheet() {
    final budgetCtrl = TextEditingController(text: '15000');
    final prefsCtrl = TextEditingController();
    int days = 7;
    int people = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = context.read<ThemeProvider>().isDarkMode;
        final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final tp = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final ts = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

        return StatefulBuilder(builder: (ctx, set) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: ts.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Plan Your Groceries', style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
                      )),
                      const SizedBox(height: 2),
                      Text('Set your budget, we\'ll build the list', style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12,
                      )),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Budget
                        _sheetLabel('Your Budget (RWF)', tp),
                        const SizedBox(height: 6),
                        TextField(
                          controller: budgetCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: tp, fontSize: 22, fontWeight: FontWeight.w800),
                          decoration: _sheetInputDecor(isDark, prefix: 'RWF '),
                        ),
                        const SizedBox(height: 8),
                        // Quick budget chips
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [5000, 10000, 15000, 25000, 50000].map((b) => _budgetChip(
                            b, budgetCtrl, isDark,
                          )).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Duration + People
                        Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('Duration', tp),
                              const SizedBox(height: 6),
                              _dropdown<int>(
                                value: days,
                                items: [1, 3, 5, 7, 14, 21, 30],
                                label: (v) => '$v day${v > 1 ? 's' : ''}',
                                onChanged: (v) => set(() => days = v ?? 7),
                                isDark: isDark, tp: tp, bg: bg,
                              ),
                            ],
                          )),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetLabel('People', tp),
                              const SizedBox(height: 6),
                              _dropdown<int>(
                                value: people,
                                items: List.generate(10, (i) => i + 1),
                                label: (v) => '$v person${v > 1 ? 's' : ''}',
                                onChanged: (v) => set(() => people = v ?? 1),
                                isDark: isDark, tp: tp, bg: bg,
                              ),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 20),

                        // Preferences
                        _sheetLabel('Dietary Preferences', tp),
                        const SizedBox(height: 6),
                        TextField(
                          controller: prefsCtrl,
                          style: TextStyle(color: tp, fontSize: 14),
                          maxLines: 2,
                          decoration: _sheetInputDecor(isDark,
                            hint: 'e.g. No beef, vegetarian, high protein, halal...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: ['High protein', 'Vegetarian', 'No beef', 'Low carb', 'Family meals', 'Low budget', 'Balanced nutrition', 'Weight loss', 'Student budget', 'Meal prep', 'Halal'].map((p) =>
                            _prefChip(p, prefsCtrl, isDark),
                          ).toList(),
                        ),
                        const SizedBox(height: 28),

                        // Generate button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              final b = double.tryParse(budgetCtrl.text.replaceAll(',', ''));
                              if (b == null || b < 500) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Enter a budget of at least 500 RWF'),
                                ));
                                return;
                              }
                              Navigator.pop(ctx);
                              _generateSmartCart(budget: b, days: days, people: people, prefs: prefsCtrl.text.trim());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Build My Grocery Plan', style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _generateSmartCart({
    required double budget, int days = 7, int people = 1, String prefs = '',
  }) async {
    setState(() {
      _isSmartCartLoading = true;
      _messages.add(_ChatMessage(
        text: '\uD83D\uDED2 Planning groceries \u2014 ${_fmt.format(budget)} RWF, $days day${days > 1 ? 's' : ''}, $people person${people > 1 ? 's' : ''}'
            '${prefs.isNotEmpty ? '\nPreferences: $prefs' : ''}',
        isUser: true,
      ));
      _isSending = true;
      _showWelcome = false;
    });
    _scrollToBottom();

    try {
      final result = await _aiService.generateSmartCart(
        budget: budget, durationDays: days, householdSize: people, preferences: prefs,
      );
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _isSmartCartLoading = false;
        if (result.success && result.items.isNotEmpty) {
          _messages.add(_ChatMessage(text: '', isUser: false, smartCartResult: result));
        } else {
          _messages.add(_ChatMessage(
            text: result.error ?? 'Could not build a cart. Try adjusting your budget or preferences.',
            isUser: false, isError: true,
          ));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _isSmartCartLoading = false;
        final errMsg = e.toString().contains('Failed to fetch') || e.toString().contains('Connection')
            ? 'Connection failed. Check your internet.'
            : 'Smart Cart unavailable. Tap to retry.';
        _messages.add(_ChatMessage(text: errMsg, isUser: false, isError: true));
      });
    }
    _scrollToBottom();
  }

  // ─── Analyze Cart ───

  Future<void> _analyzeCart() async {
    setState(() {
      _messages.add(_ChatMessage(text: '\uD83D\uDD0D Analyzing your cart...', isUser: true));
      _isSending = true;
      _showWelcome = false;
    });
    _scrollToBottom();

    try {
      final appContext = await _buildAppContext();
      final analysis = await _aiService.analyzeCart(context: appContext);
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: '', isUser: false, cartAnalysis: analysis));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: 'Cart analysis unavailable right now.', isUser: false, isError: true));
      });
    }
    _scrollToBottom();
  }

  // ─── Meal Ideas ───

  Future<void> _getMealIdeas([String? mealType]) async {
    setState(() {
      _messages.add(_ChatMessage(
        text: '\uD83C\uDF73 Getting ${mealType ?? 'meal'} ideas from your products...',
        isUser: true,
      ));
      _isSending = true;
      _showWelcome = false;
    });
    _scrollToBottom();

    try {
      final appContext = await _buildAppContext();
      final meals = await _aiService.getMealIdeas(context: appContext, mealType: mealType);
      if (!mounted) return;
      setState(() {
        _isSending = false;
        if (meals.isNotEmpty) {
          _messages.add(_ChatMessage(text: '', isUser: false, mealIdeas: meals));
        } else {
          _messages.add(_ChatMessage(text: 'No meal ideas found. Try adding more products to browse.', isUser: false));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: 'Meal ideas unavailable right now.', isUser: false, isError: true));
      });
    }
    _scrollToBottom();
  }

  // ─── Chat History Sheet ───

  void _showHistorySheet(bool isDark, Color surface, Color tp, Color ts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(color: ts.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Icon(Icons.history_rounded, color: tp, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Chat History', style: TextStyle(color: tp, fontSize: 17, fontWeight: FontWeight.w700))),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await _clearAllHistory();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Text('Clear all', style: TextStyle(color: ts, fontSize: 12)),
                  ),
              ]),
            ),
            const Divider(height: 1),
            Flexible(
              child: _history.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 40, color: ts.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No conversations yet', style: TextStyle(color: ts, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Your chats will appear here', style: TextStyle(color: ts.withOpacity(0.5), fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final session = _history[i];
                        final title = session['title'] as String? ?? 'Chat';
                        final ts2 = DateTime.tryParse(session['ts'] ?? '');
                        final msgCount = (session['messages'] as List?)?.length ?? 0;
                        final timeStr = ts2 != null ? _formatHistoryTime(ts2) : '';

                        return Dismissible(
                          key: Key(session['id'] ?? '$i'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          ),
                          onDismissed: (_) => _deleteHistorySession(session['id'] ?? ''),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.chat_rounded, size: 16, color: _brandLight),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(color: tp, fontSize: 14, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$msgCount messages  \u2022  $timeStr',
                              style: TextStyle(color: ts, fontSize: 11.5),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: ts, size: 18),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _restoreSession(session);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHistoryTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  // ─── Handle quick action taps ───

  void _handleAction(String action) {
    if (action == '__SMART_CART__') {
      _showSmartCartSheet();
    } else if (action == '__ANALYZE_CART__') {
      _analyzeCart();
    } else if (action == '__MEAL_IDEAS__') {
      _getMealIdeas();
    } else if (action == '__TRACK_ORDER__') {
      _trackOrder();
    } else if (action == '__RECOMMENDATIONS__') {
      _getRecommendations();
    } else if (action == '__COOK_WITH__') {
      _showCookWithDialog();
    } else if (action == '__PRICE_CHECK__') {
      _showPriceCheckDialog();
    } else if (action == '__HEALTH_GUIDE__') {
      _showHealthGuideSheet();
    } else {
      _sendMessage(action);
    }
  }

  // ─── Health Guide Bottom Sheet ───

  Future<void> _showHealthGuideSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final ts = isDark ? Colors.white60 : const Color(0xFF888888);

    // Load existing profile
    final existingProfile = await _aiService.loadHealthProfile();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HealthGuideSheet(
        isDark: isDark,
        surface: surface,
        tp: tp,
        ts: ts,
        existingProfile: existingProfile,
        onGoalSelected: (goal) async {
          Navigator.of(ctx).pop();
          await _fetchHealthGuidance(goal);
        },
        onProfileSaved: (profile) async {
          await _aiService.saveHealthProfile(profile);
          if (!mounted) return;
          Navigator.of(ctx).pop();
          _sendMessage('I have ${profile.healthGoal?.replaceAll('_', ' ') ?? 'general health'} goals. '
              'My family size is ${profile.familySize} and monthly food budget is ${_fmt.format(profile.monthlyBudget)} RWF. '
              '${profile.conditions.isNotEmpty ? 'Health conditions: ${profile.conditions.join(', ')}. ' : ''}'
              '${profile.allergies.isNotEmpty ? 'Allergies: ${profile.allergies.join(', ')}. ' : ''}'
              'Give me personalized nutrition guidance and smart shopping advice.');
        },
      ),
    );
  }

  Future<void> _fetchHealthGuidance(String goal) async {
    setState(() {
      _showWelcome = false;
      _messages.add(_ChatMessage(text: '🌿 Health guide: ${goal.replaceAll('_', ' ')}', isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final guidance = await _aiService.getHealthGuidance(goal);
      if (!mounted) return;

      if (guidance == null) {
        setState(() {
          _isSending = false;
          _messages.add(_ChatMessage(text: 'Health guidance not available for that goal.', isUser: false));
        });
        return;
      }

      final buf = StringBuffer();
      buf.writeln('🎯 **${guidance.goal}**\n');
      buf.writeln(guidance.advice);
      buf.writeln();
      if (guidance.foodsToIncrease.isNotEmpty) {
        buf.writeln('✅ Eat more: ${guidance.foodsToIncrease.join(', ')}');
      }
      if (guidance.foodsToReduce.isNotEmpty) {
        buf.writeln('⚠️ Eat less: ${guidance.foodsToReduce.join(', ')}');
      }
      if (guidance.rwandanTip.isNotEmpty) {
        buf.writeln('\n🇷🇼 ${guidance.rwandanTip}');
      }
      if (guidance.seasonTip.isNotEmpty) {
        buf.writeln('\n🌦️ ${guidance.seasonTip}');
      }
      if (guidance.proteinCombos.isNotEmpty) {
        buf.writeln('\n💪 Power combos: ${guidance.proteinCombos.join(' | ')}');
      }

      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: buf.toString().trim(), isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: 'Could not load health guidance. ${e.toString().replaceAll('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  // ─── Track Order ───

  Future<void> _trackOrder() async {
    setState(() {
      _showWelcome = false;
      _messages.add(_ChatMessage(text: '📦 Track my order', isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final tracking = await _aiService.trackOrder();
      if (!mounted) return;

      // Build rich response
      final buf = StringBuffer(tracking.note);
      if (tracking.orders.isNotEmpty) {
        buf.writeln('\n');
        for (final o in tracking.orders) {
          buf.writeln('${o.emoji} #${o.orderNumber} — ${o.statusLabel}');
          if (o.eta.isNotEmpty) buf.writeln('   ETA: ${o.eta}');
          if (o.total > 0) buf.writeln('   Total: ${_fmt.format(o.total)} RWF');
        }
      }

      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: buf.toString().trim(), isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: '• Could not fetch order status\n• ${e.toString().replaceAll('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  // ─── Recommendations ───

  Future<void> _getRecommendations() async {
    setState(() {
      _showWelcome = false;
      _messages.add(_ChatMessage(text: '🔄 Reorder my favorites', isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final recs = await _aiService.getRecommendations();
      if (!mounted) return;

      final buf = StringBuffer(recs.note);
      if (recs.reorderList.isNotEmpty) {
        buf.writeln('\n\n📋 Your usual items:');
        for (final item in recs.reorderList) {
          buf.writeln('• ${item.name} — ${_fmt.format(item.price)} RWF (bought ${item.timesBought}x)');
        }
      }
      if (recs.complementary.isNotEmpty) {
        buf.writeln('\n✨ You might also like:');
        for (final item in recs.complementary) {
          buf.writeln('• ${item.name} — ${_fmt.format(item.price)} RWF');
          if (item.reason.isNotEmpty) buf.writeln('  ${item.reason}');
        }
      }

      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: buf.toString().trim(), isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: '• Could not load recommendations\n• ${e.toString().replaceAll('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  // ─── Cook With Ingredients ───

  void _showCookWithDialog() {
    final ingredientController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🍳 What do you have?'),
        content: TextField(
          controller: ingredientController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. rice, beans, onions, tomatoes...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = ingredientController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) _cookWithIngredients(text);
            },
            child: const Text('Find recipes'),
          ),
        ],
      ),
    );
  }

  Future<void> _cookWithIngredients(String ingredients) async {
    setState(() {
      _showWelcome = false;
      _messages.add(_ChatMessage(text: '🍳 Cook with: $ingredients', isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final result = await _aiService.cookWithIngredients(ingredients: ingredients);
      if (!mounted) return;

      final buf = StringBuffer();
      if (result.note.isNotEmpty) buf.writeln(result.note);

      if (result.meals.isNotEmpty) {
        for (final meal in result.meals) {
          buf.writeln('\n🍽️ ${meal.name}');
          if (meal.time.isNotEmpty) buf.writeln('   ⏱️ ${meal.time}');
          if (meal.steps.isNotEmpty) buf.writeln('   ${meal.steps}');
          if (meal.missing.isNotEmpty) {
            buf.writeln('   🛒 Need to buy: ${meal.missing.join(', ')}');
          }
        }
      }

      if (result.buyItems.isNotEmpty) {
        buf.writeln('\n💰 Items to buy:');
        for (final item in result.buyItems) {
          buf.writeln('• ${item.name} x${item.qty} — ${_fmt.format(item.subtotal)} RWF');
        }
        buf.writeln('Total: ${_fmt.format(result.buyTotal)} RWF');
      }

      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: buf.toString().trim().isEmpty ? '• No recipes found for those ingredients' : buf.toString().trim(),
          isUser: false,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: '• Could not find recipes\n• ${e.toString().replaceAll('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  // ─── Price Check ───

  void _showPriceCheckDialog() {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💰 Check prices'),
        content: TextField(
          controller: priceController,
          decoration: const InputDecoration(
            hintText: 'e.g. rice, milk, eggs, bread...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = priceController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) _checkPrices(text);
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPrices(String items) async {
    setState(() {
      _showWelcome = false;
      _messages.add(_ChatMessage(text: '💰 Price check: $items', isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final result = await _aiService.checkPrices(items: items);
      if (!mounted) return;

      final buf = StringBuffer(result.note);
      if (result.items.isNotEmpty) {
        buf.writeln('\n');
        for (final item in result.items) {
          buf.write('• ${item.name} — ${_fmt.format(item.price)} RWF');
          if (item.unit.isNotEmpty) buf.write(' / ${item.unit}');
          buf.writeln();
        }
      }

      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(text: buf.toString().trim(), isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages.add(_ChatMessage(
          text: '• Could not check prices\n• ${e.toString().replaceAll('Exception: ', '')}',
          isUser: false,
          isError: true,
        ));
      });
    }
    _scrollToBottom();
  }

  static IconData _vendorTypeIcon(String? vendorType) {
    switch (vendorType?.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.coffee;
      case 'fast_food':
        return Icons.fastfood;
      case 'bar':
        return Icons.local_bar;
      case 'bakery':
        return Icons.bakery_dining;
      case 'supermarket':
        return Icons.store;
      case 'grocery':
        return Icons.shopping_basket;
      case 'minimart':
        return Icons.storefront;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'electronics':
        return Icons.devices;
      case 'fashion':
        return Icons.checkroom;
      default:
        return Icons.shopping_bag;
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _retryLast() {
    String? lastUserMsg;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) { lastUserMsg = _messages[i].text; break; }
    }
    if (lastUserMsg != null) {
      if (_messages.isNotEmpty && _messages.last.isError) setState(() => _messages.removeLast());
      if (_messages.isNotEmpty && _messages.last.isUser) setState(() => _messages.removeLast());
      _sendMessage(lastUserMsg);
    }
  }

  // ─── Add AI-suggested items to cart ───

  /// Score how well two names match (higher = better)
  int _scoreMatch(String query, String candidate) {
    final q = query.toLowerCase().trim();
    final c = candidate.toLowerCase().trim();
    if (q == c) return 100;
    if (c.contains(q) || q.contains(c)) return 80;
    // Word overlap scoring
    final qWords = q.split(RegExp(r'\s+')).toSet();
    final cWords = c.split(RegExp(r'\s+')).toSet();
    final overlap = qWords.intersection(cWords).length;
    if (overlap > 0) return (overlap / qWords.length * 70).round();
    return 0;
  }

  /// Find a matching Product from all loaded products by name (scored fuzzy match).
  Product? _findProduct(String name) {
    final productProvider = context.read<ProductProvider>();
    final allProducts = productProvider.allProducts;
    final lower = name.toLowerCase().trim();

    // 1. Exact match in allProducts (most reliable source)
    for (final p in allProducts) {
      if (p.name.toLowerCase().trim() == lower) return p;
    }

    // 2. Scored fuzzy match across allProducts
    Product? bestMatch;
    int bestScore = 0;
    for (final p in allProducts) {
      final score = _scoreMatch(name, p.name);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = p;
      }
    }
    if (bestScore >= 50) return bestMatch;

    // 3. Also search vendor products as fallback
    final vendorProvider = context.read<VendorProvider>();
    for (final vendor in vendorProvider.vendors) {
      final products = productProvider.getProductsByVendor(vendor.id);
      for (final p in products) {
        if (p.name.toLowerCase().trim() == lower) return p;
        final score = _scoreMatch(name, p.name);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = p;
        }
      }
    }
    return bestScore >= 40 ? bestMatch : null;
  }

  /// Check if the vendor for a product is currently open
  bool _isVendorOpen(String vendorId) {
    final vendorProvider = context.read<VendorProvider>();
    for (final v in vendorProvider.vendors) {
      if (v.id == vendorId) return v.isOpen;
    }
    return true; // If vendor not found, assume open
  }

  /// Add a single AI item to cart
  void _addSingleItemToCart(AiReplyItem aiItem) {
    final product = _findProduct(aiItem.name);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${aiItem.name}" not found — try browsing the store first'),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    final vid = aiItem.vendorId ?? product.vendorId;
    if (!_isVendorOpen(vid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${aiItem.name}" — vendor is currently closed'),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    final cart = context.read<CartProvider>();
    for (int i = 0; i < aiItem.qty; i++) {
      cart.addToCart(product, vendorId: vid);
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${aiItem.name} ×${aiItem.qty} added'),
      backgroundColor: _brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Add all AI-suggested items to cart
  void _addAllItemsToCart(List<AiReplyItem> items) {
    final cart = context.read<CartProvider>();
    int added = 0;
    int notFound = 0;
    int closed = 0;

    for (final aiItem in items) {
      final product = _findProduct(aiItem.name);
      if (product != null) {
        final vid = aiItem.vendorId ?? product.vendorId;
        if (!_isVendorOpen(vid)) {
          closed++;
          continue;
        }
        for (int i = 0; i < aiItem.qty; i++) {
          cart.addToCart(product, vendorId: vid);
        }
        added++;
      } else {
        notFound++;
      }
    }

    HapticFeedback.mediumImpact();
    String msg;
    if (closed > 0 && added > 0) {
      msg = '$added added, $closed skipped (vendor closed)';
    } else if (closed > 0 && added == 0) {
      msg = 'All vendors are currently closed';
    } else if (notFound > 0) {
      msg = '$added added, $notFound not found';
    } else {
      msg = '$added items added to cart';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'VIEW CART',
        textColor: Colors.white,
        onPressed: () => context.push('/cart'),
      ),
    ));
  }

  /// Add Smart Cart items to local cart (with edited quantities)
  void _addSmartCartToLocalCart(List<SmartCartItem> items) {
    final cart = context.read<CartProvider>();
    int added = 0;
    int notFound = 0;
    int closed = 0;
    final notFoundNames = <String>[];

    for (final scItem in items) {
      if (scItem.quantity <= 0) continue;
      final product = _findProduct(scItem.name);
      if (product != null) {
        final vid = scItem.vendorId ?? product.vendorId;
        if (!_isVendorOpen(vid)) {
          closed++;
          continue;
        }
        for (int i = 0; i < scItem.quantity; i++) {
          cart.addToCart(product, vendorId: vid);
        }
        added++;
      } else {
        notFound++;
        notFoundNames.add(scItem.name);
      }
    }

    HapticFeedback.mediumImpact();
    String msg;
    if (closed > 0 && added > 0) {
      msg = '$added added. $closed skipped (vendor closed)';
    } else if (closed > 0 && added == 0 && notFound == 0) {
      msg = 'All vendors are currently closed. Try again later.';
    } else if (notFound > 0 && added > 0) {
      msg = '$added added to cart. $notFound unavailable: ${notFoundNames.take(2).join(", ")}';
    } else if (added > 0) {
      msg = '$added items added to cart!';
    } else {
      msg = 'No matching products found. Try browsing vendors first.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: added > 0 ? _brand : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      action: added > 0 ? SnackBarAction(
        label: 'VIEW CART',
        textColor: Colors.white,
        onPressed: () => context.push('/cart'),
      ) : null,
    ));
  }

  // ─── Save as Shopping List ───

  final ShoppingListService _shoppingListService = ShoppingListService();

  void _saveAsShoppingList(List<AiReplyItem> items) async {
    final nameController = TextEditingController(
      text: 'Shopping list ${DateFormat('MMM d').format(DateTime.now())}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save shopping list'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'List name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final list = ShoppingListService.fromAiItems(
      nameController.text.trim().isEmpty ? 'My list' : nameController.text.trim(),
      items.map((i) => {'name': i.name, 'qty': i.qty, 'price': i.price}).toList(),
    );

    await _shoppingListService.saveList(list);

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('\u2705 Saved "${list.name}" (${list.items.length} items)'),
      backgroundColor: _brand,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'SHARE',
        textColor: Colors.white,
        onPressed: () => _shoppingListService.shareList(list),
      ),
    ));
  }

  // ═══════════ BUILD ═══════════

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7);
    final surface = isDark ? const Color(0xFF161616) : Colors.white;
    final tp = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final ts = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bg,
      appBar: _appBar(isDark, surface, tp, ts),
      body: Column(
        children: [
          Expanded(
            child: _showWelcome && _messages.isEmpty
                ? _buildWelcome(isDark, surface, tp, ts, w)
                : _buildChat(isDark, surface, tp, ts, w),
          ),
          _buildInput(isDark, surface, tp, ts),
        ],
      ),
    );
  }

  // ─── App Bar ───

  PreferredSizeWidget _appBar(bool isDark, Color surface, Color tp, Color ts) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(58),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: tp, size: 20),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('N', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NTWAZA', style: TextStyle(
                        color: tp, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                      )),
                      Text(
                        _isSending ? 'Thinking...' : 'Smart Food & Health Guide',
                        style: TextStyle(color: _isSending ? Colors.orange : ts, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.history_rounded, color: ts, size: 20),
                  tooltip: 'Chat history',
                  onPressed: () => _showHistorySheet(isDark, surface, tp, ts),
                ),
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: ts, size: 20),
                    tooltip: 'New chat',
                    onPressed: () async {
                      await _saveCurrentChat();
                      setState(() { _messages.clear(); _showWelcome = true; });
                      _loadRecentSearches();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════ WELCOME SCREEN ═══════════

  Widget _buildWelcome(bool isDark, Color surface, Color tp, Color ts, double w) {
    final cartProvider = context.read<CartProvider>();
    final hasCart = cartProvider.items.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Center(child: Text(_greeting, style: TextStyle(
            color: tp, fontSize: 22, fontWeight: FontWeight.w600,
          ))),
          const SizedBox(height: 4),
          Center(child: Text(_timeContext, style: TextStyle(color: ts, fontSize: 13))),

          const SizedBox(height: 20),

          // Two primary buttons
          Row(children: [
            Expanded(child: _welcomeButton(
              label: 'Plan Groceries',
              onTap: () => _handleAction('__SMART_CART__'),
              isDark: isDark, tp: tp, isPrimary: true,
            )),
            const SizedBox(width: 10),
            Expanded(child: _welcomeButton(
              label: 'Health Guide',
              onTap: () => _handleAction('__HEALTH_GUIDE__'),
              isDark: isDark, tp: tp,
            )),
          ]),

          if (hasCart) ...[
            const SizedBox(height: 8),
            _welcomeButton(
              label: 'Analyze Cart  \u2022  ${cartProvider.itemCount} items  \u2022  ${_fmt.format(cartProvider.totalPrice)} RWF',
              onTap: () => _handleAction('__ANALYZE_CART__'),
              isDark: isDark, tp: tp, full: true,
            ),
          ],

          // Nutrition tip of the day
          _buildNutritionTipCard(isDark, tp, ts),

          // Recent searches
          ..._buildRecentSearches(isDark, tp, ts),

          const SizedBox(height: 18),

          // Quick actions — compact row
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _contextualActions
                .where((a) => a.action != '__SMART_CART__' && a.action != '__ANALYZE_CART__')
                .map((a) => _actionChip(a, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Nutrition tip card on welcome screen ──

  Widget _buildNutritionTipCard(bool isDark, Color tp, Color ts) {
    // Rotate tips daily without a network call
    final day = DateTime.now().weekday;
    final tips = [
      ('💪', 'Complete Protein', 'Rice + Beans = complete protein with all essential amino acids. The ultimate Rwandan health combo.'),
      ('🩸', 'Iron Booster', 'Isombe (cassava leaves) is the best affordable iron source. Eat 3x/week to prevent anemia.'),
      ('💰', 'Smart Shopping', 'With 3,000 RWF you can buy rice + beans + tomatoes + onions = 3 balanced meals.'),
      ('🦴', 'Bone Builder', 'Sambaza (dried fish) is a calcium powerhouse — you eat the bones! Best for growing kids.'),
      ('🥬', 'Green Power', 'Dodo (amaranth greens) is extremely rich in iron and folate. Essential for pregnant women.'),
      ('🥗', 'Daily Balance', 'A healthy Rwandan plate: ½ vegetables, ¼ starch (rice/potatoes), ¼ protein (beans/fish).'),
      ('💧', 'Hydration Tip', 'Replace 1 soda per day with water. Saves money and reduces sugar intake significantly.'),
    ];
    final (emoji, title, text) = tips[day % tips.length];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1B3320) : const Color(0xFFF0F8F0),
        border: Border.all(color: _brandLight.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily Tip: $title', style: TextStyle(
                color: _brandLight, fontSize: 12, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(color: tp, fontSize: 12.5, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }

  // ── Clean welcome button (replaces heavy feature tiles) ──

  Widget _welcomeButton({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color tp,
    bool full = false,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: full ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isPrimary
                ? _brand
                : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isPrimary ? Colors.white : tp,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            )),
          ),
        ),
      ),
    );
  }

  Widget _actionChip(_QuickAction a, bool isDark) {
    final chipText = isDark ? Colors.white70 : const Color(0xFF555555);
    return GestureDetector(
      onTap: () => _handleAction(a.action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
        ),
        child: Text(a.label, style: TextStyle(fontSize: 12, color: chipText)),
      ),
    );
  }

  // ═══════════ CHAT VIEW ═══════════

  Widget _buildChat(bool isDark, Color surface, Color tp, Color ts, double w) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (ctx, idx) {
        // Typing indicator
        if (_isSending && idx == _messages.length) {
          return _typingBubble(isDark, surface, ts);
        }
        final msg = _messages[idx];
        return _buildMessage(msg, isDark, surface, tp, ts, w);
      },
    );
  }

  Widget _buildMessage(_ChatMessage msg, bool isDark, Color surface, Color tp, Color ts, double w) {
    // Smart Cart result card
    if (msg.smartCartResult != null) {
      return _smartCartCard(msg.smartCartResult!, isDark, surface, tp, ts, w);
    }
    // Cart analysis card
    if (msg.cartAnalysis != null) {
      return _cartAnalysisCard(msg.cartAnalysis!, isDark, surface, tp, ts, w);
    }
    // Meal ideas card
    if (msg.mealIdeas != null && msg.mealIdeas!.isNotEmpty) {
      return _mealIdeasCard(msg.mealIdeas!, isDark, surface, tp, ts, w);
    }
    // Structured AI reply card
    if (!msg.isUser && msg.aiReply != null && !msg.isError) {
      return _buildAiReplyCard(msg, isDark, surface, tp, ts, w);
    }

    final isUser = msg.isUser;
    final time = DateFormat('h:mm a').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_avatar(small: true), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: w * 0.78),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Copied'), backgroundColor: _brand,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 1),
                      ));
                    },
                    onTap: msg.isError ? _retryLast : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isUser ? _brand : msg.isError
                            ? (isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF3F3))
                            : surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.isError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.refresh_rounded, size: 13, color: Colors.red[300]),
                                const SizedBox(width: 4),
                                Text('Tap to retry', style: TextStyle(color: Colors.red[300], fontSize: 10, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          if (isUser)
                            SelectableText(msg.text, style: const TextStyle(
                              color: Colors.white, fontSize: 14.5, height: 1.45,
                            ))
                          else
                            _richText(msg.text, tp, ts, isDark),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(time, style: TextStyle(color: ts.withOpacity(0.5), fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ STRUCTURED AI REPLY CARD ═══════════

  Widget _buildAiReplyCard(_ChatMessage msg, bool isDark, Color surface, Color tp, Color ts, double w) {
    final reply = msg.aiReply!;
    final time = DateFormat('h:mm a').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(small: true),
          const SizedBox(width: 8),
          Flexible(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(text: reply.note));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Copied'), backgroundColor: _brand,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 1),
                  ));
                },
                child: Container(
                  constraints: BoxConstraints(maxWidth: w * 0.88),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18), topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Note text
                      if (reply.note.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(14, 12, 14, reply.hasItems || reply.hasSwaps ? 6 : 12),
                          child: _richText(reply.note, tp, ts, isDark),
                        ),

                      // Items — compact list with vendor + product intelligence
                      if (reply.hasItems) ...[
                        ...reply.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text('${item.name} \u00D7${item.qty}', style: TextStyle(
                                  color: tp, fontSize: 13, fontWeight: FontWeight.w500,
                                ))),
                                Text('${_fmt.format(item.subtotal)} RWF', style: TextStyle(
                                  color: ts, fontSize: 12,
                                )),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _addSingleItemToCart(item),
                                  child: Icon(Icons.add_circle_outline_rounded, size: 20, color: _brandLight),
                                ),
                              ]),
                              // Vendor name + type + prep time + allergens
                              if (item.vendorName != null && item.vendorName!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Row(children: [
                                    Icon(_vendorTypeIcon(item.vendorType), size: 11, color: ts.withOpacity(0.7)),
                                    const SizedBox(width: 3),
                                    Text('@${item.vendorName}', style: TextStyle(
                                      color: ts.withOpacity(0.7), fontSize: 11,
                                    )),
                                    if (item.prepTime != null) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.timer_outlined, size: 11, color: ts.withOpacity(0.6)),
                                      Text(' ${item.prepTime}min', style: TextStyle(
                                        color: ts.withOpacity(0.6), fontSize: 11,
                                      )),
                                    ],
                                    if (item.allergens != null && item.allergens!.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('\u26a0 ${item.allergens}', style: TextStyle(
                                        color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.w500,
                                      )),
                                    ],
                                  ]),
                                ),
                            ],
                          ),
                        )),
                        // Total + Add All
                        if (reply.total != null && reply.total! > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text('${_fmt.format(reply.total!)} RWF', style: const TextStyle(
                                  color: _brand, fontSize: 13, fontWeight: FontWeight.w700,
                                )),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: () => _addAllItemsToCart(reply.items),
                                    child: Text('Add ${reply.items.length} to cart', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brand,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveAsShoppingList(reply.items),
                                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                  label: const Text('Save', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _brand,
                                    side: const BorderSide(color: _brand, width: 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Swaps — simple inline
                      if (reply.hasSwaps) ...[
                        ...reply.swaps.map((swap) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          child: Row(children: [
                            Text(swap.remove, style: TextStyle(
                              color: ts, fontSize: 12, decoration: TextDecoration.lineThrough,
                            )),
                            const Text(' \u2192 ', style: TextStyle(fontSize: 12)),
                            Expanded(child: Text(swap.add, style: TextStyle(
                              color: tp, fontSize: 12, fontWeight: FontWeight.w600,
                            ))),
                          ]),
                        )),
                      ],

                      // Tip — inline
                      if (reply.hasTip)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                          child: Text('\uD83D\uDCA1 ${reply.tip!.text}', style: TextStyle(
                            color: ts, fontSize: 12, height: 1.3,
                          )),
                        ),

                      if (reply.hasItems || reply.hasSwaps || reply.hasTip)
                        const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4),
                child: Text(time, style: TextStyle(color: ts.withOpacity(0.5), fontSize: 10)),
              ),
              // Contextual action chips
              if (reply.note.isNotEmpty) _postMessageChips(reply.note, isDark),
            ],
          )),
        ],
      ),
    );
  }

  // ─── Rich text rendering ───

  Widget _richText(String text, Color tp, Color ts, bool isDark) {
    if (text.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];

      // Bullet points: - or •
      if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('\u2022 ')) {
        spans.add(TextSpan(
          text: '  \u2022 ',
          style: TextStyle(color: tp, fontWeight: FontWeight.w700, fontSize: 14.5),
        ));
        _parseInline(line.trimLeft().substring(2), spans, tp, isDark);
      }
      // Numbered lists: 1. 2. etc.
      else if (RegExp(r'^\d+\.\s').hasMatch(line.trimLeft())) {
        final match = RegExp(r'^(\d+\.)\s(.*)').firstMatch(line.trimLeft());
        if (match != null) {
          spans.add(TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(color: tp, fontWeight: FontWeight.w700, fontSize: 14.5),
          ));
          _parseInline(match.group(2) ?? '', spans, tp, isDark);
        } else {
          _parseInline(line, spans, tp, isDark);
        }
      }
      // Price detection: X,XXX RWF or X RWF
      else {
        _parseInline(line, spans, tp, isDark);
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans, style: TextStyle(color: tp, fontSize: 14.5, height: 1.5)),
    );
  }

  void _parseInline(String text, List<InlineSpan> spans, Color tp, bool isDark) {
    // Bold: **text**
    final parts = text.split(RegExp(r'(\*\*[^*]+\*\*)'));
    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(TextSpan(
          text: part.substring(2, part.length - 2),
          style: TextStyle(fontWeight: FontWeight.w700, color: tp),
        ));
      } else {
        // Highlight prices: 1,234 RWF
        final priceParts = part.split(RegExp(r'(\d[\d,]*\s*RWF)'));
        for (final pp in priceParts) {
          if (RegExp(r'^\d[\d,]*\s*RWF$').hasMatch(pp.trim())) {
            spans.add(TextSpan(
              text: pp,
              style: TextStyle(color: tp, fontWeight: FontWeight.w700),
            ));
          } else {
            spans.add(TextSpan(text: pp));
          }
        }
      }
    }
  }

  // ─── Post-message contextual chips ───

  Widget _postMessageChips(String text, bool isDark) {
    final lower = text.toLowerCase();
    final chips = <_QuickAction>[];

    if (lower.contains('budget') || lower.contains('save') || lower.contains('spend') || lower.contains('rwf') || lower.contains('cheap')) {
      chips.add(_QuickAction('Plan budget', Icons.psychology_rounded, '__SMART_CART__'));
    }
    if (lower.contains('cart') || lower.contains('added') || lower.contains('basket')) {
      chips.add(_QuickAction('View cart', Icons.shopping_cart_rounded, '__ANALYZE_CART__'));
    }
    if (lower.contains('health') || lower.contains('nutrition') || lower.contains('diet') || lower.contains('weight')) {
      chips.add(_QuickAction('Health guide', Icons.health_and_safety_rounded, '__HEALTH_GUIDE__'));
    }
    if (lower.contains('meal') || lower.contains('cook') || lower.contains('recipe') || lower.contains('breakfast') || lower.contains('lunch') || lower.contains('dinner')) {
      chips.add(_QuickAction('Meal ideas', Icons.restaurant_rounded, '__MEAL_IDEAS__'));
    }
    if (lower.contains('order') || lower.contains('delivery') || lower.contains('track')) {
      chips.add(_QuickAction('Track order', Icons.local_shipping_rounded, '__TRACK_ORDER__'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: chips.take(2).map((c) => _miniChip(c, isDark)).toList(),
      ),
    );
  }

  Widget _miniChip(_QuickAction a, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleAction(a.action),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _brand.withOpacity(isDark ? 0.1 : 0.04),
            border: Border.all(color: _brand.withOpacity(0.12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(a.icon, size: 12, color: _brandLight),
            const SizedBox(width: 4),
            Text(a.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brandLight)),
          ]),
        ),
      ),
    );
  }

  // ═══════════ SMART CART CARD ═══════════

  Widget _smartCartCard(SmartCartResult r, bool isDark, Color surface, Color tp, Color ts, double w) {
    final b = r.budget;
    final n = r.nutrition;

    // Compute live total from (possibly edited) items
    double liveTotal = 0;
    for (final item in r.items) {
      liveTotal += item.price * item.quantity;
    }
    final liveRemaining = b.requested - liveTotal;
    final livePct = b.requested > 0 ? (liveTotal / b.requested * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(small: true),
          const SizedBox(width: 8),
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: w * 0.88),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Inline title + summary
              Row(children: [
                Expanded(child: Text(
                  'Grocery Plan \u2022 ${r.items.where((i) => i.quantity > 0).length} items',
                  style: TextStyle(color: tp, fontSize: 14, fontWeight: FontWeight.w600),
                )),
                Text('${_fmt.format(liveTotal)} RWF', style: TextStyle(color: ts, fontSize: 12)),
              ]),

              const SizedBox(height: 10),

              // Items — clean rows
              ...r.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(child: Text(
                    item.name,
                    style: TextStyle(
                      color: item.quantity > 0 ? tp : ts,
                      fontSize: 13,
                      decoration: item.quantity <= 0 ? TextDecoration.lineThrough : null,
                    ),
                  )),
                  // Qty controls — minimal
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () {
                        if (item.quantity > 0) {
                          HapticFeedback.selectionClick();
                          setState(() { item.quantity--; item.subtotal = item.price * item.quantity; });
                        }
                      },
                      child: Icon(Icons.remove_circle_outline, size: 18, color: ts),
                    ),
                    SizedBox(
                      width: 24, child: Center(child: Text(
                        '${item.quantity}', style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() { item.quantity++; item.subtotal = item.price * item.quantity; });
                      },
                      child: Icon(Icons.add_circle_outline, size: 18, color: ts),
                    ),
                  ]),
                  SizedBox(
                    width: 60, child: Text(
                      '${_fmt.format(item.price * item.quantity)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: ts, fontSize: 12),
                    ),
                  ),
                ]),
              )),

              // Budget line
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_fmt.format(b.requested)} RWF budget', style: TextStyle(color: ts, fontSize: 11)),
                Text(
                  liveRemaining >= 0 ? '${_fmt.format(liveRemaining)} left' : '${_fmt.format(-liveRemaining)} over',
                  style: TextStyle(
                    color: liveRemaining < 0 ? Colors.red[400] : _brandLight,
                    fontSize: 11, fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (livePct / 100).clamp(0.0, 1.0),
                  backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
                  valueColor: AlwaysStoppedAnimation(livePct > 100 ? Colors.red[400]! : _brandLight),
                  minHeight: 4,
                ),
              ),

              // Buttons
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => _addSmartCartToLocalCart(r.items),
                      child: Text('Add to Cart', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: _isSmartCartLoading ? null : _showSmartCartSheet,
                      child: const Text('Redo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tp,
                        side: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ]),

              // ── Nutrition breakdown (Health) ──
              if (n != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2A1A) : const Color(0xFFF0F8F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _brandLight.withOpacity(0.15)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.monitor_heart_outlined, size: 14, color: _brandLight),
                      const SizedBox(width: 5),
                      Text('Nutrition Estimate', style: TextStyle(color: _brandLight, fontSize: 11, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (n.balanceRating.isNotEmpty) _ratingBadge(n.balanceRating),
                    ]),
                    const SizedBox(height: 8),
                    // Macro bars
                    Row(children: [
                      _macroBar('Protein', n.proteinPercent, const Color(0xFF2196F3), isDark),
                      const SizedBox(width: 4),
                      _macroBar('Carbs', n.carbsPercent, const Color(0xFFFFA726), isDark),
                      const SizedBox(width: 4),
                      _macroBar('Veg', n.fatsPercent, const Color(0xFF66BB6A), isDark),
                      const SizedBox(width: 4),
                      _macroBar('Fats', n.fiberPercent, const Color(0xFFEF5350), isDark),
                    ]),
                    const SizedBox(height: 6),
                    if (n.dailyCalories > 0)
                      Text(
                        '~${_fmt.format(n.dailyCalories)} kcal/day per person \u2022 ${n.durationDays}d \u2022 ${n.householdSize} person${n.householdSize > 1 ? 's' : ''}',
                        style: TextStyle(color: ts, fontSize: 10),
                      ),
                    if (n.summary != null && n.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(n.summary!, style: TextStyle(color: ts, fontSize: 10, height: 1.3)),
                    ],
                  ]),
                ),
              ],
            ]),
          )),
        ],
      ),
    );
  }

  // ═══════════ CART ANALYSIS CARD ═══════════

  Widget _cartAnalysisCard(CartAnalysis a, bool isDark, Color surface, Color tp, Color ts, double w) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(small: true),
          const SizedBox(width: 8),
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: w * 0.88),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Inline title
              Text('Cart Analysis', style: TextStyle(color: _brandLight, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),

              if (a.summary.isNotEmpty)
                Text(a.summary, style: TextStyle(color: tp, fontSize: 13.5, height: 1.45)),

              if (a.nutritionNote != null && a.nutritionNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nutrition \u2014 ${a.nutritionNote!}', style: TextStyle(color: ts, fontSize: 12.5, height: 1.4)),
              ],

              if (a.savingsTip != null && a.savingsTip!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('\uD83D\uDCA1 ${a.savingsTip!}', style: TextStyle(color: ts, fontSize: 12.5, height: 1.4)),
              ],

              if (a.missingStaples.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('You might need: ${a.missingStaples.join(', ')}', style: TextStyle(color: tp, fontSize: 12.5)),
              ],

              if (a.mealSuggestion != null && a.mealSuggestion!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('\uD83C\uDF73 ${a.mealSuggestion!}', style: TextStyle(color: ts, fontSize: 12.5, height: 1.4)),
              ],
            ]),
          )),
        ],
      ),
    );
  }

  // ═══════════ MEAL IDEAS CARD ═══════════

  Widget _mealIdeasCard(List<MealIdea> meals, bool isDark, Color surface, Color tp, Color ts, double w) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(small: true),
          const SizedBox(width: 8),
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: w * 0.88),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${meals.length} Meal Ideas', style: TextStyle(color: _brandLight, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              ...meals.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: TextStyle(color: tp, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (m.time.isNotEmpty)
                    Text(m.time, style: TextStyle(color: ts, fontSize: 11)),
                  if (m.ingredients.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(m.ingredients.join(', '), style: TextStyle(color: ts, fontSize: 11.5)),
                    ),
                  if (m.tip.isNotEmpty)
                    Text(m.tip, style: TextStyle(color: ts, fontSize: 11.5, fontStyle: FontStyle.italic)),
                ]),
              )),
            ]),
          )),
        ],
      ),
    );
  }

  // ═══════════ TYPING INDICATOR ═══════════

  Widget _typingBubble(bool isDark, Color surface, Color ts) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 60, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(small: true),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
                ),
              ),
              child: AnimatedBuilder(
                animation: _dotController,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.2;
                    final t = (_dotController.value - delay) % 1.0;
                    final y = sin(t * pi) * 4;
                    return Transform.translate(
                      offset: Offset(0, -y.abs()),
                      child: Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _brandLight.withOpacity(0.5 + 0.5 * (y.abs() / 4)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════ INPUT BAR ═══════════

  Widget _buildInput(bool isDark, Color surface, Color tp, Color ts) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        // Smart Cart shortcut
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSmartCartLoading ? null : _showSmartCartSheet,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology_rounded, size: 20, color: ts),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0), width: 0.5),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(color: tp, fontSize: 14.5),
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask about health, budget, meals...',
                hintStyle: TextStyle(color: ts.withOpacity(0.5), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _brand,
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSending ? null : () => _sendMessage(),
              customBorder: const CircleBorder(),
              child: Center(
                child: _isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════ HELPERS ═══════════

  Widget _avatar({bool small = false}) {
    final s = small ? 24.0 : 32.0;
    return Container(
      width: s, height: s,
      decoration: const BoxDecoration(
        color: _brand,
        shape: BoxShape.circle,
      ),
      child: Center(child: Text('N', style: TextStyle(color: Colors.white, fontSize: small ? 11 : 14, fontWeight: FontWeight.w800))),
    );
  }

  Widget _ratingBadge(String rating) {
    final r = rating.toLowerCase();
    final color = r.contains('excellent') || r.contains('great') ? Colors.green
        : r.contains('good') || r.contains('balanced') ? _brandLight
        : r.contains('fair') ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(rating, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _macroBar(String label, double pct, Color color, bool isDark) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.1 : 0.05), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text('${pct.round()}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    ));
  }

  Widget _sheetLabel(String text, Color tp) {
    return Text(text, style: TextStyle(color: tp, fontSize: 13, fontWeight: FontWeight.w700));
  }

  InputDecoration _sheetInputDecor(bool isDark, {String? prefix, String? hint}) {
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: TextStyle(color: _brandLight, fontSize: 16, fontWeight: FontWeight.w600),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 13),
      filled: true,
      fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _budgetChip(int amount, TextEditingController ctrl, bool isDark) {
    return GestureDetector(
      onTap: () => ctrl.text = amount.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _brand.withOpacity(isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brand.withOpacity(0.15)),
        ),
        child: Text('${_fmt.format(amount)}', style: const TextStyle(
          color: _brandLight, fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  Widget _prefChip(String label, TextEditingController ctrl, bool isDark) {
    return GestureDetector(
      onTap: () {
        final current = ctrl.text.trim();
        if (current.isNotEmpty && !current.endsWith(',')) {
          ctrl.text = '$current, $label';
        } else {
          ctrl.text = current.isEmpty ? label : '$current $label';
        }
        ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: _brandLight, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value, required List<T> items,
    required String Function(T) label, required void Function(T?) onChanged,
    required bool isDark, required Color tp, required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true, dropdownColor: bg,
          style: TextStyle(color: tp, fontSize: 14),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(label(v)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════ Data Classes ═══════════

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;
  final AiReply? aiReply;
  final SmartCartResult? smartCartResult;
  final CartAnalysis? cartAnalysis;
  final List<MealIdea>? mealIdeas;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.aiReply,
    this.smartCartResult,
    this.cartAnalysis,
    this.mealIdeas,
  }) : timestamp = DateTime.now();
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String action;
  const _QuickAction(this.label, this.icon, this.action);
}

// ═══════════ Health Guide Bottom Sheet ═══════════

class _HealthGuideSheet extends StatefulWidget {
  final bool isDark;
  final Color surface;
  final Color tp;
  final Color ts;
  final HealthProfile? existingProfile;
  final Future<void> Function(String goal) onGoalSelected;
  final Future<void> Function(HealthProfile profile) onProfileSaved;

  const _HealthGuideSheet({
    required this.isDark,
    required this.surface,
    required this.tp,
    required this.ts,
    this.existingProfile,
    required this.onGoalSelected,
    required this.onProfileSaved,
  });

  @override
  State<_HealthGuideSheet> createState() => _HealthGuideSheetState();
}

class _HealthGuideSheetState extends State<_HealthGuideSheet> {
  static const _brand = Color(0xFF1B5E20);
  static const _brandLight = Color(0xFF4CAF50);

  bool _showSetup = false;
  String? _selectedGoal;
  int _familySize = 1;
  double _monthlyBudget = 50000;
  final List<String> _selectedConditions = [];
  final List<String> _selectedAllergies = [];

  static const _healthGoals = [
    ('weight_loss', 'Lose Weight', '🏃', 'Healthy weight management with local foods'),
    ('weight_gain', 'Gain Weight', '💪', 'Build mass with protein-rich Rwandan meals'),
    ('diabetes', 'Manage Diabetes', '🩺', 'Blood sugar control with smart food choices'),
    ('anemia', 'Fight Anemia', '🩸', 'Iron-rich foods to boost your energy'),
    ('child_nutrition', 'Child Nutrition', '👶', 'Healthy meals for growing children'),
    ('pregnancy', 'Pregnancy Diet', '🤰', 'Nutrition for mom and baby'),
    ('student_budget', 'Student Budget', '🎓', 'Balanced meals on a tight budget'),
    ('gym_fitness', 'Gym & Fitness', '🏋️', 'Fuel your workouts properly'),
  ];

  static const _conditionOptions = [
    'Diabetes', 'High blood pressure', 'Anemia', 'High cholesterol',
    'Lactose intolerant', 'Celiac disease', 'Kidney disease',
  ];

  static const _allergyOptions = [
    'Peanuts', 'Tree nuts', 'Dairy', 'Eggs', 'Fish', 'Shellfish', 'Soy', 'Wheat',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    if (p != null) {
      _selectedGoal = p.healthGoal;
      _familySize = p.familySize;
      _monthlyBudget = p.monthlyBudget > 0 ? p.monthlyBudget : 50000;
      _selectedConditions.addAll(p.conditions);
      _selectedAllergies.addAll(p.allergies);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: widget.ts.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_showSetup ? 'Set Up Health Profile' : 'Health & Nutrition Guide',
                      style: TextStyle(color: widget.tp, fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(_showSetup ? 'Personalize your nutrition advice' : 'Rwandan-focused health guidance',
                      style: TextStyle(color: widget.ts, fontSize: 12)),
                  ],
                )),
                if (!_showSetup)
                  TextButton(
                    onPressed: () => setState(() => _showSetup = true),
                    child: Text('Set up profile', style: TextStyle(color: _brandLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                if (_showSetup)
                  TextButton(
                    onPressed: () => setState(() => _showSetup = false),
                    child: Text('Quick guide', style: TextStyle(color: _brandLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _showSetup ? _buildProfileSetup() : _buildGoalList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      shrinkWrap: true,
      itemCount: _healthGoals.length,
      itemBuilder: (ctx, i) {
        final (id, label, emoji, desc) = _healthGoals[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onGoalSelected(id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
              ),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: widget.tp, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(desc, style: TextStyle(color: widget.ts, fontSize: 12)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, color: widget.ts, size: 20),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSetup() {
    final fmt = NumberFormat('#,###', 'en');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health goal selection
          Text('Health Goal', style: TextStyle(color: widget.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _healthGoals.map((g) {
              final (id, label, emoji, _) = g;
              final selected = _selectedGoal == id;
              return GestureDetector(
                onTap: () => setState(() => _selectedGoal = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: selected
                        ? _brand.withOpacity(0.15)
                        : (widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2)),
                    border: selected ? Border.all(color: _brandLight, width: 1.5) : null,
                  ),
                  child: Text('$emoji $label', style: TextStyle(
                    fontSize: 12.5,
                    color: selected ? _brandLight : widget.tp,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  )),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Family size
          Text('Family Size', style: TextStyle(color: widget.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _counterBtn(Icons.remove, () { if (_familySize > 1) setState(() => _familySize--); }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_familySize', style: TextStyle(color: widget.tp, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            _counterBtn(Icons.add, () { if (_familySize < 15) setState(() => _familySize++); }),
            const SizedBox(width: 12),
            Text(_familySize == 1 ? 'person' : 'people', style: TextStyle(color: widget.ts, fontSize: 13)),
          ]),

          const SizedBox(height: 22),

          // Monthly budget
          Text('Monthly Food Budget', style: TextStyle(color: widget.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${fmt.format(_monthlyBudget.round())} RWF/month', style: TextStyle(color: _brandLight, fontSize: 15, fontWeight: FontWeight.w700)),
          Slider(
            value: _monthlyBudget,
            min: 20000,
            max: 300000,
            divisions: 28,
            activeColor: _brand,
            inactiveColor: widget.isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
            onChanged: (v) => setState(() => _monthlyBudget = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('20k', style: TextStyle(color: widget.ts, fontSize: 10)),
              Text('300k', style: TextStyle(color: widget.ts, fontSize: 10)),
            ],
          ),

          const SizedBox(height: 18),

          // Conditions
          Text('Health Conditions (optional)', style: TextStyle(color: widget.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _conditionOptions.map((c) {
              final selected = _selectedConditions.contains(c);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _selectedConditions.remove(c) : _selectedConditions.add(c);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? Colors.orange.withOpacity(0.15)
                        : (widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2)),
                    border: selected ? Border.all(color: Colors.orange, width: 1) : null,
                  ),
                  child: Text(c, style: TextStyle(
                    fontSize: 12, color: selected ? Colors.orange : widget.ts,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Allergies
          Text('Allergies (optional)', style: TextStyle(color: widget.tp, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _allergyOptions.map((a) {
              final selected = _selectedAllergies.contains(a);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _selectedAllergies.remove(a) : _selectedAllergies.add(a);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? Colors.red.withOpacity(0.12)
                        : (widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2)),
                    border: selected ? Border.all(color: Colors.red.shade300, width: 1) : null,
                  ),
                  child: Text(a, style: TextStyle(
                    fontSize: 12, color: selected ? Colors.red.shade300 : widget.ts,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final profile = HealthProfile(
                  healthGoal: _selectedGoal,
                  familySize: _familySize,
                  monthlyBudget: _monthlyBudget,
                  allergies: List.from(_selectedAllergies),
                  conditions: List.from(_selectedConditions),
                );
                widget.onProfileSaved(profile);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Get Personalized Advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        ),
        child: Icon(icon, size: 18, color: widget.tp),
      ),
    );
  }
}
