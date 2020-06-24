import 'dart:async';
import 'dart:typed_data';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:torn_pda/models/own_profile_model.dart';
import 'package:torn_pda/providers/user_details_provider.dart';
import 'package:torn_pda/utils/api_caller.dart';
import 'package:torn_pda/utils/html_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:torn_pda/providers/settings_provider.dart';
import 'package:torn_pda/providers/theme_provider.dart';
import 'package:torn_pda/widgets/webview_generic.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

enum ProfileNotification {
  energy,
  nerve,
  life,
  drugs,
  medical,
  booster,
}

extension ProfileNotificationExtension on ProfileNotification {
  String get string {
    switch (this) {
      case ProfileNotification.energy:
        return 'energy';
        break;
      case ProfileNotification.nerve:
        return 'nerve';
        break;
      case ProfileNotification.life:
        return 'life';
        break;
      case ProfileNotification.drugs:
        return 'drugs';
        break;
      case ProfileNotification.medical:
        return 'medical';
        break;
      case ProfileNotification.booster:
        return 'booster';
        break;
      default:
        return null;
    }
  }
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  Future _apiFetched;
  bool _apiGoodData;

  OwnProfileModel _user;

  DateTime _serverTime;

  Timer _tickerCallChainApi;

  SettingsProvider _settingsProvider;
  ThemeProvider _themeProvider;

  // For dial FAB
  ScrollController scrollController;
  bool dialVisible = true;

  bool _energyNotificationsPending = false;
  bool _nerveNotificationsPending = false;
  bool _lifeNotificationsPending = false;
  bool _drugsNotificationsPending = false;
  bool _medicalNotificationsPending = false;
  bool _boosterNotificationsPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _requestIOSPermissions();
    _retrievePendingNotifications();

    scrollController = ScrollController()
      ..addListener(() {
        setDialVisible(scrollController.position.userScrollDirection ==
            ScrollDirection.forward);
      });

    _apiFetched = _fetchApi();

