import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/sync_service.dart';

/// A widget that shows an animated offline banner when the device loses
/// connectivity, and fires a "Synced X changes" SnackBar when sync completes.
///
/// Usage — wrap your Scaffold body in a Column and put this first:
/// ```dart
/// Column(
///   children: [
///     OfflineBanner(scaffoldContext: context),
///     Expanded(child: _yourContent()),
///   ],
/// )
/// ```
class OfflineBanner extends StatefulWidget {
  /// The [BuildContext] that owns the nearest [Scaffold].
  /// Pass the `context` from inside the `build()` method of the screen.
  final BuildContext scaffoldContext;

  const OfflineBanner({super.key, required this.scaffoldContext});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _isOnline = SyncService.instance.isOnline;
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;

  late final StreamSubscription<bool> _onlineSub;
  late final StreamSubscription<int> _syncCountSub;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);

    // Show banner immediately if already offline.
    if (!_isOnline) _animCtrl.value = 1.0;

    // Listen to online/offline changes.
    _onlineSub = SyncService.instance.onlineStatusStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
      if (online) {
        _animCtrl.reverse();
      } else {
        _animCtrl.forward();
      }
    });

    // Listen for successful syncs and show a SnackBar.
    _syncCountSub = SyncService.instance.syncCountStream.listen((count) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(widget.scaffoldContext);
      if (messenger == null) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Synced $count pending ${count == 1 ? 'change' : 'changes'} successfully!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    });
  }

  @override
  void dispose() {
    _onlineSub.cancel();
    _syncCountSub.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _slideAnim,
      axisAlignment: -1,
      child: _buildBanner(),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline. Changes saved locally and will sync when online.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
