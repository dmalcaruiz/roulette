import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef PointerMoveCallback = void Function(PointerMoveEvent event);
typedef PointerUpCallback = void Function(PointerUpEvent event);
typedef PointerCancelCallback = void Function(PointerCancelEvent event);

// Global pointer tracker that captures pointer events once a slider is activated.
// This allows tracking finger movement even when it leaves the slider bounds.
//
// Only one pointer can be tracked at a time (single-registration model).
class GlobalPointerTracker extends InheritedWidget {
  final GlobalPointerTrackerState state;

  const GlobalPointerTracker({
    super.key,
    required this.state,
    required super.child,
  });

  static GlobalPointerTrackerState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlobalPointerTracker>()
        ?.state;
  }

  @override
  bool updateShouldNotify(GlobalPointerTracker oldWidget) => false;
}

class GlobalPointerTrackerState {
  PointerMoveCallback? _onPointerMove;
  PointerUpCallback? _onPointerUp;
  PointerCancelCallback? _onPointerCancel;
  int? _activePointerId;

  // Register a slider to receive global pointer events.
  //
  // Only ONE slider can be tracked at a time. New registrations
  // will replace any previous registration.
  //
  // Asserts in debug mode if attempting to register a different pointer
  // while another is already being tracked.
  void registerSlider({
    required int pointerId,
    required PointerMoveCallback onMove,
    required PointerUpCallback onUp,
    required PointerCancelCallback onCancel,
  }) {
    assert(
      _activePointerId == null || _activePointerId == pointerId,
      'Cannot register slider: pointer $_activePointerId is already being tracked. '
      'Attempted to register pointer $pointerId.',
    );

    _activePointerId = pointerId;
    _onPointerMove = onMove;
    _onPointerUp = onUp;
    _onPointerCancel = onCancel;

    if (kDebugMode) {
      debugPrint('🌍 Global tracker ACTIVATED for pointer $pointerId');
    }
  }

  // Unregister the active slider
  void unregisterSlider() {
    if (kDebugMode && _activePointerId != null) {
      debugPrint('🌍 Global tracker DEACTIVATED');
    }
    _activePointerId = null;
    _onPointerMove = null;
    _onPointerUp = null;
    _onPointerCancel = null;
  }

  // Handle global pointer move events
  void handlePointerMove(PointerMoveEvent event) {
    if (_activePointerId == event.pointer) {
      _onPointerMove?.call(event);
    }
  }

  // Handle global pointer up events
  void handlePointerUp(PointerUpEvent event) {
    if (_activePointerId == event.pointer) {
      _onPointerUp?.call(event);
      unregisterSlider();
    }
  }

  // Handle global pointer cancel events
  void handlePointerCancel(PointerCancelEvent event) {
    if (_activePointerId == event.pointer) {
      _onPointerCancel?.call(event);
      unregisterSlider();
    }
  }

  // Whether a pointer is currently being tracked
  bool get isTracking => _activePointerId != null;

  // The currently tracked pointer ID (null if not tracking)
  int? get activePointerId => _activePointerId;
}

// Provides global pointer tracking for the widget subtree.
//
// This widget enables tracking pointer movement across the entire app,
// which is particularly useful for sliders that need to continue tracking
// finger movement even when the pointer moves outside the slider's bounds.
//
// Example usage:
// ```dart
// final tracker = GlobalPointerTracker.of(context);
// tracker?.registerSlider(
//   pointerId: event.pointer,
//   onMove: (e) => handleMove(e),
//   onUp: (e) => handleUp(e),
//   onCancel: (e) => handleCancel(e),
// );
// ```
class GlobalPointerTrackerProvider extends StatefulWidget {
  final Widget child;

  const GlobalPointerTrackerProvider({
    super.key,
    required this.child,
  });

  @override
  State<GlobalPointerTrackerProvider> createState() =>
      _GlobalPointerTrackerProviderState();
}

class _GlobalPointerTrackerProviderState
    extends State<GlobalPointerTrackerProvider> {
  final GlobalPointerTrackerState _trackerState = GlobalPointerTrackerState();

  @override
  void dispose() {
    _trackerState.unregisterSlider();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: _trackerState.handlePointerMove,
      onPointerUp: _trackerState.handlePointerUp,
      onPointerCancel: _trackerState.handlePointerCancel,
      child: GlobalPointerTracker(
        state: _trackerState,
        child: widget.child,
      ),
    );
  }
}

