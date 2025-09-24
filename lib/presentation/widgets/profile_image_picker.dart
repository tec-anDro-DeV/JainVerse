import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class ProfileImagePicker extends StatelessWidget {
  final bool hasCustomImage;
  final File? selectedImage;
  final String? networkImageUrl;
  final VoidCallback onImageTap;

  const ProfileImagePicker({
    super.key,
    required this.hasCustomImage,
    this.selectedImage,
    this.networkImageUrl,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Profile image container
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 180,
              margin: const EdgeInsets.fromLTRB(15, 25, 15, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors().colorBackEditText,
                border: Border.all(color: const Color(0xa64f5055)),
              ),
              child: Container(
                width: 200,
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 72.0,
                  backgroundColor: const Color(0xfffcf7f8),
                  backgroundImage: _getImageProvider(),
                ),
              ),
            ),
          ),
          // Edit button
          Positioned(
            bottom: 14,
            right: 40,
            child: GestureDetector(
              onTap: onImageTap,
              child: CircleAvatar(
                backgroundColor: appColors().red,
                radius: 15.0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/icons/edit.png',
                    color: appColors().white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider() {
    if (hasCustomImage && selectedImage != null) {
      return FileImage(selectedImage!);
    } else if (networkImageUrl != null && networkImageUrl!.isNotEmpty) {
      return NetworkImage(networkImageUrl!);
    } else {
      return const AssetImage('assets/icons/user2.png');
    }
  }
}

class ImagePickerBottomSheet extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  const ImagePickerBottomSheet({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      height: MediaQuery.of(context).size.height * 0.29,
      decoration: BoxDecoration(
        color: appColors().colorBackEditText,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.all(7),
            child: Text(
              'From where would you like to \ntake the image?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: Platform.isAndroid ? 18 : 20,
                color: appColors().colorTextSideDrawer,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPickerOption(
                icon: 'assets/images/Camera.png',
                label: 'Camera',
                onTap: onCameraTap,
              ),
              _buildPickerOption(
                icon: 'assets/images/Gallery.png',
                label: 'Gallery',
                onTap: onGalleryTap,
              ),
              _buildPickerOption(
                icon: 'assets/images/Cancel.png',
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerOption({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            backgroundColor: const Color(0xff161826),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Image.asset(icon),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: Platform.isAndroid ? 13 : 18,
            color: appColors().colorText,
          ),
        ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required VoidCallback onCameraTap,
    required VoidCallback onGalleryTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ImagePickerBottomSheet(
            onCameraTap: onCameraTap,
            onGalleryTap: onGalleryTap,
          ),
    );
  }
}
