import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class EventTile extends StatelessWidget {
  final Event event;

  const EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(event.title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(DateFormat('MMM d, h:mm a').format(event.startTime)),
      trailing: const Icon(Icons.event, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
