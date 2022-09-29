// Copyright 2022 Orpaz & Elichay Mizrachi & Revital Ben-Shmuel. All rights reserved.

import 'dart:isolate';
import 'dart:ui'; //IsolateNameServer.registerPortWithName


import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() {
  //TODO understand 'then'
  initSettings().then((_) {
    initAlarm();
    runApp(const MyApp());
    setAlarm();
  });
}

void printHello(int id) {
  final DateTime now = DateTime.now();
  final int isolateId = Isolate.current.hashCode;
  Settings.setValue('key-isolate-alarm-id', isolateId);
  debugPrint("[$now] Hello, world! isolate=$isolateId,"
      "alarmId = $id, function='$printHello'");
}

class Alarm {
  /// The name associated with the UI isolate's [SendPort].
  static const String _backgroundAlarmIsolate = 'backgroundAlarmIsolate';
  /// A port used to communicate from a background isolate to the UI isolate.
  final ReceivePort _receivePort = ReceivePort();

  // TODO learn more about async in constructors
  Alarm() {
    // Register the UI isolate's SendPort to allow for communication from the
    // background isolate.
    IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _backgroundAlarmIsolate,
    );

    _receivePort.listen((_) => _awakeAlarm());

    //TODO - learn about this line
    WidgetsFlutterBinding.ensureInitialized();
    AndroidAlarmManager.initialize();
  }


  static void _awakeAlarm() {
    //TODO Add log
    // developer.log('Increment counter!');
    // Ensure we've loaded the updated count from the background isolate.
    runApp(const MyApp());
  }

  void setAlarm() {
    const int helloAlarmID = 0;
    int hour = int.parse(Settings.getValue('key-first-hour', '1'));
    int minute = int.parse(Settings.getValue('key-first-minute', '1'));
    var duration = const Duration(minutes: 3);
    DateTime startAt = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      12,
      20,
    );

    AndroidAlarmManager.periodic(duration, helloAlarmID, printHello,
        startAt: startAt, exact: true, wakeup: true, rescheduleOnReboot: true);
  }

}
// TODO understand 'Futures' and there use better
// Init the cache within the settings will be saved
Future<void> initSettings() async {
  await Settings.init(cacheProvider: SharePreferenceCache());
}

// // Init the alarm manager
// Future<void> initAlarm() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await AndroidAlarmManager.initialize();
// }

