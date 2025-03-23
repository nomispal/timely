import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final DateTime date;
  final DateTime startTime;
  final String? description;
  final String? address;
  final String type;
  final bool isRecurring;
  final int? recurrenceInterval;
  final int reminderPeriodMonths;
  final int reminderDays;
  final int reminderMinutes;
  final int recurrenceDays;
  final int recurrenceMinutes;
  final int? recurrenceDayOfMonth;
  final List<DateTime> excludedDates;
  final int? recurrenceCount;
  final DateTime? recurrenceEndDate;
  final bool? notified;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    this.description,
    this.address,
    required this.type,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.reminderPeriodMonths = 0,
    this.reminderDays = 0,
    this.reminderMinutes = 0,
    this.recurrenceDays = 0,
    this.recurrenceMinutes = 0,
    this.recurrenceDayOfMonth,
    this.excludedDates = const [],
    this.recurrenceCount,
    this.recurrenceEndDate,
    this.notified,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'description': description,
      'address': address,
      'type': type,
      'isRecurring': isRecurring,
      'recurrenceInterval': recurrenceInterval,
      'reminderPeriodMonths': reminderPeriodMonths,
      'reminderDays': reminderDays,
      'reminderMinutes': reminderMinutes,
      'recurrenceDays': recurrenceDays,
      'recurrenceMinutes': recurrenceMinutes,
      'recurrenceDayOfMonth': recurrenceDayOfMonth,
      'excludedDates':
          excludedDates.map((date) => Timestamp.fromDate(date)).toList(),
      'recurrenceCount': recurrenceCount,
      'recurrenceEndDate': recurrenceEndDate != null
          ? Timestamp.fromDate(recurrenceEndDate!)
          : null,
      'notified': notified,
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      description: data['description'],
      address: data['address'],
      type: data['type'] ?? 'other',
      isRecurring: data['isRecurring'] ?? false,
      recurrenceInterval: data['recurrenceInterval'],
      reminderPeriodMonths: data['reminderPeriodMonths'] ?? 0,
      reminderDays: data['reminderDays'] ?? 0,
      reminderMinutes: data['reminderMinutes'] ?? 0,
      recurrenceDays: data['recurrenceDays'] ?? 0,
      recurrenceMinutes: data['recurrenceMinutes'] ?? 0,
      recurrenceDayOfMonth: data['recurrenceDayOfMonth'],
      excludedDates: (data['excludedDates'] as List<dynamic>?)
              ?.map((timestamp) => (timestamp as Timestamp).toDate())
              .toList() ??
          [],
      recurrenceCount: data['recurrenceCount'],
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? (data['recurrenceEndDate'] as Timestamp).toDate()
          : null,
      notified: data['notified'] as bool?,
    );
  }

  DateTime get reminderDate {
    DateTime adjustedDate = date;
    adjustedDate = DateTime(
      adjustedDate.year,
      adjustedDate.month - reminderPeriodMonths,
      adjustedDate.day,
      adjustedDate.hour,
      adjustedDate.minute,
    );
    return adjustedDate
        .subtract(Duration(days: reminderDays, minutes: reminderMinutes));
  }

  static Future<void> addEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());
      print('Event added with ID: ${event.id}');
    } catch (e) {
      print('Error adding event: $e');
      throw Exception('Failed to add event: $e');
    }
  }

  static Future<void> removeEvent(Event event) async {
    try {
      final firestore = FirebaseFirestore.instance;
      print('Attempting to delete event with ID: ${event.id}');
      await firestore.collection('events').doc(event.id).delete();

      if (event.id.contains('--')) {
        String baseId = event.id.split('--')[0];
        DateTime occurrenceDate = event.date;
        print('Occurrence date to exclude: $occurrenceDate');

        DocumentSnapshot baseDoc =
            await firestore.collection('events').doc(baseId).get();
        if (baseDoc.exists) {
          List<DateTime> excludedDates = List<DateTime>.from(
            (baseDoc.data() as Map<String, dynamic>)['excludedDates']
                    ?.map((t) => (t as Timestamp).toDate()) ??
                [],
          );
          DateTime normalizedOccurrenceDate = DateTime(
              occurrenceDate.year, occurrenceDate.month, occurrenceDate.day);
          if (!excludedDates.any((d) => DateTime(d.year, d.month, d.day)
              .isAtSameMomentAs(normalizedOccurrenceDate))) {
            print('Adding $occurrenceDate to excludedDates for ID: $baseId');
            excludedDates.add(occurrenceDate);
            await firestore.collection('events').doc(baseId).update({
              'excludedDates':
                  excludedDates.map((d) => Timestamp.fromDate(d)).toList(),
            });
          }
        } else {
          print(
              'Base event not found for ID: $baseId; occurrence deleted anyway');
        }
      }
    } catch (e) {
      print('Error deleting event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    DateTime? startTime,
    String? description,
    String? address,
    String? type,
    bool? isRecurring,
    int? recurrenceInterval,
    int? reminderPeriodMonths,
    int? reminderDays,
    int? reminderMinutes,
    int? recurrenceDays,
    int? recurrenceMinutes,
    int? recurrenceDayOfMonth,
    int? recurrenceCount,
    DateTime? recurrenceEndDate,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      description: description ?? this.description,
      address: address ?? this.address,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      reminderPeriodMonths: reminderPeriodMonths ?? this.reminderPeriodMonths,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceMinutes: recurrenceMinutes ?? this.recurrenceMinutes,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      excludedDates: excludedDates,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
    );
  }

  static Stream<List<Event>> getAllEventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
  }

  static Stream<List<Event>> getEventsForDateStream(
      DateTime start, DateTime end) {
    return FirebaseFirestore.instance.collection('events').snapshots().map(
      (snapshot) {
        final events = <Event>[];
        final seenIds = <String>{};

        for (final doc in snapshot.docs) {
          final event = Event.fromFirestore(doc);

          // Add the base event if it falls within the date range
          if (event.date.isAfter(start.subtract(const Duration(days: 1))) &&
              event.date.isBefore(end.add(const Duration(days: 1))) &&
              !event.excludedDates.any((d) => d.isAtSameMomentAs(event.date)) &&
              !seenIds.contains(event.id)) {
            events.add(event);
            seenIds.add(event.id);
          }

          if (event.isRecurring &&
              event.recurrenceCount != null &&
              event.recurrenceCount! > 0) {
            String baseId =
                event.id.contains('--') ? event.id.split('--')[0] : event.id;
            DateTime nextDate = event.date;
            int occurrenceCount = 1; // Base event is the first occurrence

            if (event.recurrenceInterval != null &&
                event.recurrenceInterval! > 0) {
              if (event.recurrenceInterval == 30 &&
                  event.recurrenceDayOfMonth != null) {
                // Monthly recurrence
                while (occurrenceCount < event.recurrenceCount! &&
                    nextDate.isBefore(end) &&
                    (event.recurrenceEndDate == null ||
                        nextDate.isBefore(event.recurrenceEndDate!))) {
                  nextDate = DateTime(nextDate.year, nextDate.month + 1,
                      event.recurrenceDayOfMonth!);
                  if (nextDate.day != event.recurrenceDayOfMonth) {
                    nextDate = DateTime(nextDate.year, nextDate.month + 1, 1)
                        .subtract(const Duration(days: 1));
                  }
                  if (nextDate.isAfter(event.date)) {
                    // Ensure we don’t re-add the base date
                    occurrenceCount++;
                    _addOccurrence(
                        event, nextDate, baseId, end, start, events, seenIds);
                  }
                }
              } else if (event.recurrenceInterval == 365 &&
                  event.recurrenceDayOfMonth != null) {
                // Yearly recurrence with multi-year interval
                int yearsInterval = event.recurrenceDays ~/ 365;
                if (yearsInterval < 1)
                  yearsInterval = 1; // Minimum interval of 1 year
                while (occurrenceCount < event.recurrenceCount! &&
                    nextDate.isBefore(end) &&
                    (event.recurrenceEndDate == null ||
                        nextDate.isBefore(event.recurrenceEndDate!))) {
                  nextDate = DateTime(nextDate.year + yearsInterval,
                      nextDate.month, event.recurrenceDayOfMonth!);
                  if (nextDate.month != event.date.month ||
                      nextDate.day != event.recurrenceDayOfMonth) {
                    nextDate = DateTime(nextDate.year, nextDate.month + 1, 1)
                        .subtract(const Duration(days: 1));
                    if (nextDate.day > event.recurrenceDayOfMonth!) {
                      nextDate = DateTime(nextDate.year, nextDate.month,
                          event.recurrenceDayOfMonth!);
                    }
                  }
                  if (nextDate.isAfter(event.date)) {
                    // Ensure we don’t re-add the base date
                    occurrenceCount++;
                    _addOccurrence(
                        event, nextDate, baseId, end, start, events, seenIds);
                  }
                }
              } else {
                // Custom recurrence (days/minutes), including daily
                int totalRecurrenceMinutes =
                    (event.recurrenceDays * 24 * 60) + event.recurrenceMinutes;
                while (occurrenceCount < event.recurrenceCount! &&
                    nextDate.isBefore(end) &&
                    (event.recurrenceEndDate == null ||
                        nextDate.isBefore(event.recurrenceEndDate!))) {
                  if (totalRecurrenceMinutes > 0) {
                    nextDate =
                        nextDate.add(Duration(minutes: totalRecurrenceMinutes));
                    if (nextDate.isAfter(event.date)) {
                      // Ensure we don’t re-add the base date
                      occurrenceCount++;
                      _addOccurrence(
                          event, nextDate, baseId, end, start, events, seenIds);
                    }
                  } else {
                    break;
                  }
                }
              }
            }
          }
        }
        return events;
      },
    );
  }

  static void _addOccurrence(Event event, DateTime nextDate, String baseId,
      DateTime end, DateTime start, List<Event> events, Set<String> seenIds) {
    final eventId = '$baseId--${nextDate.millisecondsSinceEpoch}';
    if (nextDate.isAfter(start) &&
        nextDate.isBefore(end) &&
        !event.excludedDates.any((d) => d.isAtSameMomentAs(nextDate)) &&
        !seenIds.contains(eventId) &&
        (event.recurrenceEndDate == null ||
            nextDate.isBefore(event.recurrenceEndDate!))) {
      events.add(event.copyWith(
        id: eventId,
        date: nextDate,
        startTime: nextDate,
        isRecurring: false,
      ));
      seenIds.add(eventId);
    }
  }
}
