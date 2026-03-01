import 'api/api_service.dart';

class AiAssistantService {
  final ApiService _apiService = ApiService();

  Future<String> sendMessage({
    required String message,
    Map<String, dynamic>? context,
  }) async {
    final response = await _apiService.post('/api/ai/assistant', {
      'message': message,
      'context': context ?? {},
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      return (response['reply'] ?? '').toString();
    }

    final error = response is Map<String, dynamic>
        ? (response['error'] ?? 'AI assistant unavailable')
        : 'AI assistant unavailable';
    throw Exception(error);
  }
}
