import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/theme_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/vendor_provider.dart';
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
  static const _brandGold = Color(0xFFF9A825);

  final _fmt = NumberFormat('#,###', 'en');

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

  String get _timeEmoji {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return '\u2615'; // coffee
    if (h >= 12 && h < 17) return '\u2600\uFE0F'; // sun
    if (h >= 17 && h < 21) return '\uD83C\uDF05'; // sunset
    return '\uD83C\uDF19'; // moon
  }

  List<_QuickAction> get _contextualActions {
    final h = DateTime.now().hour;
    final cartProvider = context.read<CartProvider>();
    final hasCart = cartProvider.items.isNotEmpty;

    final actions = <_QuickAction>[];

    // Time-based suggestion
    if (h >= 6 && h < 10) {
      actions.add(_QuickAction('Breakfast ideas', Icons.egg_alt_rounded, 'What quick breakfast can I make?'));
    } else if (h >= 11 && h < 14) {
      actions.add(_QuickAction('Lunch ideas', Icons.lunch_dining_rounded, 'Suggest a healthy lunch'));
    } else if (h >= 17 && h < 21) {
      actions.add(_QuickAction('Dinner ideas', Icons.dinner_dining_rounded, 'What should I cook for dinner?'));
    }

    // Core actions
    actions.add(_QuickAction('What\'s in stock?', Icons.inventory_2_rounded, 'What products are available right now?'));
    actions.add(_QuickAction('Health tips', Icons.favorite_rounded, 'Give me a healthy eating tip based on what you sell'));
    actions.add(_QuickAction('Budget advice', Icons.savings_rounded, 'How can I save money on my groceries this week?'));

    if (hasCart) {
      actions.add(_QuickAction('Check my cart', Icons.shopping_cart_checkout_rounded, 'Is my cart balanced and good value?'));
    }

    actions.add(_QuickAction('Help with order', Icons.support_agent_rounded, 'I need help with my order'));

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
          .map((m) => {'text': m.isUser ? m.text : (m.aiReply?.note ?? m.text), 'isUser': m.isUser})
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_brand, Color(0xFF2E7D32)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Smart Cart Planner', style: TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
                            )),
                            Text('AI builds your perfect grocery list', style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 12,
                            )),
                          ],
                        ),
                      ),
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
                          children: ['High protein', 'Vegetarian', 'No beef', 'Low carb', 'Family meals'].map((p) =>
                            _prefChip(p, prefsCtrl, isDark),
                          ).toList(),
                        ),
                        const SizedBox(height: 28),

                        // Generate button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Build My Grocery Plan', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2,
                                )),
                              ],
                            ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 6, offset: const Offset(0, 1),
          )],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: tp, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Avatar
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_brand, _brandLight]),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ntwaza Assistant', style: TextStyle(
                        color: tp, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3,
                      )),
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: _isSending ? Colors.orange : _brandLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isSending ? 'Typing...' : 'Online',
                          style: TextStyle(color: ts, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ],
                  ),
                ),
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: ts, size: 20),
                    tooltip: 'New chat',
                    onPressed: () => setState(() { _messages.clear(); _showWelcome = true; }),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
      child: Column(
        children: [
          // Compact hero
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_brand, _brandLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _brand.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          Text('Your shopping guide $_timeEmoji', style: TextStyle(
            color: tp, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
          )),
          const SizedBox(height: 4),
          Text('Smart shopping, health tips & budget\nadvice \u2014 in simple words.', 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ts, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Quick action chips — the only interactive element
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _contextualActions.map((a) => _actionChip(a, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required bool isDark, required Color surface,
    required Color tp, required Color ts,
    VoidCallback? onTap, String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: TextStyle(
                    color: tp, fontSize: 14.5, fontWeight: FontWeight.w700,
                  )),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_brand, _brandLight]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(badge, style: const TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800,
                      )),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: ts, fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: ts.withOpacity(0.5), size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _actionChip(_QuickAction a, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleAction(a.action),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _brand.withOpacity(isDark ? 0.12 : 0.05),
            border: Border.all(color: _brand.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.icon, size: 14, color: _brandLight),
              const SizedBox(width: 6),
              Text(a.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brandLight)),
            ],
          ),
        ),
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
                        gradient: isUser ? const LinearGradient(colors: [_brand, Color(0xFF2E7D32)]) : null,
                        color: isUser ? null : msg.isError
                            ? (isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF3F3))
                            : surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        boxShadow: [BoxShadow(
                          color: isUser ? _brand.withOpacity(0.15) : Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                          blurRadius: 6, offset: const Offset(0, 2),
                        )],
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
                    border: Border.all(color: _brand.withOpacity(0.1)),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                      blurRadius: 6, offset: const Offset(0, 2),
                    )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Note/bullets
                      if (reply.note.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.fromLTRB(14, 12, 14, reply.hasItems || reply.hasSwaps ? 4 : 12),
                          child: _buildBullets(reply.note, tp, ts),
                        ),

                      // Items list
                      if (reply.hasItems) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          child: Row(children: [
                            const Icon(Icons.shopping_cart_rounded, size: 13, color: _brandLight),
                            const SizedBox(width: 6),
                            Text('SUGGESTED ITEMS', style: TextStyle(
                              color: ts, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                            )),
                          ]),
                        ),
                        ...reply.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          child: Row(children: [
                            Container(width: 5, height: 5, decoration: const BoxDecoration(color: _brandLight, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.name} \u00D7${item.qty}', style: TextStyle(
                                  color: tp, fontSize: 13, fontWeight: FontWeight.w600,
                                )),
                                if (item.reason.isNotEmpty)
                                  Text(item.reason, style: TextStyle(color: ts, fontSize: 11)),
                              ],
                            )),
                            Text('${_fmt.format(item.subtotal)} RWF', style: const TextStyle(
                              color: _brandLight, fontSize: 12, fontWeight: FontWeight.w700,
                            )),
                          ]),
                        )),
                        // Total bar
                        if (reply.total != null && reply.total! > 0)
                          Container(
                            margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(isDark ? 0.15 : 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text('${_fmt.format(reply.total!)} RWF', style: const TextStyle(
                                  color: _brand, fontSize: 13, fontWeight: FontWeight.w800,
                                )),
                              ],
                            ),
                          ),
                      ],

                      // Swaps
                      if (reply.hasSwaps) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          child: Row(children: [
                            const Icon(Icons.swap_horiz_rounded, size: 13, color: _brandGold),
                            const SizedBox(width: 6),
                            Text('SWAP IDEAS', style: TextStyle(
                              color: ts, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                            )),
                          ]),
                        ),
                        ...reply.swaps.map((swap) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _brandGold.withOpacity(isDark ? 0.08 : 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Flexible(
                              flex: 2,
                              child: Text(swap.remove, style: TextStyle(
                                color: ts, fontSize: 12, decoration: TextDecoration.lineThrough,
                              )),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: _brandGold),
                            ),
                            Flexible(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(swap.add, style: TextStyle(
                                    color: tp, fontSize: 12, fontWeight: FontWeight.w600,
                                  )),
                                  if (swap.why.isNotEmpty)
                                    Text(swap.why, style: TextStyle(color: ts, fontSize: 10.5)),
                                ],
                              ),
                            ),
                          ]),
                        )),
                      ],

                      // Proactive tip (health / budget / seasonal)
                      if (reply.hasTip) _buildTipBadge(reply.tip!, isDark, tp, ts),

                      if (reply.hasItems || reply.hasSwaps || reply.hasTip)
                        const SizedBox(height: 8),
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

  // ── Bullet point renderer ──

  Widget _buildBullets(String text, Color tp, Color ts) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final clean = line.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 4, height: 4, decoration: BoxDecoration(
                  color: _brand.withOpacity(0.5), shape: BoxShape.circle,
                )),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(clean, style: TextStyle(color: tp, fontSize: 13.5, height: 1.4))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Proactive tip badge (health / budget / seasonal) ──

  Widget _buildTipBadge(AiReplyTip tip, bool isDark, Color tp, Color ts) {
    final isHealth = tip.type == 'health';
    final isBudget = tip.type == 'budget';
    final color = isBudget ? const Color(0xFF1565C0) : isHealth ? const Color(0xFFE91E63) : _brandLight;
    final icon = isBudget ? Icons.savings_rounded : isHealth ? Icons.favorite_rounded : Icons.eco_rounded;
    final label = isBudget ? 'Budget Tip' : isHealth ? 'Health Tip' : 'Seasonal Tip';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(tip.text, style: TextStyle(color: tp, fontSize: 12.5, height: 1.35)),
        ])),
      ]),
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
          style: TextStyle(color: _brandLight, fontWeight: FontWeight.w700, fontSize: 14.5),
        ));
        _parseInline(line.trimLeft().substring(2), spans, tp, isDark);
      }
      // Numbered lists: 1. 2. etc.
      else if (RegExp(r'^\d+\.\s').hasMatch(line.trimLeft())) {
        final match = RegExp(r'^(\d+\.)\s(.*)').firstMatch(line.trimLeft());
        if (match != null) {
          spans.add(TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(color: _brandLight, fontWeight: FontWeight.w700, fontSize: 14.5),
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
              style: TextStyle(color: _brandLight, fontWeight: FontWeight.w700),
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
    // Keep contextual chips minimal
    final lower = text.toLowerCase();
    final chips = <_QuickAction>[];

    if (lower.contains('order') || lower.contains('delivery') || lower.contains('track')) {
      chips.add(_QuickAction('Contact support', Icons.support_agent_rounded, 'How do I contact support about my order?'));
    }
    if (lower.contains('cart') || lower.contains('added')) {
      chips.add(_QuickAction('View cart', Icons.shopping_cart_rounded, 'What\'s in my cart?'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: chips.map((c) => _miniChip(c, isDark)).toList(),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(small: true),
          const SizedBox(width: 8),
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: w * 0.88),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _brand.withOpacity(0.15)),
              boxShadow: [BoxShadow(color: _brand.withOpacity(isDark ? 0.08 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_brand, Color(0xFF2E7D32)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(children: [
                  const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Smart Cart Plan', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${r.items.length} items \u2022 ${_fmt.format(b.totalCost)} RWF', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11.5)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text('${b.usedPercent.round()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),

              // Items
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('GROCERY LIST', style: TextStyle(color: ts, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              ...r.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _brandLight, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${item.name} \u00D7${item.quantity}', style: TextStyle(color: tp, fontSize: 13))),
                  Text('${_fmt.format(item.subtotal)} RWF', style: TextStyle(color: ts, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )),

              // Budget bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Budget', style: TextStyle(color: ts, fontSize: 11)),
                  Text('${_fmt.format(b.remaining)} RWF left', style: const TextStyle(color: _brandLight, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (b.usedPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
                    valueColor: AlwaysStoppedAnimation(b.usedPercent > 95 ? Colors.orange : _brandLight),
                    minHeight: 6,
                  ),
                ),
              ),

              // Nutrition
              if (n != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                  child: Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.orange[400]),
                    const SizedBox(width: 4),
                    Text('NUTRITION', style: TextStyle(color: ts, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const Spacer(),
                    _ratingBadge(n.balanceRating),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '~${n.dailyCalories.round()} kcal/day \u2022 ${n.householdSize} person${n.householdSize > 1 ? 's' : ''} \u2022 ${n.durationDays} days',
                    style: TextStyle(color: ts, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(children: [
                    _macroBar('Protein', n.proteinPercent, Colors.blue, isDark),
                    const SizedBox(width: 6),
                    _macroBar('Carbs', n.carbsPercent, Colors.amber[700]!, isDark),
                    const SizedBox(width: 6),
                    _macroBar('Fats', n.fatsPercent, Colors.red[400]!, isDark),
                    const SizedBox(width: 6),
                    _macroBar('Fiber', n.fiberPercent, Colors.green, isDark),
                  ]),
                ),
              ],

              // Cart status
              if (r.itemsAddedToCart > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _brandLight.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: _brandLight),
                      const SizedBox(width: 6),
                      Text('${r.itemsAddedToCart} items added to cart', style: const TextStyle(color: _brandLight, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              // Re-optimize
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity, height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _isSmartCartLoading ? null : _showSmartCartSheet,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Re-optimize', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brand,
                      side: BorderSide(color: _brand.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
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
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blue.withOpacity(0.15)),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(children: [
                  const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Cart Analysis', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                ]),
              ),

              // Summary
              if (a.summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text(a.summary, style: TextStyle(color: tp, fontSize: 13.5, height: 1.45)),
                ),

              // Nutrition note
              if (a.nutritionNote != null && a.nutritionNote!.isNotEmpty)
                _analysisSection(Icons.local_fire_department_rounded, Colors.orange, 'Nutrition', a.nutritionNote!, tp, ts, isDark),

              // Savings tip
              if (a.savingsTip != null && a.savingsTip!.isNotEmpty)
                _analysisSection(Icons.savings_rounded, _brandLight, 'Savings Tip', a.savingsTip!, tp, ts, isDark),

              // Missing staples
              if (a.missingStaples.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.red[400]),
                      const SizedBox(width: 6),
                      Text('Missing Staples', style: TextStyle(color: tp, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: a.missingStaples.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(isDark ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 11, color: Colors.red[400], fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ]),
                ),

              // Meal suggestion
              if (a.mealSuggestion != null && a.mealSuggestion!.isNotEmpty)
                _analysisSection(Icons.restaurant_rounded, _brandGold, 'Meal Idea', a.mealSuggestion!, tp, ts, isDark),

              const SizedBox(height: 14),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _analysisSection(IconData icon, Color color, String title, String text, Color tp, Color ts, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: tp, fontSize: 12.5, height: 1.4)),
          ])),
        ]),
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
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withOpacity(0.15)),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[500]!]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(children: [
                  const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${meals.length} Meal Ideas', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                ]),
              ),

              ...meals.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                return Container(
                  margin: EdgeInsets.fromLTRB(14, idx == 0 ? 12 : 4, 14, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.1)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('\uD83C\uDF73', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.name, style: TextStyle(
                        color: tp, fontSize: 14, fontWeight: FontWeight.w700,
                      ))),
                      if (m.time.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(m.time, style: TextStyle(color: Colors.orange[700], fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    if (m.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: m.ingredients.map((i) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _brandLight.withOpacity(isDark ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(i, style: TextStyle(fontSize: 10, color: _brandLight, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                    if (m.tip.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('\uD83D\uDCA1 ${m.tip}', style: TextStyle(color: ts, fontSize: 11.5, fontStyle: FontStyle.italic)),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 14),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
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
                hintText: 'What should I buy today?',
                hintStyle: TextStyle(color: ts.withOpacity(0.5), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_brand, Color(0xFF2E7D32)]),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [BoxShadow(color: _brand.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSending ? null : () => _sendMessage(),
              borderRadius: BorderRadius.circular(23),
              child: Center(
                child: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════ HELPERS ═══════════

  Widget _avatar({bool small = false}) {
    final s = small ? 26.0 : 34.0;
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brand, _brandLight]),
        borderRadius: BorderRadius.circular(s * 0.32),
      ),
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: small ? 14 : 18),
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
