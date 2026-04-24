class Announcement {
  Announcement({
    required this.klass,
    required this.section,
    required this.text,
  });

  final String klass;
  final String section;
  final String text;

  factory Announcement.fromJson(dynamic json) {
    final map = (json is Map) ? json : const {};
    return Announcement(
      klass: (map['class'] ?? '').toString().trim(),
      section: (map['section'] ?? '').toString().trim(),
      text: (map['text'] ?? '').toString().trim(),
    );
  }
}
