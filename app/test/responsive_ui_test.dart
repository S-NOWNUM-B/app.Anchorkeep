import 'package:anchorkeep/app/theme.dart';
import 'package:anchorkeep/app/preferences.dart';
import 'package:anchorkeep/core/crypto/aead.dart';
import 'package:anchorkeep/core/crypto/kdf.dart';
import 'package:anchorkeep/core/vault/entry.dart';
import 'package:anchorkeep/core/vault/vault.dart';
import 'package:anchorkeep/features/session/entries_controller.dart';
import 'package:anchorkeep/features/onboarding/access_screens.dart';
import 'package:anchorkeep/features/vault/backup_screen.dart';
import 'package:anchorkeep/features/vault/entry_screens.dart';
import 'package:anchorkeep/features/vault/restore_flow_workspace.dart';
import 'package:anchorkeep/features/vault/settings_screen.dart';
import 'package:anchorkeep/shared/vault_illustration.dart';
import 'package:anchorkeep/shared/access_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _EmptyEntries extends EntriesController {
  @override
  List<Entry> build() => const [];

  @override
  Future<Entry> add(
    EntryType type,
    String title,
    Map<String, String> fields,
  ) async {
    final now = DateTime.utc(2026);
    final entry = Entry(
      id: 'created',
      type: type,
      title: title,
      fields: fields,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, entry];
    return entry;
  }
}

