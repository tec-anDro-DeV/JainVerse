import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/offline_mode_service.dart';

/// Debug panel for testing offline mode functionality
/// Only shows in debug mode
class OfflineModeDebugPanel extends StatefulWidget {
  const OfflineModeDebugPanel({super.key});

  @override
  State<OfflineModeDebugPanel> createState() => _OfflineModeDebugPanelState();
}

class _OfflineModeDebugPanelState extends State<OfflineModeDebugPanel> {
  final OfflineModeService _offlineModeService = OfflineModeService();

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG: Offline Mode Testing',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 8.w),
          StreamBuilder<bool>(
            stream: _offlineModeService.connectivityStream,
            initialData: _offlineModeService.hasConnectivity,
            builder: (context, connectivitySnapshot) {
              return StreamBuilder<bool>(
                stream: _offlineModeService.offlineModeStream,
                initialData: _offlineModeService.isOfflineMode,
                builder: (context, offlineSnapshot) {
                  final hasConnectivity = connectivitySnapshot.data ?? true;
                  final isOfflineMode = offlineSnapshot.data ?? false;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connectivity: ${hasConnectivity ? "🟢 Online" : "🔴 Offline"}',
                        style: TextStyle(
                          color: hasConnectivity ? Colors.green : Colors.red,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        'Mode: ${isOfflineMode ? "📱 Offline Mode" : "🌐 Online Mode"}',
                        style: TextStyle(
                          color: isOfflineMode ? Colors.orange : Colors.blue,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        'User: ${_offlineModeService.isUserLoggedIn ? "✅ Logged In" : "❌ Not Logged In"}',
                        style: TextStyle(
                          color:
                              _offlineModeService.isUserLoggedIn
                                  ? Colors.green
                                  : Colors.red,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 12.w),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.w,
                        children: [
                          _buildDebugButton(
                            'Simulate No Internet',
                            () =>
                                _offlineModeService.simulateConnectivityLoss(),
                            Colors.red,
                          ),
                          _buildDebugButton(
                            'Simulate Internet Back',
                            () =>
                                _offlineModeService
                                    .simulateConnectivityRestoration(),
                            Colors.green,
                          ),
                          _buildDebugButton(
                            'Force Offline Mode',
                            () => _offlineModeService.setOfflineMode(
                              true,
                              force: true,
                            ),
                            Colors.orange,
                          ),
                          _buildDebugButton(
                            'Force Online Mode',
                            () => _offlineModeService.setOfflineMode(
                              false,
                              force: true,
                            ),
                            Colors.blue,
                          ),
                          _buildDebugButton(
                            'Test Offline Prompt',
                            () =>
                                _offlineModeService.simulateConnectivityLoss(),
                            Colors.purple,
                          ),
                          _buildDebugButton(
                            'Trigger Prompt',
                            () => _offlineModeService.triggerOfflinePrompt(),
                            Colors.cyan,
                          ),
                          _buildDebugButton(
                            'Hide Prompt',
                            () => _offlineModeService.hideOfflinePrompt(),
                            Colors.grey,
                          ),
                          _buildDebugButton('Test Offline Switch', () {
                            _offlineModeService.switchToOfflineMode();
                          }, Colors.deepOrange),
                          _buildDebugButton('Test Online Switch', () {
                            _offlineModeService.switchToOnlineMode();
                          }, Colors.lightBlue),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(String label, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.w),
        minimumSize: Size(0, 32.w),
        textStyle: TextStyle(fontSize: 10.sp),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.sp, fontFamily: 'Poppins'),
      ),
    );
  }
}

/// Floating debug widget that can be dragged around the screen
class FloatingOfflineModeDebugPanel extends StatefulWidget {
  const FloatingOfflineModeDebugPanel({super.key});

  @override
  State<FloatingOfflineModeDebugPanel> createState() =>
      _FloatingOfflineModeDebugPanelState();
}

class _FloatingOfflineModeDebugPanelState
    extends State<FloatingOfflineModeDebugPanel> {
  Offset _position = Offset(16, 100);
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildPanel(),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          setState(() {
            _position = details.offset;
          });
        },
        child: _buildPanel(),
      ),
    );
  }

  Widget _buildPanel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8.r),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isExpanded ? 280.w : 80.w,
          height: _isExpanded ? null : 40.w,
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child:
              _isExpanded
                  ? const OfflineModeDebugPanel()
                  : Center(
                    child: Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}