// void setAlarm() {
//   const int helloAlarmID = 0;
//   int hour = int.parse(Settings.getValue('key-first-hour', '1'));
//   int minute = int.parse(Settings.getValue('key-first-minute', '1'));
//   var duration = const Duration(minutes: 3);
//   DateTime startAt = DateTime(
//     DateTime.now().year,
//     DateTime.now().month,
//     DateTime.now().day,
//     hour,
//     minute,
//   );
//
//   AndroidAlarmManager.periodic(duration, helloAlarmID, printHello,
//       startAt: startAt, exact: true, wakeup: true, rescheduleOnReboot: true);
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'The Guardian',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title = 'שלום'});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                AndroidAlarmManager.cancel(0);
                AndroidAlarmManager.cancel(0);
                debugPrint(Settings.getValue('key-isolate-alarm-id', 'defaultValue'));
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              })
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'שלום '
              // '${Settings.getValue('key-user-title', '3')} '
                  '${Settings.getValue('key-user-name', 'default')}',
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("הגדרות משתמש"),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            tooltip: "לחץ כדי לצאת מהגדרות",
          ),
        ),
        body: SettingsGroup(title: "", children: <Widget>[
          SettingsGroup(title: "פרטים אישיים", children: <Widget>[
            TextInputSettingsTile(
              title: 'שם משתמש',
              settingKey: 'key-user-name',
              initialValue: 'לחץ כדי לעדכן את שמך',
              keyboardType: TextInputType.text,
              borderColor: Colors.blueAccent,
              errorColor: Colors.deepOrangeAccent,
            ),
            TextInputSettingsTile(
              title: 'מספר טלפון',
              settingKey: 'key-user-phone',
              initialValue: 'לחץ כדי לעדכן את מספר הטלפון שלך',
              keyboardType: TextInputType.phone,
              borderColor: Colors.blueAccent,
              errorColor: Colors.deepOrangeAccent,
            ),
          ]),
          SettingsGroup(title: "פרטי איש קשר", children: <Widget>[
            TextInputSettingsTile(
              title: 'שם איש קשר',
              settingKey: 'key-contact-name',
              initialValue: 'לחץ כדי לעדכן את שם איש הקשר',
              keyboardType: TextInputType.text,
              borderColor: Colors.blueAccent,
              errorColor: Colors.deepOrangeAccent,
            ),
            TextInputSettingsTile(
              title: 'מספר טלפון',
              settingKey: 'key-contact-phone',
              initialValue: 'לחץ כדי לעדכן את מספר הטלפון של איש הקשר',
              keyboardType: TextInputType.phone,
            ),
          ]),

          // SimpleDropDownSettingsTile(
          //   title: 'תואר',
          //   settingKey: 'key-user-title',
          //   values: const <String>[
          //     'מר',
          //     'גברת',
          //     'עו"ד',
          //     'רו"ח',
          //     'ד"ר',
          //     "פרופ'",
          //     'אחר'
          //   ],
          //   onChange: (value) {
          //     debugPrint('key-dropdown-email-view: $value');
          //   }, selected: 'אחר',
          // ),

          TextInputSettingsTile(
            title: 'שעת התחלה',
            settingKey: 'key-first-hour',
            keyboardType: TextInputType.number,
            borderColor: Colors.blueAccent,
            errorColor: Colors.deepOrangeAccent,
            onChange: (value) {
              debugPrint('key-first-hour: $value');
            },
          ),
          TextInputSettingsTile(
            title: 'דקות התחלה',
            settingKey: 'key-first-minute',
            keyboardType: TextInputType.number,
            borderColor: Colors.blueAccent,
            errorColor: Colors.deepOrangeAccent,
            onChange: (value) {
              debugPrint('key-first-minute: $value');
            },
          ),
          // SliderSettingsTile(
          //   title: 'שעת התחלה',
          //   settingKey: 'key-slider-first-hour',
          //   defaultValue: DateTime.now().hour.toDouble(),
          //   min: 0,
          //   max: 23,
          //   step: 1,
          //   leading: const Icon(Icons.timelapse),
          //   onChange: (value) {
          //     debugPrint('key-slider-first-hour: $value');
          //   },
          // ),
          //
          // SliderSettingsTile(
          //   title: 'דקות התחלה',
          //   settingKey: 'key-slider-first-minute',
          //   defaultValue: DateTime.now().minute.toDouble(),
          //   min: 0,
          //   max: 59,
          //   step: 1,
          //   leading: const Icon(Icons.timelapse),
          //   onChange: (value) {
          //     debugPrint('key-slider-first-minute: $value');
          //   },
          // ),

          // ColorPickerSettingsTile(
          //   settingKey: 'key-color-picker',
          //   title: 'Accent Color',
          //   defaultValue: Colors.blue,
          //   onChange: (value) {
          //     debugPrint('key-color-picker: $value');
          //   },
          // ),
          //
          // SimpleSettingsTile(
          //   title: 'Advanced',
          //   subtitle: 'More, advanced settings.',
          //   child: SettingsScreen(
          //     title: 'Sub menu',
          //     children: <Widget>[
          //       CheckboxSettingsTile(
          //         settingKey: 'check box',
          //         title: 'This is a simple Checkbox',
          //       ),
          //     ],
          //   ),
          // ),
          SwitchSettingsTile(
            leading: const Icon(Icons.family_restroom),
            settingKey: 'key-switch-shabat-mode',
            title: 'מצב שבת',
            onChange: (value) {
              //TODO whatever happened in shabat mode
              debugPrint('key-switch-shabat-mode: $value');
            },
            childrenIfEnabled: <Widget>[
              CheckboxSettingsTile(
                leading: Icon(Icons.adb),
                settingKey: 'key-is-developer',
                title: 'Developer Mode',
                onChange: (value) {
                  debugPrint('key-is-developer: $value');
                },
              ),
              SwitchSettingsTile(
                leading: Icon(Icons.usb),
                settingKey: 'key-is-usb-debugging',
                title: 'USB Debugging',
                onChange: (value) {
                  debugPrint('key-is-usb-debugging: $value');
                },
              ),
              SimpleSettingsTile(
                title: 'Root Settings',
                subtitle: 'These settings is not accessible',
                enabled: false,
              )
            ],
          ),
        ]));
  }
}
