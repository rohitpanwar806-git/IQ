import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/player_service.dart';
import '../leaderboard_screen.dart';

/// A classic memory match game.
///
/// The player flips cards to find matching pairs. Score rewards speed and
/// accuracy, and is submitted to the global leaderboard on completion.
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key, required this.playerService});

  final PlayerService playerService;

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  late List<_Card> _cards;
  int? _firstIndex;
  bool _busy = false;
  int _moves = 0;
  int _matches = 0;
  int _seconds = 0;
  Timer? _timer;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  void _startNewGame() {
    final symbols = const [
      '🍎', '🚀', '🐶', '🌟', '🎈', '🍕', '🎸', '⚽',
    ];
    final deck = <_Card>[];
    for (final s in symbols) {
      deck.add(_Card(symbol: s));
      deck.add(_Card(symbol: s));
    }
    deck.shuffle(Random());

    _timer?.cancel();
    setState(() {
      _cards = deck;
      _firstIndex = null;
      _busy = false;
      _moves = 0;
      _matches = 0;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _onTapCard(int index) async {
    if (_busy) return;
    final card = _cards[index];
    if (card.matched || card.faceUp) return;

    setState(() => card.faceUp = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    _moves++;
    final firstIndex = _firstIndex!;
    _firstIndex = null;
    _busy = true;

    if (_cards[firstIndex].symbol == card.symbol) {
      setState(() {
        _cards[firstIndex].matched = true;
        card.matched = true;
        _matches++;
        _busy = false;
      });
      if (_matches == _cards.length ~/ 2) {
        _onWin();
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _cards[firstIndex].faceUp = false;
        card.faceUp = false;
        _busy = false;
      });
    }
  }

  int _computeScore() {
    // Reward finishing fast with few moves. Never below zero.
    const base = 1000;
    final penalty = _seconds * 3 + _moves * 5;
    return max(50, base - penalty);
  }

  Future<void> _onWin() async {
    _timer?.cancel();
    final score = _computeScore();

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WinDialog(
        score: score,
        seconds: _seconds,
        moves: _moves,
        onPlayAgain: () {
          Navigator.pop(context);
          _startNewGame();
        },
        onSubmit: () async {
          Navigator.pop(context);
          await _submitScore(score);
        },
      ),
    );
  }

  Future<void> _submitScore(int score) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.submitScore(
        userId: widget.playerService.userId,
        gameId: AppConfig.memoryGameId,
        score: score,
        displayName: widget.playerService.displayName,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Score submitted!')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const LeaderboardScreen(gameId: AppConfig.memoryGameId),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit score: $e')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Network error submitting score.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Match'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            onPressed: _startNewGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Time', value: '${_seconds}s'),
                _Stat(label: 'Moves', value: '$_moves'),
                _Stat(label: 'Pairs', value: '$_matches / ${_cards.length ~/ 2}'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return _CardTile(
                    card: card,
                    onTap: () => _onTapCard(index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card {
  _Card({required this.symbol});
  final String symbol;
  bool faceUp = false;
  bool matched = false;
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});

  final _Card card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showing = card.faceUp || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: showing
              ? scheme.surfaceContainerHighest
              : scheme.primary,
          borderRadius: BorderRadius.circular(12),
          border: card.matched
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            showing ? card.symbol : '',
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _WinDialog extends StatelessWidget {
  const _WinDialog({
    required this.score,
    required this.seconds,
    required this.moves,
    required this.onPlayAgain,
    required this.onSubmit,
  });

  final int score;
  final int seconds;
  final int moves;
  final VoidCallback onPlayAgain;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 You won!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Score: $score', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Finished in ${seconds}s with $moves moves.'),
        ],
      ),
      actions: [
        TextButton(onPressed: onPlayAgain, child: const Text('Play again')),
        FilledButton(onPressed: onSubmit, child: const Text('Submit score')),
      ],
    );
  }
}
