class MaterialItem {
  MaterialItem({
    required this.klass,
    required this.subject,
    required this.chapter,
    required this.title,
    required this.category,
    required this.year,
    required this.webViewLink,
    required this.webContentLink,
    required this.fileId,
  });

  final String klass;
  final String subject;
  final String chapter;
  final String title;
  final String category;
  final String year;
  final String webViewLink;
  final String webContentLink;
  final String fileId;

  String get bestLink {
    final a = webViewLink.trim();
    if (a.isNotEmpty) return a;
    final b = webContentLink.trim();
    if (b.isNotEmpty) return b;
    return '';
  }

  factory MaterialItem.fromJson(dynamic json) {
    final map = (json is Map) ? json : const {};
    return MaterialItem(
      klass: (map['class'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      chapter: (map['chapter'] ?? '').toString().trim(),
      title: (map['title'] ?? map['fileName'] ?? '').toString().trim(),
      category: (map['category'] ?? '').toString().trim().toLowerCase(),
      year: (map['year'] ?? '').toString().trim(),
      webViewLink: (map['webViewLink'] ?? '').toString(),
      webContentLink: (map['webContentLink'] ?? '').toString(),
      fileId: (map['fileId'] ?? '').toString().trim(),
    );
  }
}
