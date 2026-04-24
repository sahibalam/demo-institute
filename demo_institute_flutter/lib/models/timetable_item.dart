class TimetableItem {
  TimetableItem({
    required this.klass,
    required this.section,
    required this.title,
    required this.webViewLink,
    required this.webContentLink,
    required this.fileId,
  });

  final String klass;
  final String section;
  final String title;
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

  factory TimetableItem.fromJson(dynamic json) {
    final map = (json is Map) ? json : const {};
    final title = (map['title'] ?? map['fileName'] ?? 'Time-table').toString().trim();
    return TimetableItem(
      klass: (map['class'] ?? '').toString().trim(),
      section: (map['section'] ?? '').toString().trim(),
      title: title,
      webViewLink: (map['webViewLink'] ?? '').toString(),
      webContentLink: (map['webContentLink'] ?? '').toString(),
      fileId: (map['fileId'] ?? '').toString().trim(),
    );
  }
}
