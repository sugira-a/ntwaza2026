// lib/services/vendor_batch_upload_service.dart
/// Vendor concurrent product upload service
/// Allows uploading multiple products simultaneously with progress tracking

import 'dart:async';
import '../models/product.dart';
import 'api/api_service.dart';

class VendorBatchUploadService {
  final ApiService _apiService = ApiService();
  
  // Track uploads in progress
  final Map<String, StreamController<double>> _uploadProgress = {};
  
  /// Upload multiple products concurrently
  /// Returns list of uploaded products and failed uploads
  Future<BatchUploadResult> uploadProductsBatch(
    List<Map<String, dynamic>> productsData, {
    int maxConcurrent = 3,
    void Function(BatchUploadProgress)? onProgress,
  }) async {
    try {
      print('\n' + '='*60);
      print('📦 BATCH UPLOAD SERVICE: Uploading ${productsData.length} products');
      print('   Max concurrent: $maxConcurrent');
      print('='*60);

      final uploaded = <Product>[];
      final failed = <FailedUpload>[];
      int completed = 0;

      // Create chunks for concurrent processing
      final chunks = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < productsData.length; i += maxConcurrent) {
        chunks.add(productsData.sublist(
          i,
          i + maxConcurrent > productsData.length ? productsData.length : i + maxConcurrent,
        ));
      }

      // Process each chunk concurrently
      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        print('\n📊 Processing chunk ${chunkIndex + 1}/${chunks.length} (${chunk.length} items)');

        final futures = chunk.map((productData) async {
          try {
            final result = await _uploadSingleProduct(productData);
            completed++;
            
            final progress = BatchUploadProgress(
              total: productsData.length,
              completed: completed,
              currentProduct: result.name,
              status: 'Uploaded: ${result.name}',
            );
            onProgress?.call(progress);
            print('  ✅ [$completed/${productsData.length}] ${result.name}');
            
            return result;
          } catch (e) {
            completed++;
            final productName = productData['name'] ?? 'Unknown';
            failed.add(FailedUpload(
              productName: productName,
              error: e.toString(),
              index: productsData.indexOf(productData),
            ));
            
            final progress = BatchUploadProgress(
              total: productsData.length,
              completed: completed,
              currentProduct: productName,
              status: 'Failed: $e',
              isError: true,
            );
            onProgress?.call(progress);
            print('  ❌ [$completed/${productsData.length}] $productName: $e');
            
            return null;
          }
        }).toList();

        final results = await Future.wait(futures);
        uploaded.addAll(results.whereType<Product>());
      }

      print('\n' + '='*60);
      print('✅ BATCH UPLOAD COMPLETE');
      print('   Total: ${productsData.length}');
      print('   Successful: ${uploaded.length}');
      print('   Failed: ${failed.length}');
      print('='*60 + '\n');

      return BatchUploadResult(
        uploaded: uploaded,
        failed: failed,
        totalAttempted: productsData.length,
        successCount: uploaded.length,
        failureCount: failed.length,
      );
    } catch (e) {
      print('❌ FATAL Batch Upload Error: $e');
      rethrow;
    }
  }

  /// Upload single product to backend
  Future<Product> _uploadSingleProduct(Map<String, dynamic> productData) async {
    try {
      final formData = <String, dynamic>{
        'name': productData['name'],
        'description': productData['description'] ?? '',
        'category': productData['category'] ?? 'Uncategorized',
        'price': productData['price'] ?? 0,
        'original_price': productData['original_price'],
        'is_active': productData['is_active'] ?? true,
      };

      // Add optional fields
      if (productData['image_url'] != null) {
        formData['image_url'] = productData['image_url'];
      }
      if (productData['preparation_time'] != null) {
        formData['preparation_time'] = productData['preparation_time'];
      }
      if (productData['modifiers'] != null) {
        formData['modifiers'] = productData['modifiers'];
      }

      final response = await _apiService.post(
        '/api/vendor/products',
        body: formData,
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Upload failed');
      }

      // Parse response to Product model
      final productJson = response['product'] ?? response['data'];
      return Product.fromJson(productJson);
    } catch (e) {
      print('Error uploading single product: $e');
      rethrow;
    }
  }

  /// Track upload progress by product ID
  StreamController<double> createProgressStream(String productId) {
    final controller = StreamController<double>();
    _uploadProgress[productId] = controller;
    return controller;
  }

  /// Update progress for a product
  void updateProgress(String productId, double percentage) {
    _uploadProgress[productId]?.add(percentage);
  }

  /// Clean up progress stream
  void closeProgress(String productId) {
    _uploadProgress[productId]?.close();
    _uploadProgress.remove(productId);
  }

  /// Cleanup all streams
  void dispose() {
    for (var controller in _uploadProgress.values) {
      controller.close();
    }
    _uploadProgress.clear();
  }
}

// Data classes
class BatchUploadResult {
  final List<Product> uploaded;
  final List<FailedUpload> failed;
  final int totalAttempted;
  final int successCount;
  final int failureCount;

  BatchUploadResult({
    required this.uploaded,
    required this.failed,
    required this.totalAttempted,
    required this.successCount,
    required this.failureCount,
  });

  bool get isSuccess => failureCount == 0;
  double get successPercentage => (successCount / totalAttempted * 100).clamp(0, 100);
}

class FailedUpload {
  final String productName;
  final String error;
  final int index;

  FailedUpload({
    required this.productName,
    required this.error,
    required this.index,
  });
}

class BatchUploadProgress {
  final int total;
  final int completed;
  final String currentProduct;
  final String status;
  final bool isError;

  BatchUploadProgress({
    required this.total,
    required this.completed,
    required this.currentProduct,
    required this.status,
    this.isError = false,
  });

  double get percentage => (completed / total * 100).clamp(0, 100);
}
