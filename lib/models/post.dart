class Post {
  final int? id; 
  final String title;
  final String body;
  final int? userId;
  final String? status;
  final String? imageUrl; 
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Post({
    this.id, 
    required this.title,
    this.body = '',
    this.userId,
    this.status,
    this.imageUrl, 
    this.createdAt,
    this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Fungsi pembantu untuk mengonversi nilai apa pun dari DB menjadi int secara aman
    int? parseIntAman(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Post(
      // Menggunakan parseIntAman agar ID besar (int8) tidak crash saat di-parsing
      id: parseIntAman(json['id']),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      userId: parseIntAman(json['user_id']),
      status: json['status']?.toString(),
      
      // CATATAN: Pastikan di database Supabase Anda nama kolomnya 'image_url' (pakai underscore)
      imageUrl: json['image_url']?.toString(), 
      
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id, 
      'title': title,
      'body': body,
      'user_id': userId,
      'status': status,
      'image_url': imageUrl, 
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Post copyWith({
    int? id,
    String? title,
    String? body,
    int? userId,
    String? status,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}