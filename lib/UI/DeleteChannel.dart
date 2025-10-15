import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/presenters/channel_presenter.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';

class DeleteChannel extends StatefulWidget {
  final int channelId;
  final String channelName;

  const DeleteChannel({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<DeleteChannel> createState() => _DeleteChannelState();
}

class _DeleteChannelState extends State<DeleteChannel> {
  bool _loading = false;
  // No typed confirmation per new requirement

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  @override
  void initState() {
    super.initState();
    // Initialize audio handler for mini player detection
    _audioHandler = const MyApp().called();
  }

  @override
  void dispose() {
    // no controller to dispose anymore
    super.dispose();
  }

  Future<void> _attemptDelete() async {
    setState(() => _loading = true);

    try {
      final presenter = ChannelPresenter();
      final resp = await presenter.deleteChannel(widget.channelId);
      setState(() => _loading = false);

      if (resp['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp['msg']?.toString() ?? 'Channel deleted'),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resp['msg']?.toString() ?? 'Could not delete channel',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Delete Channel'),
        centerTitle: true,
      ),
      body: StreamBuilder<MediaItem?>(
        stream: _audioHandler?.mediaItem,
        builder: (context, snapshot) {
          // Calculate proper bottom padding accounting for mini player and navigation
          final hasMiniPlayer = snapshot.hasData;
          final bottomPadding =
              hasMiniPlayer
                  ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 60.w
                  : AppSizes.basePadding + AppSizes.miniPlayerPadding + 50.w;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20.w,
              right: 20.w,
              top: 24.w,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Icon Header
                Center(
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      size: 60.w,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                SizedBox(height: 24.w),

                // Main Title
                Center(
                  child: Text(
                    'Delete Channel?',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: appColors().colorTextHead,
                    ),
                  ),
                ),
                SizedBox(height: 8.w),

                // Channel Name Display
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.w,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.w),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      widget.channelName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: appColors().colorTextHead,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.w),

                // Warning Container
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12.w),
                    border: Border.all(color: Colors.orange[200]!, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 24.w,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This action is permanent',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                            SizedBox(height: 6.w),
                            Text(
                              'You cannot undo this action once confirmed.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.w),

                // What will be deleted section
                Text(
                  'What will be deleted:',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: appColors().colorTextHead,
                  ),
                ),
                SizedBox(height: 12.w),

                _buildDeleteItem(
                  Icons.video_library_outlined,
                  'All videos and content',
                ),
                SizedBox(height: 10.w),
                _buildDeleteItem(
                  Icons.people_outline,
                  'All followers and subscribers',
                ),
                SizedBox(height: 10.w),
                _buildDeleteItem(
                  Icons.comment_outlined,
                  'Comments and interactions',
                ),
                SizedBox(height: 10.w),
                _buildDeleteItem(
                  Icons.settings_outlined,
                  'Channel settings and customizations',
                ),
                SizedBox(height: 10.w),
                _buildDeleteItem(
                  Icons.analytics_outlined,
                  'Analytics and statistics',
                ),
                SizedBox(height: 24.w),

                // Processing time notice
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10.w),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.blue[700], size: 20.w),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Deletion may take from a few minutes up to several days depending on your content volume.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.blue[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.w),

                // Delete Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: EdgeInsets.symmetric(vertical: 16.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      elevation: 2,
                    ),
                    onPressed: !_loading ? _attemptDelete : null,
                    child:
                        _loading
                            ? SizedBox(
                              height: 20.w,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_forever, size: 20.w),
                                SizedBox(width: 8.w),
                                Text(
                                  'Delete Channel Permanently',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                SizedBox(height: 12.w),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                    ),
                    onPressed:
                        _loading
                            ? null
                            : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: appColors().colorTextHead,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.w),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeleteItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22.w, color: Colors.red[600]),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[800],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
