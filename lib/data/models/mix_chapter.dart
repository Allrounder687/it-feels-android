class MixChapter {
  final String title;
  final int startSeconds;
  final int? endSeconds;
  const MixChapter({
    required this.title,
    required this.startSeconds,
    this.endSeconds,
  });
  factory MixChapter.fromJson(Map<String, dynamic> j) {
    final title = j['title']?.toString().trim() ?? '';
    final start = j['start'] is num ? (j['start'] as num).toInt() : -1;
    final end = j['end'] is num ? (j['end'] as num).toInt() : null;
    if (title.isEmpty || start < 0 || (end != null && end <= start)) {
      throw const FormatException('Invalid chapter');
    }
    return MixChapter(title: title, startSeconds: start, endSeconds: end);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'start': startSeconds,
    if (endSeconds != null) 'end': endSeconds,
  };
}
