import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/app/sections.dart';
import 'package:habittech/data/in_memory_repository.dart';
import 'package:habittech/main.dart';
import 'package:habittech/state/app_state.dart';
import 'package:habittech/widgets/habit_card.dart';

import 'helpers.dart';

/// Boots the real app and visits every section. This does not replace
/// testing on a device, but it catches build exceptions and RenderFlex
/// overflows on a small phone screen.
void main() {
  testWidgets('every section renders without errors on a 320px phone',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state =
        AppState(repository: InMemoryStorageRepository(), clock: () => kNow);
    await state.init();

    await tester.pumpWidget(HabitTechApp(state: state));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final section in AppSection.values) {
      state.goTo(section);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section ${section.name}');
    }
  });

  testWidgets('every section renders on a wide desktop window', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state =
        AppState(repository: InMemoryStorageRepository(), clock: () => kNow);
    await state.init();
    await tester.pumpWidget(HabitTechApp(state: state));
    await tester.pumpAndSettle();

    for (final section in AppSection.values) {
      state.goTo(section);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section ${section.name}');
    }
  });

  testWidgets('tapping the check button completes a habit and persists it',
      (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = InMemoryStorageRepository();
    final state = AppState(repository: repo, clock: () => kNow);
    await state.init();
    state.clearDemoData();
    state.addHabit(makeHabit('a', start: '2026-10-01', name: 'Stretch'));
    state.goTo(AppSection.today);

    await tester.pumpWidget(HabitTechApp(state: state));
    await tester.pumpAndSettle();

    expect(state.stats.dayCount(state.today).completed, 0);
    await tester.tap(find.byType(HabitCheckButton).first);
    await tester.pumpAndSettle();

    expect(state.stats.dayCount(state.today).completed, 1);
    expect(find.text('1 of 1 completed'), findsOneWidget);
    await state.flush();
    expect(repo.raw, contains('"habitId":"a"'));
  });
}
