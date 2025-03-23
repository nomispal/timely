import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/event_title.dart';

class EventSearch extends StatefulWidget {
  const EventSearch({super.key});

  @override
  _EventSearchState createState() => _EventSearchState();
}

class _EventSearchState extends State<EventSearch> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Search events...",
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (value) {
              setState(() {
                query = value.toLowerCase();
              });
            },
          ),
        ),
        StreamBuilder<List<Event>>(
          stream: Event.getAllEventsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final filteredEvents = snapshot.data!
                .where((event) => event.title.toLowerCase().contains(query))
                .toList();

            return ListView.builder(
              shrinkWrap: true,
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) =>
                  EventTile(event: filteredEvents[index]),
            );
          },
        ),
      ],
    );
  }
}
