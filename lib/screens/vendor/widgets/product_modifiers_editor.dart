import 'package:flutter/material.dart';
import '../../../models/product.dart';

class ProductModifiersEditor extends StatefulWidget {
  final List<ProductModifier> initialModifiers;
  final Function(List<ProductModifier>) onModifiersChanged;

  const ProductModifiersEditor({
    Key? key,
    required this.initialModifiers,
    required this.onModifiersChanged,
  }) : super(key: key);

  @override
  State<ProductModifiersEditor> createState() => _ProductModifiersEditorState();
}

class _ProductModifiersEditorState extends State<ProductModifiersEditor> {
  late List<ProductModifier> modifiers;

  @override
  void initState() {
    super.initState();
    modifiers = [...widget.initialModifiers];
  }

  String _generateId() {
    return 'mod_${DateTime.now().millisecondsSinceEpoch}_${modifiers.length}';
  }

  void _addModifierGroup() {
    showDialog(
      context: context,
      builder: (context) => _AddModifierGroupDialog(
        onAdd: (name, description, isRequired, minSelections, maxSelections) {
          setState(() {
            modifiers.add(ProductModifier(
              id: _generateId(),
              name: name,
              description: description,
              isRequired: isRequired,
              minSelections: minSelections,
              maxSelections: maxSelections,
              options: [],
            ));
            widget.onModifiersChanged(modifiers);
          });
        },
      ),
    );
  }

  void _editModifierGroup(int index) {
    final modifier = modifiers[index];
    showDialog(
      context: context,
      builder: (context) => _EditModifierDialog(
        modifier: modifier,
        onSave: (updated) {
          setState(() {
            modifiers[index] = updated;
            widget.onModifiersChanged(modifiers);
          });
        },
      ),
    );
  }

  void _deleteModifierGroup(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Modifier?'),
        content: Text('Are you sure you want to delete "${modifiers[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                modifiers.removeAt(index);
                widget.onModifiersChanged(modifiers);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product Modifiers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addModifierGroup,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Modifiers list
        if (modifiers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              'No modifiers added yet',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modifiers.length,
            itemBuilder: (context, index) {
              final modifier = modifiers[index];
              return _ModifierCard(
                modifier: modifier,
                onEdit: () => _editModifierGroup(index),
                onDelete: () => _deleteModifierGroup(index),
              );
            },
          ),
      ],
    );
  }
}

