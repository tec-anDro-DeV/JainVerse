import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/services/my_videos_service.dart';

class ReelOverlayHelper {
  static OverlayEntry? _current;
  static final MyVideosService _service = MyVideosService();

  static void dismiss() {
    _current?.remove();
    _current = null;
  }

  static void showOptions({
    required BuildContext context,
    required ReelItem reel,
    required void Function(ReelItem) onEdited,
    required void Function() onDeleted,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _current = OverlayEntry(
      builder: (_) => _OptionsOverlay(
        onEdit: () =>
            showEdit(context: context, reel: reel, onEdited: onEdited),
        onDelete: () =>
            showDelete(context: context, reel: reel, onDeleted: onDeleted),
        onDismiss: dismiss,
      ),
    );
    overlay.insert(_current!);
  }

  static void showEdit({
    required BuildContext context,
    required ReelItem reel,
    required void Function(ReelItem) onEdited,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _current = OverlayEntry(
      builder: (_) => _EditOverlay(
        reel: reel,
        service: _service,
        onEdited: (updated) {
          dismiss();
          onEdited(updated);
        },
        onDismiss: dismiss,
      ),
    );
    overlay.insert(_current!);
  }

  static void showDelete({
    required BuildContext context,
    required ReelItem reel,
    required void Function() onDeleted,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _current = OverlayEntry(
      builder: (_) => _DeleteOverlay(
        reel: reel,
        service: _service,
        onDeleted: () {
          dismiss();
          onDeleted();
        },
        onDismiss: dismiss,
      ),
    );
    overlay.insert(_current!);
  }
}

// ---------------------------------------------------------------------------
// Shared scaffold
// ---------------------------------------------------------------------------

class _OverlayScaffold extends StatelessWidget {
  final VoidCallback onDismiss;
  final Widget card;

  const _OverlayScaffold({required this.onDismiss, required this.card});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.black38),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.6),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Options overlay
// ---------------------------------------------------------------------------

class _OptionsOverlay extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const _OptionsOverlay({
    required this.onEdit,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      onDismiss: onDismiss,
      card: Material(
        borderRadius: BorderRadius.circular(12.w),
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionRow(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
            Divider(
              height: 1.h,
              indent: 16.w,
              endIndent: 16.w,
              color: Colors.grey.shade200,
            ),
            _OptionRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: Colors.red,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.w),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Icon(icon, size: 22.w, color: c),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                color: c,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit overlay
// ---------------------------------------------------------------------------

class _EditOverlay extends StatefulWidget {
  final ReelItem reel;
  final MyVideosService service;
  final void Function(ReelItem) onEdited;
  final VoidCallback onDismiss;

  const _EditOverlay({
    required this.reel,
    required this.service,
    required this.onEdited,
    required this.onDismiss,
  });

  @override
  State<_EditOverlay> createState() => _EditOverlayState();
}

class _EditOverlayState extends State<_EditOverlay> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final ValueNotifier<bool> _saving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.reel.title);
    _descCtrl = TextEditingController(text: widget.reel.description ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _saving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving.value) return;
    _saving.value = true;

    try {
      final updated = await widget.service.updateShortVideo(
        shortId: widget.reel.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;

      if (updated != null) {
        widget.onEdited(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short updated successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update short.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.w),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.w),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.w),
        borderSide: const BorderSide(color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      onDismiss: widget.onDismiss,
      card: Material(
        borderRadius: BorderRadius.circular(12.w),
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Short',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _titleCtrl,
                decoration: _inputDecoration('Title'),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _descCtrl,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
              ),
              SizedBox(height: 20.h),
              ValueListenableBuilder<bool>(
                valueListenable: _saving,
                builder: (_, saving, __) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: saving ? null : widget.onDismiss,
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: saving ? null : _save,
                        child: saving
                            ? SizedBox(
                                height: 18.w,
                                width: 18.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete overlay
// ---------------------------------------------------------------------------

class _DeleteOverlay extends StatefulWidget {
  final ReelItem reel;
  final MyVideosService service;
  final VoidCallback onDeleted;
  final VoidCallback onDismiss;

  const _DeleteOverlay({
    required this.reel,
    required this.service,
    required this.onDeleted,
    required this.onDismiss,
  });

  @override
  State<_DeleteOverlay> createState() => _DeleteOverlayState();
}

class _DeleteOverlayState extends State<_DeleteOverlay> {
  final ValueNotifier<bool> _deleting = ValueNotifier(false);

  @override
  void dispose() {
    _deleting.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting.value) return;
    _deleting.value = true;

    try {
      final ok = await widget.service.deleteShortVideo(shortId: widget.reel.id);

      if (!mounted) return;

      if (ok) {
        widget.onDeleted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short deleted successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete short.')),
        );
        _deleting.value = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        _deleting.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      onDismiss: widget.onDismiss,
      card: Material(
        borderRadius: BorderRadius.circular(12.w),
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Short',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Are you sure you want to delete this short?',
                style: TextStyle(fontSize: 14.sp, color: Colors.black87),
              ),
              SizedBox(height: 20.h),
              ValueListenableBuilder<bool>(
                valueListenable: _deleting,
                builder: (_, deleting, __) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: deleting ? null : widget.onDismiss,
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: deleting ? null : _delete,
                        child: deleting
                            ? SizedBox(
                                height: 18.w,
                                width: 18.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
