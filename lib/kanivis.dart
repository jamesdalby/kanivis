import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:kanivis/offcourse.dart';
import 'package:kanivis/qspeak.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:nmea/nmea.dart';

import 'package:provider/provider.dart';

import 'Application.dart';
import 'constants.dart';

// use for localization and need "Flutter Intl" plugin
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';

class KanivisApp extends StatefulWidget {
  const KanivisApp({Key? key}) : super(key: key);
  @override
  State<KanivisApp> createState() => _KanivisAppState();
  static _KanivisAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_KanivisAppState>();
}

Locale? _locale;

class _KanivisAppState extends State<KanivisApp> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    //_locale = Locale("fr");
    //Locale locale = Locale(Platform.localeName.substring(0, 2));

    //print(locale.countryCode);

    return MaterialApp(
        localeResolutionCallback: (deviceLocale, supportedLocales) {
          setDefaultLocale(deviceLocale);
          // here you make your app language similar to device language , but you should check whether the localization is supported by your app
        },
        locale: _locale,
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en', 'US'), // English
          const Locale('fr', 'FR'), // French
        ],
        //supportedLocales: S.delegate.supportedLocales,
        title: 'KANIVIS',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage());
  }

  bool _defaultLocaleSet = false;
  void setDefaultLocale(Locale? deviceLocale) {
    if (!_defaultLocaleSet) {
      Application().getLocale(deviceLocale ?? Locale("en")).then((value) {
        setLocale(value);
      });
      _defaultLocaleSet = true;
    }
  }

  Locale getLocale() {
    if (_locale == null) {
      setDefaultLocale(Locale("en"));
    }
    return _locale ?? Locale("en");
  }

  void setLocale(Locale locale) {
    //Force known local

    if ((_locale == null) || (_locale!.languageCode != locale.languageCode)) {
      if (locale.languageCode == "fr") {
        _locale = Locale("fr");
      } else {
        _locale = Locale("en");
      }
      S.load(locale).then((value) => setState(() {
            ;
          }));
      Application().locale = locale;
    }
  }
}

// Degrees, Minutes, Seconds N/S/E/W
// The primary purpose is the toString() method used to format in a way that works nicely with TTS
class DMS {
  final int deg;
  final double ms;
  final String nesw;

  // Internal representation of Degrees, Minutes (not seconds, only decimal minutes) and a N, S E or W indicator.
  DMS(this.deg, this.ms, this.nesw);

  /// convert to a form suitable for passing into TTS
  @override
  String toString() {
    String v = nesw;
    switch (nesw.toLowerCase()) {
      case 'n':
        v = S.current.north;
        break;
      case 'e':
        v = S.current.east;
        break;
      case 'w':
        v = S.current.west;
        break;
      case 's':
        v = S.current.south;
        break;
    }
    return "$deg " +
        S.current.degrees +
        ", ${_dp1(ms)} " +
        S.current.minutes +
        " $v";
  }

  static DMS? latitude(double? lat) {
    if (lat == null) return null;
    String ns = 'n';
    if (lat < 0) {
      lat = -lat;
      ns = 'S';
    }
    int deg = lat.truncate();
    double min = (lat - deg) * 60;

    return DMS(deg, min, ns);
  }

  static DMS? longitude(double? lng) {
    if (lng == null) return null;
    String ew = 'e';
    if (lng < 0) {
      lng = -lng;
      ew = 'W';
    }
    int deg = lng.truncate();
    double min = (lng - deg) * 60;

    return DMS(deg, min, ew);
  }
}

/// NMEA derived data goes into here in a canonicalised form where it is read by the Flutter side for speaking/display
class BusData {
  int? _awa, _twa;
  String? _tack; // null, 'Starboard', 'Port'
  double? _aws, _tws;
  // double _twd; // true wind direction - use to compute twa?
  DMS? _lat, _lng;
  DateTime? _utc;
  int? _btw;
  double? _dtw, _xte, _vmw;
  String? _wpt;

  // int _heading;
  int? _cog;
  int? _compass;
  double? _bsp, _sog, _vmg;
  double? _trip, _gpsTrip;
  double? _dbk, _dbt, _dbs;

  int? get btw => _btw;

  int? get awa => _awa;

  String? get tack => _tack;

  int? get twa => _twa;

  double? get aws => _aws;

  double? get tws => _tws;

  int? get latDeg => _lat?.deg;

  double? get latMS => _lat?.ms;

  int? get lngDeg => _lng?.deg;

  double? get lngMS => _lng?.ms;

  double? depth(String sel) {
    switch (sel) {
      case 'DBS':
        return _dbs;
      case 'DBK':
        return _dbk;
      case 'DBT':
        return _dbt;
    }
    return null;
  }

  DateTime? get utc => _utc;

  double? get dtw => _dtw;

  int? get cog => _cog;

  // int get heading => _heading;

  int? get compass => _compass;

  double? get bsp => _bsp;

  double? get sog => _sog;

  double? get vmg => _vmg;

  double? get trip => _trip;

  double? get gpsTrip => _gpsTrip;

  String? get wpt => _wpt;

  // Cross track error as a string suitable for speaking using TTS
  String get xte {
    if (_xte == null) {
      return S.current.Unavailable;
    }
    if (_xte! < 0) {
      return (-_xte!).toStringAsFixed(2) + ", " + S.current.toPort;
    }
    return _xte!.toStringAsFixed(2) + ", " + S.current.toStarboard;
  }

  double? get vmw => _vmw;

