import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation du système de fuseau horaire
  tz.initializeTimeZones();
  
  // Initialisation des préférences partagées
  final prefs = await SharedPreferences.getInstance();
  
  runApp(const HydrationApp());
}

class HydrationApp extends StatelessWidget {
  const HydrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydratation Douce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF4FC3F7), 
          secondary: const Color(0xFF80D8FF), 
          surface: Colors.white,
          background: const Color(0xFFF5F9FF), 
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: const Color(0xFF424242), 
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF424242),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: IconThemeData(color: Color(0xFF424242)),
        ),
      ),
      home: const HydrationHomePage(),
    );
  }
}

class HydrationHomePage extends StatefulWidget {
  const HydrationHomePage({super.key});

  @override
  _HydrationHomePageState createState() => _HydrationHomePageState();
}

class _HydrationHomePageState extends State<HydrationHomePage> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isActive = false;
  int _interval = 60; // en minutes
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadSettings();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Gérer le clic sur la notification si nécessaire
      },
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isActive = prefs.getBool('isActive') ?? false;
      _interval = prefs.getInt('interval') ?? 60;
      // Charger les heures sauvegardées si elles existent
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActive', _isActive);
    await prefs.setInt('interval', _interval);
  }

  Future<void> _scheduleNotifications() async {
    if (!_isActive) {
      await _cancelAllNotifications();
      return;
    }

    // Annuler les notifications existantes
    await _cancelAllNotifications();

    // Planifier les nouvelles notifications
    final now = DateTime.now();
    var current = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
    final end = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);

    int notificationId = 0;
    
    while (current.isBefore(end)) {
      final scheduledTime = tz.TZDateTime.from(current, tz.local);
      
      await _notificationsPlugin.zonedSchedule(
        notificationId++,
        'Il est temps de boire de l\'eau 💧',
        'Votre corps a besoin d\'être hydraté régulièrement.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_reminder',
            'Rappels d\'hydratation',
            channelDescription: 'Rappels pour boire de l\'eau régulièrement',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      current = current.add(Duration(minutes: _interval));
    }
  }

  Future<void> _cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  void _toggleReminders() async {
    setState(() {
      _isActive = !_isActive;
    });
    
    await _saveSettings();
    
    if (_isActive) {
      await _scheduleNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappels d\'hydratation activés')),
      );
    } else {
      await _cancelAllNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappels d\'hydratation désactivés')),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4FC3F7),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF424242),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      await _saveSettings();
      if (_isActive) {
        await _scheduleNotifications();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F9FF),
              Color(0xFFE1F5FE),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Hydratation Douce',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Prenez soin de vous en restant hydraté tout au long de la journée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.water_drop_outlined,
                          size: 60,
                          color: Color(0xFF4FC3F7),
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text(
                            'Activer les rappels',
                            style: TextStyle(fontSize: 18),
                          ),
                          value: _isActive,
                          activeColor: const Color(0xFF4FC3F7),
                          onChanged: (value) => _toggleReminders(),
                        ),
                        const Divider(height: 30),
                        ListTile(
                          title: const Text('Heure de début'),
                          subtitle: Text(
                            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () => _selectTime(context, true),
                        ),
                        ListTile(
                          title: const Text('Heure de fin'),
                          subtitle: Text(
                            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () => _selectTime(context, false),
                        ),
                        const SizedBox(height: 10),
                        const Text('Intervalle entre les rappels'),
                        Slider(
                          value: _interval.toDouble(),
                          min: 15,
                          max: 120,
                          divisions: 7,
                          label: '$_interval min',
                          activeColor: const Color(0xFF4FC3F7),
                          inactiveColor: Colors.grey[300],
                          onChanged: (value) async {
                            setState(() {
                              _interval = value.round();
                            });
                            await _saveSettings();
                            if (_isActive) {
                              await _scheduleNotifications();
                            }
                          },
                        ),
                        Text(
                          'Toutes les $_interval minutes',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Conseil du jour',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 10),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Boire un verre d\'eau au réveil aide à réhydrater votre corps après une nuit de sommeil.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
