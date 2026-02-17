import '../utils/helpers.dart';

class Notification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;  // Add this
  final DateTime? readAt;    // Optional: add this too

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.data,
    required this.createdAt,  // Add this
    this.readAt,              // Add this
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['is_read'] ?? false,
      data: json['data'],
      createdAt: parseServerTime(json['created_at']),
      readAt: json['read_at'] != null ? parseServerTime(json['read_at']) : null,
    );
  }

  // Add a getter for formatted time
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // Add a getter for formatted date
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  // Add a getter for full datetime
  String get formattedDateTime {
    return '$formattedDate at $formattedTime';
  }

  // Keep your existing timeAgo getter
  String get timeAgo {
    final label = timeAgoFrom(createdAt);
    if (label.endsWith('d ago')) {
      final days = int.tryParse(label.split('d').first) ?? 0;
      if (days >= 7) {
        return formattedDate;
      }
    }
    return label;
  }

  Notification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,  // Add this
      readAt: readAt ?? this.readAt,            // Add this
    );
  }

  @override
  String toString() {
    return 'Notification(id: $id, title: $title, isRead: $isRead, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}