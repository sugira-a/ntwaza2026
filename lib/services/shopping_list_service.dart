import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

/// Local shopping list — saved to SharedPreferences, sharable via text.
/// Zero backend cost.
class ShoppingListService {
  static const _key = 'ntwaza_shopping_lists';

  /// Get all saved shopping lists
  Future<List<ShoppingList>> getLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => ShoppingList.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a new list or update existing
  Future<void> saveList(ShoppingList list) async {
    final lists = await getLists();
    final idx = lists.indexWhere((l) => l.id == list.id);
    if (idx >= 0) {
      lists[idx] = list;
    } else {
      lists.insert(0, list);
    }
    // Keep max 20 lists
    if (lists.length > 20) lists.removeRange(20, lists.length);
    await _persist(lists);
  }

  /// Delete a list
  Future<void> deleteList(String id) async {
    final lists = await getLists();
    lists.removeWhere((l) => l.id == id);
    await _persist(lists);
  }

  /// Toggle item checked state
  Future<void> toggleItem(String listId, int itemIndex) async {
    final lists = await getLists();
    final idx = lists.indexWhere((l) => l.id == listId);
    if (idx >= 0 && itemIndex < lists[idx].items.length) {
      lists[idx].items[itemIndex].checked = !lists[idx].items[itemIndex].checked;
      await _persist(lists);
    }
  }

  /// Share a list as text
  Future<void> shareList(ShoppingList list) async {
    final buf = StringBuffer('🛒 ${list.name}\n');
    buf.writeln('—' * 20);
    double total = 0;
    for (final item in list.items) {
      final check = item.checked ? '✅' : '⬜';
      buf.writeln('$check ${item.name} x${item.qty} — ${item.price.toStringAsFixed(0)} RWF');
      total += item.price * item.qty;
    }
    buf.writeln('—' * 20);
    buf.writeln('💰 Total: ${total.toStringAsFixed(0)} RWF');
    buf.writeln('\nShared via Ntwaza App');

    await SharePlus.instance.share(ShareParams(text: buf.toString()));
  }

  /// Create a shopping list from AI reply items
  static ShoppingList fromAiItems(String name, List<Map<String, dynamic>> items) {
    return ShoppingList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      items: items
          .map((i) => ShoppingListItem(
                name: i['name'] as String? ?? '',
                qty: i['qty'] as int? ?? 1,
                price: (i['price'] as num?)?.toDouble() ?? (i['subtotal'] as num?)?.toDouble() ?? 0,
              ))
          .where((i) => i.name.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _persist(List<ShoppingList> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lists.map((l) => l.toJson()).toList()));
  }
}

class ShoppingList {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<ShoppingListItem> items;

  ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    this.items = const [],
  });

  double get total => items.fold(0, (sum, i) => sum + i.price * i.qty);
  int get checkedCount => items.where((i) => i.checked).length;
  bool get isComplete => items.isNotEmpty && checkedCount == items.length;

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Shopping list',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      items: (json['items'] as List?)
              ?.map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class ShoppingListItem {
  final String name;
  final int qty;
  final double price;
  bool checked;

  ShoppingListItem({
    required this.name,
    this.qty = 1,
    this.price = 0,
    this.checked = false,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      name: json['name'] as String? ?? '',
      qty: json['qty'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      checked: json['checked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'price': price,
        'checked': checked,
      };
}
