import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../state/calendar_controller.dart';
import 'upcoming_event_list.dart';

// New color scheme
const Color primaryColor = Color(0xFF1A6B3C);
const Color accentColor = Color(0xFF4CAF50);
const Color backgroundColor = Colors.white;
const Color cardColor = Colors.white;
const Color subtleColor = Color(0xFFF5F5F5);

const Duration _animationDuration = Duration(milliseconds: 300);
const Curve _animationCurve = Curves.easeInOut;

class MyCalendar extends StatefulWidget {
  final CalendarController controller;

  const MyCalendar({required this.controller, super.key});

  @override
  State<MyCalendar> createState() => _MyCalendarState();
}

class _MyCalendarState extends State<MyCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.controller.focusedDayNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _animationDuration,
      curve: _animationCurve,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<DateTime>(
                valueListenable: widget.controller.focusedDayNotifier,
                builder: (context, focusedDay, _) {
                  _focusedDay = focusedDay;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TableCalendar(
                      rowHeight: 36,
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2050, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          widget.controller.focusedDayNotifier.value =
                              focusedDay;
                        });
                      },
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month'
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                          widget.controller.focusedDayNotifier.value =
                              focusedDay;
                        });
                      },
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      calendarStyle: CalendarStyle(
                        cellPadding: const EdgeInsets.all(2),
                        cellMargin: const EdgeInsets.all(2),
                        defaultTextStyle: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        weekendTextStyle: const TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        todayDecoration: BoxDecoration(
                          color: accentColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        leftChevronVisible: false,
                        rightChevronVisible: false,
                      ),
                      headerVisible: true,
                      calendarBuilders: CalendarBuilders(
                        headerTitleBuilder: (context, day) {
                          return _buildCustomHeader(day);
                        },
                        dowBuilder: (context, day) {
                          final text = [
                            'M',
                            'T',
                            'W',
                            'T',
                            'F',
                            'S',
                            'S'
                          ][day.weekday - 1];
                          return Center(
                            child: Text(
                              text,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: subtleColor, height: 24, thickness: 1),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      UpcomingEventsList(),
                      Divider(color: subtleColor, height: 16, thickness: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(DateTime focusedDay) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: focusedDay.month,
          items: List.generate(12, (index) {
            return DropdownMenuItem(
              value: index + 1,
              child: Text(
                DateFormat('MMMM').format(DateTime(2020, index + 1)),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            );
          }),
          onChanged: (month) {
            if (month != null) {
              setState(() {
                _focusedDay =
                    DateTime(_focusedDay.year, month, _focusedDay.day);
                widget.controller.focusedDayNotifier.value = _focusedDay;
              });
            }
          },
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: focusedDay.year,
          items: List.generate(31, (index) {
            final year = 2020 + index;
            return DropdownMenuItem(
              value: year,
              child: Text(
                '$year',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            );
          }),
          onChanged: (year) {
            if (year != null) {
              setState(() {
                _focusedDay =
                    DateTime(year, _focusedDay.month, _focusedDay.day);
                widget.controller.focusedDayNotifier.value = _focusedDay;
              });
            }
          },
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
        ),
      ],
    );
  }
}
