import 'package:flutter/material.dart';
import 'package:torn_pda/utils/shared_prefs.dart';

enum BrowserSetting {
  app,
  external,
}

enum TimeFormatSetting {
  h24,
  h12,
}

enum TimeZoneSetting {
  localTime,
  tornTime,
}

class SettingsProvider extends ChangeNotifier {

  int lastAppUse;

  var _currentBrowser = BrowserSetting.app;
  BrowserSetting get currentBrowser => _currentBrowser;
  set changeBrowser(BrowserSetting browserType) {
    _currentBrowser = browserType;
    _saveSettingsSharedPrefs();
    notifyListeners();
  }

  var _testBrowserActive = false;
  bool get testBrowserActive => _testBrowserActive;
  set changeTestBrowserActive(bool active) {
    _testBrowserActive = active;
    _saveSettingsSharedPrefs();
    notifyListeners();
  }

  var _currentTimeFormat = TimeFormatSetting.h24;
  TimeFormatSetting get currentTimeFormat => _currentTimeFormat;
  set changeTimeFormat(TimeFormatSetting timeFormatSetting) {
    _currentTimeFormat = timeFormatSetting;
    _saveSettingsSharedPrefs();
    notifyListeners();
  }

  var _currentTimeZone = TimeZoneSetting.localTime;
  TimeZoneSetting get currentTimeZone => _currentTimeZone;
  set changeTimeZone(TimeZoneSetting timeZoneSetting) {
    _currentTimeZone = timeZoneSetting;
    _saveSettingsSharedPrefs();
    notifyListeners();
  }

  void _saveSettingsSharedPrefs() {
    String browserSave;
    switch (_currentBrowser) {
      case BrowserSetting.app:
        browserSave = 'app';
        break;
      case BrowserSetting.external:
        browserSave = 'external';
        break;
    }
    SharedPreferencesModel().setDefaultBrowser(browserSave);

    SharedPreferencesModel().setTestBrowserActive(_testBrowserActive);

    String timeFormatSave;
    switch (_currentTimeFormat) {
      case TimeFormatSetting.h24:
        timeFormatSave = '24';
        break;
      case TimeFormatSetting.h12:
        timeFormatSave = '12';
        break;
    }
    SharedPreferencesModel().setDefaultTimeFormat(timeFormatSave);

    String timeZoneSave;
    switch (_currentTimeZone) {
      case TimeZoneSetting.localTime:
        timeZoneSave = 'local';
        break;
      case TimeZoneSetting.tornTime:
        timeZoneSave = 'torn';
        break;
    }
    SharedPreferencesModel().setDefaultTimeZone(timeZoneSave);
  }

  void updateLastUsed(int timeStamp) {
    SharedPreferencesModel().setLastAppUse(timeStamp);
    lastAppUse = timeStamp;
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    lastAppUse = await SharedPreferencesModel().getLastAppUse();

    String restoredBrowser = await SharedPreferencesModel().getDefaultBrowser();
    switch (restoredBrowser) {
      case 'app':
        _currentBrowser = BrowserSetting.app;
        break;
      case 'external':
        _currentBrowser = BrowserSetting.external;
        break;
    }

    _testBrowserActive = await SharedPreferencesModel().getTestBrowserActive();

    String restoredTimeFormat =
        await SharedPreferencesModel().getDefaultTimeFormat();
    switch (restoredTimeFormat) {
      case '24':
        _currentTimeFormat = TimeFormatSetting.h24;
        break;
      case '12':
        _currentTimeFormat = TimeFormatSetting.h12;
        break;
    }

    String restoredTimeZone =
        await SharedPreferencesModel().getDefaultTimeZone();
    switch (restoredTimeZone) {
      case 'local':
        _currentTimeZone = TimeZoneSetting.localTime;
        break;
      case 'torn':
        _currentTimeZone = TimeZoneSetting.tornTime;
        break;
    }

    notifyListeners();
  }
}
