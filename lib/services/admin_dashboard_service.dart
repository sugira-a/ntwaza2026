// services/admin_dashboard_service.dart
import 'api/api_service.dart';

class AdminDashboardService {
  final ApiService _apiService;
  
  AdminDashboardService(this._apiService);
  
  // ═══════════════════════════════════════════════════════════════════
  // 1. DASHBOARD STATISTICS (KPIs)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get dashboard statistics and KPIs
  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _apiService.get('/api/admin/dashboard/stats');
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error fetching admin stats: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 2. CUSTOMERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get paginated list of customers
  Future<Map<String, dynamic>> getCustomers({
    int page = 1,
    int perPage = 50,
    String? search,
  }) async {
    try {
      String endpoint = '/api/admin/dashboard/customers?page=$page&per_page=$perPage';
      if (search != null && search.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(search)}';
      }
      
      final response = await _apiService.get(endpoint);
      
      return {
        'customers': response['data'] as List<dynamic>,
        'pagination': response['pagination'] as Map<String, dynamic>,
      };
    } catch (e) {
      print('❌ Error fetching customers: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 3. VENDORS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get paginated list of vendors
  Future<Map<String, dynamic>> getVendors({
    int page = 1,
    int perPage = 50,
    String status = 'all',
    String? search,
  }) async {
    try {
      String endpoint = '/api/admin/dashboard/vendors?page=$page&per_page=$perPage&status=$status';
      if (search != null && search.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(search)}';
      }
      final response = await _apiService.get(endpoint);
      return {
        'vendors': response['data'] as List<dynamic>,
        'pagination': response['pagination'] as Map<String, dynamic>,
      };
    } catch (e) {
      print('❌ Error fetching vendors: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 4. RIDERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get paginated list of riders
  Future<Map<String, dynamic>> getRiders({
    int page = 1,
    int perPage = 50,
    String status = 'all',
  }) async {
    try {
      String endpoint = '/api/admin/dashboard/riders?page=$page&per_page=$perPage&status=$status';
      final response = await _apiService.get(endpoint);
      return {
        'riders': response['data'] as List<dynamic>,
        'pagination': response['pagination'] as Map<String, dynamic>,
      };
    } catch (e) {
      print('❌ Error fetching riders: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 5. SUPPORT TICKETS/COMPLAINTS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get paginated list of support tickets
  Future<Map<String, dynamic>> getComplaints({
    int page = 1,
    int perPage = 50,
    String priority = 'all',
    String status = 'all',
  }) async {
    try {
      String endpoint = '/api/admin/dashboard/complaints?page=$page&per_page=$perPage&priority=$priority&status=$status';
      final response = await _apiService.get(endpoint);
      return {
        'complaints': response['data'] as List<dynamic>,
        'pagination': response['pagination'] as Map<String, dynamic>,
      };
    } catch (e) {
      print('❌ Error fetching complaints: $e');
      rethrow;
    }
  }
  
  /// Submit a new support ticket (customer-facing)
  Future<Map<String, dynamic>> submitComplaint({
    required String subject,
    required String description,
    required String category,
    String priority = 'medium',
  }) async {
    try {
      final response = await _apiService.post(
        '/api/admin/dashboard/complaints/submit',
        {
          'subject': subject,
          'description': description,
          'category': category,
          'priority': priority,
        },
      );
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error submitting complaint: $e');
      rethrow;
    }
  }
  
  /// Resolve a support ticket (admin only)
  Future<void> resolveComplaint({
    required String ticketId,
    required String resolution,
    String status = 'resolved',
  }) async {
    try {
      await _apiService.put(
        '/api/admin/dashboard/complaints/$ticketId/resolve',
        {
          'resolution': resolution,
          'status': status,
        },
      );
    } catch (e) {
      print('❌ Error resolving complaint: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 6. ANALYTICS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Get analytics data
  Future<Map<String, dynamic>> getAnalytics({
    String period = 'monthly',
  }) async {
    try {
      String endpoint = '/api/admin/dashboard/analytics?period=$period';
      final response = await _apiService.get(endpoint);
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error fetching analytics: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // 7. ORDER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════
  
  /// Assign an order to a rider
  Future<Map<String, dynamic>> assignOrderToRider({
    required String orderId,
    required String riderId,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/admin/orders/$orderId/assign-rider',
        {
          'rider_id': riderId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      print('❌ Error assigning order: $e');
      rethrow;
    }
  }
  
  /// Send a message to order participants (customer, vendor, rider)
  Future<void> sendOrderMessage({
    required String orderId,
    required String message,
    List<String> recipients = const ['customer', 'vendor', 'rider'],
  }) async {
    try {
      await _apiService.post(
        '/api/admin/orders/$orderId/message',
        {
          'message': message,
          'recipients': recipients,
          'send_push': true, // Always send push notification
        },
      );
    } catch (e) {
      print('❌ Error sending order message: $e');
      rethrow;
    }
  }
  
  /// Get messages/comments for an order
  Future<List<dynamic>> getOrderMessages(String orderId) async {
    try {
      final response = await _apiService.get('/api/admin/orders/$orderId/messages');
      return response['data'] as List<dynamic>;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('endpoint not found') || msg.contains('404')) {
        return [];
      }
      print('❌ Error fetching order messages: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. REVENUE & FINANCE
  // ═══════════════════════════════════════════════════════════════════

  /// Get revenue report with platform fee, delivery fees, and net revenue
  Future<Map<String, dynamic>> getRevenueReport({
    String period = 'month',
    String? startDate,
    String? endDate,
  }) async {
    try {
      String endpoint = '/api/admin/finance/revenue-report?period=$period';
      if (startDate != null) endpoint += '&start_date=$startDate';
      if (endDate != null) endpoint += '&end_date=$endDate';
      
      final response = await _apiService.get(endpoint);
      return response['report'] as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error fetching revenue report: $e');
      rethrow;
    }
  }

  /// Get financial transactions
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int perPage = 50,
    String? type,
    String? status,
  }) async {
    try {
      String endpoint = '/api/admin/finance/transactions?page=$page&per_page=$perPage';
      if (type != null) endpoint += '&type=$type';
      if (status != null) endpoint += '&status=$status';
      
      final response = await _apiService.get(endpoint);
      return {
        'transactions': response['transactions'] as List<dynamic>,
        'total': response['total'] as int,
        'pages': response['pages'] as int,
      };
    } catch (e) {
      print('❌ Error fetching transactions: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. SUPPORT TICKETS & CUSTOMER ISSUES
  // ═══════════════════════════════════════════════════════════════════

  /// Get support tickets (issues and feedback)
  Future<Map<String, dynamic>> getSupportTickets({
    int page = 1,
    int perPage = 50,
    String? status,
    String? priority,
    String? category,
  }) async {
    try {
      String endpoint = '/api/admin/support/tickets?page=$page&per_page=$perPage';
      if (status != null) endpoint += '&status=$status';
      if (priority != null) endpoint += '&priority=$priority';
      if (category != null) endpoint += '&category=$category';
      
      final response = await _apiService.get(endpoint);
      return {
        'tickets': response['tickets'] as List<dynamic>,
        'total': response['total'] as int,
        'counts': response['counts'] as Map<String, dynamic>,
      };
    } catch (e) {
      print('❌ Error fetching support tickets: $e');
      rethrow;
    }
  }

  /// Get ticket details with messages
  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    try {
      final response = await _apiService.get('/api/admin/support/tickets/$ticketId');
      return response['ticket'] as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error fetching ticket detail: $e');
      rethrow;
    }
  }

  /// Update ticket status
  Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _apiService.post(
        '/api/admin/support/tickets/$ticketId/status',
        {'status': status},
      );
    } catch (e) {
      print('❌ Error updating ticket status: $e');
      rethrow;
    }
  }

  /// Assign ticket to admin
  Future<void> assignTicket(String ticketId, String assignTo) async {
    try {
      await _apiService.post(
        '/api/admin/support/tickets/$ticketId/assign',
        {'assigned_to': assignTo},
      );
    } catch (e) {
      print('❌ Error assigning ticket: $e');
      rethrow;
    }
  }

  /// Reply to support ticket
  Future<void> replyToTicket(String ticketId, String message) async {
    try {
      await _apiService.post(
        '/api/admin/support/tickets/$ticketId/reply',
        {'message': message},
      );
    } catch (e) {
      print('❌ Error replying to ticket: $e');
      rethrow;
    }
  }
}
