/// Ответ GET `/organizations/:orgId/client-cars/:carId/transfer-insight` (Business).
class CarTransferInsight {
  final bool showNotice;
  final String message;
  final String? lastEventAt;

  const CarTransferInsight({
    required this.showNotice,
    required this.message,
    this.lastEventAt,
  });

  factory CarTransferInsight.fromJson(Map<String, dynamic> j) {
    return CarTransferInsight(
      showNotice: j['show_notice'] == true,
      message: j['message'] as String? ?? '',
      lastEventAt: j['last_event_at'] as String?,
    );
  }
}
