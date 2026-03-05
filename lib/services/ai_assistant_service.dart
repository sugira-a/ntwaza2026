import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api_service.dart';
import '../providers/cart_provider.dart';
import '../providers/vendor_provider.dart';

// ═══════════ Models ═══════════

/// Structured AI reply — backend-enriched with real prices
class AiReply {
  final String note;
  final List<AiReplyItem> items;
  final List<AiReplySwap> swaps;
  final AiReplyTip? tip;
  final double? total;

  AiReply({required this.note, this.items = const [], this.swaps = const [], this.tip, this.total});

  factory AiReply.fromJson(Map<String, dynamic> json) {
    final tipData = json['tip'];
    return AiReply(
      note: json['note'] as String? ?? '',
      items: (json['items'] as List?)
              ?.map((e) => AiReplyItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      swaps: (json['swaps'] as List?)
              ?.map((e) => AiReplySwap.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tip: tipData is Map<String, dynamic> ? AiReplyTip.fromJson(tipData) : null,
      total: (json['total'] as num?)?.toDouble(),
    );
  }

  bool get hasItems => items.isNotEmpty;
  bool get hasSwaps => swaps.isNotEmpty;
  bool get hasTip => tip != null && tip!.text.isNotEmpty;
}

class AiReplyTip {
  final String type; // health, budget, seasonal
  final String text;

  AiReplyTip({required this.type, required this.text});

  factory AiReplyTip.fromJson(Map<String, dynamic> json) {
    return AiReplyTip(
      type: json['type'] as String? ?? 'health',
      text: json['text'] as String? ?? '',
    );
  }
}

class AiReplyItem {
  final String name;
  final int qty;
  final double price;
  final double subtotal;
  final String reason;
  final String? category;
  final String? vendorId;
  final String? vendorName;
  final String? vendorType;
  final String? allergens;
  final int? prepTime;

  AiReplyItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.reason = '',
    this.category,
    this.vendorId,
    this.vendorName,
    this.vendorType,
    this.allergens,
    this.prepTime,
  });

  factory AiReplyItem.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    final qty = json['qty'] as int? ?? 1;
    return AiReplyItem(
      name: json['name'] as String? ?? '',
      qty: qty,
      price: price,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? price * qty,
      reason: json['reason'] as String? ?? '',
      category: json['category'] as String?,
      vendorId: json['vendor_id'] as String?,
      vendorName: json['vendor_name'] as String?,
      vendorType: json['vendor_type'] as String?,
      allergens: json['allergens'] as String?,
      prepTime: json['prep_time'] as int?,
    );
  }
}

class AiReplySwap {
  final String remove;
  final String add;
  final String why;

  AiReplySwap({required this.remove, required this.add, this.why = ''});

  factory AiReplySwap.fromJson(Map<String, dynamic> json) {
    return AiReplySwap(
      remove: json['remove'] as String? ?? '',
      add: json['add'] as String? ?? '',
      why: json['why'] as String? ?? '',
    );
  }
}

/// Smart Cart result from the backend
class SmartCartResult {
  final bool success;
  final List<SmartCartItem> items;
  final SmartCartBudget budget;
  final SmartCartNutrition? nutrition;
  final int itemsAddedToCart;
  final String? error;

  SmartCartResult({
    required this.success,
    this.items = const [],
    required this.budget,
    this.nutrition,
    this.itemsAddedToCart = 0,
    this.error,
  });

  factory SmartCartResult.fromJson(Map<String, dynamic> json) {
    final planList = json['plan'];
    final budgetData = json['budget'] as Map<String, dynamic>? ?? {};
    final nutritionData = json['nutrition'] as Map<String, dynamic>?;

    List itemsList;
    if (planList is List) {
      itemsList = planList;
    } else if (planList is Map) {
      itemsList = (planList as Map<String, dynamic>)['items'] as List? ?? [];
    } else {
      itemsList = json['items'] as List? ?? [];
    }

    return SmartCartResult(
      success: json['success'] == true,
      items: itemsList.map((e) => SmartCartItem.fromJson(e as Map<String, dynamic>)).toList(),
      budget: SmartCartBudget.fromJson(budgetData),
      nutrition: nutritionData != null ? SmartCartNutrition.fromJson(nutritionData) : null,
      itemsAddedToCart: json['item_count'] as int? ?? itemsList.length,
      error: json['error'] as String?,
    );
  }
}

