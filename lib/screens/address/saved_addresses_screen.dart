// lib/screens/address/saved_addresses_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/delivery_address.dart';
import '../map/location_picker_screen.dart';

class SavedAddressesScreen extends StatelessWidget {
  final bool isSelecting; // true when selecting for checkout

  const SavedAddressesScreen({super.key, this.isSelecting = false});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isSelecting ? 'Select Address' : 'Saved Addresses',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: addressProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : addressProvider.hasAddresses
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addressProvider.savedAddresses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Add New Address button
                      return _buildAddNewButton(context, isDarkMode, cardColor, textColor);
                    }

                    final address = addressProvider.savedAddresses[index - 1];
                    return _buildAddressCard(
                      context,
                      address,
                      addressProvider,
                      isDarkMode,
                      cardColor,
                      textColor,
                      subtextColor,
                    );
                  },
                )
              : _buildEmptyState(context, isDarkMode, cardColor, textColor, subtextColor),
    );
  }

  Widget _buildAddNewButton(BuildContext context, bool isDarkMode, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationPickerScreen(),
            ),
          );

          if (result != null && isSelecting) {
            Navigator.pop(context, result);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E7D32),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_location_alt,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick location on map',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    DeliveryAddress address,
    AddressProvider provider,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isSelecting
            ? () {
                provider.selectAddress(address);
                provider.markAddressAsUsed(address.id);
                Navigator.pop(context, address);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: address.isDefault
                ? Border.all(color: const Color(0xFF2E7D32), width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    address.label == 'Home'
                        ? Icons.home
                        : address.label == 'Work'
                            ? Icons.work
                            : Icons.location_on,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      address.label ?? 'Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: subtextColor),
                    itemBuilder: (context) => [
                      if (!address.isDefault)
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, size: 20),
                              SizedBox(width: 12),
                              Text('Set as Default'),
                            ],
                          ),
                          onTap: () => provider.setDefaultAddress(address.id),
                        ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                        onTap: () async {
                          await Future.delayed(Duration.zero);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationPickerScreen(
                                initialAddress: address,
                              ),
                            ),
                          );
                        },
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: () {
                          Future.delayed(Duration.zero, () {
                            _showDeleteDialog(context, address, provider);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address.fullAddress,
                style: TextStyle(
                  fontSize: 14,
                  color: subtextColor,
                ),
              ),
              if (address.additionalInfo != null) ...[
                const SizedBox(height: 4),
                Text(
                  address.additionalInfo!,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 120,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Addresses',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your delivery addresses for faster checkout',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationPickerScreen(),
                  ),
                );

                if (result != null && isSelecting) {
                  Navigator.pop(context, result);
                }
              },
              icon: const Icon(Icons.add_location),
              label: const Text('Add Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, DeliveryAddress address, AddressProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address?'),
        content: Text('Are you sure you want to delete "${address.label ?? 'this address'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteAddress(address.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}