import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/pantry_list_screen.dart';
import 'services/asset_db_installer.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Copy the bundled offline databases into place before anything reads them.
  await AssetDbInstaller.instance.install();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const ProviderScope(child: PantryPalApp()));
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pantry Pal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const PantryListScreen(),
    );
  }
}
