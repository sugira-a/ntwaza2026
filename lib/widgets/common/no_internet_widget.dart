import 'package:flutter/material.dart';

/// A professional "no internet" banner / full-screen widget.
class NoInternetWidget extends StatelessWidget {
  /// If non-null, displayed as a retry button callback.
  final VoidCallback? onRetry;

  /// When true, renders as a compact banner instead of a full-screen placeholder.
  final bool compact;

  const NoInternetWidget({
    super.key,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return _buildBanner(isDark);
    }

    return _buildFullScreen(isDark);
  }

  Widget _buildBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF3E0),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No internet connection',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                ),
              ),
            ),
            if (onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'RETRY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final iconColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      color: bgColor,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade800.withOpacity(0.5)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your Wi-Fi or mobile data\nand try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (onRetry != null)
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
