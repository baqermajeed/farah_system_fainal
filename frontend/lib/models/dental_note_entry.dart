class DentalNoteEntry {
  final String text;
  final DateTime createdAt;

  const DentalNoteEntry({
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DentalNoteEntry.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    return DentalNoteEntry(
      text: json['text']?.toString() ?? '',
      createdAt: createdAtRaw is String
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
