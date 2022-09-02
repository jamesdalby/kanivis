import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Application {
  static final Application _instance = Application._internal();

  factory Application() {
    return _instance;
  }

  Application._internal();

  static const String _LOCALE_LANGUAGE = "LOCALE_LANGUAGE";
  static const String _LOCALE_COUNTRY = "LOCALE_COUNTRY";

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  void set locale(Locale _locale) {
    _prefs.then((value) {
      value.setString(_LOCALE_LANGUAGE, _locale.languageCode);
      if (_locale.countryCode != null) {
        value.setString(_LOCALE_COUNTRY, _locale.countryCode ?? "");
      }
    });
  }

  Future<Locale> getLocale(Locale defaultValue) {
    return _prefs.then((value) {
      if (value.containsKey(_LOCALE_LANGUAGE)) {
        String languageCode =
            value.getString(_LOCALE_LANGUAGE) ?? defaultValue.languageCode;
        String? countryCode = value.getString(_LOCALE_COUNTRY);
        return Locale(languageCode, countryCode);
      } else {
        return defaultValue;
      }
    });
  }

  AppLocalizations? _appLocalizations;
  set appLocalizations(AppLocalizations? appLocal) {
    _appLocalizations = appLocal;
  }

  AppLocalizations? get appLocalizations {
    return _appLocalizations;
  }
}
