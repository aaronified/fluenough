// Scratch: renders the picker's gallery entries to PNGs. Not committed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/theme.dart';

import 'support/harness.dart';

const out = String.fromEnvironment('SHOTS', defaultValue: '/tmp/shots');
const ids = String.fromEnvironment('IDS', defaultValue: 'learn-languages');
const scroll = int.fromEnvironment('SCROLL', defaultValue: 0);
const ts = String.fromEnvironment('TS', defaultValue: '1.0');
const sp =
    '/tmp/claude-0/-home-user-fluenough/1d4a8948-fad4-57d2-8d2c-45dc32323311/scratchpad';

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

const fallback = <String>['NBn', 'NDe', 'NGu', 'NKn', 'NTe', 'NJp'];

ThemeData withFallback(ThemeData t) =>
    t.copyWith(textTheme: t.textTheme.apply(fontFamilyFallback: fallback));

void main() {
  testWidgets('shots', (tester) async {
    const fonts = '$sp/flutter/bin/cache/artifacts/material_fonts';
    await tester.runAsync(() async {
      await loadFont('Roboto', [
        '$fonts/Roboto-Regular.ttf',
        '$fonts/Roboto-Medium.ttf',
        '$fonts/Roboto-Bold.ttf',
        '$fonts/Roboto-Black.ttf',
      ]);
      await loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
      await loadFont('NBn', [
        '$sp/fonts/NotoSansBengali-Regular.ttf',
        '$sp/fonts/NotoSansBengali-SemiBold.ttf',
      ]);
      await loadFont('NDe', [
        '$sp/fonts/NotoSansDevanagari-Regular.ttf',
        '$sp/fonts/NotoSansDevanagari-SemiBold.ttf',
      ]);
      await loadFont('NGu', [
        '$sp/fonts/NotoSansGujarati-Regular.ttf',
        '$sp/fonts/NotoSansGujarati-SemiBold.ttf',
      ]);
      await loadFont('NKn', [
        '$sp/fonts/NotoSansKannada-Regular.ttf',
        '$sp/fonts/NotoSansKannada-SemiBold.ttf',
      ]);
      await loadFont('NTe', [
        '$sp/fonts/NotoSansTelugu-Regular.ttf',
        '$sp/fonts/NotoSansTelugu-SemiBold.ttf',
      ]);
      await loadFont('NJp', ['$sp/fonts/NotoSansJP.otf']);
    });
    usePhone(tester, textScale: double.parse(ts));
    final app = AppState.test();
    await app.load();
    Directory(out).createSync(recursive: true);
    for (final spec in ids.split(',')) {
      final dark = spec.endsWith(':dark');
      final id = spec.replaceAll(':dark', '');
      final entry = allGalleryEntries.firstWhere((e) => e.id == id);
      final state = (entry.state ?? GalleryFixtures.state)(app);
      await state.load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AppScope(
            state: state,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: withFallback(AppTheme.light()),
              darkTheme: withFallback(AppTheme.dark()),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              onGenerateRoute: AppRoutes.onGenerateRoute,
              home: Builder(builder: entry.builder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scroll != 0) {
        final list = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        await tester.drag(list.first, Offset(0, -scroll.toDouble()));
        await tester.pumpAndSettle();
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/$id${dark ? '-dark' : ''}${scroll != 0 ? '-s$scroll' : ''}${ts != '1.0' ? '-ts$ts' : ''}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
