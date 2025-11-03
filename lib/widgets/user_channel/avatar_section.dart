import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class AvatarSection extends StatelessWidget {
  final bool isEditMode;
  final File? selectedImage;
  final String imageUrl;
  final VoidCallback onPickImage;

  const AvatarSection({
    super.key,
    required this.isEditMode,
    required this.selectedImage,
    required this.imageUrl,
    required this.onPickImage,
  });

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: appColors().primaryColorApp.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 60.w,
          color: appColors().primaryColorApp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: isEditMode ? onPickImage : null,
          child: Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  appColors().primaryColorApp,
                  appColors().primaryColorApp.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(
                  child: selectedImage != null
                      ? Image.file(selectedImage!, fit: BoxFit.cover)
                      : (imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholderAvatar();
                                },
                              )
                            : _buildPlaceholderAvatar()),
                ),
              ),
            ),
          ),
        ),

        if (isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(50.w),
              child: InkWell(
                onTap: onPickImage,
                borderRadius: BorderRadius.circular(50.w),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20.w,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
