import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local price alert tracker — stores watched items + last known price.
/// Compares on next app open. Zero backend cost.
class PriceAlertService {
  static const _key = 'ntwaza_price_alerts';

  /// Get all price alerts
  Future<List<PriceAlert>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => PriceAlert.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a price alert for an item
  Future<void> addAlert(PriceAlert alert) async {
    final alerts = await getAlerts();
    // Remove existing alert for same item name
    alerts.removeWhere((a) => a.itemName.toLowerCase() == alert.itemName.toLowerCase());
    alerts.insert(0, alert);
    if (alerts.length > 30) alerts.removeRange(30, alerts.length);
    await _persist(alerts);
  }

  /// Remove an alert
  Future<void> removeAlert(String itemName) async {
    final alerts = await getAlerts();
    alerts.removeWhere((a) => a.itemName.toLowerCase() == itemName.toLowerCase());
    await _persist(alerts);
  }

  /// Check for price changes — returns alerts with price drops/increases
  Future<List<PriceChangeInfo>> checkPriceChanges(List<Map<String, dynamic>> currentPrices) async {
    final alerts = await getAlerts();
    if (alerts.isEmpty || currentPrices.isEmpty) return [];

    final changes = <PriceChangeInfo>[];
    final updatedAlerts = <PriceAlert>[];

    for (final alert in alerts) {
      // Find matching product in current prices
      final match = currentPrices.cast<Map<String, dynamic>?>().firstWhere(
        (p) => (p?['name'] as String? ?? '').toLowerCase() == alert.itemName.toLowerCase(),
        orElse: () => null,
      );

      if (match != null) {
        final currentPrice = (match['price'] as num?)?.toDouble() ?? 0;
        if (currentPrice > 0 && alert.lastKnownPrice > 0) {
          final diff = currentPrice - alert.lastKnownPrice;
          final pctChange = (diff / alert.lastKnownPrice * 100).roundToDouble();

          if (pctChange.abs() >= 3) {
            // Significant price change (3%+)
            changes.add(PriceChangeInfo(
              itemName: alert.itemName,
              oldPrice: alert.lastKnownPrice,
              newPrice: currentPrice,
              percentChange: pctChange,
              isPriceDrop: diff < 0,
            ));
          }
        }

        // Update last known price
        updatedAlerts.add(PriceAlert(
          itemName: alert.itemName,
          lastKnownPrice: currentPrice,
          addedAt: alert.addedAt,
        ));
      } else {
        updatedAlerts.add(alert);
      }
    }

    if (updatedAlerts.isNotEmpty) await _persist(updatedAlerts);
    return changes;
  }

  Future<void> _persist(List<PriceAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(alerts.map((a) => a.toJson()).toList()));
  }
}

class PriceAlert {
  final String itemName;
  final double lastKnownPrice;
  final DateTime addedAt;

  PriceAlert({
    required this.itemName,
    required this.lastKnownPrice,
    required this.addedAt,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      itemName: json['item_name'] as String? ?? '',
      lastKnownPrice: (json['last_known_price'] as num?)?.toDouble() ?? 0,
      addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_name': itemName,
        'last_known_price': lastKnownPrice,
        'added_at': addedAt.toIso8601String(),
      };
}

class PriceChangeInfo {
  final String itemName;
  final double oldPrice;
  final double newPrice;
  final double percentChange;
  final bool isPriceDrop;

  PriceChangeInfo({
    required this.itemName,
    required this.oldPrice,
    required this.newPrice,
    required this.percentChange,
    required this.isPriceDrop,
  });

  String get displayText {
    final direction = isPriceDrop ? '📉 Price drop' : '📈 Price increase';
    final pct = percentChange.abs().toStringAsFixed(0);
    return '$direction: $itemName — ${oldPrice.toStringAsFixed(0)} → ${newPrice.toStringAsFixed(0)} RWF ($pct%)';
  }
}
