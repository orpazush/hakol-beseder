// Copyright 2022 Elichay &  Orpaz Mizrachi & Revital Ben-Shmuel.
// All rights reserved.

import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

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
import 'package:flutter_sms/flutter_sms.dart';

class Scheduler {
  /// The name associated with the UI isolate's [SendPort].
  static const String isolateName = 'background';

  // /// A port used to communicate from a background isolate to the UI isolate.
  static final ReceivePort receivePort = ReceivePort();

  static int countSnooze = 0;
  static bool isGotResponse = false;

  static init() async {
    // only if it's on main
    WidgetsFlutterBinding.ensureInitialized();
    // Register the UI isolate's SendPort to allow for communication from the
    // background isolate.
    IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      isolateName,
    );

    await AndroidAlarmManager.initialize();
  }

  static emergencyCall(Function callback) {

  }

  static snooze(Function callback) {
    developer.log("snooze: ${DateTime.now()}");
    if (!isGotResponse) {
      countSnooze++;
      if (countSnooze > 5)
        {
          return;
        }
      // TODO - change id
      AndroidAlarmManager.oneShot(
          Duration(seconds: 5),
          2,
          callback,
          allowWhileIdle: true,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true
      );
    }
  }

  static regularCheck(Function callback) {
    developer.log('set regular check: ${DateTime.now()}');
    AndroidAlarmManager.oneShotAt(
        DateTime.now().add(Duration(
            seconds: Settings.getValue('interval', 5))),
        1,
        callback,
        allowWhileIdle: true,
        exact: true,
      wakeup: true,
      rescheduleOnReboot: true
    );
  }
}

class NotificationManager {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Streams are created so that app can respond to notification-related events
  /// since the plugin is initialised in the `main` function
  final StreamController<ReceivedNotification>
  didReceiveLocalNotificationStream =
  StreamController<ReceivedNotification>.broadcast();

  final StreamController<String?> selectNotificationStream =
  StreamController<String?>.broadcast();

//TODO - understand
  static const MethodChannel platform = MethodChannel('hakol_beseder_channel');

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
          'text_id_2',
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

  // TODO - to understand this need & configure a top level or static method which
  // will handle the action:
  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    // ignore: avoid_print
    print('notification(${notificationResponse.id}) action tapped: '
        '${notificationResponse.actionId} with'
        ' payload: ${notificationResponse.payload}');
    if (notificationResponse.input?.isNotEmpty ?? false) {
      // ignore: avoid_print
      print(
          'notification action tapped with input: ${notificationResponse
              .input}');
    }
  }

  //TODO probably delete it
  static int receivedNotifyId = 0;

  init() async {
    developer.log("init the notification manager: ${DateTime.now()}");
    // needed only if it comes before runApp
    WidgetsFlutterBinding.ensureInitialized();

    await _configureLocalTimeZone();

    // TODO maybe only for tests and can be delete
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
    await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      selectedNotificationPayload =
          notificationAppLaunchDetails!.notificationResponse?.payload;
    }

    // initialise the plugin class with the settings to use for each platform
    //---------------initialize Android Settings ---------------------
    //TODO -  app_icon needs to be a added as a drawable resource to the Android head project
    // StalkOverflow - Add your icon to
    // [projectFolder]/android/app/src/main/res/drawable (for example app_icon.png)
    // and use that name here:
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

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
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  void initState() {
    _isAndroidPermissionGranted();
    _requestPermissions();
  }

  static Future<void> showNotification(data) async {
    developer.log("showNotification: ${DateTime.now()}, send: $data");
    Scheduler.snooze(_HomePageState.onSnooze);
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails('your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        color: Colors.amber);
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        receivedNotifyId++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _zonedScheduleNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'scheduled title',
        'scheduled body',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'your channel id', 'your channel name',
                channelDescription: 'your channel description')),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> _scheduleNotificationEveryMin() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'daily scheduled notification title',
        'daily scheduled notification body',
        _nextInstanceOfTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('daily notification channel id',
              'daily notification channel name',
              channelDescription: 'daily notification description'),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> _repeatNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
        'repeating channel id', 'repeating channel name',
        channelDescription: 'repeating description');
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShow(
        receivedNotifyId++,
        'repeating title',
        'repeating body',
        RepeatInterval.everyMinute,
        notificationDetails,
        androidAllowWhileIdle: true);
  }

  tz.TZDateTime _nextInstanceOfTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        30);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(minutes: 1));
    }
    return scheduledDate;
  }

  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(--receivedNotifyId);
  }

  Future<void> _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _showFullScreenNotification(
      {required BuildContext context}) async {
    await showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text('Turn off your screen'),
            content: const Text(
                'to see the full-screen intent in 5 seconds, press OK and TURN '
                    'OFF your screen'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await flutterLocalNotificationsPlugin.zonedSchedule(
                      0,
                      'fullscreen title',
                      'fullscreen body',
                      tz.TZDateTime.now(tz.local).add(
                          const Duration(seconds: 5)),
                      const NotificationDetails(
                          //TODO - lots of options but only for android!!
                          android: AndroidNotificationDetails(
                              'full screen channel id',
                              'full screen channel name',
                              channelDescription: 'full screen channel description',
                              priority: Priority.high,
                              importance: Importance.high,
                              fullScreenIntent: true,
                          timeoutAfter: 3,
                          ongoing: false,
                          onlyAlertOnce: false)),
                      androidAllowWhileIdle: true,
                      uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime);
                  Navigator.pop(context);
                },
                child: const Icon(Icons.cabin),
              )
            ],
          ),
    );
  }

  Future<void> _showNotificationWithAudioAttributeAlarm() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your alarm channel id',
      'your alarm channel name',
      channelDescription: 'your alarm channel description',
      importance: Importance.max,
      priority: Priority.high,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'notification sound controlled by alarm volume',
      'alarm notification sound body',
      platformChannelSpecifics,
    );
  }

  static Future<void> _showNotificationWithTextChoice() async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_2',
          'Action 2',
          // icon: DrawableResourceAndroidBitmap('food'),
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              choices: <String>['ABC', 'DEF'],
              allowFreeFormInput: false,
            ),
          ],
          contextual: true,
        ),
      ],
    );

    const DarwinNotificationDetails darwinNotificationDetails =
    DarwinNotificationDetails(
      categoryIdentifier: _darwinNotificationCategoryText,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        receivedNotifyId++, 'text title', 'text body', notificationDetails,
        payload: 'item x');

    Scheduler.snooze(_HomePageState.onSnooze);
  }

  Future<void> _showNotificationWithTextAction() async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_1',
          'Enter Text',
          // icon: DrawableResourceAndroidBitmap('food'),
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: 'Enter a message',
            ),
          ],
        ),
      ],
    );

    const DarwinNotificationDetails darwinNotificationDetails =
    DarwinNotificationDetails(
      categoryIdentifier: _darwinNotificationCategoryText,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
        receivedNotifyId++,
        'Text Input Notification',
        'Expand to see input action',
        notificationDetails,
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
  Scheduler s = Scheduler();
  await nM.init();
  await Scheduler.init();
  await initSettings();
  runApp(MyApp(notifyManager: nM, scheduler: s,));
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
  Widget build(BuildContext context) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      );
}