  void handleNMEA(var msg) {
    // arriving message - exciting!
    print(msg.toString());

    // Pos is a mixin, not exclusive:
    if (msg is Pos) {
      _lat = DMS.latitude(msg.lat);
      _lng = DMS.longitude(msg.lng);
    }

    if (msg is RMB) {
      // TODO: Cansider also using BWR, BWC for recording waypoint info?
      _btw = msg.bearingToDestination.toInt();
      _dtw = msg.rangeToDestination;
      _xte = msg.crossTrackError;
      _vmw = msg.destinationClosingVelocity;
      _wpt = msg.destinationWaypointID;
    } else if (msg is RMC) {
      _lat = DMS.latitude(msg.position.lat);
      _lng = DMS.longitude(msg.position.lng);
      _sog = msg.sog;
      // _vmg = m.trackMadeGood; // XXX
      _utc = msg.utc;
    } else if (msg is VTG) {
      _cog = msg.cogTrue.round();
      _sog = msg.sog;
    } else if (msg is DPT) {
      if (msg.depthKeel != null) {
        _dbk = msg.depthKeel;
      }
      if (msg.depthTransducer != null) {
        _dbt = msg.depthTransducer;
      }
      if (msg.depthSurface != null) {
        _dbs = msg.depthSurface;
      }
    } else if (msg is DBT) {
      _dbt = msg.metres;
    } else if (msg is DBS) {
      // depth below surface
      _dbs = msg.depthSurface;
    } else if (msg is DBK) {
      // depth below keel
      _dbk = msg.depthKeel;
    } else if (msg is HDG) {
      _compass = msg.heading?.toInt();
      // _heading = msg.trueHeading.toInt();
    } else if (msg is HDT) {
      // _heading = msg.heading.toInt();
//      _check(_hdgt, _course);
    } else if (msg is MWV) {
      if (msg.isTrue) {
        _twa = msg.windAngleToBow?.toInt();
        _tws = msg.windSpeed;
        _tack = msg
            .tack; // slightly dodgy, maybe? distinguish twa and awa tacks?  Not sure it matters that much.
      } else {
        _awa = msg.windAngleToBow?.toInt();
        _aws = msg.windSpeed;
        _tack = msg.tack;
      }
    } else if (msg is VHW) {
      _bsp = msg.boatspeedKnots;
      if (msg.headingTrue != null) {
        // _heading = msg.headingTrue.toInt();
      } // TODO: Should this be mag? selectable?
    } else if (msg is GSA) {
      // Active satellites
    } else if (msg is ZDA) {
      _utc = msg.utc;
    } else if (msg is MWD) {
      _tws = msg.trueWindSpeedKnots;
      //  _twd = msg.trueWindDirection;
    } else if (msg is MTW) {
      // water temp
    } else if (msg is GLL) {
      // Geographic lat/long - handled by 'Pos' above
    } else if (msg is GLC) {
      // obsolete loran
    } else if (msg is GGA) {
      // GPS, handled by Pos above
    } else if (msg is VDO) {
      // Own vessel data for AIS.
    } else if (msg is WPL) {
      // Waypoint info
    } else if (msg is AAM) {
      // Waypoint arrival alarm
    } else if (msg is APB) {
      // TODO
    } else if (msg is BOD) {
      // Bearing wpt to wpt, not interesting to us.
    } else if (msg is GSV) {
      // Satellites in view, not interesting to us.
    } else if (msg is VDM) {
      // AIS VDM - currently not interesting (maybe one day?)
    } else if (msg is VLW) {
      _trip = msg.resetDistance;
      _gpsTrip = msg.cumulativeGroundDistance;
    } else if (msg is XDR) {
      // transducer measurement, currently not interesting
    } else if (msg is XTE) {
      // cross track error
      _xte = msg.crossTrackError * (msg.directionToSteer == 'L' ? 1 : -1);
    } else {
      print('msg : ' + msg.runtimeType.toString());
    }
  }

  void sensorPosition(Position? p) {
    if (p == null) {
      return;
    }

    _sog = p.speed * 1.94384; // convert m/s to knots
    _cog = p.heading.toInt();
    // print (p.heading.toStringAsFixed(1));
    _lat = DMS.latitude(p.latitude);
    _lng = DMS.longitude(p.longitude);
    _utc = p.timestamp;
  }