class _SampleEntries extends EntriesController {
  @override
  List<Entry> build() => [
    Entry(
      id: 'github',
      type: EntryType.password,
      title: 'GitHub',
      fields: const {
        'login': 'work@example.com',
        'password': 'SecretPass123!',
        'url': 'https://www.github.com',
        'note': 'Work account',
      },
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<void> delete(String id) async {
    state = state.where((entry) => entry.id != id).toList();
  }

  @override
  Future<Entry> update(
    String id, {
    String? title,
    Map<String, String>? fields,
  }) async {
    final old = state.firstWhere((entry) => entry.id == id);
    final updated = old.copyWith(
      title: title,
      fields: fields,
      updatedAt: DateTime.utc(2026, 11, 1),
    );
    state = [updated];
    return updated;
  }
}

class _SampleNotes extends EntriesController {
  @override
  List<Entry> build() => [
    Entry(
      id: 'idea',
      type: EntryType.note,
      title: 'Project ideas',
      fields: const {'text': 'Plan for the week'},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<Entry> add(
    EntryType type,
    String title,
    Map<String, String> fields,
  ) async {
    final now = DateTime.utc(2026, 11, 1);
    final entry = Entry(
      id: 'new-note',
      type: type,
      title: title,
      fields: fields,
      createdAt: now,
      updatedAt: now,
    );
    state = [...state, entry];
    return entry;
  }

  @override
  Future<Entry> update(
    String id, {
    String? title,
    Map<String, String>? fields,
  }) async {
    final old = state.firstWhere((entry) => entry.id == id);
    final updated = old.copyWith(
      title: title,
      fields: fields,
      updatedAt: DateTime.utc(2026, 11, 1),
    );
    state = [
      for (final entry in state)
        if (entry.id == id) updated else entry,
    ];
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    state = state.where((entry) => entry.id != id).toList();
  }
}

void main() {
  testWidgets('кнопка темы сразу переключает Android между светлой и тёмной', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ref.watch(themeModeProvider),
            home: const Scaffold(body: Center(child: ThemeButton())),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pump();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pump();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('создание сейфа требует подтверждения потери мастер-пароля', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateVaultScreen())),
    );
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).first,
      'StrongPassword123!',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'StrongPassword123!',
    );
    await tester.ensureVisible(find.text('Create encrypted vault'));
    await tester.tap(find.text('Create encrypted vault'));
    await tester.pump();
    expect(
      find.text(
        'Confirm that you understand the risk of losing your master password.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('разблокировка показывает крупный замок в Light и Dark', (
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
              home: const UnlockScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('Vault locked'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('unlock-emblem'))).width,
          116,
        );
        expect(find.text('Restore from backup'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size / $mode');
      }
    }
  });

  testWidgets(
    'разблокировка показывает ошибку пустого пароля и открывает глаз',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: UnlockScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        false,
      );
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Enter master password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('основные страницы не выходят за границы Android и Windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 360.0, 800.0, 1360.0]) {
      tester.view.physicalSize = Size(width, 768);
      for (final page in <Widget>[
        const EntryScreen(type: EntryType.password),
        const EntryScreen(type: EntryType.note),
        const BackupScreen(),
        const SettingsScreen(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(body: page),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $width px',
        );
      }
    }
  });

  testWidgets('редактор пароля помещается в узком окне', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: EntryScreen(type: EntryType.password)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No passwords yet'), findsOneWidget);
    expect(find.text('Select an entry'), findsNothing);
    await tester.tap(find.text('Add first password'));
    await tester.pumpAndSettle();
    expect(find.text('New password'), findsOneWidget);
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pump();
    expect(find.text('Enter a title for this entry.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(
      find.text('Entry not saved. Fix the errors in the form.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Create a strong password'));
    await tester.tap(find.text('Create a strong password'));
    await tester.pumpAndSettle();
    expect(find.text('Password generator'), findsOneWidget);
    expect(find.text('16 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Use password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use password'));
    await tester.pumpAndSettle();
    expect(find.text('Password generator'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller
          ?.text
          .length,
      16,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Work account');
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(find.text('Password entry'), findsOneWidget);
    expect(find.text('Work account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Windows показывает пароли сеткой 3 колонки и детали после выбора',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [entriesProvider.overrideWith(_SampleEntries.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: EntryScreen(type: EntryType.password)),
          ),
        ),
      );
      await tester.pump();
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3,
      );
      expect(find.text('Login'), findsNothing);
      expect(find.text('github.com · work@example.com'), findsOneWidget);
      await tester.tap(find.text('GitHub'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'после создания пароля Windows возвращается к сетке без деталей',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: EntryScreen(type: EntryType.password)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Add password'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Personal account',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'SecretPass123!',
      );
      await tester.ensureVisible(find.text('Save password'));
      await tester.tap(find.text('Save password'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Personal account'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      await tester.tap(find.text('Personal account'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('поиск по URL, просмотр и удаление пароля работают на Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_SampleEntries.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: EntryScreen(type: EntryType.password)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('CipherVault'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Passwords')).dy -
          tester.getTopLeft(find.text('CipherVault')).dy,
      greaterThan(45),
    );
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'github.com');
    await tester.pump();
    expect(find.text('GitHub'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'missing-entry');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.text('Clear search').last);
    await tester.pump();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Password entry')).dy, lessThan(80));
    expect(tester.getTopLeft(find.byTooltip('Back')).dy, lessThan(80));
    expect(tester.getTopLeft(find.byTooltip('Edit')).dy, lessThan(80));
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('SecretPass123!'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(find.text('SecretPass123!'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'GitHub Work');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub Work'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete entry'));
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    expect(find.text('Delete GitHub Work password?'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No passwords yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows открывает полноэкранную форму и модальный генератор', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: EntryScreen(type: EntryType.password)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add password'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create password'), findsOneWidget);
    expect(find.text('Access for you alone.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Cancel')).dy,
      greaterThan(tester.getBottomLeft(find.byType(VaultIllustration)).dy),
    );
    final cancelWidth = tester
        .getSize(find.widgetWithText(OutlinedButton, 'Cancel'))
        .width;
    final saveWidth = tester
        .getSize(find.widgetWithText(FilledButton, 'Save password'))
        .width;
    expect((cancelWidth - saveWidth).abs(), lessThan(2));
    await tester.tap(find.text('Generate a strong password'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Password generator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('заметку можно создать в узком окне с проверкой полей', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: EntryScreen(type: EntryType.note)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('CipherVault'), findsOneWidget);
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Notes')).dy -
          tester.getTopLeft(find.text('CipherVault')).dy,
      greaterThan(45),
    );
    await tester.tap(find.text('Add first note'));
    await tester.pumpAndSettle();
    expect(find.text('Create note'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    expect(tester.getTopLeft(find.text('New note')).dy, lessThan(80));
    expect(
      tester.getSize(find.byType(TextFormField).last).height,
      greaterThan(190),
    );
    expect(find.text('0 characters'), findsOneWidget);
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Enter a note title.'), findsOneWidget);
    expect(find.text('Enter note text.'), findsOneWidget);
    expect(find.text('Check the fields'), findsOneWidget);
    expect(find.text('Note not saved. Check the fields.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'My idea');
    await tester.enterText(
      find.byType(TextFormField).last,
      'A private thought',
    );
    await tester.pump();
    expect(find.text('17 characters'), findsOneWidget);
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(find.text('A private thought'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('форма заметки помещается в тёмной теме на Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_EmptyEntries.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: EntryScreen(type: EntryType.note)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add first note'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsOneWidget);
    expect(
      tester.getSize(find.byType(TextFormField).last).height,
      greaterThan(190),
    );
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Note not saved. Check the fields.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('список, поиск, просмотр, редактирование и удаление заметки', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_SampleNotes.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: EntryScreen(type: EntryType.note)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('CipherVault'), findsOneWidget);
    expect(find.text('My notes'), findsOneWidget);
    expect(find.text('1 note · on this device only'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.text('Clear search').last);
    await tester.pump();
    await tester.tap(find.text('Project ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Plan for the week'), findsOneWidget);
    final noteDate = find.textContaining(' · ');
    expect(noteDate, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Note')).dy,
      lessThan(tester.getTopLeft(noteDate).dy),
    );
    expect(
      tester.getTopLeft(noteDate).dy,
      lessThan(tester.getTopLeft(find.text('NOTE TEXT')).dy),
    );
    expect(
      tester.getTopLeft(find.text('NOTE TEXT')).dy,
      lessThan(tester.getTopLeft(find.text('Project ideas')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Project ideas')).dy,
      lessThan(tester.getTopLeft(find.text('Plan for the week')).dy),
    );
    expect(find.byTooltip('Open full note'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Read full note')).dy,
      lessThan(tester.getTopLeft(find.text('Delete note')).dy),
    );
    expect(
      tester.getBottomLeft(find.widgetWithText(TextButton, 'Delete note')).dy,
      greaterThan(880),
    );
    await tester.tap(find.text('Read full note'));
    await tester.pumpAndSettle();
    expect(find.text('Full note'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Revised ideas');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Revised ideas'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete note'));
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    expect(find.text('Delete note Revised ideas?'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Revised ideas'), findsOneWidget);
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('просмотр заметки помещает действия на экране 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesProvider.overrideWith(_SampleNotes.new)],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
          home: const Scaffold(body: EntryScreen(type: EntryType.note)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Project ideas'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.text('Delete note'), findsOneWidget);
    expect(find.text('Read full note'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.widgetWithText(TextButton, 'Delete note')).dy,
      greaterThan(665),
    );
    expect(find.byTooltip('Share via NFC'), findsOneWidget);
    await tester.tap(find.byTooltip('Share via NFC'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Windows показывает список и предпросмотр заметки в тёмной теме',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [entriesProvider.overrideWith(_SampleNotes.new)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: EntryScreen(type: EntryType.note)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('MY NOTES'), findsOneWidget);
      expect(find.text('PREVIEW'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await tester.tap(find.text('Project ideas').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Plan for the week'), findsOneWidget);
      expect(find.text('Your text. Your rules.'), findsNothing);
      await tester.tap(find.byTooltip('Open full note'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Full note'), findsOneWidget);
      expect(find.text('Plan for the week'), findsOneWidget);
      await tester.tap(find.text('Back to notes'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('New note'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your text. Your rules.'), findsOneWidget);
      final cancelWidth = tester
          .getSize(find.widgetWithText(OutlinedButton, 'Cancel'))
          .width;
      final saveWidth = tester
          .getSize(find.widgetWithText(FilledButton, 'Save note'))
          .width;
      expect((cancelWidth - saveWidth).abs(), lessThan(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('бэкап открывает основные сценарии на узком экране', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: BackupScreen())),
      ),
    );
    await tester.pump();
    expect(find.text('Encrypted file'), findsOneWidget);
    expect(
      tester.getRect(find.text('Backup and verification')).top,
      lessThan(80),
    );
    await tester.tap(find.text('Export'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose save location'), findsOneWidget);
    expect(tester.getRect(find.text('Export').last).top, lessThan(80));
    await tester.tap(find.byTooltip('Back').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Restore'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose a backup'), findsOneWidget);
    expect(tester.getRect(find.text('Restore').last).top, lessThan(80));
    await tester.tap(find.byTooltip('Back').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Anchor'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Anchor this file version'), findsOneWidget);
    expect(tester.getRect(find.text('Anchor version').first).top, lessThan(80));
    await tester.tap(find.byTooltip('Back').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Verify'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Verify this file version'), findsOneWidget);
    expect(tester.getRect(find.text('Verify backup')).top, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'экспорт, заверение и проверка помещаются на Android в обеих темах',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = const Size(320, 700);
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(mode),
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: const Scaffold(body: BackupScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Encrypted file'), findsOneWidget);
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        expect(find.text('Choose save location'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'export / $mode');
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anchor'));
        await tester.pumpAndSettle();
        expect(find.text('Anchor version'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'anchor / $mode');
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(find.text('Choose .akbackup file'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'verify / $mode');
      }
    },
  );

  testWidgets('Windows показывает бэкап и иллюстрацию в тёмной теме', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: BackupScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Your data under your control'), findsOneWidget);
    await tester.tap(find.text('Export'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing the backup'), findsOneWidget);
    await tester.tap(find.text('Back to backup'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Encrypted file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('восстановление проверяет пароль до экрана замены сейфа', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late VaultSession testVault;
    final bytes = await tester.runAsync(() async {
      testVault = await createVault(
        'correct-password',
        kdf: KdfParams(
          memoryKiB: 1024,
          iterations: 1,
          parallelism: 1,
          salt: randomBytes(16),
        ),
      );
      return saveVault(testVault);
    });
    addTearDown(testVault.close);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: VaultRestoreFlow(
              initialBytes: bytes!,
              onCancel: () {},
              fetchRecord: (_, _) async => null,
              // На устройстве сейфа нет: экран сравнивает бэкап с диском (MAIN-69).
              currentHeader: () async => null,
              unlockBackup: (_, password) async {
                if (password != 'correct-password') {
                  throw StateError('bad password');
                }
                return testVault;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Enter master password'), findsWidgets);
    await tester.tap(find.text('Check file'));
    await tester.pump();
    expect(find.text('Enter the backup master password.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Check file'));
    await tester.pumpAndSettle();
    expect(find.text('Restore the vault?'), findsOneWidget);
    expect(
      find.text('A vault will be created from this backup.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('восстановление с экрана входа помещается на Android и Windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 1360.0]) {
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RestoreScreen())),
      );
      await tester.pump();
      expect(find.text('Choose a backup'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'RestoreScreen at $width px',
      );
    }
  });

  testWidgets('отдельный экран восстановления адаптируется к Light и Dark', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(320, 568), const Size(412, 915)]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: const RestoreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Choose a backup'), findsOneWidget);
        expect(find.text('Choose .akbackup file'), findsOneWidget);
        expect(find.text('Choose file'), findsOneWidget);
        expect(
          tester.getRect(find.text('Choose a backup')).top,
          lessThan(tester.getRect(find.text('Choose file')).top),
        );
        expect(tester.takeException(), isNull, reason: '$size / $mode');
      }
    }
  });

  testWidgets(
    'на Android настройки переключают тему, язык и открывают подтверждение блокировки',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Theme'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Appearance and language'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.ensureVisible(find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(container.read(languageProvider).languageCode, 'en');
      await tester.ensureVisible(find.byTooltip('Back').last);
      await tester.tap(find.byTooltip('Back').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Lock vault'));
      await tester.tap(find.text('Lock vault'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Unsaved changes may be lost.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your vault, your settings.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('шапка всех страниц настроек остаётся сверху на Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(mode),
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Settings')).top, lessThan(80));
      for (final entry in [
        'Theme',
        'Auto lock',
        'Lock vault',
        'Solana Devnet',
      ]) {
        await tester.ensureVisible(find.text(entry));
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Settings')).top,
          lessThan(80),
          reason: '$entry / $mode',
        );
        expect(tester.takeException(), isNull, reason: '$entry / $mode');
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets(
    'окно смены мастер-пароля помещается на Android и проверяет поля',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(mode),
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: const Scaffold(body: SettingsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Master password'));
        await tester.tap(find.text('Master password'));
        await tester.pumpAndSettle();
        expect(find.text('Change master password'), findsOneWidget);
        expect(find.byTooltip('Show password'), findsNWidgets(3));
        await tester.tap(find.byTooltip('Show password').first);
        await tester.pump();
        expect(find.byTooltip('Hide password'), findsOneWidget);
        await tester.ensureVisible(find.text('Save password'));
        await tester.tap(find.text('Save password'));
        await tester.pumpAndSettle();
        expect(find.text('Enter current password.'), findsOneWidget);
        expect(find.text('At least 12 characters.'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode');
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Change master password'), findsNothing);
      }
    },
  );

  testWidgets('Windows показывает настройки и Devnet с иллюстрацией', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Everything stays local'), findsOneWidget);
    await tester.tap(find.text('Solana Devnet'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Network details'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('все подразделы настроек помещаются в Windows панели', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    for (final (entry, heading) in [
      ('Theme', 'Appearance and language'),
      ('Auto lock', 'When should the vault lock?'),
      ('Lock vault', 'Lock now'),
      ('Solana Devnet', 'Network details'),
    ]) {
      await tester.ensureVisible(find.text(entry));
      await tester.tap(find.text(entry));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(heading), findsOneWidget);
      expect(tester.takeException(), isNull, reason: entry);
      await tester.tap(find.text('Back to settings'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$entry back');
    }
  });
}
