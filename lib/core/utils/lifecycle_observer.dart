import 'dart:async';
import 'package:flutter/widgets.dart';

class FocusLifecycleObserver extends StatefulWidget {
  const FocusLifecycleObserver({super.key, required this.child, required this.onBackground, required this.onResume, required this.pauseOnBackground});

  final Widget child;
  final VoidCallback onBackground;
  final VoidCallback onResume;
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
      onResume: widget.onResume,
      onStateChange: (state) {
        if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
          if (widget.pauseOnBackground) {
            widget.onBackground();
          }
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
