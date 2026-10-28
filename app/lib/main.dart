import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/events/sqflite_event_repository.dart';
import 'core/storage/app_database.dart';
import 'features/settings/settings_provider.dart';
import 'features/settings/settings_repository.dart';
import 'features/today/routine_repository.dart';
import 'features/today/routines_provider.dart';
import 'features/today/today_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsRepository().load();
  final database = await openAppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        eventRepositoryProvider.overrideWithValue(
          SqfliteEventRepository(database),
        ),
        routineRepositoryProvider.overrideWithValue(
          SqfliteRoutineRepository(database),
        ),
      ],
      child: const DailyAnchorApp(),
    ),
  );
}
