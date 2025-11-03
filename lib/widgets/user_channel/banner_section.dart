import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/widgets/user_channel/avatar_section.dart';

class BannerSection extends StatelessWidget {
  final bool isEditMode;
  final File? selectedBannerImage;
  final String bannerImageUrl;
  final VoidCallback onPickBanner;

  // Avatar related props (rendered as a child inside the banner stack)
  final bool avatarIsEditMode;
  final File? avatarSelectedImage;
  final String avatarImageUrl;
  final VoidCallback onPickImage;

  const BannerSection({
    super.key,
    required this.isEditMode,
    required this.selectedBannerImage,
    required this.bannerImageUrl,
    required this.onPickBanner,
    required this.avatarIsEditMode,
    required this.avatarSelectedImage,
    required this.avatarImageUrl,
    required this.onPickImage,
  });

  Widget _buildPlaceholderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appColors().primaryColorApp.withOpacity(0.3),
            appColors().primaryColorApp.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48.w, color: Colors.grey[400]),
            SizedBox(height: 8.w),
            Text(
              isEditMode ? 'Tap "Edit Banner" to add' : 'No banner image',
              style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200.w + 80.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 200.w,
            decoration: BoxDecoration(color: Colors.grey[200]),
            child: selectedBannerImage != null
                ? Image.file(
                    selectedBannerImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : (bannerImageUrl.isNotEmpty
                      ? Image.network(
                          bannerImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderBanner(context);
                          },
                        )
                      : _buildPlaceholderBanner(context)),
          ),

          if (isEditMode)
            Positioned(
              top: 16.w,
              right: 16.w,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPickBanner,
                  borderRadius: BorderRadius.circular(10.w),
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10.w),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, color: Colors.white, size: 16.w),
                        SizedBox(width: 6.w),
                        Text(
                          'Edit Banner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Avatar positioned overlapping the banner.
          Positioned(
            left: MediaQuery.of(context).size.width * 0.20 - 70.w,
            bottom: 20.w,
            width: 140.w,
            height: 140.w,
            child: AvatarSection(
              isEditMode: avatarIsEditMode,
              selectedImage: avatarSelectedImage,
              imageUrl: avatarImageUrl,
              onPickImage: onPickImage,
            ),
          ),
        ],
      ),
    );
  }
}
