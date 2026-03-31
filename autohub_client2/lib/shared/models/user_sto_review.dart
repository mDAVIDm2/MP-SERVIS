/// Отзыв пользователя о точке в каталоге. Хранится локально, участвует в пересчёте рейтинга.
class UserStoReview {
  final String id;
  final String stoId;
  final String authorName;
  final int rating;
  final String date;
  final String text;
  final DateTime createdAt;

  const UserStoReview({
    required this.id,
    required this.stoId,
    required this.authorName,
    required this.rating,
    required this.date,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'stoId': stoId,
        'authorName': authorName,
        'rating': rating,
        'date': date,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static UserStoReview fromJson(Map<String, dynamic> map) => UserStoReview(
        id: map['id'] as String? ?? '',
        stoId: map['stoId'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        rating: (map['rating'] as num?)?.toInt() ?? 0,
        date: map['date'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as num?)?.toInt() ?? 0),
      );
}