// ----------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.notifyManager, this.scheduler});

  final NotificationManager? notifyManager;
  final Scheduler? scheduler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Guardian',
      home: HomePage(
        notifyManager: notifyManager,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title = 'שלום', this.notifyManager, this.scheduler});

  final String title;
  final NotificationManager? notifyManager;
  final Scheduler? scheduler;


  @override
  State<HomePage> createState() => _HomePageState();
}

//---------------------------- Settings ----------------------------

Future<void> initSettings() async {
  await Settings.init(cacheProvider: SharePreferenceCache());
  Settings.setValue('interval', 13);
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

class _HomePageState extends State<HomePage> {
  //------------------- help ----------------------
  static SendPort? uiSendPort;

  @override
  void initState() {
    developer.log("initState");
    super.initState();
    // TODO understand better '?' and null values
    widget.notifyManager?.initState();
    Scheduler.receivePort.listen((id) async => await onGetAlarm(id));

    Scheduler.regularCheck(callback);
  }

  static onGetAlarm(int id) {
    switch (id) {
      case 1: {
    NotificationManager.showNotification(id);
    }
    break;
      case 2: {
        NotificationManager._showNotificationWithTextChoice();

      }
    }
  }

  static Future<void> onSnooze(int id) async {
    developer.log('snoozeCallback: ${DateTime.now()}');
    // // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(Scheduler.isolateName);
    uiSendPort?.send(id);
  }

  static Future<void> callback(int id) async {
    developer.log('regularCheck callback: ${DateTime.now()}');
    // // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(Scheduler.isolateName);
    developer.log('Alarm fired: ${DateTime.now()}, $uiSendPort');
    uiSendPort?.send(id);
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
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                })
          ],
        ),
        body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(8),
    child: Center(
    child: Column(
    children: <Widget>[
    Text(
    'שלום '
    // '${Settings.getValue('key-user-title', '3')} '
    '${Settings.getValue('key-user-name', 'default')}',
    ),
    PaddedElevatedButton(
    buttonText: 'Show plain notification with payload',
    onPressed: () async {
    await NotificationManager.showNotification('PaddedElevatedButton');
    },
    ),
    PaddedElevatedButton(
    buttonText: 'Schedule notification to appear in 5 seconds '
    'based on local time zone',
    onPressed: () async {
    await widget.notifyManager?._zonedScheduleNotification();
    },
    ),
    // PaddedElevatedButton(
    // buttonText: 'regular check',
    // onPressed: () async {
    // await Scheduler?.regularCheck();
    // },
    // ),
    PaddedElevatedButton(
    buttonText: 'Schedule notification to appear in every minute',
    onPressed: () async {
    await widget.notifyManager?._repeatNotification();
    },
    ),
    PaddedElevatedButton(
    buttonText: 'cancel the last notify',
    onPressed: () async {
    await widget.notifyManager?._cancelNotification();
    },
    ),
    PaddedElevatedButton(
    buttonText: '_showFullScreenNotification',
    onPressed: () async {
    await widget.notifyManager
        ?._showFullScreenNotification(context: context);
    },
    ),
    PaddedElevatedButton(
    buttonText: 'Show notification with sound controlled by '
    'alarm volume',
    onPressed: () async {
    await widget.notifyManager
        ?._showNotificationWithAudioAttributeAlarm();
    },
    ),
    const Divider(),
    const Text(
    'Notifications with actions',
    style: TextStyle(fontWeight: FontWeight.bold),
    ),
    PaddedElevatedButton(
    buttonText: 'Show notification with text choice',
    onPressed: () async {
    await NotificationManager._showNotificationWithTextChoice();
    },
    ),
    PaddedElevatedButton(
    buttonText: 'Show notification with text action',
    onPressed: () async {
    await widget.notifyManager?._showNotificationWithTextAction();
    },
    ),
    ],
    ),
    ),
    ),
    ),
    );
  }
}
