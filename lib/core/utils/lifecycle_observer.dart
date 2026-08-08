import 'package:flutter/widgets.dart';

class FocusLifecycleObserver extends StatefulWidget {
  const FocusLifecycleObserver({
    super.key,
    required this.child,
    required this.onBackground,
    required this.onResume,
    required this.pauseOnInactive,
    required this.pauseOnBackground,
  });

  final Widget child;
  final VoidCallback onBackground;
  final VoidCallback onResume;
  final bool pauseOnInactive;
  final bool pauseOnBackground;

  @override
  State<FocusLifecycleObserver> createState() => _FocusLifecycleObserverState();
}

class _FocusLifecycleObserverState extends State<FocusLifecycleObserver> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: widget.onBackground, // Minimized
      onHide: widget.onBackground, // Desktop window hidden
      onDetach: widget.onBackground, // App killing
      onResume: widget.onResume,
      onInactive: () {
        // Screen dimmed or system dialog appeared
        if (widget.pauseOnInactive) {
          widget.onBackground();
        }
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