    _tickerCallChainApi =
        new Timer.periodic(Duration(seconds: 30), (Timer t) => _fetchApi());
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  @override
  void dispose() {
    _tickerCallChainApi.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    return Scaffold(
      drawer: new Drawer(),
      appBar: AppBar(
        title: Text('Profile'),
        leading: new IconButton(
          icon: new Icon(Icons.menu),
          onPressed: () {
            final ScaffoldState scaffoldState =
                context.findRootAncestorStateOfType();
            scaffoldState.openDrawer();
          },
        ),
      ),
      floatingActionButton: buildSpeedDial(),
      body: Container(
        child: FutureBuilder(
          future: _apiFetched,
          builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (_apiGoodData) {
                return SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                        child: Column(
                          children: <Widget>[
                            Text(
                              '${_user.name} [${_user.playerId}]',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Level ${_user.level}',
                            ),
                            Text(
                              _user.lastAction.relative[0] == '0'
                                  ? 'Online now'
                                  : 'Online ${_user.lastAction.relative}',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
                        child: _playerStatus(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                        child: _basicBars(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                        child: _coolDowns(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                        child: _eventsTimeline(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
                        child: _netWorth(),
                      ),
                      SizedBox(height: 50),
                    ],
                  ),
                );
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'OPS!',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 20),
                        child: Text(
                          'There was an error getting the information, please '
                          'try again later!',
                        ),
                      ),
                    ],
                  ),
                );
              }
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('Fetching data...'),
                    SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Card _playerStatus() {
    Widget descriptionWidget() {
      if (_user.status.state == 'Okay') {
        return SizedBox.shrink();
      } else {
        String descriptionText = _user.status.description;

        // Is there a detailed description? Add it.
        if (_user.status.details != '') {
          descriptionText += '- ${_user.status.details}';
        }

        // Causing player ID (jailed of hospitalised the user)
        RegExp expHtml = RegExp(r"<[^>]*>");
        var matches = expHtml.allMatches(descriptionText).map((m) => m[0]);
        String causingId = '';
        if (matches.length > 0) {
          RegExp expId = RegExp(r"(?!XID=)([0-9])+");
          var id = expId.allMatches(_user.status.details).map((m) => m[0]);
          causingId = id.first;
        }

        // If there is a player causing it, add a span to click and go to the
        // profile, otherwise return just the description text
        Widget detailsWidget;
        if (_user.status.details != '') {
          if (causingId != '') {
            detailsWidget = RichText(
              text: new TextSpan(
                children: [
                  new TextSpan(
                    text: HtmlParser.fix(descriptionText),
                    style: new TextStyle(color: _themeProvider.mainText),
                  ),
                  new TextSpan(
                    text: ' (',
                    style: new TextStyle(color: _themeProvider.mainText),
                  ),
                  new TextSpan(
                    text: 'profile',
                    style: new TextStyle(color: Colors.blue),
                    recognizer: new TapGestureRecognizer()
                      ..onTap = () async {
                        var browserType = _settingsProvider.currentBrowser;
                        switch (browserType) {
                          case BrowserSetting.app:
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (BuildContext context) =>
                                    TornWebViewGeneric(
                                  profileId: causingId,
                                  //profileName: causingId,
                                  genericTitle: 'Event Profile',
                                  webViewType: WebViewType.profile,
                                  genericCallBack: _updateCallback,
                                ),
                              ),
                            );
                            break;
                          case BrowserSetting.external:
                            var url = 'https://www.torn.com/profiles.php?'
                                'XID=$causingId';
                            if (await canLaunch(url)) {
                              await launch(url, forceSafariVC: false);
                            }
                            break;
                        }
                      },
                  ),
                  new TextSpan(
                    text: ')',
                    style: new TextStyle(color: _themeProvider.mainText),
                  ),
                ],
              ),
            );
          } else {
            detailsWidget = Text(descriptionText);
          }

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 60,
                  child: Text('Details: '),
                ),
                Flexible(
                  child: detailsWidget,
                ),
              ],
            ),
          );
        } else {
          return SizedBox.shrink();
        }
      }
    }

    Color stateColor;
    if (_user.status.color == 'red') {
      stateColor = Colors.red;
    } else if (_user.status.color == 'green') {
      stateColor = Colors.green;
    } else if (_user.status.color == 'blue') {
      stateColor = Colors.blue;
    }

    Widget stateBall() {
      return Padding(
        padding: EdgeInsets.only(left: 8),
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
              color: stateColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black)),
        ),
      );
    }

    Widget traveling() {
      if (_user.status.state == 'Traveling') {
        var startTime = _user.travel.departed;
        var endTime = _user.travel.timestamp;
        var totalSeconds = endTime - startTime;

        var dateTimeArrival =
            DateTime.fromMillisecondsSinceEpoch(_user.travel.timestamp * 1000);
        var timeDifference = dateTimeArrival.difference(DateTime.now());
        String twoDigits(int n) => n.toString().padLeft(2, "0");
        String twoDigitMinutes =
            twoDigits(timeDifference.inMinutes.remainder(60));
        String diff =
            '${twoDigits(timeDifference.inHours)}h ${twoDigitMinutes}m';

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: <Widget>[
              Text('Arriving in '),
              LinearPercentIndicator(
                center: Text(
                  diff,
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
                width: 150,
                lineHeight: 18,
                progressColor: Colors.blue[200],
                backgroundColor: Colors.grey,
                percent: 1 - (_user.travel.timeLeft / totalSeconds),
              ),
            ],
          ),
        );
      } else {
        return SizedBox.shrink();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 60,
                        child: Text('Status: '),
                      ),
                      Text(_user.status.state),
                      stateBall(),
                    ],
                  ),
                  traveling(),
                  descriptionWidget(),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Card _basicBars() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                'BARS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 50,
                            child: Text('Energy'),
                          ),
                          SizedBox(width: 10),
                          LinearPercentIndicator(
                            width: 150,
                            lineHeight: 20,
                            progressColor: Colors.green,
                            backgroundColor: Colors.grey,
                            center: Text(
                              '${_user.energy.current}',
                              style: TextStyle(color: Colors.black),
                            ),
                            percent: _user.energy.current /
                                        _user.energy.maximum >
                                    1.0
                                ? 1.0
                                : _user.energy.current / _user.energy.maximum,
                          ),
                        ],
                      ),
                      _notificationIcon(ProfileNotification.energy),
                    ],
                  ),
                  _barTime('energy'),
                ],
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 50,
                            child: Text('Nerve'),
                          ),
                          SizedBox(width: 10),
                          LinearPercentIndicator(
                            width: 150,
                            lineHeight: 20,
                            progressColor: Colors.redAccent,
                            backgroundColor: Colors.grey,
                            center: Text(
                              '${_user.nerve.current}',
                              style: TextStyle(color: Colors.black),
                            ),
                            percent:
                                _user.nerve.current / _user.nerve.maximum > 1.0
                                    ? 1.0
                                    : _user.nerve.current / _user.nerve.maximum,
                          ),
                        ],
                      ),
                      _notificationIcon(ProfileNotification.nerve),
                    ],
                  ),
                  _barTime('nerve'),
                ],
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 50,
                        child: Text('Happy'),
                      ),
                      SizedBox(width: 10),
                      LinearPercentIndicator(
                        width: 150,
                        lineHeight: 20,
                        progressColor: Colors.amber,
                        backgroundColor: Colors.grey,
                        center: Text(
                          '${_user.happy.current}',
                          style: TextStyle(color: Colors.black),
                        ),
                        percent: _user.happy.current / _user.happy.maximum > 1.0
                            ? 1.0
                            : _user.happy.current / _user.happy.maximum,
                      ),
                    ],
                  ),
                  _barTime('happy'),
                ],
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          SizedBox(
                            width: 50,
                            child: Text('Life'),
                          ),
                          SizedBox(width: 10),
                          LinearPercentIndicator(
                            width: 150,
                            lineHeight: 20,
                            progressColor: Colors.blue,
                            backgroundColor: Colors.grey,
                            center: Text(
                              '${_user.life.current}',
                              style: TextStyle(color: Colors.black),
                            ),
                            percent:
                                _user.life.current / _user.life.maximum > 1.0
                                    ? 1.0
                                    : _user.life.current / _user.life.maximum,
                          ),
                          _user.status.state == "Hospital"
                              ? Icon(
                                  Icons.local_hospital,
                                  size: 20,
                                  color: Colors.red,
                                )
                              : SizedBox.shrink(),
                        ],
                      ),
                      _notificationIcon(ProfileNotification.life),
                    ],
                  ),
                  _barTime('life'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barTime(String type) {
    switch (type) {
      case "energy":
        if (_user.energy.fulltime == 0 ||
            _user.energy.current > _user.energy.maximum) {
          return SizedBox.shrink();
        } else {
          var time;
          time = _serverTime.add(Duration(seconds: _user.energy.fulltime));
          var formatter = new DateFormat('HH:mm');
          String timeFormatted = formatter.format(time);
          return Row(
            children: <Widget>[
              SizedBox(width: 65),
              Text('Full at $timeFormatted LT'),
            ],
          );
        }
        break;
      case "nerve":
        if (_user.nerve.fulltime == 0 ||
            _user.nerve.current > _user.nerve.maximum) {
          return SizedBox.shrink();
        } else {
          var time;
          time = _serverTime.add(Duration(seconds: _user.nerve.fulltime));
          var formatter = new DateFormat('HH:mm');
          String timeFormatted = formatter.format(time);
          return Row(
            children: <Widget>[
              SizedBox(width: 65),
              Text('Full at $timeFormatted LT'),
            ],
          );
        }
        break;
      case "happy":
        if (_user.happy.fulltime == 0 ||
            _user.happy.current > _user.happy.maximum) {
          return SizedBox.shrink();
        } else {
          var time;
          time = _serverTime.add(Duration(seconds: _user.happy.fulltime));
          var formatter = new DateFormat('HH:mm');
          String timeFormatted = formatter.format(time);
          return Row(
            children: <Widget>[
              SizedBox(width: 65),
              Text('Full at $timeFormatted LT'),
            ],
          );
        }
        break;
      case "life":
        if (_user.life.fulltime == 0 ||
            _user.life.current > _user.life.maximum) {
          return SizedBox.shrink();
        } else {
          var time;
          time = _serverTime.add(Duration(seconds: _user.life.fulltime));
          var formatter = new DateFormat('HH:mm');
          String timeFormatted = formatter.format(time);
          return Row(
            children: <Widget>[
              SizedBox(width: 65),
              Text('Full at $timeFormatted LT'),
            ],
          );
        }
        break;
      default:
        return SizedBox.shrink();
    }
  }

  Widget _notificationIcon(ProfileNotification notificationType) {
    int fullTime;
    bool notificationsPending;
    String setString;
    String cancelString;
    var formatter = new DateFormat('HH:mm');

    switch (notificationType) {
      case ProfileNotification.energy:
        fullTime = _user.energy.fulltime;
        notificationsPending = _energyNotificationsPending;
        var energyCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.energy.fulltime));
        String formattedTime = formatter.format(energyCurrentSchedule);
        setString = 'Energy notification set for $formattedTime local time';
        cancelString = 'Energy notification cancelled!';
        break;
      case ProfileNotification.nerve:
        fullTime = _user.nerve.fulltime;
        notificationsPending = _nerveNotificationsPending;
        var nerveCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.nerve.fulltime));
        String formattedTime = formatter.format(nerveCurrentSchedule);
        setString = 'Nerve notification set for $formattedTime local time';
        cancelString = 'Nerve notification cancelled!';
        break;
      case ProfileNotification.life:
        fullTime = _user.life.fulltime;
        notificationsPending = _lifeNotificationsPending;
        var lifeCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.life.fulltime));
        String formattedTime = formatter.format(lifeCurrentSchedule);
        setString = 'Life notification set for $formattedTime local time';
        cancelString = 'Life notification cancelled!';
        break;
      case ProfileNotification.drugs:
        fullTime = _user.cooldowns.drug;
        notificationsPending = _drugsNotificationsPending;
        var drugsCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.cooldowns.drug));
        String formattedTime = formatter.format(drugsCurrentSchedule);
        setString =
            'Drugs cooldown notification set for $formattedTime local time';
        cancelString = 'Drugs cooldown notification cancelled!';
        break;
      case ProfileNotification.medical:
        fullTime = _user.cooldowns.medical;
        notificationsPending = _medicalNotificationsPending;
        var medicalCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.cooldowns.medical));
        String formattedTime = formatter.format(medicalCurrentSchedule);
        setString =
            'Medical cooldown notification set for $formattedTime local time';
        cancelString = 'Medical cooldown notification cancelled!';
        break;
      case ProfileNotification.booster:
        fullTime = _user.cooldowns.booster;
        notificationsPending = _boosterNotificationsPending;
        var boosterCurrentSchedule =
            DateTime.now().add(Duration(seconds: _user.cooldowns.booster));
        String formattedTime = formatter.format(boosterCurrentSchedule);
        setString =
            'Booster cooldown notification set for $formattedTime local time';
        cancelString = 'Booster cooldown notification cancelled!';
        break;
    }

    if (fullTime == 0) {
      return SizedBox.shrink();
    } else {
      Color thisColor;
      if (notificationsPending) {
        thisColor = Colors.green;
      } else {
        thisColor = _themeProvider.mainText;
      }

      return InkWell(
        child: Icon(
          Icons.alarm,
          size: 22,
          color: thisColor,
        ),
        onTap: () {
          if (!notificationsPending) {
            _scheduleNotification(notificationType);
            BotToast.showText(
              text: setString,
              textStyle: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              contentColor: Colors.green,
              duration: Duration(seconds: 5),
              contentPadding: EdgeInsets.all(10),
            );
          } else {
            _cancelNotifications(notificationType);
            BotToast.showText(
              text: cancelString,
              textStyle: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              contentColor: Colors.orange[800],
              duration: Duration(seconds: 5),
              contentPadding: EdgeInsets.all(10),
            );
          }
        },
      );
    }
  }

  Card _coolDowns() {
    Widget cooldownItems;
    if (_user.cooldowns.drug > 0 ||
        _user.cooldowns.booster > 0 ||
        _user.cooldowns.medical > 0) {
      cooldownItems = Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          children: <Widget>[
            _user.cooldowns.drug > 0
                ? Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: [
                                _drugIcon(),
                                SizedBox(width: 10),
                                _drugCounter(),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _notificationIcon(ProfileNotification.drugs),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  )
                : SizedBox.shrink(),
            _user.cooldowns.medical > 0
                ? Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: [
                                _medicalIcon(),
                                SizedBox(width: 10),
                                _medicalCounter(),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _notificationIcon(ProfileNotification.medical),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  )
                : SizedBox.shrink(),
            _user.cooldowns.booster > 0
                ? Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: [
                                _boosterIcon(),
                                SizedBox(width: 10),
                                _boosterCounter(),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _notificationIcon(ProfileNotification.booster),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  )
                : SizedBox.shrink(),
          ],
        ),
      );
    } else {
      cooldownItems = Row(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text("Nothing to report, well done!"),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                'COOLDOWNS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            cooldownItems,
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Image _drugIcon() {
    // 0-10 minutes
    if (_user.cooldowns.drug > 0 && _user.cooldowns.drug < 600) {
      return Image.asset('images/icons/cooldowns/drug1.png', width: 20);
    } // 10-60 minutes
    else if (_user.cooldowns.drug >= 600 && _user.cooldowns.drug < 3600) {
      return Image.asset('images/icons/cooldowns/drug2.png', width: 20);
    } // 1-2 hours
    else if (_user.cooldowns.drug >= 3600 && _user.cooldowns.drug < 7200) {
      return Image.asset('images/icons/cooldowns/drug3.png', width: 20);
    } // 2-5 hours
    else if (_user.cooldowns.drug >= 7200 && _user.cooldowns.drug < 18000) {
      return Image.asset('images/icons/cooldowns/drug4.png', width: 20);
    } // 5+ hours
    else {
      return Image.asset('images/icons/cooldowns/drug5.png', width: 20);
    }
  }

  Image _medicalIcon() {
    // 0-6 hours
    if (_user.cooldowns.medical > 0 && _user.cooldowns.medical < 21600) {
      return Image.asset('images/icons/cooldowns/medical1.png', width: 20);
    } // 6-12 hours
    else if (_user.cooldowns.medical >= 21600 &&
        _user.cooldowns.medical < 43200) {
      return Image.asset('images/icons/cooldowns/medical2.png', width: 20);
    } // 12-18 hours
    else if (_user.cooldowns.medical >= 43200 &&
        _user.cooldowns.medical < 64800) {
      return Image.asset('images/icons/cooldowns/medical3.png', width: 20);
    } // 18-24 hours
    else if (_user.cooldowns.medical >= 64800 &&
        _user.cooldowns.medical < 86400) {
      return Image.asset('images/icons/cooldowns/medical4.png', width: 20);
    } // 24+ hours
    else {
      return Image.asset('images/icons/cooldowns/medical5.png', width: 20);
    }
  }

  Image _boosterIcon() {
    // 0-6 hours
    if (_user.cooldowns.booster > 0 && _user.cooldowns.booster < 21600) {
      return Image.asset('images/icons/cooldowns/booster1.png', width: 20);
    } // 6-12 hours
    else if (_user.cooldowns.booster >= 21600 &&
        _user.cooldowns.booster < 43200) {
      return Image.asset('images/icons/cooldowns/booster2.png', width: 20);
    } // 12-18 hours
    else if (_user.cooldowns.booster >= 43200 &&
        _user.cooldowns.booster < 64800) {
      return Image.asset('images/icons/cooldowns/booster3.png', width: 20);
    } // 18-24 hours
    else if (_user.cooldowns.booster >= 64800 &&
        _user.cooldowns.booster < 86400) {
      return Image.asset('images/icons/cooldowns/booster4.png', width: 20);
    } // 24+ hours
    else {
      return Image.asset('images/icons/cooldowns/booster5.png', width: 20);
    }
  }

  Widget _drugCounter() {
    var timeEnd = _serverTime.add(Duration(seconds: _user.cooldowns.drug));
    var formatter = new DateFormat('HH:mm');
    String timeFormatted = formatter.format(timeEnd);
    String diff = _cooldownTimeFormatted(timeEnd);
    return Flexible(child: Text('@ $timeFormatted $diff'));
  }

  Widget _medicalCounter() {
    var timeEnd = _serverTime.add(Duration(seconds: _user.cooldowns.medical));
    var formatter = new DateFormat('HH:mm');
    String timeFormatted = formatter.format(timeEnd);
    String diff = _cooldownTimeFormatted(timeEnd);
    return Flexible(child: Text('@ $timeFormatted $diff'));
  }

  Widget _boosterCounter() {
    var timeEnd = _serverTime.add(Duration(seconds: _user.cooldowns.booster));
    var formatter = new DateFormat('HH:mm');
    String timeFormatted = formatter.format(timeEnd);
    String diff = _cooldownTimeFormatted(timeEnd);
    return Flexible(child: Text('@ $timeFormatted $diff'));
  }

  String _cooldownTimeFormatted(DateTime timeEnd) {
    String diff;
    var timeDifference = timeEnd.difference(_serverTime);
    if (timeDifference.inMinutes < 1) {
      diff = 'LT , seconds away';
    } else if (timeDifference.inMinutes == 1 && timeDifference.inHours < 1) {
      diff = 'LT , in 1 minute';
    } else if (timeDifference.inMinutes > 1 && timeDifference.inHours < 1) {
      diff = 'LT , in ${timeDifference.inMinutes} minutes';
    } else if (timeDifference.inHours == 1 && timeDifference.inDays < 1) {
      diff = 'LT , in 1 hour';
    } else if (timeDifference.inHours > 1 && timeDifference.inDays < 1) {
      diff = 'LT , in ${timeDifference.inHours} hours';
    } else {
      diff = 'LT tomorrow, in ${timeDifference.inHours} hours';
    }
    return diff;
  }

  Card _eventsTimeline() {
    var timeline = List<Widget>();

    int unreadCount = 0;
    int loopCount = 1;
    int maxCount;

    if (_user.events.length > 20) {
      maxCount = 20;
    } else {
      maxCount = _user.events.length;
    }

    for (var e in _user.events.values) {
      if (e.seen == 0) {
        unreadCount++;
      }

      String message = HtmlParser.fix(e.event);
      message = message.replaceAll('View the details here!', '');
      message = message.replaceAll(' [view]', '.');

      Widget insideIcon = _eventsInsideIconCases(message);

      IndicatorStyle iconBubble;
      iconBubble = IndicatorStyle(
        width: 30,
        height: 30,
        drawGap: true,
        indicator: Container(
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(
                color: Colors.grey,
              ),
            ),
            shape: BoxShape.rectangle,
          ),
          child: insideIcon,
        ),
      );

      var eventTime = DateTime.fromMillisecondsSinceEpoch(e.timestamp * 1000);

      var event = TimelineTile(
        isFirst: loopCount == 1 ? true : false,
        isLast: loopCount == maxCount ? true : false,
        alignment: TimelineAlign.manual,
        indicatorStyle: iconBubble,
        lineX: 0.25,
        rightChild: Container(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: e.seen == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        leftChild: Container(
          child: Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Text(
              _eventsTimeFormatted(eventTime),
              style: TextStyle(
                fontSize: 11,
                fontWeight: e.seen == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

      timeline.add(event);

      if (loopCount == maxCount) {
        break;
      }
      loopCount++;
    }

    var unreadString = '';
    if (unreadCount == 0) {
      unreadString = 'No unread events';
    } else if (unreadCount == 1) {
      unreadString = "1 unread event";
    } else {
      unreadString = '$unreadCount unread events';
    }

    return Card(
      child: ExpandablePanel(
        header: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            'EVENTS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        collapsed: Padding(
          padding: const EdgeInsets.fromLTRB(30, 5, 20, 20),
          child: Text(
            unreadString,
            style: TextStyle(
              color: unreadCount == 0 ? Colors.green : Colors.red,
              fontWeight:
                  unreadCount == 0 ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        expanded: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: timeline,
          ),
        ),
      ),
    );
  }

  Widget _eventsInsideIconCases(String message) {
    Widget insideIcon;
    if (message.contains('revive')) {
      insideIcon = Icon(
        Icons.local_hospital,
        color: Colors.green,
        size: 20,
      );
    } else if (message.contains('the director of')) {
      insideIcon = Icon(
        Icons.work,
        color: Colors.brown[300],
        size: 20,
      );
    } else if (message.contains('jail')) {
      insideIcon = Center(
        child: Image.asset(
          'images/icons/jail.png',
          width: 20,
          height: 20,
        ),
      );
    } else if (message.contains('trade')) {
      insideIcon = Icon(
        Icons.switch_camera,
        color: Colors.purple,
        size: 20,
      );
    } else if (message.contains('has given you') ||
        message.contains('You were sent') ||
        message.contains('You have been credited with') ||
        message.contains('on your doorstep')) {
      insideIcon = Icon(
        Icons.card_giftcard,
        color: Colors.green,
        size: 20,
      );
    } else if (message.contains('Get out of my education') ||
        message.contains('You must have overdosed')) {
      insideIcon = Icon(
        Icons.warning,
        color: Colors.red,
        size: 20,
      );
    } else if (message.contains('purchased membership')) {
      insideIcon = Icon(
        Icons.fitness_center,
        color: Colors.black54,
        size: 20,
      );
    } else if (message.contains('You upgraded your level')) {
      insideIcon = Icon(
        Icons.file_upload,
        color: Colors.green,
        size: 20,
      );
    } else if (message.contains('won') ||
        message.contains('lottery') ||
        message.contains('check has been credited to your') ||
        message.contains('withdraw your check from the bank')) {
      insideIcon = Icon(
        Icons.monetization_on,
        color: Colors.green,
        size: 20,
      );
    } else if (message.contains('attacked you') ||
        message.contains('mugged you and stole') ||
        message.contains('attacked and hospitalized')) {
      insideIcon = Container(
        child: Center(
          child: Image.asset(
            'images/icons/ic_target_account_black_48dp.png',
            width: 20,
            height: 20,
            color: Colors.red,
          ),
        ),
      );
    } else if (message.contains('You and your team') ||
        message.contains('You have been selected') ||
        message.contains('canceled the')) {
      insideIcon = Container(
        child: Center(
          child: Image.asset(
            'images/icons/ic_pistol_black_48dp.png',
            width: 20,
            height: 20,
            color: Colors.blue,
          ),
        ),
      );
    } else if (message.contains('You left your faction') ||
        message.contains('Your application to') ||
        message.contains('canceled the')) {
      insideIcon = Container(
        child: Center(
          child: Image.asset(
            'images/icons/faction.png',
            width: 20,
            height: 20,
            color: Colors.black,
          ),
        ),
      );
    } else {
      insideIcon = Container(
        child: Center(
          child: Text(
            'T',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }
    return insideIcon;
  }

  String _eventsTimeFormatted(DateTime eventTime) {
    String diff;
    var timeDifference = _serverTime.difference(eventTime);
    if (timeDifference.inMinutes < 1) {
      diff = 'Seconds ago';
    } else if (timeDifference.inMinutes == 1 && timeDifference.inHours < 1) {
      diff = '1 min ago';
    } else if (timeDifference.inMinutes > 1 && timeDifference.inHours < 1) {
      diff = '${timeDifference.inMinutes} mins ago';
    } else if (timeDifference.inHours == 1 && timeDifference.inDays < 1) {
      diff = '1 hr ago';
    } else if (timeDifference.inHours > 1 && timeDifference.inDays < 1) {
      diff = '${timeDifference.inHours} hrs ago';
    } else {
      diff = '${timeDifference.inDays} days ago';
    }
    return diff;
  }

  Card _netWorth() {
    // Currency configuration
    final moneyFormat = new NumberFormat("#,##0", "en_US");

    // Total when folded
    int total;
    for (var v in _user.networth.entries) {
      if (v.key == 'total') {
        total = v.value.round();
      }
    }

    // List for all sources in column
    var moneySources = List<Widget>();

    // Total Expanded
    moneySources.add(
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 110,
              child: Text(
                'Total: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '\$${moneyFormat.format(total)}',
              style: TextStyle(
                color: total < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // Loop all other sources
    for (var v in _user.networth.entries) {
      String source;
      if (v.key == 'total' || v.key == 'parsetime') {
        continue;
      } else if (v.key == 'piggybank') {
        source = 'Piggy Bank';
      } else if (v.key == 'displaycase') {
        source = 'Display Case';
      } else if (v.key == 'stockmarket') {
        source = 'Stock Market';
      } else if (v.key == 'auctionhouse') {
        source = 'Auction House';
      } else if (v.key == 'unpaidfees') {
        source = 'Unpaid Fees';
      } else {
        source = "${v.key[0].toUpperCase()}${v.key.substring(1)}";
      }

      moneySources.add(
        Row(
          children: <Widget>[
            SizedBox(
              height: 20,
              width: 110,
              child: Text('$source: '),
            ),
            Text(
              '\$${moneyFormat.format(v.value.round())}',
              style: TextStyle(
                color: v.value < 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: ExpandablePanel(
        header: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            'NETWORTH',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        collapsed: Padding(
          padding: const EdgeInsets.fromLTRB(30, 5, 20, 20),
          child: Text(
            '\$${moneyFormat.format(total)}',
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: total <= 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        expanded: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: moneySources,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchApi() async {
    var userProvider = Provider.of<UserDetailsProvider>(context, listen: false);
    var apiResponse =
        await TornApiCaller.ownProfile(userProvider.myUser.userApiKey)
            .getOwnProfile;

    setState(() {
      if (apiResponse is OwnProfileModel) {
        _user = apiResponse;
        _serverTime =
            DateTime.fromMillisecondsSinceEpoch(_user.serverTime * 1000);
        _apiGoodData = true;
        _checkIfNotificationsAreCurrent();
      } else {
        _apiGoodData = false;
      }
    });

    _retrievePendingNotifications();
  }

  SpeedDial buildSpeedDial() {
    return SpeedDial(
      //animatedIcon: AnimatedIcons.menu_close,
      //animatedIconTheme: IconThemeData(size: 22.0),
      backgroundColor: Colors.transparent,
      overlayColor: Colors.transparent,
      child: Container(
        width: 58,
        height: 58,
        decoration: new BoxDecoration(
          border: Border.all(
            color: Colors.grey[800],
            width: 2,
          ),
          shape: BoxShape.circle,
          image: new DecorationImage(
            fit: BoxFit.fill,
            image: AssetImage("images/icons/torn_t_logo.png"),
          ),
        ),
      ),
      visible: dialVisible,
      curve: Curves.bounceIn,
      children: [
        SpeedDialChild(
          child: Icon(
            Icons.comment,
            color: Colors.black,
          ),
          backgroundColor: Colors.grey[400],
          onTap: () async {
            _openTornBrowser('events');
          },
          label: 'EVENTS',
          labelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.grey[400],
        ),
        SpeedDialChild(
          child: Icon(
            Icons.card_giftcard,
            color: Colors.black,
          ),
          backgroundColor: Colors.blue[400],
          onTap: () async {
            _openTornBrowser('items');
          },
          label: 'ITEMS',
          labelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.blue[400],
        ),
        SpeedDialChild(
          child: Center(
            child: Image.asset(
              'images/icons/ic_pistol_black_48dp.png',
              width: 25,
              height: 25,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.deepOrange[400],
          onTap: () async {
            _openTornBrowser('crimes');
          },
          label: 'CRIMES',
          labelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.deepOrange[400],
        ),
        SpeedDialChild(
          child: Icon(
            Icons.fitness_center,
            color: Colors.black,
          ),
          backgroundColor: Colors.green[400],
          onTap: () async {
            _openTornBrowser('gym');
          },
          label: 'GYM',
          labelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.green[400],
        ),
      ],
    );
  }

  Future _openTornBrowser(String page) async {
    var tornPage = '';
    switch (page) {
      case 'gym':
        tornPage = 'https://www.torn.com/gym.php';
        break;
      case 'crimes':
        tornPage = 'https://www.torn.com/crimes.php#/step=main';
        break;
      case 'items':
        tornPage = 'https://www.torn.com/item.php';
        break;
      case 'events':
        tornPage = 'https://www.torn.com/events.php#/step=all';
        break;
    }

    var browserType = _settingsProvider.currentBrowser;
    switch (browserType) {
      case BrowserSetting.app:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) => TornWebViewGeneric(
              webViewType: WebViewType.custom,
              customUrl: tornPage,
              genericTitle: 'Torn',
              genericCallBack: _updateCallback,
            ),
          ),
        );
        break;
      case BrowserSetting.external:
        var url = tornPage;
        if (await canLaunch(url)) {
          await launch(url, forceSafariVC: false);
        }
        break;
    }
  }

  void setDialVisible(bool value) {
    setState(() {
      dialVisible = value;
    });
  }

  Future _updateCallback() async {
    // Even if this implies colling the app twice, it enhances player
    // experience as the bars are updated quickly after a change
    // In turn, we only call the API every 30 seconds with the timer
    await Future.delayed(Duration(seconds: 10));
    _fetchApi();
    await Future.delayed(Duration(seconds: 10));
    _fetchApi();
  }

  void _scheduleNotification(ProfileNotification notificationType) async {
    int secondsToNotification;
    String channelTitle;
    String channelSubtitle;
    String channelDescription;
    String notificationTitle;
    String notificationSubtitle;
    int notificationId;

    // We will add the timestamp to the payload
    String notificationPayload = '';

    switch (notificationType) {
      case ProfileNotification.energy:
        notificationId = 101;
        secondsToNotification = _user.energy.fulltime;
        channelTitle = 'Energy';
        channelSubtitle = 'Energy Full';
        channelDescription = 'Urgent notifications about energy';
        notificationTitle = 'Energy Full';
        notificationSubtitle = 'Here is your energy reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.energy.fulltime;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
      case ProfileNotification.nerve:
        notificationId = 102;
        secondsToNotification = _user.nerve.fulltime;
        channelTitle = 'Nerve';
        channelSubtitle = 'Nerve Full';
        channelDescription = 'Urgent notifications about nerve';
        notificationTitle = 'Nerve Full';
        notificationSubtitle = 'Here is your nerve reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.nerve.fulltime;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
      case ProfileNotification.life:
        notificationId = 103;
        secondsToNotification = _user.life.fulltime;
        channelTitle = 'Life';
        channelSubtitle = 'Life Full';
        channelDescription = 'Urgent notifications about life';
        notificationTitle = 'Life Full';
        notificationSubtitle = 'Here is your life reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.life.fulltime;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
      case ProfileNotification.drugs:
        notificationId = 104;
        secondsToNotification = _user.cooldowns.drug;
        channelTitle = 'Drugs';
        channelSubtitle = 'Drugs Expired';
        channelDescription = 'Urgent notifications about drugs cooldown';
        notificationTitle = 'Drug Cooldown';
        notificationSubtitle = 'Here is your drugs cooldown reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.cooldowns.drug;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
      case ProfileNotification.medical:
        notificationId = 105;
        secondsToNotification = _user.cooldowns.medical;
        channelTitle = 'Medical';
        channelSubtitle = 'Medical Expired';
        channelDescription = 'Urgent notifications about medical cooldown';
        notificationTitle = 'Medical Cooldown';
        notificationSubtitle = 'Here is your medical cooldown reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.cooldowns.medical;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
      case ProfileNotification.booster:
        notificationId = 106;
        secondsToNotification = _user.cooldowns.booster;
        channelTitle = 'Booster';
        channelSubtitle = 'Booster Expired';
        channelDescription = 'Urgent notifications about booster cooldown';
        notificationTitle = 'Booster Cooldown';
        notificationSubtitle = 'Here is your booster cooldown reminder!';
        var myTimeStamp =
            (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                _user.cooldowns.booster;
        notificationPayload += '${notificationType.string}-$myTimeStamp';
        break;
    }

    var vibrationPattern = Int64List(8);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 400;
    vibrationPattern[2] = 400;
    vibrationPattern[3] = 600;
    vibrationPattern[4] = 400;
    vibrationPattern[5] = 800;
    vibrationPattern[6] = 400;
    vibrationPattern[7] = 1000;

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelTitle,
      channelSubtitle,
      channelDescription,
      importance: Importance.Max,
      priority: Priority.High,
      visibility: NotificationVisibility.Public,
      icon: 'notification_icon',
      sound: RawResourceAndroidNotificationSound('slow_spring_board'),
      vibrationPattern: vibrationPattern,
      enableLights: true,
      //color: const Color.fromARGB(255, 255, 0, 0),
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
      sound: 'slow_spring_board.aiff',
    );

    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.schedule(
      notificationId,
      notificationTitle,
      notificationSubtitle,
      //DateTime.now().add(Duration(seconds: 10)), // DEBUG 10 SECONDS
      DateTime.now().add(Duration(seconds: secondsToNotification)),
      platformChannelSpecifics,
      payload: notificationPayload,
      androidAllowWhileIdle: true, // Deliver at exact time
    );

    _retrievePendingNotifications();
  }

  Future<void> _retrievePendingNotifications() async {
    bool energy = false;
    bool nerve = false;
    bool life = false;
    bool drugs = false;
    bool medical = false;
    bool booster = false;

    var pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    if (pendingNotificationRequests.length > 0) {
      for (var notification in pendingNotificationRequests) {
        if (notification.payload.contains('energy')) {
          energy = true;
        } else if (notification.payload.contains('nerve')) {
          nerve = true;
        } else if (notification.payload.contains('life')) {
          life = true;
        } else if (notification.payload.contains('drugs')) {
          drugs = true;
        } else if (notification.payload.contains('medical')) {
          medical = true;
        } else if (notification.payload.contains('booster')) {
          booster = true;
        }
      }
    }

    setState(() {
      _energyNotificationsPending = energy;
      _nerveNotificationsPending = nerve;
      _lifeNotificationsPending = life;
      _drugsNotificationsPending = drugs;
      _medicalNotificationsPending = medical;
      _boosterNotificationsPending = booster;
    });
  }

  Future<void> _cancelNotifications(
      ProfileNotification notificationType) async {
    switch (notificationType) {
      case ProfileNotification.energy:
        await flutterLocalNotificationsPlugin.cancel(101);
        break;
      case ProfileNotification.nerve:
        await flutterLocalNotificationsPlugin.cancel(102);
        break;
      case ProfileNotification.life:
        await flutterLocalNotificationsPlugin.cancel(103);
        break;
      case ProfileNotification.drugs:
        await flutterLocalNotificationsPlugin.cancel(104);
        break;
      case ProfileNotification.medical:
        await flutterLocalNotificationsPlugin.cancel(105);
        break;
      case ProfileNotification.booster:
        await flutterLocalNotificationsPlugin.cancel(106);
        break;
    }

    _retrievePendingNotifications();
  }

  void _checkIfNotificationsAreCurrent() async {
    var pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    if (pendingNotificationRequests.length == 0) {
      return;
    }

    bool triggered = false;
    var updatedTypes = List<String>();
    var updatedTimes = List<String>();
    var formatter = new DateFormat('HH:mm');

    for (var notification in pendingNotificationRequests) {
      var splitPayload = notification.payload.split('-');
      var oldTimeStamp = int.parse(splitPayload[1]);

      if (notification.payload.contains('energy')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.energy.fulltime))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.energy);
          _scheduleNotification(ProfileNotification.energy);
          triggered = true;
          updatedTypes.add('energy');
          var energyCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.energy.fulltime));
          updatedTimes.add(formatter.format(energyCurrentSchedule));
        }
      } else if (notification.payload.contains('nerve')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.nerve.fulltime))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.nerve);
          _scheduleNotification(ProfileNotification.nerve);
          triggered = true;
          updatedTypes.add('nerve');
          var nerveCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.nerve.fulltime));
          updatedTimes.add(formatter.format(nerveCurrentSchedule));
        }
      } else if (notification.payload.contains('life')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.life.fulltime))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.life);
          _scheduleNotification(ProfileNotification.life);
          triggered = true;
          updatedTypes.add('life');
          var lifeCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.life.fulltime));
          updatedTimes.add(formatter.format(lifeCurrentSchedule));
        }
      } else if (notification.payload.contains('drugs')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.cooldowns.drug))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.drugs);
          _scheduleNotification(ProfileNotification.drugs);
          triggered = true;
          updatedTypes.add('drugs');
          var drugsCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.cooldowns.drug));
          updatedTimes.add(formatter.format(drugsCurrentSchedule));
        }
      } else if (notification.payload.contains('medical')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.cooldowns.medical))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.medical);
          _scheduleNotification(ProfileNotification.medical);
          triggered = true;
          updatedTypes.add('medical');
          var medicalCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.cooldowns.medical));
          updatedTimes.add(formatter.format(medicalCurrentSchedule));
        }
      } else if (notification.payload.contains('booster')) {
        var newCalculation = DateTime.now()
                .add(Duration(seconds: _user.cooldowns.booster))
                .millisecondsSinceEpoch /
            1000;
        var compareTimeStamps = (newCalculation - oldTimeStamp).abs().floor();
        if (compareTimeStamps > 120) {
          _cancelNotifications(ProfileNotification.booster);
          _scheduleNotification(ProfileNotification.booster);
          triggered = true;
          updatedTypes.add('booster');
          var boosterCurrentSchedule =
              DateTime.now().add(Duration(seconds: _user.cooldowns.booster));
          updatedTimes.add(formatter.format(boosterCurrentSchedule));
        }
      }
    }

    if (triggered) {
      String thoseUpdated = '';
      for (var i = 0; i < updatedTypes.length; i++) {
        thoseUpdated += updatedTypes[i];
        thoseUpdated += ' (${updatedTimes[i]})';
        if (i < updatedTypes.length - 1) {
          thoseUpdated += ", ";
        }
      }

      BotToast.showText(
        text: 'Some notifications have been updated: $thoseUpdated',
        textStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        contentColor: Colors.grey[700],
        duration: Duration(seconds: 5),
        contentPadding: EdgeInsets.all(10),
      );
    }
  }

}
