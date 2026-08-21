import 'package:flutter/material.dart';

import 'services/player_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final playerService = PlayerService();
  await playerService.load();

  runApp(IQGamesApp(playerService: playerService));
}

class IQGamesApp extends StatelessWidget {
  const IQGamesApp({super.key, required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IQ Mind Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B4CFF)),
        useMaterial3: true,
      ),
      home: HomeScreen(playerService: playerService),
    );
  }
}
