import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/home_models.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/widgets/music/circular_card.dart';

class ChannelDirectoryScreen extends StatelessWidget {
  final List<ChannelModel> channels;
  final ModelTheme sharedTheme;

  const ChannelDirectoryScreen({
    super.key,
    required this.channels,
    required this.sharedTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: channels.isEmpty ? _buildEmptyState(context) : _buildGrid(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          'No channels available right now.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16.sp, color: appColors().colorText),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900
        ? 5
        : width >= 600
        ? 4
        : 3;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16.w,
        20.w,
        16.w,
        AppPadding.bottom(context),
      ),
      itemCount: channels.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 18.w,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final channel = channels[index];
        final subtitle = channel.handle.isNotEmpty
            ? '@${channel.handle}'
            : null;
        return CircularCard(
          imagePath: _resolveImage(channel),
          title: channel.name,
          subtitle: subtitle,
          onTap: () => _openChannel(context, channel),
          sharedPreThemeData: sharedTheme,
          size: 110,
        );
      },
    );
  }

  void _openChannel(BuildContext context, ChannelModel channel) {
    final channelId = channel.id ?? channel.userId;
    if (channelId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Channel unavailable.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelVideosScreen(
          channelId: channelId,
          channelName: channel.name,
        ),
      ),
    );
  }

  String _resolveImage(ChannelModel channel) {
    if (channel.imageUrl.isNotEmpty) return channel.imageUrl;
    if (channel.image.isNotEmpty) return channel.image;
    return '';
  }
}
