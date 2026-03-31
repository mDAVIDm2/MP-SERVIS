/// Импортированный отзыв (например с Авито): автор, оценка, дата, текст.
/// Может храниться локально или на бэкенде, привязан к userId (или stoId для партнёров).
class ImportedReview {
  final String id;
  final String authorName;
  final int rating;
  final String date;
  final String text;
  final String source;

  const ImportedReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.date,
    required this.text,
    this.source = 'avito',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'rating': rating,
        'date': date,
        'text': text,
        'source': source,
      };

  static ImportedReview fromJson(Map<String, dynamic> map) => ImportedReview(
        id: map['id'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        rating: (map['rating'] as num?)?.toInt() ?? 0,
        date: map['date'] as String? ?? '',
        text: map['text'] as String? ?? '',
        source: map['source'] as String? ?? 'avito',
      );
}
