class LectureItem {
  LectureItem({
    required this.klass,
    required this.section,
    required this.subject,
    required this.youtubeUrl,
  });

  final String klass;
  final String section;
  final String subject;
  final String youtubeUrl;

  factory LectureItem.fromJson(dynamic json) {
    final map = (json is Map) ? json : const {};
    return LectureItem(
      klass: (map['class'] ?? '').toString().trim(),
      section: (map['section'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      youtubeUrl: (map['youtubeUrl'] ?? '').toString().trim(),
    );
  }
}