class SmartCartItem {
  final String name;
  int quantity;
  final double price;
  double subtotal;
  final String? category;
  final String? unit;
  final String? productId;
  final String? vendorId;
  final String? imageUrl;

  SmartCartItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.category,
    this.unit,
    this.productId,
    this.vendorId,
    this.imageUrl,
  });

  factory SmartCartItem.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble() ?? 0;
    final qty = json['quantity'] as int? ?? 1;
    return SmartCartItem(
      name: json['name'] as String? ?? '',
      quantity: qty,
      price: price,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? price * qty,
      category: json['category'] as String?,
      unit: json['unit'] as String?,
      productId: json['product_id'] as String?,
      vendorId: json['vendor_id'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class SmartCartBudget {
  final double requested;
  final double totalCost;
  final double remaining;
  final double usedPercent;
  final int uniqueItems;
  final int totalQuantity;

  SmartCartBudget({
    required this.requested,
    required this.totalCost,
    required this.remaining,
    required this.usedPercent,
    required this.uniqueItems,
    required this.totalQuantity,
  });

  factory SmartCartBudget.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toDouble() ?? (json['requested'] as num?)?.toDouble() ?? 0;
    final spent = (json['spent'] as num?)?.toDouble() ?? (json['total_cost'] as num?)?.toDouble() ?? 0;
    final remaining = (json['remaining'] as num?)?.toDouble() ?? (total - spent);
    final pct = (json['utilization_pct'] as num?)?.toDouble() ?? (json['used_percent'] as num?)?.toDouble() ?? (total > 0 ? spent / total * 100 : 0);

    return SmartCartBudget(
      requested: total,
      totalCost: spent,
      remaining: remaining,
      usedPercent: pct,
      uniqueItems: json['unique_items'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
    );
  }
}

class SmartCartNutrition {
  final double dailyCalories;
  final double proteinPercent;
  final double carbsPercent;
  final double fatsPercent;
  final double fiberPercent;
  final String balanceRating;
  final int durationDays;
  final int householdSize;
  final String? summary;

  SmartCartNutrition({
    required this.dailyCalories,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatsPercent,
    required this.fiberPercent,
    required this.balanceRating,
    required this.durationDays,
    required this.householdSize,
    this.summary,
  });

  factory SmartCartNutrition.fromJson(Map<String, dynamic> json) {
    return SmartCartNutrition(
      dailyCalories: (json['daily_kcal_estimate'] as num?)?.toDouble() ?? (json['estimated_daily_kcal'] as num?)?.toDouble() ?? 0,
      proteinPercent: (json['protein_pct'] as num?)?.toDouble() ?? 0,
      carbsPercent: (json['carbs_pct'] as num?)?.toDouble() ?? 0,
      fatsPercent: (json['fats_pct'] as num?)?.toDouble() ?? (json['vegetables_pct'] as num?)?.toDouble() ?? 0,
      fiberPercent: (json['fiber_pct'] as num?)?.toDouble() ?? 0,
      balanceRating: json['balance_rating'] as String? ?? 'Unknown',
      durationDays: json['duration_days'] as int? ?? 7,
      householdSize: json['household_size'] as int? ?? 1,
      summary: json['summary'] as String?,
    );
  }
}

/// Cart analysis result
class CartAnalysis {
  final String summary;
  final String? nutritionNote;
  final String? savingsTip;
  final List<String> missingStaples;
  final String? mealSuggestion;

  CartAnalysis({
    required this.summary,
    this.nutritionNote,
    this.savingsTip,
    this.missingStaples = const [],
    this.mealSuggestion,
  });

  factory CartAnalysis.fromJson(Map<String, dynamic> json) {
    return CartAnalysis(
      summary: json['summary'] as String? ?? '',
      nutritionNote: json['nutrition_note'] as String?,
      savingsTip: json['savings_tip'] as String?,
      missingStaples: (json['missing_staples'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mealSuggestion: json['meal_suggestion'] as String?,
    );
  }
}

/// Meal idea
class MealIdea {
  final String name;
  final List<String> ingredients;
  final String time;
  final String tip;

  MealIdea({required this.name, this.ingredients = const [], this.time = '', this.tip = ''});

  factory MealIdea.fromJson(Map<String, dynamic> json) {
    return MealIdea(
      name: json['name'] as String? ?? '',
      ingredients: (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
      time: json['time'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

/// Order tracking result
class OrderTracking {
  final String note;
  final List<TrackedOrder> orders;
  final bool hasActive;

  OrderTracking({required this.note, this.orders = const [], this.hasActive = false});

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    return OrderTracking(
      note: json['note'] as String? ?? '',
      orders: (json['orders'] as List?)
              ?.map((e) => TrackedOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasActive: json['has_active'] == true,
    );
  }
}

class TrackedOrder {
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String eta;
  final String emoji;
  final double total;

  TrackedOrder({
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    this.eta = '',
    this.emoji = '📋',
    this.total = 0,
  });

  factory TrackedOrder.fromJson(Map<String, dynamic> json) {
    return TrackedOrder(
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📋',
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Recommendations result
class Recommendations {
  final String note;
  final List<RecommendedItem> items;
  final List<RecommendedItem> reorderList;
  final List<RecommendedItem> complementary;
  final String basedOn;
  final double avgSpend;

  Recommendations({
    required this.note,
    this.items = const [],
    this.reorderList = const [],
    this.complementary = const [],
    this.basedOn = '',
    this.avgSpend = 0,
  });

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      note: json['note'] as String? ?? '',
      items: (json['items'] as List?)
              ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reorderList: (json['reorder_list'] as List?)
              ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      complementary: (json['complementary'] as List?)
              ?.map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      basedOn: json['based_on'] as String? ?? '',
      avgSpend: (json['avg_spend'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RecommendedItem {
  final String name;
  final double price;
  final String category;
  final int timesBought;
  final String reason;

  RecommendedItem({
    required this.name,
    this.price = 0,
    this.category = '',
    this.timesBought = 0,
    this.reason = '',
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    return RecommendedItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      timesBought: json['times_bought'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// Cook-with-ingredients result
class CookWithResult {
  final String note;
  final List<CookWithMeal> meals;
  final List<AiReplyItem> buyItems;
  final double buyTotal;

  CookWithResult({this.note = '', this.meals = const [], this.buyItems = const [], this.buyTotal = 0});

  factory CookWithResult.fromJson(Map<String, dynamic> json) {
    return CookWithResult(
      note: json['note'] as String? ?? '',
      meals: (json['meals'] as List?)
              ?.map((e) => CookWithMeal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      buyItems: (json['buy_items'] as List?)
              ?.map((e) => AiReplyItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      buyTotal: (json['buy_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CookWithMeal {
  final String name;
  final String steps;
  final String time;
  final String uses;
  final List<String> missing;

  CookWithMeal({this.name = '', this.steps = '', this.time = '', this.uses = '', this.missing = const []});

  factory CookWithMeal.fromJson(Map<String, dynamic> json) {
    return CookWithMeal(
      name: json['name'] as String? ?? '',
      steps: json['steps'] as String? ?? '',
      time: json['time'] as String? ?? '',
      uses: json['uses'] as String? ?? '',
      missing: (json['missing'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Price check result
class PriceCheckResult {
  final String note;
  final List<PriceItem> items;
  final String query;

  PriceCheckResult({this.note = '', this.items = const [], this.query = ''});

  factory PriceCheckResult.fromJson(Map<String, dynamic> json) {
    return PriceCheckResult(
      note: json['note'] as String? ?? '',
      items: (json['items'] as List?)
              ?.map((e) => PriceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      query: json['query'] as String? ?? '',
    );
  }
}

class PriceItem {
  final String name;
  final double price;
  final String category;
  final String unit;

  PriceItem({required this.name, this.price = 0, this.category = '', this.unit = ''});

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    return PriceItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }
}

/// Proactive notification from order-pattern analysis
class ProactiveNotification {
  final String type;
  final String title;
  final String body;
  final String action;
  final String priority;

  ProactiveNotification({
    required this.type,
    required this.title,
    required this.body,
    this.action = '',
    this.priority = 'low',
  });

  factory ProactiveNotification.fromJson(Map<String, dynamic> json) {
    return ProactiveNotification(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      action: json['action'] as String? ?? '',
      priority: json['priority'] as String? ?? 'low',
    );
  }
}

/// Health goal option from the backend
class HealthGoal {
  final String id;
  final String label;
  final String icon;

  HealthGoal({required this.id, required this.label, required this.icon});

  factory HealthGoal.fromJson(Map<String, dynamic> json) {
    return HealthGoal(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? 'health',
    );
  }
}

/// Health guidance result — Rwandan-specific advice
class HealthGuidance {
  final String goal;
  final String advice;
  final List<String> foodsToIncrease;
  final List<String> foodsToReduce;
  final String rwandanTip;
  final String seasonTip;
  final List<String> proteinCombos;

  HealthGuidance({
    required this.goal,
    required this.advice,
    this.foodsToIncrease = const [],
    this.foodsToReduce = const [],
    this.rwandanTip = '',
    this.seasonTip = '',
    this.proteinCombos = const [],
  });

  factory HealthGuidance.fromJson(Map<String, dynamic> json) {
    return HealthGuidance(
      goal: json['goal'] as String? ?? '',
      advice: json['advice'] as String? ?? '',
      foodsToIncrease: (json['foods_to_increase'] as List?)?.map((e) => e.toString()).toList() ?? [],
      foodsToReduce: (json['foods_to_reduce'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rwandanTip: json['rwandan_tip'] as String? ?? '',
      seasonTip: json['season_tip'] as String? ?? '',
      proteinCombos: (json['protein_combos'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Nutrition tip for daily display
class NutritionTip {
  final String type;
  final String title;
  final String text;

  NutritionTip({required this.type, required this.title, required this.text});

  factory NutritionTip.fromJson(Map<String, dynamic> json) {
    return NutritionTip(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

/// Traditional meal data
class TraditionalMeal {
  final String name;
  final List<String> ingredients;
  final String highlight;

  TraditionalMeal({required this.name, this.ingredients = const [], this.highlight = ''});

  factory TraditionalMeal.fromJson(Map<String, dynamic> json) {
    return TraditionalMeal(
      name: json['name'] as String? ?? '',
      ingredients: (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
      highlight: json['highlight'] as String? ?? '',
    );
  }
}

/// User health profile — stored locally
class HealthProfile {
  final String? healthGoal;
  final int familySize;
  final double monthlyBudget;
  final List<String> allergies;
  final List<String> conditions;

  HealthProfile({
    this.healthGoal,
    this.familySize = 1,
    this.monthlyBudget = 0,
    this.allergies = const [],
    this.conditions = const [],
  });

  Map<String, dynamic> toJson() => {
    'health_goal': healthGoal,
    'family_size': familySize,
    'monthly_budget': monthlyBudget,
    'allergies': allergies,
    'conditions': conditions,
  };

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      healthGoal: json['health_goal'] as String?,
      familySize: json['family_size'] as int? ?? 1,
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble() ?? 0,
      allergies: (json['allergies'] as List?)?.map((e) => e.toString()).toList() ?? [],
      conditions: (json['conditions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}


// ═══════════ Service ═══════════

class AiAssistantService {
  final ApiService _apiService = ApiService();
  static const String _healthProfileKey = 'ntwaza_health_profile';

  // ── Health profile (local storage) ──

  /// Save health profile to local storage
  Future<void> saveHealthProfile(HealthProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_healthProfileKey, jsonEncode(profile.toJson()));
  }

  /// Load health profile from local storage
  Future<HealthProfile?> loadHealthProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_healthProfileKey);
    if (raw == null) return null;
    return HealthProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Clear health profile
  Future<void> clearHealthProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_healthProfileKey);
  }

  /// Build context from current app state (now includes health profile)
  Future<Map<String, dynamic>> buildContext({
    CartProvider? cartProvider,
    VendorProvider? vendorProvider,
  }) async {
    final ctx = <String, dynamic>{};

    if (cartProvider != null && cartProvider.items.isNotEmpty) {
      ctx['cart_items'] = cartProvider.items.map((item) => {
        'name': item.product.name,
        'price': item.product.price,
        'quantity': item.quantity,
        'total': item.totalPrice,
        'category': item.product.category,
      }).toList();
      ctx['cart_total'] = cartProvider.totalPrice;
      ctx['cart_item_count'] = cartProvider.itemCount;
    }

    if (vendorProvider != null && vendorProvider.vendors.isNotEmpty) {
      ctx['vendors_summary'] = vendorProvider.vendors.take(10).map((v) => {
        'name': v.name,
        'category': v.category,
        'is_open': v.isOpen,
        'rating': v.rating,
        'delivery_fee': v.deliveryFee,
      }).toList();
    }

    // Attach health profile if available
    final hp = await loadHealthProfile();
    if (hp != null) {
      ctx['health_profile'] = hp.toJson();
    }

    return ctx;
  }

  /// General chat message — returns structured AI reply
  Future<AiReply> sendMessage({
    required String message,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? history,
  }) async {
    final response = await _apiService.post('/api/ai/assistant', {
      'message': message,
      'context': context ?? {},
      'history': history ?? [],
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final reply = response['reply'];
      if (reply is Map<String, dynamic>) {
        return AiReply.fromJson(reply);
      }
      // Fallback: old-style string reply
      return AiReply(note: reply?.toString() ?? '');
    }

    final error = response is Map<String, dynamic>
        ? (response['error'] ?? 'AI assistant unavailable')
        : 'AI assistant unavailable';
    throw Exception(error);
  }

  /// Smart Cart: AI-powered budget grocery planner
  Future<SmartCartResult> generateSmartCart({
    required double budget,
    int durationDays = 7,
    int householdSize = 1,
    String? preferences,
    String? vendorId,
    bool addToCart = true,
  }) async {
    final response = await _apiService.post('/api/ai/smart-cart', {
      'budget': budget,
      'duration_days': durationDays,
      'household_size': householdSize,
      'preferences': preferences ?? '',
      'vendor_id': vendorId,
      'add_to_cart': addToCart,
    });

    if (response is Map<String, dynamic>) {
      return SmartCartResult.fromJson(response);
    }
    throw Exception('Failed to generate smart cart');
  }

  /// Re-optimize: regenerate with tweaked preferences
  Future<SmartCartResult> reOptimize({
    required double budget,
    int durationDays = 7,
    int householdSize = 1,
    String? preferences,
    String? vendorId,
    bool addToCart = true,
  }) async {
    final response = await _apiService.post('/api/ai/re-optimize', {
      'budget': budget,
      'duration_days': durationDays,
      'household_size': householdSize,
      'preferences': preferences ?? '',
      'vendor_id': vendorId,
      'add_to_cart': addToCart,
    });

    if (response is Map<String, dynamic>) {
      return SmartCartResult.fromJson(response);
    }
    throw Exception('Failed to re-optimize cart');
  }

  /// Analyze current cart — nutrition, savings, gaps
  Future<CartAnalysis> analyzeCart({
    Map<String, dynamic>? context,
  }) async {
    final response = await _apiService.post('/api/ai/analyze-cart', {
      'context': context ?? {},
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final analysis = response['analysis'] as Map<String, dynamic>? ?? {};
      return CartAnalysis.fromJson(analysis);
    }
    throw Exception('Cart analysis unavailable');
  }

  /// Meal ideas from cart or available products
  Future<List<MealIdea>> getMealIdeas({
    Map<String, dynamic>? context,
    String? mealType,
  }) async {
    final response = await _apiService.post('/api/ai/meal-ideas', {
      'context': context ?? {},
      'meal_type': mealType ?? '',
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final meals = response['meals'] as List? ?? [];
      return meals.map((m) => MealIdea.fromJson(m as Map<String, dynamic>)).toList();
    }
    throw Exception('Meal ideas unavailable');
  }

  /// Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _apiService.get('/api/ai/health');
      return response is Map<String, dynamic> && response['configured'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Track order status via AI
  Future<OrderTracking> trackOrder({String? orderId}) async {
    final response = await _apiService.post('/api/ai/track-order', {
      if (orderId != null) 'order_id': orderId,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final tracking = response['tracking'] as Map<String, dynamic>? ?? {};
      return OrderTracking.fromJson(tracking);
    }
    throw Exception(response is Map<String, dynamic>
        ? (response['error'] ?? 'Tracking unavailable')
        : 'Tracking unavailable');
  }

  /// Purchase-history-based recommendations
  Future<Recommendations> getRecommendations() async {
    final response = await _apiService.post('/api/ai/recommendations', {});

    if (response is Map<String, dynamic> && response['success'] == true) {
      final recs = response['recommendations'] as Map<String, dynamic>? ?? {};
      return Recommendations.fromJson(recs);
    }
    throw Exception(response is Map<String, dynamic>
        ? (response['error'] ?? 'Recommendations unavailable')
        : 'Recommendations unavailable');
  }

  /// Cook with ingredients — text-based
  Future<CookWithResult> cookWithIngredients({required String ingredients}) async {
    final response = await _apiService.post('/api/ai/cook-with', {
      'ingredients': ingredients,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = response['cook_with'] as Map<String, dynamic>? ?? {};
      return CookWithResult.fromJson(data);
    }
    throw Exception(response is Map<String, dynamic>
        ? (response['error'] ?? 'Recipe suggestions unavailable')
        : 'Recipe suggestions unavailable');
  }

  /// Price check — no AI call, instant
  Future<PriceCheckResult> checkPrices({required String items}) async {
    final response = await _apiService.post('/api/ai/price-check', {
      'items': items,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = response['prices'] as Map<String, dynamic>? ?? {};
      return PriceCheckResult.fromJson(data);
    }
    throw Exception(response is Map<String, dynamic>
        ? (response['error'] ?? 'Price check unavailable')
        : 'Price check unavailable');
  }

  /// Proactive check — returns notifications the user should see
  Future<List<ProactiveNotification>> proactiveCheck() async {
    try {
      final response = await _apiService.post('/api/ai/proactive-check', {});
      if (response is Map<String, dynamic> && response['success'] == true) {
        final items = response['notifications'] as List? ?? [];
        return items
            .map((e) => ProactiveNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Health & Nutrition endpoints (no AI call, instant) ──

  /// Get available health goals or guidance for a specific goal
  Future<HealthGuidance?> getHealthGuidance(String goal) async {
    final response = await _apiService.post('/api/ai/health-guide', {
      'goal': goal,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      final guidance = response['guidance'] as Map<String, dynamic>?;
      if (guidance != null) {
        return HealthGuidance.fromJson(guidance);
      }
    }
    return null;
  }

  /// Get list of available health goals
  Future<List<HealthGoal>> getHealthGoals() async {
    final response = await _apiService.post('/api/ai/health-guide', {});

    if (response is Map<String, dynamic> && response['success'] == true) {
      final goals = response['goals'] as List? ?? [];
      return goals.map((g) => HealthGoal.fromJson(g as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Get daily nutrition tips — no AI call, instant response
  Future<({List<NutritionTip> tips, TraditionalMeal? meal})> getNutritionTips() async {
    final response = await _apiService.get('/api/ai/nutrition-tips');

    if (response is Map<String, dynamic> && response['success'] == true) {
      final tipsList = response['tips'] as List? ?? [];
      final mealData = response['traditional_meal'] as Map<String, dynamic>?;
      return (
        tips: tipsList.map((t) => NutritionTip.fromJson(t as Map<String, dynamic>)).toList(),
        meal: mealData != null ? TraditionalMeal.fromJson(mealData) : null,
      );
    }
    return (tips: <NutritionTip>[], meal: null);
  }
}
