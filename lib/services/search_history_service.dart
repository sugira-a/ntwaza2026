// lib/services/search_history_service.dart
/// Service to manage search history
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _searchHistoryKey = 'search_history';
  static const int maxSearchItems = 15;

  /// Add search query to history
  static Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];

      // Remove duplicate if exists
      history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());

      // Add to top
      history.insert(0, query.trim());

      // Limit to max items
      if (history.length > maxSearchItems) {
        history.removeRange(maxSearchItems, history.length);
      }

      await prefs.setStringList(_searchHistoryKey, history);
      print('🔍 Search saved: "$query"');
    } catch (e) {
      print('❌ Error saving search: $e');
    }
  }

  /// Get search history
  static Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_searchHistoryKey) ?? [];
    } catch (e) {
      print('❌ Error getting search history: $e');
      return [];
    }
  }

  /// Remove specific search from history
  static Future<void> removeSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];
      history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
      await prefs.setStringList(_searchHistoryKey, history);
    } catch (e) {
      print('❌ Error removing search: $e');
    }
  }

  /// Clear all search history
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
      print('✅ Search history cleared');
    } catch (e) {
      print('❌ Error clearing history: $e');
    }
  }

  /// Get trending searches (mock - replace with real data)
  static Future<List<String>> getTrendingSearches() async {
    try {
      // In production, fetch from backend
      return [
        'Rice',
        'Chapati',
        'Milk',
        'Eggs',
        'Vegetables',
        'Bread',
        'Meat',
      ];
    } catch (e) {
      return [];
    }
  }
}
