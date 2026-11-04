import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../data/models/user_profile.dart';

/// A circular profile picture — the uploaded photo when there is one, otherwise
/// the person's initials (or a generic icon for a guest). With [onCameraTap] a
/// small camera badge sits on its lower-right edge.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.size = 64,
    this.onCameraTap,
  });

  final UserProfile? profile;
  final double size;
  final VoidCallback? onCameraTap;

  String get _initials {
    final p = profile;
    if (p == null) return '';
    final first = p.firstName.trim();
    final last = p.lastName.trim();
    return [
      if (first.isNotEmpty) first[0],
      if (last.isNotEmpty) last[0],
    ].join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = profile?.avatarUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initials = _initials;

    // Initials, or a generic person for a guest — also what shows if the photo
    // can't be loaded.
    final fallback = initials.isNotEmpty
        ? Text(
            initials,
            style: TextStyle(
              color: AppColors.brand400,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
            ),
          )
        : Icon(
            Icons.person_rounded,
            color: AppColors.brand400,
            size: size * 0.5,
          );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brand400.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: hasPhoto
                ? CachedNetworkImage(
                    imageUrl: photo,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    errorWidget: (context, url, error) => fallback,
                  )
                : fallback,
          ),
          if (onCameraTap != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onCameraTap,
                child: Container(
                  width: size * 0.36,
                  height: size * 0.36,
                  decoration: BoxDecoration(
                    color: AppColors.lightInk,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: size * 0.18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
