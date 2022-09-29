// Copyright 2022 Orpaz & Elichay Mizrachi & Revital Ben-Shmuel. All rights reserved.
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

class NotificationManager {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  /// Streams are created so that app can respond to notification-related events
  /// since the plugin is initialised in the `main` function
  final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
  StreamController<ReceivedNotification>.broadcast();

  final StreamController<String?> selectNotificationStream =
  StreamController<String?>.broadcast();

//TODO - understand
  static const MethodChannel platform = MethodChannel('yad_sara_channel');

  static const String portName = 'notification_send_port';

  // TODO - put at the right place
  static bool notificationsEnabled = false;

  String? selectedNotificationPayload;

// TODO - doesn't really needed
  /// A notification action which triggers a url launch event
  static const String _urlLaunchActionId = 'id_1';

  /// A notification action which triggers a App navigation event
  static const String _navigationActionId = 'id_3';

  /// Defines a iOS/MacOS notification category for text input actions.
  static const String _darwinNotificationCategoryText = 'textCategory';

  /// Defines a iOS/MacOS notification category for plain actions.
  static const String _darwinNotificationCategoryPlain = 'plainCategory';

  // TODO - to understand this need & configure a top level or static method which
  // will handle the action:
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    // ignore: avoid_print
    print('notification(${notificationResponse.id}) action tapped: '
        '${notificationResponse.actionId} with'
        ' payload: ${notificationResponse.payload}');
    if (notificationResponse.input?.isNotEmpty ?? false) {
      // ignore: avoid_print
      print(
          'notification action tapped with input: ${notificationResponse.input}');
    }
  }

  int receivedNotifyId = 0;

  init() async {
    developer.log("inside init: ${DateTime.now()}");
    // needed if you intend to initialize in the `main` function
    WidgetsFlutterBinding.ensureInitialized();

    await _configureLocalTimeZone();
    developer.log("after _configureLocalTimeZone: ${DateTime.now()}");

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      selectedNotificationPayload =
          notificationAppLaunchDetails!.notificationResponse?.payload;
    }
    developer.log("after NotificationAppLaunchDetails: ${DateTime.now()}");

    // initialise the plugin class with the settings to use for each platform
    //---------------initialize Android Settings ---------------------
    //TODO -  app_icon needs to be a added as a drawable resource to the Android head project
    // StalkOverflow - Add your icon to
    // [projectFolder]/android/app/src/main/res/drawable (for example app_icon.png)
    // and use that name here:
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    developer.log("after initializationSettingsAndroid: ${DateTime.now()}");

    // ---------------------------------------------------------------
    // ---- configuration of ios notification categories & actions ---
    // TODO narrow the list to things I actually need
    final List<DarwinNotificationCategory> darwinNotificationCategories =
        <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        _darwinNotificationCategoryText,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.text(
            // TODO - notification_action_text, action_text
            'text_1',
            'Action 1',
            buttonTitle: 'Send',
            placeholder: 'Placeholder',
          ),
        ],
      ),
      DarwinNotificationCategory(
        _darwinNotificationCategoryPlain,
        actions: <DarwinNotificationAction>[
          //urlLaunchActionId = 'id_1'
          DarwinNotificationAction.plain(_urlLaunchActionId, 'Action 1'),
          DarwinNotificationAction.plain(
            'id_2',
            'Action 2 (destructive)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
          DarwinNotificationAction.plain(
            _navigationActionId,
            'Action 3 (foreground)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            },
          ),
          DarwinNotificationAction.plain(
            'id_4',
            'Action 4 (auth required)',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.authenticationRequired,
            },
          ),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      )
    ];

    /// Note: permissions aren't requested here just to demonstrate that can be
    /// done later
    // ------------------Initialize IOS Settings ---------------------
    // The constructor for the DarwinInitializationSettings class has three named
    // parameters (requestSoundPermission, requestBadgePermission and
    // requestAlertPermission) that controls which permissions are being requested.
    // If you want to request permissions at a later point in your application on
    // iOS, set all of the above to false when initialising the plugin.
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
            didReceiveLocalNotificationStream.add(
          ReceivedNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
          ),
        );
      },
      notificationCategories: darwinNotificationCategories,
    );

    // Sum the settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    developer.log("InitializationSettings", time: DateTime.now());

    // Initialize Plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      //Note that this callback is only intended to work when the app is running.
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        switch (notificationResponse.notificationResponseType) {
          case NotificationResponseType.selectedNotification:
            selectNotificationStream.add(notificationResponse.payload);
            break;
          case NotificationResponseType.selectedNotificationAction:
            if (notificationResponse.actionId == _navigationActionId) {
              selectNotificationStream.add(notificationResponse.payload);
            }
            break;
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    developer.log("flutterLocalNotificationsPlugin.initialize. the End of init: ${DateTime.now()}");
  }


  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  void initState() {
    developer.log("inside initState: ${DateTime.now()}");
    _isAndroidPermissionGranted();
    _requestPermissions();
  }

  Future<void> showNotification() async {
    debugPrint("suppose to show notify 2");
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        receivedNotifyId++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      // TODO how to put it right
      // setState(() {
      notificationsEnabled = granted;
      // });
    }
  }

// call the requestPermissions method with desired permissions at the appropriate
// point in your application
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestPermission();
      // setState(() {
      notificationsEnabled = granted ?? false;
      // });
    }
  }

  void printLog() {
    debugPrint("widget is working");
  }
}

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
Future<void> main() async {
  NotificationManager nM = NotificationManager();
  await nM.init();
  developer.log("after init: ${DateTime.now()}");
  //TODO understand 'then'
  initSettings().then((_) {
    runApp(MyApp(notifyManager: nM));
  });
}

// TODO - to get details & information if i need
// late final NotificationAppLaunchDetails? notificationAppLaunchDetails;
//
// bool get didNotificationLaunchApp =>
//     notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;

class PaddedElevatedButton extends StatelessWidget {
  const PaddedElevatedButton({
    required this.buttonText,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      );
}

// ----------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.notifyManager});

  final NotificationManager? notifyManager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Guardian',
      home: HomePage(notifyManager: notifyManager,),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title = 'שלום', this.notifyManager});

  final String title;
  final NotificationManager? notifyManager;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //------------------- help ----------------------
  @override
  void initState() {
    developer.log("initState");
    developer.log(widget.title);
    widget.notifyManager?.printLog();
    super.initState();
    // TODO understand better '?' and null values
    widget.notifyManager?.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
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
            PaddedElevatedButton(
              buttonText: 'Show plain notification with payload',
              onPressed: () async {
                await widget.notifyManager?.showNotification();
                debugPrint("suppose to show notify 1");
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> initSettings() async {
  await Settings.init(cacheProvider: SharePreferenceCache());
}

//---------------------------- Settings ----------------------------
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
                leading: const Icon(Icons.adb),
                settingKey: 'key-is-developer',
                title: 'Developer Mode',
                onChange: (value) {
                  debugPrint('key-is-developer: $value');
                },
              ),
              SwitchSettingsTile(
                leading: const Icon(Icons.usb),
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
