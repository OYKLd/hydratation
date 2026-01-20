import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const HydrationApp());
}

class HydrationApp extends StatelessWidget {
  const HydrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hydratation Douce',
      theme: ThemeData(
        primaryColor: const Color(0xFF4FC3F7),
        fontFamily: 'Roboto',
      ),
      home: const HydrationHomePage(),
    );
  }
}

class HydrationHomePage extends StatefulWidget {
  const HydrationHomePage({super.key});

  @override
  State<HydrationHomePage> createState() => _HydrationHomePageState();
}

class _HydrationHomePageState extends State<HydrationHomePage> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isActive = false;
  int _interval = 60;

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  // ---------------- CONSEILS ----------------
  final List<String> _tips = [
    "Boire un verre d’eau au réveil aide à réhydrater le corps.",
    "Boire régulièrement évite les maux de tête.",
    "L’eau améliore la concentration.",
    "Boire avant d’avoir soif est une bonne habitude.",
    "Une bonne hydratation améliore la peau.",
    "Boire après le sport aide la récupération.",
    "Garde toujours une bouteille près de toi.",
    "L’eau aide à éliminer les toxines.",
  ];

  String _dailyTip = "";

  // -----------------------------------------

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadSettings();
    _generateDailyTip();
  }

  void _generateDailyTip() {
    final today = DateTime.now().day;
    final index = today % _tips.length;
    _dailyTip = _tips[index];
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _notificationsPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isActive = prefs.getBool('isActive') ?? false;
      _interval = prefs.getInt('interval') ?? 60;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActive', _isActive);
    await prefs.setInt('interval', _interval);
  }

  Future<void> _cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> _scheduleNotifications() async {
    if (!_isActive) return;

    await _cancelAllNotifications();

    final now = DateTime.now();

    DateTime current = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );

    final end = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime.hour,
      _endTime.minute,
    );

    int id = 0;

    while (current.isBefore(end)) {
      await _notificationsPlugin.zonedSchedule(
        id++,
        'Hydratation 💧',
        'Pense à boire de l’eau',
        tz.TZDateTime.from(current, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration',
            'Rappels hydratation',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      current = current.add(Duration(minutes: _interval));
    }
  }

  void _toggleReminders() async {
    setState(() => _isActive = !_isActive);
    await _saveSettings();

    if (_isActive) {
      await _scheduleNotifications();
    } else {
      await _cancelAllNotifications();
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        isStart ? _startTime = picked : _endTime = picked;
      });

      if (_isActive) _scheduleNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Hydratation Douce",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Prenez soin de vous en restant hydratée toute la journée",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // ---------------- CARD PRINCIPALE ----------------
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        size: 60,
                        color: Color(0xFF4FC3F7),
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text("Activer les rappels"),
                        value: _isActive,
                        onChanged: (_) => _toggleReminders(),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text("Heure de début"),
                        subtitle: Text(_startTime.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectTime(true),
                      ),
                      ListTile(
                        title: const Text("Heure de fin"),
                        subtitle: Text(_endTime.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectTime(false),
                      ),
                      const SizedBox(height: 10),
                      const Text("Intervalle entre les rappels"),
                      Slider(
                        value: _interval.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 7,
                        label: "$_interval min",
                        onChanged: (v) {
                          setState(() => _interval = v.round());
                          _saveSettings();
                          if (_isActive) _scheduleNotifications();
                        },
                      ),
                      Text("Toutes les $_interval minutes"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- CONSEIL DU JOUR ----------------
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Conseil du jour",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _dailyTip,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
