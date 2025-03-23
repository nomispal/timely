import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class UpcomingEventsList extends StatelessWidget {
  const UpcomingEventsList({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final nextWeek = today.add(const Duration(days: 7));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduced vertical padding
          child: Text(
            "Upcoming Tasks",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Slightly smaller font
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.25, // Reduced to 25% of screen height
          child: StreamBuilder<List<Event>>(
            stream: Event.getEventsForDateStream(today, nextWeek),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return const Center(child: Text("No upcoming events."));
              }

              return ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Reduced margin
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          spreadRadius: 0.5, // Reduced shadow
                        ),
                      ],
                    ),
                    child: ListTile(
                      dense: true, // Makes the ListTile more compact
                      visualDensity: const VisualDensity(vertical: -3), // Further reduces vertical space
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // Keeps column as small as possible
                        children: [
                          Text(
                            '${DateFormat('EEE, MMM d').format(event.date)} • ${DateFormat('h:mm a').format(event.startTime)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          if (event.address != null && event.address!.isNotEmpty)
                            Text(
                              event.address!,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              maxLines: 1, // Limits address to one line
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.event, size: 18, color: Colors.blue), // Smaller icon
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}