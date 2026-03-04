// lib/services/ai_store_assistant_service.dart
/// Frontend AI Store Assistant Service
/// Smart shopping guide trained on vendor and user preferences

import 'package:provider/provider.dart';
import 'api/api_service.dart';

class AIStoreAssistantService {
  final ApiService _apiService = ApiService();

  /// Get personalized meal plan
  /// 
  /// Parameters:
  /// - budgetRwf: Budget in RWF (e.g., 15000)
  /// - dietaryPreference: 'balanced', 'vegetarian', 'low-fat', 'high-protein'
  /// - vendorId: Optional vendor ID to limit recommendations
  Future<Map<String, dynamic>> generateMealPlan({
    required double budgetRwf,
    required String dietaryPreference,
    String? vendorId,
  }) async {
    try {
      print('\n🍽️  AI MEAL PLAN SERVICE');
      print('   Budget: RWF ${budgetRwf.toStringAsFixed(0)}');
      print('   Preference: $dietaryPreference');
      if (vendorId != null) print('   Vendor: $vendorId');

      final response = await _apiService.post(
        '/api/ai/meal-plan',
        body: {
          'budget_rwf': budgetRwf,
          'dietary_preference': dietaryPreference,
          'vendor_id': vendorId,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Meal plan generation failed');
      }

      print('✅ Meal plan generated successfully');
      return response;
    } catch (e) {
      print('❌ Meal plan error: $e');
      rethrow;
    }
  }

  /// Get product recommendations based on query
  /// 
  /// Parameters:
  /// - query: User request (e.g., "healthy breakfast")
  /// - vendorId: Optional vendor ID to limit recommendations
  Future<Map<String, dynamic>> getProductRecommendations({
    required String query,
    String? vendorId,
  }) async {
    try {
      print('\n💡 AI RECOMMENDATIONS SERVICE');
      print('   Query: "$query"');
      if (vendorId != null) print('   Vendor: $vendorId');

      final response = await _apiService.post(
        '/api/ai/recommend',
        body: {
          'query': query,
          'vendor_id': vendorId,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Recommendation failed');
      }

      print('✅ Recommendations generated successfully');
      return response;
    } catch (e) {
      print('❌ Recommendation error: $e');
      rethrow;
    }
  }

  /// Analyze nutritional content of selected products
  /// 
  /// Parameters:
  /// - products: List of product maps with name, price, category
  Future<Map<String, dynamic>> analyzeNutrition(
    List<Map<String, dynamic>> products,
  ) async {
    try {
      print('\n🥗 AI NUTRITION ANALYSIS');
      print('   Products: ${products.length}');

      final response = await _apiService.post(
        '/api/ai/nutrition-analysis',
        body: {
          'products': products,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Nutrition analysis failed');
      }

      print('✅ Nutrition analysis complete');
      return response;
    } catch (e) {
      print('❌ Nutrition analysis error: $e');
      rethrow;
    }
  }

  /// Answer shopping/health questions in context
  /// 
  /// Parameters:
  /// - question: User question
  /// - vendorId: Optional vendor context
  Future<Map<String, dynamic>> answerQuestion({
    required String question,
    String? vendorId,
  }) async {
    try {
      print('\n❓ AI QUESTION ANSWERING');
      print('   Question: "$question"');

      final response = await _apiService.post(
        '/api/ai/answer-question',
        body: {
          'question': question,
          'vendor_id': vendorId,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Question answering failed');
      }

      print('✅ Answer generated');
      return response;
    } catch (e) {
      print('❌ Question answering error: $e');
      rethrow;
    }
  }

  /// Re-optimize an existing cart based on budget or health goals
  /// 
  /// Parameters:
  /// - cartItems: Current cart items
  /// - budget: Optional budget limit
  /// - healthGoal: Optional health goal
  Future<Map<String, dynamic>> optimizeCart({
    required List<Map<String, dynamic>> cartItems,
    double? budget,
    String? healthGoal,
  }) async {
    try {
      print('\n🛒 AI CART OPTIMIZATION');
      print('   Items: ${cartItems.length}');
      if (budget != null) print('   Budget: RWF ${budget.toStringAsFixed(0)}');
      if (healthGoal != null) print('   Goal: $healthGoal');

      final response = await _apiService.post(
        '/api/ai/optimize-cart',
        body: {
          'cart_items': cartItems,
          'budget': budget,
          'health_goal': healthGoal,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Cart optimization failed');
      }

      print('✅ Cart optimized');
      return response;
    } catch (e) {
      print('❌ Cart optimization error: $e');
      rethrow;
    }
  }

  /// Get budget-aware shopping suggestions
  /// 
  /// Parameters:
  /// - budgetRwf: Available budget
  /// - mealCount: Number of meals to plan
  /// - vendorId: Optional vendor to shop from
  Future<Map<String, dynamic>> getBudgetSuggestions({
    required double budgetRwf,
    int mealCount = 2,
    String? vendorId,
  }) async {
    try {
      print('\n💰 AI BUDGET SUGGESTIONS');
      print('   Budget: RWF ${budgetRwf.toStringAsFixed(0)}');
      print('   Meals: $mealCount');

      final response = await _apiService.post(
        '/api/ai/budget-suggestions',
        body: {
          'budget_rwf': budgetRwf,
          'meal_count': mealCount,
          'vendor_id': vendorId,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Budget suggestions failed');
      }

      print('✅ Suggestions generated');
      return response;
    } catch (e) {
      print('❌ Budget suggestions error: $e');
      rethrow;
    }
  }

  /// Get health guidance based on user goals
  /// 
  /// Parameters:
  /// - healthGoal: 'weight-loss', 'muscle-gain', 'balanced', etc.
  /// - vendorId: Optional vendor context
  Future<Map<String, dynamic>> getHealthGuidance({
    required String healthGoal,
    String? vendorId,
  }) async {
    try {
      print('\n❤️ AI HEALTH GUIDANCE');
      print('   Goal: $healthGoal');

      final response = await _apiService.post(
        '/api/ai/health-guidance',
        body: {
          'health_goal': healthGoal,
          'vendor_id': vendorId,
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Health guidance failed');
      }

      print('✅ Health guidance generated');
      return response;
    } catch (e) {
      print('❌ Health guidance error: $e');
      rethrow;
    }
  }

  /// Chat with AI assistant in context of current vendor and cart
  /// 
  /// Parameters:
  /// - message: User message
  /// - vendorId: Current vendor context
  /// - cartItems: Optional current cart items
  Future<Map<String, dynamic>> chat({
    required String message,
    String? vendorId,
    List<Map<String, dynamic>>? cartItems,
  }) async {
    try {
      print('\n💬 AI CHAT');
      print('   Message: "$message"');

      final response = await _apiService.post(
        '/api/ai/chat',
        body: {
          'message': message,
          'vendor_id': vendorId,
          'cart_items': cartItems ?? [],
        },
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Chat failed');
      }

      return response;
    } catch (e) {
      print('❌ Chat error: $e');
      rethrow;
    }
  }

  /// Get smart shopping tips based on season/time
  Future<Map<String, dynamic>> getSmartTips() async {
    try {
      print('\n💡 AI SMART TIPS');

      final response = await _apiService.get('/api/ai/smart-tips');

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Tips failed');
      }

      print('✅ Tips generated');
      return response;
    } catch (e) {
      print('❌ Tips error: $e');
      rethrow;
    }
  }
}
