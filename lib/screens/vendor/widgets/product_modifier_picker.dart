import 'package:flutter/material.dart';
import '../../../models/product.dart';

/// Customer-facing dialog for selecting product modifiers when adding to cart
class ProductModifierPicker extends StatefulWidget {
  final List<ProductModifier> modifiers;
  final Function(Map<String, ModifierOption>) onModifiersSelected;
  final Map<String, ModifierOption>? initialSelection;

  const ProductModifierPicker({
    Key? key,
    required this.modifiers,
    required this.onModifiersSelected,
    this.initialSelection,
  }) : super(key: key);

  @override
  State<ProductModifierPicker> createState() => _ProductModifierPickerState();
}

class _ProductModifierPickerState extends State<ProductModifierPicker> {
  late Map<String, List<ModifierOption>> selectedOptions;

  @override
  void initState() {
    super.initState();
    selectedOptions = {};
    for (final modifier in widget.modifiers) {
      selectedOptions[modifier.id] = [];
      // Initialize with existing selections if provided
      if (widget.initialSelection != null && widget.initialSelection!.containsKey(modifier.id)) {
        selectedOptions[modifier.id] = [widget.initialSelection![modifier.id]!];
      }
    }
  }

  bool get _allRequiredSelected {
    for (final modifier in widget.modifiers) {
      if (modifier.isRequired) {
        final selected = selectedOptions[modifier.id] ?? [];
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  double get _totalModifierPrice {
    double total = 0;
    selectedOptions.forEach((_, options) {
      total += options.fold(0.0, (sum, opt) => sum + opt.priceAdjustment);
    });
    return total;
  }

  void _toggleOption(ProductModifier modifier, ModifierOption option) {
    setState(() {
      final selected = selectedOptions[modifier.id] ?? [];
      final optionIndex = selected.indexWhere((o) => o.id == option.id);

      if (optionIndex >= 0) {
        // Already selected, remove it
        selected.removeAt(optionIndex);
      } else {
        // Not selected
        if (modifier.maxSelections == 1) {
          // Single selection: clear previous
          selected.clear();
        } else if (selected.length >= modifier.maxSelections) {
          // Max reached: remove first to make room
          selected.removeAt(0);
        }
        selected.add(option);
      }

      selectedOptions[modifier.id] = selected;
      _notifyParent();
    });
  }

  void _notifyParent() {
    // Convert Map<String, List<ModifierOption>> back to Map<String, ModifierOption>
    // Taking the first/only option for each modifier
    Map<String, ModifierOption> result = {};
    selectedOptions.forEach((modifierId, options) {
      if (options.isNotEmpty) {
        result[modifierId] = options.first;
      }
    });
    widget.onModifiersSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    if (widget.modifiers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customize your order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select your preferences below',
              style: TextStyle(fontSize: 13, color: subtextColor),
            ),
            const SizedBox(height: 16),

            // Modifiers list
            Expanded(
              child: ListView.builder(
                itemCount: widget.modifiers.length,
                itemBuilder: (context, index) {
                  final modifier = widget.modifiers[index];
                  final selectedList = selectedOptions[modifier.id] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modifier title and selection info
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modifier.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                if (modifier.description != null &&
                                    modifier.description!.isNotEmpty)
                                  Text(
                                    modifier.description!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (modifier.isRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Required',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (modifier.maxSelections > 1)
                                Text(
                                  'Pick ${selectedList.length}/${modifier.maxSelections}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtextColor,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Options grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: modifier.options
                            .where((opt) => opt.isAvailable)
                            .map((option) {
                          final isSelected =
                              selectedList.any((o) => o.id == option.id);

                          return GestureDetector(
                            onTap: () => _toggleOption(modifier, option),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2E7D32)
                                    : bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2E7D32)
                                      : (isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    option.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : textColor,
                                    ),
                                  ),
                                  if (option.priceAdjustment > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '+${option.priceAdjustment.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.green[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                  );
                },
              ),
            ),

            // Footer with price and confirm button
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Price summary
                  if (_totalModifierPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Modifier price:',
                            style: TextStyle(
                              fontSize: 13,
                              color: subtextColor,
                            ),
                          ),
                          Text(
                            '+${_totalModifierPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Confirmation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _allRequiredSelected
                          ? () => Navigator.pop(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _allRequiredSelected
                            ? 'Confirm Selection'
                            : 'Select all required options',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