  void compassEvent(CompassEvent e) {
    int? h = e.heading?.toInt();
    if (h == null) return;

    if (h < 0) h = 360 + h;
    _compass = h;
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

/// Convert [num] to a three digit (zero padded) number suitable for passing to TTS
String _hdg(int? num) {
  if (num == null) {
    return S.current.Unavailable;
  }
  return num.toString().padLeft(3, '0').split('').join(' ');
}

/// Convert [num] to a decimal with 1 digit after the decimal point
String _dp1(double? num) {
  if (num == null) {
    return S.current.Unavailable;
  }
  return num.toStringAsFixed(1);
}

/// Whether currently in command-entry mode or number-entry mode.
enum Mode { Num, Cmd, Opt, Steer }

/// During number entry, + or - switch into Relative (Neg, Pos) mode, otherwise Absolute
enum Rel { Neg, Abs, Pos }

/// Currently selected steering mode
enum Steer { None, Compass, Wind }

/// How off-course should be reported.
enum OffCourse { Off, Periodic, Hint, Error, Beep }

class _MyHomePageState extends State<MyHomePage> {
  // permissions check, refrenced if we're using device sensors
  bool _hasPermissions = false;

  // initialise test-to-speech magic
  static QSpeak _spk = QSpeak();

  /// Update [_latReportedDepth] whenever the user has been told of the depth (not when it's sent on NMEA)
  double? _lastReportedDepth;

  /// incoming NMEA data stashed in here.
  BusData _busData = new BusData();

  // Only one of _nmea and _positionStream can be non-null
  late NMEASocketReader _nmea;
  Stream<Position>? _positionStream;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSub;

  /// current user-defined target course or target wind angle, used to detect deviation therefrom.
  int? _target;

  bool _depthReport = true;

  static double _pitch = 1;

  static double get pitch => _pitch;

  static set pitch(double v) => _pitch = limit(v, .5, 2.0);

  static int _volume = 10;
  static int get volume => _volume;
  static set volume(int v) => _volume = limit(v, 1, 10);

  static double _speechRate = 1;
  static double get speechRate => _speechRate;
  static set speechRate(double v) => _speechRate = limit(v, 0.1, 3.0);

  static late SharedPreferences _prefs;

  late Locale _locale;
  setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  /// initialise text-to-speech stuff to default/sensible values
  static _initTTS() async {
    await _spk.setLanguage(_prefs.getString(PREFS_LANGUAGE) ?? "en");

    // await spk.setVoice()

    // print(await spk.getVoices);
    speechRate = (_prefs.get(PREFS_SPEECH_RATE) as double?) ??
        (Platform.isAndroid ? 1.0 : 0.5);
    await _spk.setSpeechRate(speechRate);

    volume = (_prefs.get(PREFS_VOLUME) as int?) ?? 10;
    await _spk.setVolume(volume);

    pitch = (_prefs.get(PREFS_PITCH) as double?) ?? 1.0;
    await _spk.setPitch(pitch);

    _spk.immediate(S.current.initialiseTextToSpeech);
    //'Knowles Audible Navigation Information for Visually Impaired Sailors');
  }

  static late AudioPlayer _audioPlayer;
  static late AudioCache _audioCache;

  static void _initBeep() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerError.listen((e) => print("Error $e"));

    // _audioPlayer.onPlayerStateChanged.listen((e) => print("State $e"));

    _audioCache =
        AudioCache(prefix: 'assets/beeps/', fixedPlayer: _audioPlayer);

    await _audioCache.loadAll([
      'high-1.wav',
      'low-1.wav', // XXX: I think these should be generated on demand?  Can control freq & volume (and maybe style)
    ]);
  }

  /// ensure TTS is closed off also audioplayer & cache
  @override
  void dispose() {
    super.dispose();
    _audioCache.clearAll();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _spk.stop();
  }

  /// current mode, command or number-entry, starts off in command mode.
  Mode _mode = Mode.Cmd;

  /// Whether tracking errors are measured against AWA or Compass
  Steer _steer = Steer.None;

  OffCourse _offCourse = OffCourse.Off;

  late Map<Mode, List<_LabelledAction>> _menus;
  // late StreamSubscription<Position> _positionStream;

  _MyHomePageState() {
    _menus = _initMenus();
    SharedPreferences.getInstance().then((p) {
      _prefs = p;

      _initTTS();
      _initBeep();
      _sensitivity = _prefs.getInt(PREFS_SENSITIVITY) ?? 5;
      _depthPref = _prefs.getString(PREFS_DEPTH_PREFERENCE) ?? 'DBS';

      // This doesn't actually connect, just sets up...
      _nmea = new NMEASocketReader(
          _prefs.getString(PREFS_NETWORK_HOST) ?? 'dealingtechnology.com',
          _prefs.getInt(PREFS_NETWORK_PORT) ?? 10110,
          _busData.handleNMEA);

      if (_prefs.getBool(PREFS_DEVICE_SENSORS) ?? false) {
        // Here we can connect to the local (phone/tablet) sensors if NMEA not available,
        // including: GPS, (Time), Course, SOG

        // make sure we have permissions:

        final LocationSettings locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
        _positionStream =
            Geolocator.getPositionStream(locationSettings: locationSettings);
        _positionStreamSubscription =
            _positionStream!.listen(_busData.sensorPosition);
      } else {
        // This initiates the connection:
        _nmea.process();
      }

      Timer.periodic(Duration(seconds: 1), (t) => _checkHdg());
    });
  }

  Timer? _offCourseTimer;
  double _beepInterval = 0;
  int _sensitivity = 3;
  int? _err;

  void _offCourseBeep(int sign) {
    String p = sign < 0 ? "high" : "low";
    _audioCache.play('$p-1.wav').onError((error, stackTrace) {
      print(error.toString());
      return _audioPlayer;
    });
  }

  void _checkHdg() {
    double? d = _busData.depth(_depthPref);
    if (d != null && d != 0) {
      if ((_lastReportedDepth ?? 0) != 0) {
        double ratio = d / _lastReportedDepth!.toDouble();
        if (ratio >= 1.1) {
          if (_depthReport) {
            _depth();
          }
          _lastReportedDepth = d;
        } else if (ratio < 0.9) {
          if (_depthReport) {
            _depth();
          }
          _lastReportedDepth = d;
        }
      } else {
        _lastReportedDepth = d;
      }
    }

    if (_target != null) {
      // -180 <= _err < 180
      // if _err > 0 then we should steer left
      // if _err < 0 then we should steer right
      // if _err is null then either compass or wind angle isn't available.
      // When steering to wind, the tack is relevant
      // see Steer.md for a more comprehensive explanation
      //
      switch (_steer) {
        case Steer.None:
          return;
        case Steer.Compass:
          if (_busData.compass != null) {
            _err = _normalise(_busData.compass! - _target!);
          } else {
            _err = null;
          }
          break;
        case Steer.Wind:
          if (_busData.awa != null) {
            _err = _normalise(_busData.awa! -
                _target!); // prob dn't need normalise, but no harm
            if (_busData.tack == 'Starboard') {
              _err = -_err!;
            }
          } else {
            _err = null;
          }
          break;
      }
      _setBeepFreq();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<_LabelledAction> a = _menus[_mode]!;
    return Scaffold(
        appBar: AppBar(
          title: Text('KANIVIS'),
        ),
        drawer: Drawer(
            child: ListView(children: <Widget>[
          ListTile(
              title: Text("User setttings"),
              onTap: () async {
                Navigator.of(context).pop();
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) => UserSettings()))
                    .then((var s) async {});
              }),
          ListTile(
              title: Text('Communications'),
              onTap: () async {
                Navigator.of(context).pop();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) =>
                            CommsSettings(_nmea, _prefs))).then((var s) async {
                  if (s == null) {
                    print("No change");
                    return;
                  }
                  print("$s ${s.host}:${s.port}");
                  _prefs.setString(PREFS_NETWORK_HOST, s.host);
                  _prefs.setInt(PREFS_NETWORK_PORT, s.port);
                  _prefs.setBool(PREFS_DEVICE_SENSORS, s.sensors);
                  if (s.sensors) {
                    // enable device sensors, disable NMEA stream
                    _nmea.active = false;

                    if (_positionStream == null) {
                      final LocationSettings locationSettings =
                          const LocationSettings(
                        accuracy: LocationAccuracy.high,
                        distanceFilter: 0,
                      );
                      _positionStream = Geolocator.getPositionStream(
                          locationSettings: locationSettings);
                    }
                    _positionStreamSubscription?.cancel();
                    _positionStreamSubscription =
                        _positionStream!.listen(_busData.sensorPosition);

                    _compassSub?.cancel();
                    _compassSub =
                        FlutterCompass.events?.listen(_busData.compassEvent);
                  } else {
                    await _compassSub?.cancel();
                    await _positionStreamSubscription?.cancel();

                    _nmea.hostname = s.host;
                    _nmea.port = s.port;
                    _nmea.active = true;
                  }
                });
              })
        ])),
        body:
            // 3x5 grid of buttons
            Container(
                constraints: BoxConstraints.expand(),
                color: Colors.redAccent,
                child: Column(children: [
                  Expanded(
                    child: Row(children: [a[0].w, a[1].w, a[2].w]),
                  ),
                  Expanded(
                    child: Row(children: [a[3].w, a[4].w, a[5].w]),
                  ),
                  Expanded(
                    child: Row(children: [a[6].w, a[7].w, a[8].w]),
                  ),
                  Expanded(
                    child: Row(children: [a[9].w, a[10].w, a[11].w]),
                  ),
                  Expanded(
                    child: Row(children: [a[12].w, a[13].w, a[14].w]),
                  ),
                ])));
  }

  void changeDepthReporting() {
    _depthReport = !_depthReport;
    _spk.immediate(S.current.DepthWarningsAreNow +
        " " +
        (_depthReport ? S.current.enabled : S.current.silenced));
  }

  int? _tot = 0;
  Rel _rel = Rel.Abs;

  void _acc(String n) async {
    if (n.compareTo('0') >= 0 && n.compareTo('9') <= 0) {
      _spk.immediate(n); // XXX If using talkback, no need to speak this?
      // it's a digit, accumulate it
      _tot = (_tot ?? 0) * 10 + int.parse(n);
      if (_tot! > 359) {
        _spk.immediate(S.current.InvalidNumberReturningToCommandMode);
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);
      }
      return;
    }

    switch (n) {
      case '-':
        _spk.immediate(S.current.minus);
        if (_tot == null) {
          _rel = Rel.Neg;
        }
        break;

      case '+':
        _spk.immediate(S.current.plus);
        if (_tot == null) {
          _rel = Rel.Pos;
        }
        break;

      case '=': // legacy
      case 'Set':
        if (_tot == null) {
          _spk.immediate(S.current.NoNumberWasEntered);
          // switch back to command node.
        } else {
          _target ??= 0;

          switch (_rel) {
            case Rel.Neg:
              _target = _target! - _tot!;
              break;

            case Rel.Abs:
              _target = _tot! % 360;
              break;

            case Rel.Pos:
              _target = _target! + _tot!;
              break;
          }
          _target = _target! % 360;

          switch (_steer) {
            case Steer.Wind:
              _spk.add(SpeakPriority.General, 'TGN',
                  S.current.TargetWindAngle + " ${_hdg(_target)}");
              break;

            case Steer.Compass:
              _spk.add(SpeakPriority.General, 'TGN',
                  S.current.TargetCourse + " ${_hdg(_target)}");
              break;

            default:
              _spk.add(SpeakPriority.General, 'TGN',
                  S.current.NoSteerModeIsSetCurrently);
              break;
          }
        }
        _tot = null;
        _setMode(Mode.Cmd);
        _rel = Rel.Abs;
        _spk.immediate(S.current.CommandMode);
        break;

      case '*':
      case 'Reset':
        _spk.immediate(S.current.Reset);
        _rel = Rel.Abs;
        _tot = null;
        break;

      case '#':
      case 'Cancel':
        _spk.immediate(S.current.NumberEntryCancelledNowInCommandMode);
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);

        break;
    }
  }

  void _apparentWind() {
    _spk.add(
        SpeakPriority.General,
        'AWA',
        S.current.AWA +
            " ${_hdg(_busData.awa)} ${_busData.tack ?? ''}, " +
            S.current.AWS +
            " ${_dp1(_busData.aws)}");
  }

  void _trueWind() {
    String? msg;
    if (_busData.twa != null) {
      msg = S.current.TWA + " " + _hdg(_busData.twa);
      if (_busData.tack != null) {
        msg += " " + _busData.tack!;
      }
    }
    if (_busData.tws != null) {
      String tws = S.current.TWS + " " + _dp1(_busData.tws);
      if (msg != null) {
        msg += ", $tws";
      } else {
        msg = tws;
      }
    }
    if (msg == null) {
      // XXX consider calculating it from Apparent + trig on boat speed/direction
      msg = S.current.TrueWindUnavailable;
    }
    _spk.add(SpeakPriority.General, 'TWA', msg);
  }

  void _aisInfo() {
    // XXX: Speak closest target by distance, by CPA and by TCPA
    // XXX: Toggle on/off announcement of changed target (hysteresis?)
    _spk.immediate(S.current.AISCurrentlyUnimplemented);
  }

  void _pos() {
    // _speak("Lat $_lat.degrees $_lat.minutes $_lat.ns, $_lng.degrees $_lng.minutes $_lng.ew");
    DMS? la = _busData._lat;
    DMS? lo = _busData._lng;
    if (la == null || lo == null) {
      _spk.add(SpeakPriority.General, 'POS', S.current.PositionUnavailable);
      return;
    }

    _spk.add(
        SpeakPriority.General,
        'POS',
        S.current.Lat +
            " ${la.toString()}, " +
            S.current.Long +
            " ${lo.toString()}");
  }

  DateFormat _formatter = new DateFormat('H,mm,ss');

  void _utc() {
    // XXX: Add support for time offset/local time?
    _spk.add(
        SpeakPriority.General,
        'UTC',
        S.current.UTC +
            " " +
            _formatter.format(_busData.utc ?? DateTime.now()));
  }

  void _waypoint() {
    if ((_busData.wpt ?? '') == '') {
      _spk.add(SpeakPriority.General, 'WPT', S.current.NoActiveWaypoint);
      return;
    }
    _spk.add(
        SpeakPriority.General,
        'WPT',
        S.current.Waypoint +
            " ${_busData.wpt}, " +
            S.current.BTW +
            " ${_hdg(_busData.btw)}, " +
            S.current.DTW +
            " ${_dp1(_busData.dtw)}, " +
            S.current.XTE +
            " ${_busData.xte}, " +
            S.current.VMW +
            " ${_dp1(_busData.vmw)}");
  }

  void _heading() {
    // XXX: Modify to include port/stbd for wind target and apparent wind angle.
    String st = "";
    if (_target != null) {
      if (_steer == Steer.Compass) {
        st = S.current.TargetCompassCourse + " ${_hdg(_target)}";
      } else if (_steer == Steer.Wind) {
        st = S.current.TargetWindAngle + " ${_hdg(_target)}";
      }
    }
    _spk.add(
        SpeakPriority.General,
        'HDG',
        S.current.Compass +
            " ${_hdg(_busData.compass)}, " +
            S.current.COG +
            " ${_hdg(_busData.cog)}, " +
            S.current.AWA +
            "${_hdg(_busData.awa)} ${_busData.tack ?? ''} $st");
  }

  void _speed() {
    _spk.add(
        SpeakPriority.General,
        'SPD',
        S.current.Speed +
            " ${_dp1(_busData.bsp)}, " +
            S.current.SOG +
            " ${_dp1(_busData.sog)}, " +
            S.current.VMG +
            " ${_dp1(_busData.vmg)}");
  }

  void _trip() {
    _spk.add(
        SpeakPriority.General,
        'TRP',
        S.current.Trip +
            " ${_dp1(_busData.trip)}, " +
            S.current.GPSTrip +
            " ${_dp1(_busData.gpsTrip)}");
  }

  void _steerTo() {
    setState(() {
      _mode = Mode.Steer;
    });
    _spk.immediate(S.current.SteerModePress);
  }

  //ToDo : add in meter
  void _depth() {
    _lastReportedDepth = _busData.depth(_depthPref);
    _spk.add(SpeakPriority.General, 'DPT',
        S.current.Depth + " ${_dp1(_lastReportedDepth)}" + S.current.Feet);
  }

  void _setMode(Mode m) {
    setState(() => _mode = m);
  }

  void _number() {
    _spk.immediate(S.current.NumberMode);
    _setMode(Mode.Num);
  }

  void _alter(int num, String wind, String compass) {
    if (_target == null) {
      _spk.immediate(S.current.NoCourseSet);
      return;
    }

    switch (_steer) {
      case Steer.None:
        // 'Can't happen'?
        return;

      case Steer.Wind:
        _target = (_target! - num);
        if (_target! < 0) {
          _target = 180 - _target!;
        } else if (_target! > 180) {
          _target = _target! - 180;
        }
        _spk.add(SpeakPriority.General, 'TGT',
            S.current.TargetAngle + " ${_target.toString()}");
        break;

      case Steer.Compass:
        _target = (_target! + num) % 360;
        _spk.add(SpeakPriority.General, 'TGT',
            S.current.TargetCourse + " ${_hdg(_target)}");
        break;
    }
  }

  void _port() {
    _alter(-10, S.current.BearAwayTenDegrees, S.current.TenDegreesToPort);
  }

  void _stbd() {
    _alter(10, S.current.LuffUpTenDegrees, S.current.TenDegreesToStarboard);
  }

  Future<void> _saveOptions() async {
    await _prefs.setDouble(PREFS_SPEECH_RATE, _speechRate);
    await _prefs.setInt(PREFS_VOLUME, _volume);
    await _prefs.setDouble(PREFS_PITCH, _pitch);
    await _prefs.setInt(PREFS_SENSITIVITY, _sensitivity);
    _spk.immediate(S.current.CommandMode);
    _setMode(Mode.Cmd);
  }

  void setSensitivity(int chg) {
    _sensitivity = limit(_sensitivity + chg, 1, 9).toInt();
    _spk.add(SpeakPriority.Application, 'SENS',
        S.current.sensitivity + " $_sensitivity");
    _setBeepFreq();
  }

  void _setSpeechVolume(int chg) {
    volume += chg;
    _spk.setVolume(volume);
    _spk.add(SpeakPriority.Application, 'VOL', S.current.volume + " $volume");
  }

  void _setSpeechRate(double chg) {
    speechRate += chg;
    _spk.setSpeechRate(speechRate);
    _spk.add(SpeakPriority.Application, 'RATE',
        S.current.rate + " ${speechRate.toStringAsFixed(1)}");
  }

  void _setSpeechPitch(double chg) {
    pitch += chg;
    _spk.setPitch(pitch.toDouble());
    _spk.add(SpeakPriority.Application, 'PITCH',
        S.current.pitch + " ${pitch.toStringAsFixed(1)}");
  }

  void _optGuidance() {
    _spk.immediate(S.current.GuidanceOption);
  }

  // If _offCourse is 'Off' then the timer is disabled&disposed.
  // For any other value, two things come into play: what to do, and how long to wait until the next iteration.
  // The 'what do do' can be speak, or beep;
  // The 'how long to wait' is a timer that runs to completion and then executed the 'what to do'.
  // There's a bit of a dilemma here: should the action be executed before the delay?  Or after.
  // It would be better if it were before, with some ability to pre-empt the timer expiry if something changes.
  // But pragmatically this is quite hard to do sensibly in the face of ever changing inputs.
  // I've decided to let the timer expire, then perform the action, then reset the timer for the next cycle.

  void _setBeepFreq() {
    if (_err == null || _err!.abs() < (10 - _sensitivity)) {
      _beepInterval = 5;
    } else {
      switch (_offCourse) {
        case OffCourse.Off:
          if (_offCourseTimer != null) {
            _offCourseTimer!.cancel();
            _offCourseTimer = null;
          }
          return;

        case OffCourse.Error:
        case OffCourse.Hint:
        case OffCourse.Beep:
          _beepInterval = interval(_sensitivity, _err!);
          break;

        case OffCourse.Periodic:
          _beepInterval = 10.0 - _sensitivity;
          break;
      }
    }

    if (_beepInterval != 0 && _offCourseTimer == null) {
      _offCourseTimer = Timer(
          Duration(milliseconds: (_beepInterval * 1000).toInt()),
          _speakOffCourse);
    }
  }

  static T limit<T extends num>(T v, T lo, T hi) {
    if (v <= lo) {
      return lo;
    }
    if (v >= hi) {
      return hi;
    }
    return v;
  }

  int _normalise(int i) {
    if (i >= 180) return i - 360;
    if (i < -180) return i + 360;
    return i;
  }

  void _steerUsing(Steer steer, OffCourse offCourse) {
    _steer = steer;
    _offCourse = offCourse;

    if (_steer == Steer.None || _offCourse == OffCourse.Off) {
      // if either is off, force both off (they may already be set thus, that's OK)
      _steer = Steer.None;
      _offCourse = OffCourse.Off;
    }
    switch (_steer) {
      case Steer.Compass:
        _target = _busData.compass;
        if (_target == null) {
          _spk.add(
              SpeakPriority.General, 'TGN', S.current.NoCompassCourseAvailable);
          return;
        }
        _spk.add(SpeakPriority.General, 'TGN',
            S.current.NowSteeringToCompass + " ${_hdg(_target)}");
        break;

      case Steer.Wind:
        _target = _busData.awa;
        if (_target == null) {
          _spk.add(
              SpeakPriority.General, 'TGN', S.current.NoWindAngleAvailableSet);
          return;
        }
        _spk.add(SpeakPriority.General, 'TGN',
            S.current.NowSteeringToApparentWind + " ${_hdg(_target)}");
        break;

      default:
        // can't happen
        _spk.add(
            SpeakPriority.General, 'TGN', S.current.SteerModeSilencedAndReset);
        _target = null;
        break;
    }
    // reset beep timer; this will set the beep delay, and also crate a one-shot timer that calls _speakOffCourse if need be
    _setBeepFreq();
    setState(() => _mode = Mode.Cmd);
    _spk.immediate(S.current.ReturningToCommandMode);
  }

  // This does the clever off course stuff, in conjunction with the [_setBeepFreq] method.
  void _speakOffCourse() {
    // _setBeepFreq();
    // print ("_speakOffCourse: $_offCourse ${_beepInterval}s $_err\n");

    if (_steer == Steer.None) {
      _offCourse = OffCourse.Off;
    }

    switch (_offCourse) {
      case OffCourse.Off:
        // disable timer
        _offCourseTimer?.cancel();
        _offCourseTimer = null;
        return;

      case OffCourse.Beep:
        // beep with increasing rapidity as we go further off course, sign indicates high beep or low beep tone.
        _offCourseBeep(_err?.sign ?? 0);
        break;

      case OffCourse.Hint:
      // indicate whether we're off with timing dependent on urgency, same as 'Periodic' but with timing dependent on error

      case OffCourse.Periodic:
        // report course/angle with periodicity dependent only on sensitivity
        switch (_steer) {
          case Steer.Compass:
            _spk.add(SpeakPriority.General, 'TGT', _hdg(_busData.compass));
            break;

          case Steer.Wind:
            _spk.add(SpeakPriority.General, 'TGT',
                _hdg(_busData.awa) + ' ' + (_busData.tack ?? ''));
            break;

          default: // can't happen
            break;
        }
        break;

      case OffCourse.Error:
        switch (_steer) {
          case Steer.Compass:
          case Steer.Wind:
            if (_err == 0) {
              _spk.add(SpeakPriority.General, 'TGT', S.current.OnCourse);
            } else {
              // error interpretation : you are too far to ...
              _spk.add(
                  SpeakPriority.General,
                  'TGT',
                  _err!.abs().toStringAsFixed(0) +
                      (_err! < 0
                          ? " " + S.current.Port
                          : " " + S.current.Starboard));
            }
            break;
          default: // can't happen
        }
        break;
    }
    // and reset the timer:
    _offCourseTimer = Timer(
        Duration(milliseconds: (_beepInterval * 1000).toInt()),
        _speakOffCourse);
  }

  _LabelledAction _l(String label, void Function() action) =>
      _LabelledAction(() => label, action);
  _LabelledAction _n(String v) => _LabelledAction(() => v, () => _acc(v));
  _LabelledAction _noop() => _LabelledAction(() => '', () => {});

  Map<Mode, List<_LabelledAction>> _initMenus() => {
        Mode.Cmd: [
          _LabelledAction(() => S.current.GUI_CmdApparentWind, _apparentWind),
          _LabelledAction(() => S.current.GUI_CmdTrueWind, _trueWind),
          _LabelledAction(() => S.current.GUI_CmdAIS, _aisInfo),
          _LabelledAction(() => S.current.GUI_CmdPos, _pos),
          _LabelledAction(() => S.current.GUI_CmdUTC, _utc),
          _LabelledAction(() => S.current.GUI_CmdWaypoint, _waypoint),
          _LabelledAction(() => S.current.GUI_CmdHeading, _heading),
          _LabelledAction(() => S.current.GUI_CmdSpeed, _speed),
          _LabelledAction(() => S.current.GUI_CmdTrip, _trip),
          _LabelledAction(() => S.current.GUI_CmdSteer, _steerTo),
          _LabelledAction(() => S.current.GUI_CmdDepth, _depth,
              longPress: changeDepthReporting),
          _LabelledAction(() => S.current.GUI_CmdNumber, _number),
          _LabelledAction(_steerLeft, _port),
          _LabelledAction(() => S.current.GUI_CmdEnter, _optionsMode),
          _LabelledAction(_steerRight, _stbd),
        ],
        Mode.Num: [
          _n('1'),
          _n('2'),
          _n('3'),
          _n('4'),
          _n('5'),
          _n('6'),
          _n('7'),
          _n('8'),
          _n('9'),
          _n('-'),
          _n('0'),
          _n('+'),
          _n(S.current.GUI_NumReset),
          _n(S.current.GUI_NumSet),
          _n(S.current.GUI_NumCancel),
        ],
        Mode.Opt: [
          _LabelledAction(() => S.current.GUI_OptGuidance, _optGuidance),
          _LabelledAction(
              () => S.current.GUI_OptPitchDown, () => _setSpeechPitch(-0.1)),
          _LabelledAction(
              () => S.current.GUI_OptPitchUp, () => _setSpeechPitch(0.1)),
          _noop(),
          _LabelledAction(
              () => S.current.GUI_OptRateDown, () => _setSpeechRate(-0.1)),
          _LabelledAction(
              () => S.current.GUI_OptRateUp, () => _setSpeechRate(0.1)),
          _noop(),
          _LabelledAction(
              () => S.current.GUI_OptVolDown, () => _setSpeechVolume(-1)),
          _LabelledAction(
              () => S.current.GUI_OptVolUp, () => _setSpeechVolume(1)),
          _noop(),
          _LabelledAction(
              () => S.current.GUI_OptSensitivityDown, () => setSensitivity(-1)),
          _LabelledAction(
              () => S.current.GUI_OptSensitivityUp, () => setSensitivity(1)),
          _LabelledAction(() => S.current.GUI_OptDepth, _depthPreference),
          _LabelledAction(() => S.current.GUI_OptSave, _saveOptions),
          _noop()
        ],
        Mode.Steer: [
          _LabelledAction(() => S.current.GUI_SteerGuidance, _steerGuidance),
          _LabelledAction(() => S.current.GUI_SteerCompass,
              () => _steerUsing(Steer.Compass, OffCourse.Periodic)),
          _LabelledAction(() => S.current.GUI_SteerWind,
              () => _steerUsing(Steer.Wind, OffCourse.Periodic)),
          _noop(),
          _LabelledAction(() => S.current.GUI_SteerHintCompas,
              () => _steerUsing(Steer.Compass, OffCourse.Hint)),
          _LabelledAction(() => S.current.GUI_SteerHintWind,
              () => _steerUsing(Steer.Wind, OffCourse.Hint)),
          _noop(),
          _LabelledAction(() => S.current.GUI_SteerErrorCompas,
              () => _steerUsing(Steer.Compass, OffCourse.Error)),
          _LabelledAction(() => S.current.GUI_SteerErrorWind,
              () => _steerUsing(Steer.Wind, OffCourse.Error)),
          _noop(),
          _LabelledAction(() => S.current.GUI_SteerBeepCompas,
              () => _steerUsing(Steer.Compass, OffCourse.Beep)),
          _LabelledAction(() => S.current.GUI_SteerBeepWind,
              () => _steerUsing(Steer.Wind, OffCourse.Beep)),
          _noop(),
          _LabelledAction(() => S.current.GUI_SteerCmd, _toCommandMode),
          _LabelledAction(() => S.current.GUI_SteerSilence,
              () => _steerUsing(Steer.None, OffCourse.Off)),
        ],
      };

  void _optionsMode() {
    _spk.immediate(S.current.OptionsModePressOneForGuidance);
    _setMode(Mode.Opt);
  }

  void _toCommandMode() {
    _spk.immediate(S.current.CommandMode);
    setState(() => _mode = Mode.Cmd);
  }

  String _depthPref = 'DBS'; // set when initialised from prefs, if stored
  List<String> _depthPrefs = ['DBT', 'DBK', 'DBS'];

  void _depthPreference() {
    int d = _depthPrefs.indexOf(_depthPref) + 1;
    d %= _depthPrefs.length;
    _depthPref = _depthPrefs[d];

    String dw = '';
    switch (_depthPref) {
      case 'DBT':
        dw = S.current.Transducer;
        break;
      case 'DBK':
        dw = S.current.Keel;
        break;
      case 'DBS':
        dw = S.current.Surface;
        break;
    }
    _spk.immediate(dw);
    _prefs.setString(PREFS_DEPTH_PREFERENCE, _depthPref);

    _depth();
  }

  void _steerGuidance() => _spk.immediate(S.current.GuidanceSteer);

  String _steerLeft() {
    switch (_steer) {
      case Steer.Compass:
        return S.current.steerLeftPort;
      case Steer.Wind:
        switch (_busData.tack) {
          case 'Starboard':
            return S.current.steerLeftBear;
          case 'Port':
            return S.current.steerLeftLuff;
        }
        return '';
      default:
        return '';
    }
  }

  String _steerRight() {
    switch (_steer) {
      case Steer.Compass:
        return S.current.steerLeftStarboard;
      case Steer.Wind:
        switch (_busData.tack) {
          case 'Starboard':
            return S.current.steerLeftLuff;
          case 'Port':
            return S.current.steerLeftBear;
        }
        return '';
      default:
        return '';
    }
  }
}

