import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../core/auth/auth_provider.dart';

import '../../../../core/config/app_config.dart';

import '../../../../core/theme/app_colors.dart';



/// Круглый аватар клиента/профиля по URL (`/profile/avatar/...`) — как [UserProfileAvatar], с Bearer.

class AuthenticatedProfileAvatar extends ConsumerWidget {

  const AuthenticatedProfileAvatar({

    super.key,

    required this.imageUrl,

    required this.fallbackLetter,

    this.size = 36,

  });



  final String? imageUrl;

  final String fallbackLetter;

  final double size;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final letter =

        fallbackLetter.trim().isNotEmpty ? fallbackLetter.trim()[0].toUpperCase() : '?';

    final resolved = AppConfig.resolveApiMediaUrl(imageUrl?.trim() ?? '');

    final token = ref.watch(authProvider).accessToken;



    if (resolved != null &&

        resolved.isNotEmpty &&

        token != null &&

        token.isNotEmpty) {

      return ClipOval(

        child: Image.network(

          resolved,

          key: ValueKey<String>(resolved),

          width: size,

          height: size,

          fit: BoxFit.cover,

          headers: {'Authorization': 'Bearer $token'},

          errorBuilder: (_, __, ___) => _letterCircle(letter),

          loadingBuilder: (context, child, progress) {

            if (progress == null) return child;

            return SizedBox(

              width: size,

              height: size,

              child: Center(

                child: SizedBox(

                  width: size * 0.42,

                  height: size * 0.42,

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                    color: AppColors.primary,

                  ),

                ),

              ),

            );

          },

        ),

      );

    }



    return _letterCircle(letter);

  }



  Widget _letterCircle(String letter) {

    return Container(

      width: size,

      height: size,

      alignment: Alignment.center,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        color: AppColors.nestedBg,

        border: Border.all(color: AppColors.borderLight),

      ),

      child: Text(

        letter,

        style: TextStyle(

          fontSize: size * 0.38,

          fontWeight: FontWeight.w700,

          color: AppColors.primary,

        ),

      ),

    );

  }

}

