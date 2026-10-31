import 'package:flutter/widgets.dart';

/// A [ListenableBuilder] that sleeps while its tab is hidden.
///
/// The tab pager keeps every tab built and sets [TickerMode] off on the ones
/// out of view. While it is off, notifications from [listenable] are only
/// remembered; the builder runs once when the tab is shown again, if anything
/// changed meanwhile. A tab that starts hidden is not built at all until it
/// is first shown (#857), and afterwards keeps its state.
class VisibleListenableBuilder extends StatefulWidget {
  const VisibleListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

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
  }

  @override
  void dispose() {
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
    if (!_visible) return _built ?? const SizedBox.shrink();
    if (_stale || _built == null) {
      _stale = false;
      _built = widget.builder(context, widget.child);
    }
    return _built!;
  }
}
