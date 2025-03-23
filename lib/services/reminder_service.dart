import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:timely/models/event.dart';
import 'package:intl/intl.dart';
import 'package:win_toast/win_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Event> events = [];
  bool _isInitialized = false;
  static const platform = MethodChannel('com.example.trackify/toast');

  // Set to store IDs of events that have already been notified
  Set<String> _notifiedEvents = {};
  SharedPreferences? _prefs;

  Future<void> init(Future<void> Function() showMainWindowCallback) async {
    _prefs = await SharedPreferences.getInstance();
    _loadNotifiedEvents();

    _eventsSubscription =
        _firestore.collection('events').snapshots().listen((snapshot) {
      events = snapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .where((event) => _hasReminder(event))
          .toList();
      print('Firestore events updated: ${events.length} events');
      checkAndShowNotifications();
    });

    try {
      await WinToast.instance().initialize(
        aumId: 'com.example.trackify',
        displayName: 'Trackify Reminders',
        iconPath: 'assets/app_icon.ico',
        clsid: '{6D809377-6AF0-444B-8957-A3773F02200E}',
      );
      platform.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      print('Windows Toast Notifications initialized successfully');
    } catch (e) {
      print('Toast initialization failed: $e');
    }
  }

  void _loadNotifiedEvents() {
    final notifiedList = _prefs?.getStringList('notified_events') ?? [];
    _notifiedEvents = Set<String>.from(notifiedList);
    print('Loaded ${_notifiedEvents.length} previously notified events');
  }

  Future<void> _saveNotifiedEvents() async {
    await _prefs?.setStringList('notified_events', _notifiedEvents.toList());
  }

  String _getReminderKey(Event event) {
    return '${event.id}_${event.reminderPeriodMonths}_${event.reminderDays}';
  }

  bool _hasReminder(Event event) {
    return event.reminderPeriodMonths > 0 || event.reminderDays > 0;
  }

  StreamSubscription<QuerySnapshot>? _eventsSubscription;

  void dispose() {
    _eventsSubscription?.cancel();
  }

  DateTime _calculateReminderTime(Event event) {
    DateTime baseDate = event.date;
    baseDate = DateTime(
      baseDate.year,
      baseDate.month - event.reminderPeriodMonths,
      baseDate.day,
    );
    return baseDate.subtract(Duration(days: event.reminderDays));
  }

  void checkAndShowNotifications() {
    if (!_isInitialized) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var event in events) {
      final reminderTime = _calculateReminderTime(event);
      if (shouldNotify(event, reminderTime, today)) {
        showNotification(event);
        final reminderKey = _getReminderKey(event);
        _notifiedEvents.add(reminderKey);
        _saveNotifiedEvents();
      }
    }
  }

  bool shouldNotify(Event event, DateTime reminderTime, DateTime today) {
    if (!_hasReminder(event)) return false;

    final reminderKey = _getReminderKey(event);
    if (_notifiedEvents.contains(reminderKey)) {
      return false;
    }

    // Check if reminder is for today
    return reminderTime.year == today.year &&
        reminderTime.month == today.month &&
        reminderTime.day == today.day;
  }

  void showNotification(Event event) async {
    if (!_isInitialized) return;

    try {
      await WinToast.instance().showCustomToast(
        xml: '''
        <toast duration="long">
          <visual>
            <binding template="ToastText02">
              <text id="1">Reminder: ${event.title}</text>
              <text id="2">Date: ${DateFormat('MMMM d, yyyy').format(event.date)}</text>
              <text id="3">${event.address ?? 'No address'}</text>
              <text id="4">${event.description ?? 'No description'}</text>
            </binding>
          </visual>
        </toast>
        ''',
      );
      print('Shown toast for ${event.title}');
    } catch (e) {
      print('Failed to show toast: $e');
    }
  }

  Future<void> clearNotificationHistory() async {
    _notifiedEvents.clear();
    await _saveNotifiedEvents();
    print('Notification history cleared');
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print(
        'Received method call: ${call.method} with arguments: ${call.arguments}');
    return null;
  }
}
