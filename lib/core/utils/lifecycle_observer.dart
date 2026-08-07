import 'package:flutter/widgets.dart';

class FocusLifecycleObserver extends StatefulWidget {
  const FocusLifecycleObserver({
    super.key,
    required this.child,
    required this.onPause,
    required this.onResume,
  });

  final Widget child;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  State<FocusLifecycleObserver> createState() => _FocusLifecycleObserverState();
}

class _FocusLifecycleObserverState extends State<FocusLifecycleObserver> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: widget.onPause,
      onHide: widget.onPause,
      onDetach: widget.onPause,
      onResume: widget.onResume,
      onInactive: widget.onPause,
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
