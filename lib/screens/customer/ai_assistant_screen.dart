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
    });
    _loadRecentSearches();
  }

  @override
  void dispose() {
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
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 21) return 'Good evening';
    return 'Hi there';
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

    // Smart Cart — always first, flagship feature
    actions.add(_QuickAction('\uD83D\uDED2 Plan my groceries', Icons.psychology_rounded, '__SMART_CART__'));

    // Time-based meal suggestion
    if (h >= 6 && h < 10) {
      actions.add(_QuickAction('Breakfast ideas', Icons.egg_alt_rounded, 'What quick healthy breakfast can I make? Include nutrition info.'));
    } else if (h >= 11 && h < 14) {
      actions.add(_QuickAction('Lunch ideas', Icons.lunch_dining_rounded, 'Suggest a healthy balanced lunch with protein and vegetables'));
    } else if (h >= 17 && h < 21) {
      actions.add(_QuickAction('Dinner ideas', Icons.dinner_dining_rounded, 'What should I cook for a healthy dinner? Consider nutrition balance.'));
    }

    // Budget
    actions.add(_QuickAction('Budget plan', Icons.savings_rounded, 'I\'m on a tight budget. Help me plan affordable groceries for the week with good nutrition.'));

    // Cart actions
    if (hasCart) {
      actions.add(_QuickAction('Analyze my cart', Icons.analytics_rounded, '__ANALYZE_CART__'));
      actions.add(_QuickAction('Complete my cart', Icons.add_shopping_cart_rounded, 'What am I missing in my cart? Suggest items for balanced nutrition and complete meals.'));
    }

    // Health
    actions.add(_QuickAction('Healthy shopping', Icons.health_and_safety_rounded, 'Build me a healthy shopping list with high protein, vegetables, and whole grains. Focus on nutrition.'));

    // Family mode
    actions.add(_QuickAction('Family groceries', Icons.family_restroom_rounded, 'Help me plan groceries for my family of 4 for a month. Include variety and balanced nutrition.'));

    // Quick order
    actions.add(_QuickAction('Quick basket', Icons.flash_on_rounded, 'Just give me a balanced grocery basket. Add the essentials to my cart now.'));

    // Meal prep
    actions.add(_QuickAction('Meal prep guide', Icons.restaurant_menu_rounded, 'Help me plan affordable meal prep for the week. Include nutrition tips and budget breakdown.'));

    // Core actions
    actions.add(_QuickAction('What\'s available?', Icons.inventory_2_rounded, 'What products are available right now? Show me the best deals by category.'));
    actions.add(_QuickAction('Help & support', Icons.support_agent_rounded, 'I need help with my order or delivery'));

    return actions;
  }

  // ─── Context builder ───

  Map<String, dynamic> _buildAppContext() {
    try {
      return _aiService.buildContext(
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
      final appContext = _buildAppContext();
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
      final appContext = _buildAppContext();
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
      final appContext = _buildAppContext();
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

  // ─── Handle quick action taps ───

  void _handleAction(String action) {
    if (action == '__SMART_CART__') {
      _showSmartCartSheet();
    } else if (action == '__ANALYZE_CART__') {
      _analyzeCart();
    } else if (action == '__MEAL_IDEAS__') {
      _getMealIdeas();
    } else {
      _sendMessage(action);
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

    final cart = context.read<CartProvider>();
    final vid = aiItem.vendorId ?? product.vendorId;
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

    for (final aiItem in items) {
      final product = _findProduct(aiItem.name);
      if (product != null) {
        final vid = aiItem.vendorId ?? product.vendorId;
        for (int i = 0; i < aiItem.qty; i++) {
          cart.addToCart(product, vendorId: vid);
        }
        added++;
      } else {
        notFound++;
      }
    }

    HapticFeedback.mediumImpact();
    final msg = notFound > 0
        ? '$added added, $notFound not found'
        : '$added items added to cart';
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
    final notFoundNames = <String>[];

    for (final scItem in items) {
      if (scItem.quantity <= 0) continue;
      final product = _findProduct(scItem.name);
      if (product != null) {
        final vid = scItem.vendorId ?? product.vendorId;
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
    if (notFound > 0 && added > 0) {
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
                      Text('NtWaza AI', style: TextStyle(
                        color: tp, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3,
                      )),
                      Text(
                        _isSending ? 'Thinking...' : 'Shop smart. Eat well. Save more.',
                        style: TextStyle(color: _isSending ? Colors.orange : ts, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: ts, size: 20),
                    tooltip: 'New chat',
                    onPressed: () {
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
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Center(child: Text(_greeting, style: TextStyle(
            color: tp, fontSize: 22, fontWeight: FontWeight.w600,
          ))),
          const SizedBox(height: 4),
          Center(child: Text('Shop smart. Eat well. Save more.', style: TextStyle(color: ts, fontSize: 13))),

          const SizedBox(height: 24),

          // Primary action row
          Row(children: [
            Expanded(child: _welcomeButton(
              label: 'Plan Groceries',
              onTap: () => _handleAction('__SMART_CART__'),
              isDark: isDark, tp: tp, isPrimary: true,
            )),
            const SizedBox(width: 10),
            Expanded(child: _welcomeButton(
              label: 'Quick Basket',
              onTap: () => _sendMessage('Just give me a balanced grocery basket with essentials. Add items to my cart.'),
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

          // Recent searches
          ..._buildRecentSearches(isDark, tp, ts),

          const SizedBox(height: 20),

          // ── Health & Nutrition Section ──
          _sectionHeader('Health & Nutrition', Icons.favorite_rounded, ts),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _actionChip(_QuickAction('Healthy shopping list', Icons.health_and_safety_rounded, 'Build me a healthy shopping list with high protein, vegetables, and whole grains. Include nutrition info.'), isDark),
              _actionChip(_QuickAction('Weight loss plan', Icons.monitor_weight_rounded, 'I want to lose weight. Help me plan healthy groceries that are low calorie but filling.'), isDark),
              _actionChip(_QuickAction('High protein meals', Icons.fitness_center_rounded, 'Suggest affordable high protein meals I can make from available products'), isDark),
              _actionChip(_QuickAction('Energy boost', Icons.bolt_rounded, 'I feel tired often. What foods give me more energy? Suggest iron and vitamin rich items.'), isDark),
            ],
          ),

          const SizedBox(height: 18),

          // ── Budget & Family Section ──
          _sectionHeader('Budget & Family', Icons.savings_rounded, ts),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _actionChip(_QuickAction('Student budget', Icons.school_rounded, 'I\'m a student with 10,000 RWF. Plan my groceries for a week with good nutrition.'), isDark),
              _actionChip(_QuickAction('Family of 4', Icons.family_restroom_rounded, 'Help me plan monthly groceries for a family of 4. Include variety and balanced nutrition.'), isDark),
              _actionChip(_QuickAction('Monthly stock', Icons.inventory_rounded, 'Build a monthly grocery stock list. Split into non-perishables and weekly perishables.'), isDark),
              _actionChip(_QuickAction('Best deals', Icons.local_offer_rounded, 'What are the best value products available right now? Show cheapest items by category.'), isDark),
            ],
          ),

          const SizedBox(height: 18),

          // ── Shopping & Meals Section ──
          _sectionHeader('Shopping & Meals', Icons.shopping_basket_rounded, ts),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _contextualActions
                .where((a) => a.action != '__SMART_CART__' && a.action != '__ANALYZE_CART__' 
                    && !a.label.contains('Healthy') && !a.label.contains('Budget') && !a.label.contains('Family'))
                .take(5)
                .map((a) => _actionChip(a, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color ts) {
    return Row(children: [
      Icon(icon, size: 13, color: ts),
      const SizedBox(width: 5),
      Text(title, style: TextStyle(color: ts, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    ]);
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

                      // Items — compact list
                      if (reply.hasItems) ...[
                        ...reply.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          child: Row(children: [
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
                          child: SizedBox(
                            width: double.infinity, height: 36,
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

    if (lower.contains('budget') || lower.contains('save') || lower.contains('spend') || lower.contains('rwf') || lower.contains('money') || lower.contains('cheap')) {
      chips.add(_QuickAction('Plan budget', Icons.psychology_rounded, '__SMART_CART__'));
      chips.add(_QuickAction('Best deals', Icons.local_offer_rounded, 'Show me the cheapest products by category'));
    }
    if (lower.contains('cart') || lower.contains('added') || lower.contains('item') || lower.contains('basket')) {
      chips.add(_QuickAction('View cart', Icons.shopping_cart_rounded, 'What\'s in my cart right now?'));
    }
    if (lower.contains('health') || lower.contains('nutrition') || lower.contains('protein') || lower.contains('vitamin') || lower.contains('calorie') || lower.contains('balanced') || lower.contains('weight') || lower.contains('diet')) {
      chips.add(_QuickAction('Health tips', Icons.favorite_rounded, 'Give me more practical health and nutrition tips for my diet'));
      chips.add(_QuickAction('Healthy list', Icons.health_and_safety_rounded, 'Build me a healthy shopping list focused on balanced nutrition'));
    }
    if (lower.contains('meal') || lower.contains('cook') || lower.contains('recipe') || lower.contains('breakfast') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('prep')) {
      chips.add(_QuickAction('Meal ideas', Icons.restaurant_rounded, '__MEAL_IDEAS__'));
    }
    if (lower.contains('family') || lower.contains('kids') || lower.contains('people') || lower.contains('household')) {
      chips.add(_QuickAction('Family plan', Icons.family_restroom_rounded, 'Help me plan monthly groceries for my family with variety and balanced nutrition.'));
    }
    if (lower.contains('order') || lower.contains('delivery') || lower.contains('track') || lower.contains('refund') || lower.contains('cancel')) {
      chips.add(_QuickAction('Contact support', Icons.support_agent_rounded, 'How do I contact support about my order?'));
    }
    if (lower.contains('product') || lower.contains('available') || lower.contains('store') || lower.contains('vendor')) {
      chips.add(_QuickAction('Browse products', Icons.store_rounded, 'Show me all available products organized by category'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: chips.take(3).map((c) => _miniChip(c, isDark)).toList(),
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
