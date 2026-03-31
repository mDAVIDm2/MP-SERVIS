import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../../shared/models/user_sto_review.dart';

const _kStoReviewsPrefix = 'sto_user_reviews_';

final stoReviewsProvider = StateNotifierProvider<StoReviewsNotifier, List<UserStoReview>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  return StoReviewsNotifier(prefs, userId);
});

class StoReviewsNotifier extends StateNotifier<List<UserStoReview>> {
  StoReviewsNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));
  final SharedPreferences? _prefs;
  final String? _userId;

  String get _key => _kStoReviewsPrefix + (_userId ?? '');

  static List<UserStoReview> _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null) return [];
    final raw = prefs.getString(_kStoReviewsPrefix + userId);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => UserStoReview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    if (_prefs == null || _userId == null) return;
    final list = state.map((e) => e.toJson()).toList();
    await _prefs!.setString(_key, jsonEncode(list));
  }

  List<UserStoReview> forSto(String stoId) =>
      state.where((r) => r.stoId == stoId).toList();

  /// Добавить отзыв; [id] — уникальный id (например uuid или timestamp).
  Future<void> add(UserStoReview review) async {
    state = [...state, review];
    await _save();
  }

  /// Пересчёт рейтинга точки с учётом отзывов пользователей и базовых данных каталога.
  static double computedRating(double baseRating, int baseReviewCount, List<UserStoReview> userReviews) {
    if (userReviews.isEmpty) return baseRating;
    final baseSum = baseRating * baseReviewCount;
    final userSum = userReviews.fold<int>(0, (s, r) => s + r.rating);
    final totalCount = baseReviewCount + userReviews.length;
    return (baseSum + userSum) / totalCount;
  }

  static int computedReviewCount(int baseReviewCount, List<UserStoReview> userReviews) =>
      baseReviewCount + userReviews.length;
}
