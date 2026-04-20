/// Заметка в профиле, привязанная к автомобилю.
class ProfileNote {
  final String id;
  final String carId;
  final String title;
  final String body;
  final DateTime date;

  const ProfileNote({
    required this.id,
    required this.carId,
    required this.title,
    required this.body,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'carId': carId,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
      };

  factory ProfileNote.fromJson(Map<String, dynamic> m) {
    return ProfileNote(
      id: '${m['id'] ?? ''}',
      carId: '${m['carId'] ?? m['car_id'] ?? ''}',
      title: '${m['title'] ?? ''}',
      body: '${m['body'] ?? ''}',
      date: DateTime.tryParse('${m['date'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
