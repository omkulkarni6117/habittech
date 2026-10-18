import 'package:flutter/material.dart';

import '../core/date_utils.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class _Message {
  const _Message(this.quote, this.reminder);
  final String quote;
  final String reminder;
}

const List<_Message> _messages = [
  _Message('Consistency beats perfection.',
      'Small actions repeated daily create meaningful progress.'),
  _Message('Show up today.',
      'On a low-energy day, do the smallest version of your habit.'),
  _Message('Progress, not perfection.',
      'A missed day is data, not failure. Start again tomorrow.'),
  _Message('You do not have to be extreme, just consistent.',
      'Pick one habit and protect it today.'),
  _Message('Make it easy to start.',
      'Lay out what you need the night before.'),
  _Message('Tiny habits compound.',
      'One percent better each day adds up over a year.'),
  _Message('Never miss twice.',
      'If you skip a day, make the next one count.'),
  _Message('Your future self is watching.',
      'Do one thing today they will thank you for.'),
  _Message('Rest is part of the plan.',
      'Sleep and recovery make every other habit easier.'),
  _Message('Start where you are.', 'A five-minute version still counts.'),
  _Message('Stack your habits.',
      'Attach a new habit to one you already do every day.'),
  _Message('Celebrate small wins.',
      'Check it off and notice how it feels.'),
];

/// Daily quote plus a practical reminder. The message is chosen from the
/// date, so it is stable all day; the refresh button steps to the next one
/// without touching any other widget.
class MotivationCard extends StatefulWidget {
  const MotivationCard({super.key, required this.today});

  final DateTime today;

  @override
  State<MotivationCard> createState() => _MotivationCardState();
}

class _MotivationCardState extends State<MotivationCard> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final dayOfYear = daysBetween(DateTime(widget.today.year, 1, 1), widget.today);
    final message = _messages[(dayOfYear + _offset) % _messages.length];
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.lightbulb_outline, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily motivation',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.quote,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  message.reminder,
                  style: TextStyle(color: c.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Show another message',
            onPressed: () => setState(() => _offset++),
            icon: Icon(Icons.refresh, color: c.primaryStrong),
          ),
        ],
      ),
    );
  }
}
