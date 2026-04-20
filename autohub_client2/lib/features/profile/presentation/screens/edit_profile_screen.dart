import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/common_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _initializedFromUser = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    final notifier = ref.read(authProvider.notifier);
    final result = kIsWeb
        ? await notifier.uploadAvatar(
            bytes: await picked.readAsBytes(),
            filename: picked.name,
          )
        : await notifier.uploadAvatar(filePath: picked.path);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Фото обновлено'), backgroundColor: context.palette.success),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: context.palette.error),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user != null && !_initializedFromUser) {
      _initializedFromUser = true;
      final parts = user.name.trim().split(RegExp(r'\s+'));
      _nameController.text = parts.isNotEmpty ? parts.first : user.name;
      _surnameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : (user.surname ?? '');
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email ?? '';
    }
    final initials = user?.initials ?? '?';
    final rawAvatar = user?.avatarUrl?.trim() ?? '';
    final avatarResolved = rawAvatar.isNotEmpty ? AppConfig.resolveProfileAvatarUrl(rawAvatar) : '';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Редактировать профиль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.nestedBg,
                    border: Border.all(color: context.palette.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _uploadingAvatar
                      ? Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                          ),
                        )
                      : avatarResolved.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarResolved,
                              cacheKey: avatarResolved,
                              fit: BoxFit.cover,
                              httpHeaders: ref.read(authProvider).accessToken != null
                                  ? {'Authorization': 'Bearer ${ref.read(authProvider).accessToken}'}
                                  : null,
                              placeholder: (_, __) => Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.primary,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: context.palette.primary,
                                ),
                              ),
                            ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.palette.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.palette.background, width: 3),
                      ),
                      child: Icon(Icons.camera_alt_rounded, size: 18, color: context.palette.onAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Нажмите на значок камеры, чтобы выбрать фото',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
            ),
          ),
          SizedBox(height: 24),
          _buildField('Имя', _nameController),
          SizedBox(height: 16),
          _buildField('Фамилия', _surnameController),
          SizedBox(height: 16),
          _buildField('Email', _emailController, keyboardType: TextInputType.emailAddress),
          SizedBox(height: 16),
          _buildField('Телефон', _phoneController, keyboardType: TextInputType.phone, enabled: false),
          SizedBox(height: 8),
          Text(
            'Для смены номера обратитесь в поддержку',
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: context.palette.cardBg,
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: GoldButton(
          text: 'Сохранить',
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final name = _nameController.text.trim();
            final surname = _surnameController.text.trim();
            await ref.read(authProvider.notifier).updateProfile(
                  name: name.isEmpty ? null : name,
                  surname: surname.isEmpty ? null : surname,
                );
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Профиль обновлён'), backgroundColor: context.palette.success),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: context.palette.textSecondary)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? context.palette.cardBg : context.palette.nestedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.palette.border),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 16, color: enabled ? context.palette.textPrimary : context.palette.textTertiary),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
