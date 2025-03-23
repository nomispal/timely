import 'dart:async';
import 'dart:io';
import 'package:timely/models/event.dart';
import 'package:timely/pages/home_page.dart';
import 'package:timely/pages/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:system_tray/system_tray.dart';
import 'package:timely/services/reminder_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:win32_registry/win32_registry.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isWindowClosed = false;
const String socketHost = '127.0.0.1';
const int socketPort = 58932;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for another instance and restore if found
  if (await _isAnotherInstanceRunning()) {
    await _sendRestoreCommand();
    exit(0); // Exit this instance
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Initialize reminder service and set up periodic checks
  await ReminderService().init(showMainWindow);

  // Check reminders every minute
  Timer.periodic(const Duration(minutes: 1), (timer) {
    ReminderService().checkAndShowNotifications();
  });

  // Configure window options
  const mainWindowOptions = WindowOptions(
    size: Size(1200, 650), // Initial size
    center: true,
    backgroundColor: Color(0xFF1A6B3C),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    minimumSize: Size(800, 400),
  );

  // Configure auto-start for Windows
  await configureAutoStart();

  // Initialize system tray
  await initSystemTray();

  // Show and focus the window
  await windowManager.waitUntilReadyToShow(mainWindowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Prevent the app from closing fully; minimize to tray instead
  await windowManager.setPreventClose(true);
  windowManager.addListener(MyWindowListener());

  // Start the socket server to handle restore commands
  _startSocketServer();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[200],
          elevation: 0,
        ),
      ),
      routes: {
        '/': (context) => const HomePage(),
        '/reminders': (context) => const RemindersScreen(),
      },
      initialRoute: '/',
    );
  }
}

class MyWindowListener extends WindowListener {
  @override
  Future<void> onWindowClose() async {
    // Minimize to tray instead of closing
    isWindowClosed = true;
    await windowManager.hide();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'focus' && isWindowClosed) {
      showMainWindow();
    }
  }
}

Future<void> configureAutoStart() async {
  if (!Platform.isWindows) return;

  final key = Registry.currentUser.createKey(
    r'Software\Microsoft\Windows\CurrentVersion\Run',
  );

  try {
    final exePath = Platform.resolvedExecutable;
    key.createValue(
      RegistryValue(
        'DayTrack',
        RegistryValueType.string,
        exePath,
      ),
    );
  } finally {
    key.close();
  }
}

Future<void> initSystemTray() async {
  final systemTray = SystemTray();
  final menu = Menu();

  await systemTray.initSystemTray(
    iconPath: 'assets/app_icon.ico',
    toolTip: 'Calendar Reminders',
  );

  await menu.buildFrom([
    MenuItemLabel(
      label: 'Show Reminders',
      onClicked: (_) async => await showRemindersRoute(),
    ),
    MenuItemLabel(
      label: 'Open App',
      onClicked: (_) async => await showMainWindow(),
    ),
    MenuItemLabel(
      label: 'Test Reminder Now',
      onClicked: (_) async {
        print('Testing notification now');
        ReminderService().showNotification(
          Event(
            id: 'test',
            title: 'Immediate Test',
            date: DateTime.now(),
            reminderDays: 0,
            reminderPeriodMonths: 0,
            startTime: DateTime.now(),
            type: 'personal',
          ),
        );
      },
    ),
    MenuSeparator(),
    MenuItemLabel(
      label: 'Exit',
      onClicked: (_) => exit(0), // Explicit exit option
    ),
  ]);

  // Handle system tray clicks
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      // Left click restores the app
      showMainWindow();
    } else if (eventName == kSystemTrayEventRightClick) {
      // Right click shows the context menu
      systemTray.popUpContextMenu();
    }
  });
}

Future<void> showMainWindow() async {
  isWindowClosed = false;
  final isVisible = await windowManager.isVisible();
  if (!isVisible) {
    await windowManager.show();
    await windowManager.focus();
  }
  navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
}

Future<void> showRemindersRoute() async {
  isWindowClosed = false;
  if (!await windowManager.isVisible()) {
    await windowManager.show();
    await windowManager.focus();
  }
  if (navigatorKey.currentState?.canPop() ?? false) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
  navigatorKey.currentState?.pushNamed('/reminders');
}

Future<bool> _isAnotherInstanceRunning() async {
  try {
    final socket = await Socket.connect(socketHost, socketPort,
        timeout: const Duration(seconds: 2)); // Increased timeout
    await socket.close();
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> _sendRestoreCommand() async {
  try {
    final socket = await Socket.connect(socketHost, socketPort,
        timeout: const Duration(seconds: 2)); // Increased timeout
    socket.write('restore');
    await socket.flush();
    await socket.close();
  } catch (e) {
    print('Failed to send restore command: $e');
  }
}

void _startSocketServer() async {
  try {
    final server = await ServerSocket.bind(socketHost, socketPort);
    server.listen((socket) async {
      socket.listen((data) async {
        final command = String.fromCharCodes(data).trim();
        if (command == 'restore') {
          await showMainWindow();
        }
      });
    }, onError: (error) {
      print('Socket server error: $error');
    }, onDone: () {
      print('Socket server closed');
    });
  } catch (e) {
    print('Failed to start socket server: $e');
  }
}
