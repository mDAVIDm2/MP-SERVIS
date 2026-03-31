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
}
