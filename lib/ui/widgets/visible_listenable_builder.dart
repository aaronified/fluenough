import 'package:flutter/widgets.dart';

/// A [ListenableBuilder] that sleeps while its tab is hidden.
///
/// The tab pager keeps every tab built and sets [TickerMode] off on the ones
/// out of view. While it is off, notifications from [listenable] are only
/// remembered; the builder runs once when the tab is shown again, if anything
/// changed meanwhile. A tab that starts hidden is not built for the first
/// frame (#857), so the app starts cheaply, and afterwards keeps its state.
///
/// With [warmUp] a hidden tab is then built in the background, one tab per
/// frame, starting right after the frame that first showed it, so the first
/// swipe to it finds a built page instead of doing the heavy first build
/// while the finger moves. Without it a hidden tab is built only when first
/// shown. A tab built in the background still catches up once when shown, if
/// its listenable changed meanwhile.
class VisibleListenableBuilder extends StatefulWidget {
  const VisibleListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
    this.warmUp = false,
  });

  /// Whether a tab that starts hidden is built in the background, one per
  /// frame, after the first frame, rather than only when first shown.
  final bool warmUp;

  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;

  @override
  State<VisibleListenableBuilder> createState() =>
      _VisibleListenableBuilderState();
}

class _VisibleListenableBuilderState extends State<VisibleListenableBuilder> {
  bool _visible = true;
  bool _stale = true;
  Widget? _built;
  bool _warming = false;

  // Hidden tabs waiting to be built, shared so that one is built per frame.
  static final List<_VisibleListenableBuilderState> _warmQueue =
      <_VisibleListenableBuilderState>[];
  static bool _warmScheduled = false;

  static void _pumpWarmQueue() {
    if (_warmScheduled || _warmQueue.isEmpty) return;
    _warmScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _warmScheduled = false;
      if (_warmQueue.isEmpty) return;
      _warmQueue.removeAt(0)._warm();
      // The next tab waits for the frame this one asks for.
      _pumpWarmQueue();
    });
    binding.ensureVisualUpdate();
  }

  void _warm() {
    if (!mounted || _visible || _built != null) return;
    setState(() => _warming = true);
  }

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void didUpdateWidget(VisibleListenableBuilder old) {
    super.didUpdateWidget(old);
    if (old.listenable != widget.listenable) {
      old.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    // A new builder or child from the parent always rebuilds.
    _stale = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Showing the tab again rebuilds only if something changed meanwhile.
    final now = TickerMode.valuesOf(context).enabled;
    // Any other inherited change (theme, locale) must still rebuild.
    if (now == _visible) _stale = true;
    _visible = now;
    if (widget.warmUp &&
        !_visible &&
        _built == null &&
        !_warmQueue.contains(this)) {
      _warmQueue.add(this);
      _pumpWarmQueue();
    }
  }

  @override
  void dispose() {
    _warmQueue.remove(this);
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!_visible) {
      _stale = true;
      return;
    }
    _stale = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // A hidden tab keeps what it showed, or shows nothing yet, and works
    // out the rest once it is shown, even when its parent rebuilds.
    if (!_visible && !(_warming && _built == null)) {
      return _built ?? const SizedBox.shrink();
    }
    _warming = false;
    if (_stale || _built == null) {
      _stale = false;
      _built = widget.builder(context, widget.child);
    }
    return _built!;
  }
}
