import 'package:anchorkeep/app/app.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/features/session/vault_session_controller.dart';
import 'package:anchorkeep/features/onboarding/access_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('стартовый Android экран сохраняет композицию в обеих темах', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 568),
      const Size(336, 747),
      const Size(412, 915),
    ]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: const WelcomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ваш сейф.\nТолько ваш.'), findsOneWidget);
        expect(find.byKey(const ValueKey('welcome-hero')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('welcome-hero'))).height,
          greaterThanOrEqualTo(230),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('welcome-shield'))).width,
          116,
        );
        expect(find.text('Создать сейф'), findsOneWidget);
        expect(find.text('Восстановить из бэкапа'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('welcome-hero'))).top,
          lessThan(tester.getRect(find.text('Создать сейф')).top),
        );
        expect(tester.takeException(), isNull, reason: '$size / $mode');
      }
    }
  });

  testWidgets('приложение запускается', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hasVaultProvider.overrideWith((ref) => false)],
        child: const AnchorkeepApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Anchorkeep'), findsOneWidget);
    expect(find.text('Создать сейф'), findsOneWidget);
  });

  testWidgets('создание сейфа сохраняет мобильную компоновку в обеих темах', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 568),
      const Size(336, 747),
      const Size(412, 915),
    ]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: const CreateVaultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Создайте сейф'), findsOneWidget);
        expect(find.text('Важно помнить'), findsOneWidget);
        expect(
          find.text('Я понимаю риск потери мастер-пароля'),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(
          tester.getRect(find.text('Создайте сейф')).top,
          lessThan(tester.getRect(find.text('Создать зашифрованный сейф')).top),
        );
        expect(tester.takeException(), isNull, reason: '$size / $mode');
      }
    }
  });

  testWidgets('широкий экран показывает иллюстрацию Windows V3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hasVaultProvider.overrideWith((ref) => false)],
        child: const AnchorkeepApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Доступ только вам.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('узкий экран открывает создание сейфа без переполнения', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hasVaultProvider.overrideWith((ref) => false)],
        child: const AnchorkeepApp(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Создать сейф'));
    await tester.tap(find.text('Создать сейф'));
    await tester.pumpAndSettle();
    expect(find.text('Создайте сейф'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('светлая кнопка использует белые текст и иконки', () {
    expect(AppTheme.light.colorScheme.onPrimary, Colors.white);
    expect(
      AppTheme.light.filledButtonTheme.style?.foregroundColor?.resolve({}),
      Colors.white,
    );
  });
}
