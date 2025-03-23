import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/calendar_controller.dart';
import './event_dialog.dart';
import '../models/event.dart';

const Color primaryColor = Color(0xFF1A6B3C);
const Color accentColor = Color(0xFF4CAF50);
const Color backgroundColor = Colors.white;
const Color cardColor = Colors.white;
const Color subtleColor = Color(0xFFF5F5F5);

const Duration _animationDuration = Duration(milliseconds: 500);
const Curve _animationCurve = Curves.easeInOut;

Map<String, Color> _eventTypeColor = {
  'meeting': const Color(0xFF4CAF50),
  'personal': const Color(0xFF2196F3),
  'work': const Color(0xFFFFC107),
  'social': const Color(0xFF9C27B0),
  'other': const Color(0xFF8BC34A),
};

class HomeCalendar extends StatefulWidget {
  final CalendarController controller;

  const HomeCalendar({required this.controller, super.key});

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar>
    with TickerProviderStateMixin {
  final Map<DateTime, String> _selectedAddresses = {};
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;
  late DateTime _lastFocusedDay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: _animationCurve),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: _animationCurve),
    );
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
          parent: _buttonAnimationController, curve: _animationCurve),
    );
    _animationController.forward();
    _lastFocusedDay = widget.controller.focusedDayNotifier.value;
  }

  @override
  void didUpdateWidget(HomeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.focusedDayNotifier.value != _lastFocusedDay) {
      _lastFocusedDay = widget.controller.focusedDayNotifier.value;
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  List<DateTime> _getMonthDays(DateTime focusedDay) {
    final start = _startOfMonth(focusedDay);
    final end = _endOfMonth(focusedDay);
    final daysInMonth = end.day;
    final firstWeekday = start.weekday - 1; // Monday = 0, Sunday = 6
    List<DateTime> days = [];

    for (int i = firstWeekday - 1; i >= 0; i--) {
      days.add(start.subtract(Duration(days: i + 1)));
    }

    for (int i = 0; i < daysInMonth; i++) {
      days.add(start.add(Duration(days: i)));
    }

    final remainingDays = 42 - days.length;
    for (int i = 0; i < remainingDays; i++) {
      days.add(end.add(Duration(days: i + 1)));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        backgroundColor: cardColor,
        title: ValueListenableBuilder<DateTime>(
          valueListenable: widget.controller.focusedDayNotifier,
          builder: (context, focusedDay, _) {
            _animationController.reset();
            _animationController.forward();
            return Text(
              DateFormat('MMMM yyyy').format(focusedDay),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor),
            );
          },
        ),
        shadowColor: Colors.grey.withOpacity(0.2),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: primaryColor),
            onPressed: () {
              widget.controller.focusedDayNotifier.value = DateTime(
                  widget.controller.focusedDayNotifier.value.year,
                  widget.controller.focusedDayNotifier.value.month - 1);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: primaryColor),
            onPressed: () {
              widget.controller.focusedDayNotifier.value = DateTime(
                  widget.controller.focusedDayNotifier.value.year,
                  widget.controller.focusedDayNotifier.value.month + 1);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            children: [
              Row(
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[800]),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: widget.controller.focusedDayNotifier,
                  builder: (context, focusedDay, _) {
                    final monthDays = _getMonthDays(focusedDay);
                    final startOfMonthDate = _startOfMonth(focusedDay);
                    final endOfMonthDate = _endOfMonth(focusedDay);

                    return StreamBuilder<List<Event>>(
                      stream: Event.getEventsForDateStream(
                          startOfMonthDate, endOfMonthDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor)));
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red)));
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _animationController.reset();
                          _animationController.forward();
                        });

                        final events = snapshot.data ?? [];
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: monthDays.length,
                            itemBuilder: (context, index) {
                              final day = monthDays[index];
                              final isCurrentMonth =
                                  day.month == focusedDay.month;
                              final dayEvents = events
                                  .where(
                                      (event) => _isSameDate(event.date, day))
                                  .toList();

                              return GestureDetector(
                                onTap: () =>
                                    _showDayDetailsDialog(day, dayEvents),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isCurrentMonth
                                        ? cardColor
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Align(
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isCurrentMonth
                                                  ? Colors.black87
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (dayEvents.isNotEmpty)
                                        Positioned(
                                          top: 20,
                                          bottom: 2,
                                          left: 2,
                                          right: 2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ...dayEvents.take(5).map(
                                                    (event) => Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 1.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                            width: 4,
                                                            height: 4,
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    right: 4),
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: _eventTypeColor[
                                                                      event.type
                                                                          .toLowerCase()] ??
                                                                  accentColor,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              event.title.length >
                                                                      12
                                                                  ? '${event.title.substring(0, 12)}...'
                                                                  : event.title,
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: isCurrentMonth
                                                                    ? Colors
                                                                        .black87
                                                                    : Colors.grey[
                                                                        400],
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                          if (event
                                                                  .isRecurring ||
                                                              event.recurrenceInterval !=
                                                                  null ||
                                                              event.id.contains(
                                                                  '--'))
                                                            const Icon(
                                                                Icons.repeat,
                                                                size: 8,
                                                                color:
                                                                    primaryColor),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              if (dayEvents.length > 5)
                                                Text(
                                                  '+${dayEvents.length - 5}',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isCurrentMonth
                                                        ? primaryColor
                                                        : Colors.grey[400],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayDetailsDialog(DateTime day, List<Event> dayEvents) {
    print(
        'Showing details for $day with events: ${dayEvents.map((e) => e.title).toList()}');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardColor,
        elevation: 4,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(day),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No Events',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      return _buildEventTile(event);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _buttonAnimationController,
                  builder: (context, child) {
                    return ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _buttonAnimationController.forward();
                          await _buttonAnimationController.reverse();
                          Navigator.pop(context);
                          _showAddEventDialog(day);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          elevation: 2,
                          shadowColor: accentColor.withOpacity(0.4),
                        ),
                        child: const Text('Add Event',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _eventTypeColor[event.type.toLowerCase()]?.withOpacity(0.2) ??
            subtleColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Title: ${event.title}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    if (event.isRecurring ||
                        event.recurrenceInterval != null ||
                        event.id.contains('--'))
                      const Icon(Icons.repeat, size: 16, color: primaryColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateFormat('MMMM d, yyyy').format(event.date)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                if (event.address != null && event.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Address: ${event.address!}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Comments: ${event.description!}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: primaryColor),
                onPressed: () {
                  Navigator.pop(context);
                  _updateEvent(event);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(event);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog(DateTime day) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EventDialog(
          date: day,
          onSave: () => setState(() {
            _animationController.reset();
            _animationController.forward();
          }),
          selectedAddresses: _selectedAddresses,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
              child: child),
        );
      },
    );
  }

  Future<void> _updateEvent(Event event) async {
    print(
        'Updating event: ID=${event.id}, Title=${event.title}, Date=${event.date}');
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EventDialog(
          date: event.date,
          onSave: () => setState(() {
            _animationController.reset();
            _animationController.forward();
          }),
          selectedAddresses: _selectedAddresses,
          event: event,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
              child: child),
        );
      },
    );
  }

  void _confirmDelete(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardColor,
        elevation: 4,
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[700], size: 24),
            const SizedBox(width: 12),
            const Text('Delete Event',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this ${event.isRecurring || event.id.contains('--') ? 'occurrence' : 'event'}?',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(event);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16))),
        ],
      ),
    );
  }

  Future<void> _performDelete(Event event) async {
    try {
      await Event.removeEvent(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.isRecurring || event.id.contains('--')
                ? 'Occurrence deleted'
                : 'Event deleted'),
            backgroundColor: accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _animationController.reset();
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting event: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  bool _isSameDate(DateTime date1, DateTime date2) =>
      date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}