class UserSettings extends StatefulWidget {
  UserSettings();

  @override
  State<StatefulWidget> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {
  @override
  Widget build(BuildContext context) {
    //KanivisApp.of(context)!.setLocale(Locale("en"));
    return Scaffold(
        appBar: AppBar(title: Text(S.current.GUI_SettingsLocalization)),
        body: Form(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                    padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                    color: Colors.white,
                    child: Center(
                        child: DropdownButton(
                      icon: Icon(Icons.language),
                      items: const [
                        DropdownMenuItem(
                          value: Locale('en'),
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: Locale('fr'),
                          child: Text("Français"),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        KanivisApp.of(context)!.setLocale(v as Locale);
                      }),
                      value: KanivisApp.of(context)!.getLocale(),
                    ))),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.of(context).pop(this);
                      },
                      child: Text(S.current.GUI_SettingsSave),
                    ),
                  ),
                )
              ]),
        ));
  }
}

class _CommsSettingsState extends State<CommsSettings> {
  String get host => _hc.text..trim();
  int get port => int.parse(_pc.text..trim());
  bool sensors;

  TextEditingController _hc;
  TextEditingController _pc;

  final _formKey = GlobalKey<FormState>();

  _CommsSettingsState(NMEASocketReader nmea, SharedPreferences prefs)
      : _hc = TextEditingController()..text = nmea.hostname,
        _pc = TextEditingController()..text = nmea.port.toString(),
        sensors = prefs.getBool(PREFS_DEVICE_SENSORS) ?? false;

