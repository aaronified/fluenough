import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';

/// A row that opens the debug gallery, and nothing at all in a release
/// build. Settings shows it at its foot; keep it there.
class GalleryLink extends StatelessWidget {
  const GalleryLink({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.grid_view_outlined),
      title: const Text('Screen gallery'), // ui-literal-ok: debug-only gallery
      subtitle: const Text(
        'Every screen and state, on fixture data', // ui-literal-ok: debug-only gallery
      ),
      onTap: () => AppNavigator.openGallery(context),
    );
  }
}
