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

  AiReplyItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.reason = '',
    this.category,
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
  final int quantity;
  final double price;
  final double subtotal;
  final String? category;
  final String? unit;

  SmartCartItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.category,
    this.unit,
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


// ═══════════ Service ═══════════

class AiAssistantService {
  final ApiService _apiService = ApiService();

  /// Build context from current app state
  Map<String, dynamic> buildContext({
    CartProvider? cartProvider,
    VendorProvider? vendorProvider,
  }) {
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
}
