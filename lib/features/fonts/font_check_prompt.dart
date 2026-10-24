import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/font_check.dart';
import 'font_check_sheet.dart';

/// Opens the font check's sheet whenever a course has scripts to ask about
/// (#611), one after another. Wraps the app's shell, so it never asks over
/// the first launch's screens.
class FontCheckPrompt extends StatefulWidget {
  const FontCheckPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<FontCheckPrompt> createState() => _FontCheckPromptState();
}

class _FontCheckPromptState extends State<FontCheckPrompt> {
  FontCheck? _check;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final check = AppScope.read(context).fontCheck;
    if (identical(check, _check)) return;
    _check?.removeListener(_changed);
    _check = check..addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _check?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_showing || _check?.pending == null) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    final script = _check?.pending;
    if (!mounted || script == null) {
      _showing = false;
      return;
    }
    await showFontCheckSheet(context, script);
    _showing = false;
    if (mounted) _changed();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
