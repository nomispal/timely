import 'package:flutter/material.dart';

class CalendarController {
  // Notifier for the currently focused day
  final ValueNotifier<DateTime> focusedDayNotifier;

  // Constructor to initialize with the current date
  CalendarController() : focusedDayNotifier = ValueNotifier(DateTime.now());

  // Updates the focused day and notifies listeners
  void updateFocusedDay(DateTime newFocusedDay) {
    focusedDayNotifier.value = newFocusedDay;
  }
}
