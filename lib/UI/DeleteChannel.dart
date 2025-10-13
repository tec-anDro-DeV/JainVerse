import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/presenters/channel_presenter.dart';

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
        title: const Text('Delete Channel'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently delete your channel',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: appColors().colorTextHead,
              ),
            ),
            SizedBox(height: 12.w),
            Text(
              'Deleting your channel will remove all associated data including videos, followers, and settings. This action cannot be undone.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 12.w),
            Text(
              'Note: Deletion may take from a few minutes up to several days depending on the amount of content you uploaded.',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 24.w),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  padding: EdgeInsets.symmetric(vertical: 14.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                ),
                onPressed: !_loading ? _attemptDelete : null,
                child:
                    _loading
                        ? SizedBox(
                          height: 18.w,
                          width: 18.w,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Delete Channel',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
            SizedBox(height: 12.w),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                ),
                onPressed:
                    _loading ? null : () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
