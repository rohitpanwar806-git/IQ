import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/player_service.dart';
import 'games/memory_game_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.playerService});

  final PlayerService playerService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('IQ Mind Games'),
        actions: [
          IconButton(
            tooltip: 'Set your name',
            icon: const Icon(Icons.person_outline),
            onPressed: _editName,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Playing as'),
              subtitle: Text(widget.playerService.displayName),
              trailing: TextButton(
                onPressed: _editName,
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Games', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _GameCard(
            title: 'Memory Match',
            subtitle: 'Flip cards and match the pairs against the clock.',
            icon: Icons.grid_view_rounded,
            color: const Color(0xFF5B4CFF),
            onPlay: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MemoryGameScreen(playerService: widget.playerService),
              ),
            ),
            onLeaderboard: () => _openLeaderboard(AppConfig.memoryGameId),
          ),
        ],
      ),
    );
  }

  void _openLeaderboard(String gameId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(gameId: gameId),
      ),
    );
  }

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: widget.playerService.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'Enter a name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await widget.playerService.setDisplayName(name);
      if (mounted) setState(() {});
    }
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPlay,
    required this.onLeaderboard,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPlay;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onLeaderboard,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Ranks'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