class _ModifierCard extends StatelessWidget {
  final ProductModifier modifier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModifierCard({
    required this.modifier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and badges
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
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (modifier.description != null && modifier.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          modifier.description!,
                          style: TextStyle(fontSize: 12, color: subtextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (modifier.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            ],
          ),
          const SizedBox(height: 12),

          // Options count
          Text(
            '${modifier.options.length} options • ${modifier.minSelections}-${modifier.maxSelections} selections',
            style: TextStyle(fontSize: 12, color: subtextColor),
          ),
          const SizedBox(height: 12),

          // Options list
          if (modifier.options.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Options:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: modifier.options.map((opt) {
                    return Chip(
                      label: Text(
                        '${opt.name}${opt.priceAdjustment > 0 ? ' +${opt.priceAdjustment.toStringAsFixed(2)}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      side: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 14),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddModifierGroupDialog extends StatefulWidget {
  final Function(String name, String? description, bool isRequired, int minSelections,
      int maxSelections) onAdd;

  const _AddModifierGroupDialog({required this.onAdd});

  @override
  State<_AddModifierGroupDialog> createState() => _AddModifierGroupDialogState();
}

class _AddModifierGroupDialogState extends State<_AddModifierGroupDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isRequired = false;
  int minSelections = 1;
  int maxSelections = 1;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return AlertDialog(
      title: const Text('Add Modifier Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Modifier Name *',
                hintText: 'e.g., Size, Temperature, Extras',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Required'),
              value: isRequired,
              onChanged: (val) => setState(() => isRequired = val ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Min Selections'),
                      const SizedBox(height: 8),
                      DecimalFormField(
                        value: minSelections,
                        onChanged: (val) =>
                            setState(() => minSelections = int.parse(val)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Max Selections'),
                      const SizedBox(height: 8),
                      DecimalFormField(
                        value: maxSelections,
                        onChanged: (val) =>
                            setState(() => maxSelections = int.parse(val)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: nameController.text.isNotEmpty
              ? () {
                  widget.onAdd(
                    nameController.text,
                    descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                    isRequired,
                    minSelections,
                    maxSelections,
                  );
                  Navigator.pop(context);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _EditModifierDialog extends StatefulWidget {
  final ProductModifier modifier;
  final Function(ProductModifier) onSave;

  const _EditModifierDialog({
    required this.modifier,
    required this.onSave,
  });

  @override
  State<_EditModifierDialog> createState() => _EditModifierDialogState();
}

class _EditModifierDialogState extends State<_EditModifierDialog> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late bool isRequired;
  late int minSelections;
  late int maxSelections;
  late List<ModifierOption> options;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.modifier.name);
    descriptionController =
        TextEditingController(text: widget.modifier.description ?? '');
    isRequired = widget.modifier.isRequired;
    minSelections = widget.modifier.minSelections;
    maxSelections = widget.modifier.maxSelections;
    options = List.from(widget.modifier.options);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _addOption() {
    showDialog(
      context: context,
      builder: (context) => _AddOptionDialog(
        onAdd: (name, description, priceAdjustment) {
          setState(() {
            options.add(ModifierOption(
              id: 'opt_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              description: description,
              priceAdjustment: priceAdjustment,
              isDefault: false,
              isAvailable: true,
            ));
          });
        },
      ),
    );
  }

  void _deleteOption(int index) {
    setState(() => options.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Modifier Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Modifier Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Required'),
              value: isRequired,
              onChanged: (val) => setState(() => isRequired = val ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Min Selections'),
                      const SizedBox(height: 8),
                      DecimalFormField(
                        value: minSelections,
                        onChanged: (val) =>
                            setState(() => minSelections = int.parse(val)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Max Selections'),
                      const SizedBox(height: 8),
                      DecimalFormField(
                        value: maxSelections,
                        onChanged: (val) =>
                            setState(() => maxSelections = int.parse(val)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Options',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Option'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (options.isEmpty)
              const Text('No options added yet', style: TextStyle(fontSize: 12))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              if (option.priceAdjustment > 0)
                                Text(
                                  '+${option.priceAdjustment.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteOption(index),
                          icon: const Icon(Icons.delete, size: 16),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          splashRadius: 14,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: nameController.text.isNotEmpty
              ? () {
                  widget.onSave(ProductModifier(
                    id: widget.modifier.id,
                    name: nameController.text,
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                    isRequired: isRequired,
                    minSelections: minSelections,
                    maxSelections: maxSelections,
                    options: options,
                  ));
                  Navigator.pop(context);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _AddOptionDialog extends StatefulWidget {
  final Function(String name, String? description, double priceAdjustment)
      onAdd;

  const _AddOptionDialog({required this.onAdd});

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Option'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Option Name *',
              hintText: 'e.g., Large, Hot, With Soda',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            decoration: InputDecoration(
              labelText: 'Price Adjustment',
              hintText: '0.00',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: nameController.text.isNotEmpty
              ? () {
                  final price =
                      double.tryParse(priceController.text) ?? 0;
                  widget.onAdd(
                    nameController.text,
                    descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                    price,
                  );
                  Navigator.pop(context);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Helper widget for decimal input
class DecimalFormField extends StatefulWidget {
  final int value;
  final ValueChanged<String> onChanged;

  const DecimalFormField({
    required this.value,
    required this.onChanged,
  });

  @override
  State<DecimalFormField> createState() => _DecimalFormFieldState();
}

class _DecimalFormFieldState extends State<DecimalFormField> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: widget.onChanged,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