  @override
  void dispose() {
    super.dispose();
    _hc.dispose();
    _pc.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? disabled = theme.textTheme.subtitle1?.copyWith(
      color: theme.disabledColor,
    );
    return Scaffold(
        appBar: AppBar(title: Text(S.current.GUI_SettingsNetwork)),
        body: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // CheckboxListTile(
                //   controlAffinity: ListTileControlAffinity.leading,
                //   value: sensors,
                //   // The change is recorded here, but processed (switching between readers)
                //   // in the calling function.
                //   onChanged: (v) async {
                //     if (v!) {
                //       PermissionStatus lwiu = await Permission.locationWhenInUse.request();
                //       if (lwiu != PermissionStatus.granted) {
                //         await openAppSettings();
                //       }
                //       v = await Permission.locationWhenInUse.request() == PermissionStatus.granted;
                //     }
                //     setState(() => sensors = v!);
                //   },
                //   title: Text("Use phone or tablet built-in sensors"),
                // ),

                Container(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: S.current.GUI_SettingsNMEANetworkSource,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              TextFormField(
                                enabled: !sensors,
                                style: sensors ? disabled : null,
                                controller: _hc,
                                decoration: InputDecoration(
                                    counterText: S.current.GUI_SettingsHostname,
                                    hintText:
                                        S.current.GUI_SettingsHostnameHint),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return S.current.GUI_SettingsHostnameError;
                                  }
                                  return null;
                                },
                              ),
                              TextFormField(
                                enabled: !sensors,
                                style: sensors ? disabled : null,
                                controller: _pc,
                                decoration: InputDecoration(
                                    counterText:
                                        S.current.GUI_SettingsPortNumber,
                                    hintText:
                                        S.current.GUI_SettingsPortNumberHint),
                                validator: (value) {
                                  try {
                                    if (value != null &&
                                        (int.tryParse(value) ?? 0) > 0) {
                                      return null;
                                    }
                                  } catch (err) {}
                                  return S.current.GUI_SettingsPortNumber;
                                },
                              )
                            ])),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(this),
                      child: Text(S.current.GUI_SettingsSave),
                    ),
                  ),
                )
              ]),
        ));
  }
}

class CommsSettings extends StatefulWidget {
  final NMEASocketReader _nmea;
  final SharedPreferences _prefs;
  CommsSettings(this._nmea, this._prefs);

  @override
  State<StatefulWidget> createState() => _CommsSettingsState(_nmea, _prefs);
}

class _LabelledAction {
  String Function() label;
  void Function() onPress;
  void Function()? longPress;

  _LabelledAction(this.label, this.onPress, {this.longPress});

  get w => Expanded(
      child: ElevatedButton(
          onPressed: onPress,
          onLongPress: longPress,
          child: Center(
              child: Text(label.call(),
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center))));
}
