import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/UI/DeleteChannel.dart';

class ChannelSettings extends StatefulWidget {
  final int channelId;
  final String channelName;

  const ChannelSettings({
    super.key,
    required this.channelId,
    this.channelName = '',
  });

  @override
  State<ChannelSettings> createState() => _ChannelSettingsState();
}

class _ChannelSettingsState extends State<ChannelSettings> {
  bool _loading = false;

  Future<void> _deleteChannel() async {
    // Navigate to dedicated delete screen (no modal)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DeleteChannel(
              channelId: widget.channelId,
              channelName: widget.channelName,
            ),
      ),
    );

    // If deletion happened, propagate true to caller
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Channel Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.w),
              ),
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red[600]),
                title: const Text('Delete Channel'),
                subtitle: const Text(
                  'Permanently delete your channel and its data',
                ),
                trailing:
                    _loading
                        ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                            color: appColors().primaryColorApp,
                          ),
                        )
                        : null,
                onTap: _loading ? null : _deleteChannel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
