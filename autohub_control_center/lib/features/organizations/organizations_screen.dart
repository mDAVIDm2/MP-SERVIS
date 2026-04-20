import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/media_url_resolver.dart';
import '../sections/section_scaffold.dart';

Widget _orgPlaceholderAvatar() {
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.business_rounded, color: AppColors.primary),
  );
}

class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(organizationsProvider);
    return SectionScaffold(
      title: 'Организации',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Поиск по названию, адресу, телефону...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          async.when(
            data: (items) {
              final filtered = _searchQuery.isEmpty
                  ? items
                  : items.where((e) {
                      final name = (e['name'] as String? ?? '').toLowerCase();
                      final address = (e['address'] as String? ?? '').toLowerCase();
                      final phone = (e['phone'] as String? ?? '').toLowerCase();
                      return name.contains(_searchQuery) || address.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();
              if (filtered.isEmpty) {
                return _emptyCard(_searchQuery.isEmpty ? 'Нет организаций' : 'Ничего не найдено');
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
              final e = filtered[index];
              final name = e['name'] as String? ?? '';
              final address = e['address'] as String? ?? '';
              final phone = e['phone'] as String? ?? '';
              final id = e['id'] as String? ?? '';
              final workingHours = e['working_hours'] as String?;
              final timezone = e['timezone'] as String?;
              final sub = e['subscription'];
              final isActive = sub is Map && sub['is_active'] == true;
              final photosRaw = e['photo_urls'];
              String? firstPhoto;
              if (photosRaw is List && photosRaw.isNotEmpty) {
                firstPhoto = resolvePublicMediaUrl(photosRaw.first?.toString());
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/app/organizations/$id'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: firstPhoto != null && firstPhoto.isNotEmpty
                              ? Image.network(
                                  firstPhoto,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _orgPlaceholderAvatar(),
                                )
                              : _orgPlaceholderAvatar(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'Без названия',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  address,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (workingHours != null && workingHours.toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  workingHours.toString(),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                              if (timezone != null && timezone.toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Часовой пояс: $timezone', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                              ],
                              if (sub is Map) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFDCFCE7) : AppColors.border.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'Подписка активна' : 'Подписка неактивна',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isActive ? const Color(0xFF166534) : AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.navInactive),
                      ],
                    ),
                  ),
                ),
              );
                },
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => _errorCard(e),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ),
        ),
      );

  Widget _errorCard(Object e) => Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Ошибка загрузки: $e', style: const TextStyle(color: AppColors.danger)),
        ),
      );
}
