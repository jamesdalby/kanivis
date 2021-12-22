import 'dart:async';
import 'dart:math';
// import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kanivis/offcourse.dart';
import 'package:kanivis/qspeak.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nmea/nmea.dart';

class KanivisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
        title: 'KANIVIS',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage()
    );
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
        v = 'north';
        break;
      case 'e':
        v = 'south';
        break;
      case 'w':
        v = 'west';
        break;
      case 's':
        v = 'south';
        break;
    }
    return "$deg degrees, ${_dp1(ms)} minutes $v";
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
  double? _depth;

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

  double? get depth => _depth;

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
      return "Unavailable";
    }
    if (_xte! < 0) {
      return (-_xte!).toStringAsFixed(2) + ", to port";
    }
    return _xte!.toStringAsFixed(2) + ", to starboard";
  }

  double? get vmw => _vmw;

  void handleNMEA(var msg) {
    // arriving message - exciting!
    // print(msg.toString());

    // Pos is a mixin, not exclusive:
    if (msg is Pos) {
      _lat = DMS.latitude(msg.lat);
      _lng = DMS.longitude(msg.lng);
    }

    if (msg is RMB) {
      // TODO: Cansider also using BWR, BWC for recording waypoint info?
      _btw = msg.bearingToDestination?.toInt();
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
      _cog = msg.cogTrue?.round();
      _sog = msg.sog;

    } else if (msg is DPT) {
      // TODO: The different depth should probably be option-switchable - keel/transducer/surface.
      // For now all set to depth below keel, and others ignored.
      if (msg.depthTransducer != null) {
        _depth = msg.depthTransducer;
      }

    } else if (msg is DBT) {
      // DBT m = msg;
      _depth = msg.metres; // transducer?

    } else if (msg is DBS) {
      // depth below surface - ignore?
      if (msg.depthSurface != null) {
        _depth = msg.depthSurface;
      }
    } else if (msg is DBK) {
      // depth below keel
      _depth = msg.depthKeel;

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
        _tack = msg.tack; // slightly dodgy, maybe? distinguish twa and awa tacks?  Not sure it matters that much.
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
      if (msg.crossTrackError != null) {
        _xte = msg.crossTrackError! * (msg.directionToSteer == 'L' ? 1 : -1);
      }

    } else {
      print('msg : ' + msg.runtimeType.toString());
    }
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
    return "Unavailable";
  }
  return num.toString().padLeft(3, '0').split('').join(' ');
}

/// Convert [num] to a decimal with 1 digit after the decimal point
String _dp1(double? num) {
  if (num == null) {
    return "Unavailable";
  }
  return num.toStringAsFixed(1);
}

/// Whether currently in command-entry mode or number-entry mode.
enum Mode { Num, Cmd, Opt, Steer }

/// During number entry, + or - switch into Relative (Neg, Pos) mode, otherwise Absolute
enum Rel { Neg, Abs, Pos }

/// Currently selected steering mode
enum Steer { Compass, Wind }

/// How off-course should be reported.
enum OffCourse { Periodic, Hint, Error, Beep }

class _MyHomePageState extends State<MyHomePage> {
  // initialise test-to-speech magic
  static QSpeak _spk = QSpeak();

  /// Update [_latReportedDepth] whenever the user has been told of the depth (not when it's sent on NMEA)
  double? _lastReportedDepth;

  /// incoming NMEA data stashed in here.
  BusData _busData = new BusData();

  late NMEASocketReader _nmea;

  /// current user-defined target course or target wind angle, used to detect deviation therefrom.
  int? _target;

  bool _depthReport = true;

  static double _pitch = 1;
  static double get pitch => _pitch;
  static set pitch(double v) => _pitch = limit(v, .5, 2.0);

  static double _volume = 1;
  static double get volume => _volume;
  static set volume(double v) => _volume = limit(v, 0.0, 1.0);

  static double _speechRate = 1;
  static double get speechRate => _speechRate;
  static set speechRate(double v) => _speechRate = limit(v, 0.1, 3.0);

  static late SharedPreferences _prefs;

  /// initialise text-to-speech stuff to default/sensible values
  static _initTTS() async {
    // await spk.setLanguage("en-US");
    // await spk.setVoice()

    // print(await spk.getVoices);

    speechRate = (_prefs.get('kanivis.speechRate') as double?)??1.0;
    await _spk.setSpeechRate(speechRate);

    volume = (_prefs.get('kanivis.volume') as double?)??1.0;
    await _spk.setVolume(volume);

    pitch = (_prefs.get('kanivis.pitch') as double?)??1.0;
    await _spk.setPitch(pitch);

    // todo: sort out interrupting.
    // we'll need to identify how to interrupt (and not interrupt) existing reporting.
    // spk.setCompletionHandler(() => print('Shh!') );

    _spk.immediate('Knowles Audible Navigation Information for Visually Impaired Sailors');

  }

  /// Speak the given text aloud
  // void _speak(String text, [bool noInteruption = false]) async {
  //   // TODO: uninterruptible TTS - depth (and beeps?)
  //   print(text);
  //   await spk.speak(text);
  // }

  static late AudioPlayer _audioPlayer;
  static late AudioCache _audioCache;

  static void _initBeep() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerError.listen((e) => print("Error $e"));

    // _audioPlayer.onPlayerStateChanged.listen((e) => print("State $e"));

    _audioCache = AudioCache(prefix: 'assets/beeps/', fixedPlayer: _audioPlayer);

    _audioCache.loadAll([
      'high-1.mp3',
      'low-1.mp3',
      'medium-1.mp3',
      'upchirp.mp3',
      'downchirp.mp3'
    ]);
  }

  /// overridden to ensure TTS is closed off
  /// TODO: also audio cache/player?
  @override
  void dispose() {
    super.dispose();
    _spk.stop();
  }

  /// current mode, command or number-entry, starts off in command mode.
  Mode _mode = Mode.Cmd;

  /// Whether tracking errors are measured against AWA or Compass
  Steer _steer = Steer.Wind;

  OffCourse? _offCourse;

  _MyHomePageState() {
    SharedPreferences.getInstance().then((p) {
      _prefs = p;

      _initTTS();
      _initBeep();
      _sensitivity = _prefs.getInt('kanivis.sensitivity') ?? 5;

      _nmea = new NMEASocketReader(
        _prefs.getString('kanivis.host')??'dealingtechnology.com',
        _prefs.getInt('kanivis.port')??10110
      );

      _nmea.process( _busData.handleNMEA);

      Timer.periodic(Duration(seconds: 1), (t) => _checkHdg());
    });
  }

  Timer? _offCourseTimer;
  int? _beepMs;
  int _sensitivity = 3;
  int? _err;

  void _offCourseBeep(int sign) {
    if (sign < 0) {
      _audioCache.play('low-1.mp3');
    } else {
      _audioCache.play('high-1.mp3');
    }
  }

  void _checkHdg() {
    if (_busData.depth != null && _busData.depth != 0) {
      if ((_lastReportedDepth ?? 0) != 0) {
        double ratio = _busData.depth! / _lastReportedDepth!.toDouble();
        if (ratio >= 1.1) {
          if (_depthReport) {
            _depth();
          }
          _lastReportedDepth = _busData.depth;
        } else if (ratio < 0.9) {
          if (_depthReport) {
            _depth();
          }
          _lastReportedDepth = _busData.depth;
        }
      } else {
        _lastReportedDepth = _busData.depth;
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
      if (_steer == Steer.Compass) {
        if (_busData.compass != null) {
          _err = _normalise(_busData.compass! - _target!);
        } else {
          _err = null;
        }
      } else {
        if (_busData.awa != null) {
          _err = _normalise(_busData.awa! - _target!); // prob dn't need normalise, but no harm
          if (_busData.tack == 'Starboard') { _err = -_err!; }
        } else {
          _err = null;
        }
      }
      _setBeepFreq();
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        appBar: AppBar(
          title: Text('KANIVIS'),
        ),
        drawer: Drawer(
            child: ListView(children: <Widget>[
              ListTile(
                  title: Text('Communications'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) =>
                                CommsSettings(_nmea))
                    ).then((var s) async {
                      print("$s ${s.host}:${s.port}");
                      _prefs.setString('kanivis.host', s.host);
                      _prefs.setInt('kanivis.port', s.port);
                      _nmea.hostname = s.host;
                      _nmea.port = s.port;
                    });
                  })
            ])),
        body:
            // 3x5 grid of buttons
            Container(
              constraints: BoxConstraints.expand(),
              color: Colors.redAccent,
              child: Column(
                
                children:
                    [
                      Expanded(
                        child: Row(
                          
                            children:[
                              _v('1', "App Wind", "Guidance", _apparentWind, 'Guidance'),
                              _v('2', "True Wind", "Pitch-", _trueWind, 'Heading'),
                              _v('3', "AIS", "Pitch+", _aisInfo, 'Angle'),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('4', "Pos", "", _pos, null),
                              _v('5', "UTC", "Speed-", _utc, 'Hint (C)'),
                              _v('6', "Waypoint", "Speed+",_waypoint, 'Hint (W)'),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('7', "Heading", "", _heading, null),
                              _v('8', "Speed", "Vol-", _speed, 'Error (C)'),
                              _v('9', "Trip", "Vol+", _trip, 'Error (W)'),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('*', "Steer", "", _steerTo, null),
                              _v('0', "Depth", "Sensitivity-", _depth, 'Beep (C)', longPress: changeDepthReporting),
                              _v('#', "Number", "Sensitivity+", _number, 'Beep (W)'),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('-', "Port 10", "", _port, null, wind: "Bear Away"),
                              _v('=', "Enter", "Cmd", _enter, 'Cmd'),
                              _v('+', "Stbd 10", "", _stbd, null, wind: "Luff Up"),

                            ]
                        ),
                      ),
                  ]
            )
            )
    );
  }

  void changeDepthReporting() {
    _depthReport = !_depthReport;
    _spk.immediate("Depth warnings are now " + (_depthReport ? 'enabled' : 'silenced'));
  }

  Widget _t(void longPress()?, Widget w) {
    if (longPress == null) {
      return w;
    }
    return GestureDetector(
        child: w,
        onLongPress: longPress
    );
  }

  Widget _v(String num, String label, String option, void op(), String? steerOption, { void longPress()?, String? wind }) =>
      Expanded(
        child: ElevatedButton(
                  onPressed: () async {
                    switch (_mode) {
                      case Mode.Cmd: op(); break;
                      case Mode.Num: _acc(num); break;
                      case Mode.Opt: _opt(num); break;
                      case Mode.Steer: _steerMode(num); break;
                    }
                  },
                  //padding: const EdgeInsets.all(2.0),
                  child: Center(
                      child: _t(longPress,
                          Text(
                              _mode == Mode.Cmd ? _wlabel(label,wind) :
                              _mode == Mode.Steer ? steerOption??'' :
                              _mode == Mode.Opt ? option :
                                                  num,
                              style: TextStyle(fontSize: 14),
                              textAlign: TextAlign.center
                          )
                      )
                  )
        ),
      );

  int? _tot = 0;
  Rel _rel = Rel.Abs;

  String _wlabel(final String label, final String? wind) {
    if (wind == null) return label;
    if (_steer == Steer.Wind) { return wind; }
    return label;
  }
  void _acc(String n) async {
    _spk.immediate(n);
    if (n.compareTo('0') >= 0 && n.compareTo('9') <= 0) {
      // it's a digit, accumulate it
      _tot = (_tot ?? 0) * 10 + int.parse(n);
      if (_tot! > 359 || _tot! < -359) {
        _spk.immediate("Invalid number, returning to command mode");
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);
      }
      return;
    }

    switch (n) {
      case '-':
        _spk.immediate('minus');
        if (_tot == null) {
          _rel = Rel.Neg;
        }
        break;

      case '+':
        _spk.immediate('plus');
        if (_tot == null) {
          _rel = Rel.Pos;
        }
        break;

      case '=':
        _enter();
        _spk.immediate('Command mode');
        break;

      case '#':
        _spk.immediate("Number entry cancelled, now in command mode");
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);

        break;
    }
  }

  void _apparentWind() {
    _spk.add(SpeakPriority.General, 'AWA', """
 A W A ${_hdg(_busData.awa)} ${_busData.tack ?? ''},
 A W S ${_dp1(_busData.aws)}
 """);
  }

  void _trueWind() {
    _spk.add(SpeakPriority.General, 'TWA', "T W A ${_hdg(_busData.twa)} ${_busData.tack ?? ''}, T W S ${_dp1(_busData.tws)}");
  }

  void _aisInfo() {
    _spk.immediate("A I S currently unimplemented, sorry");
  }

  void _pos() {
    // _speak("Lat $_lat.degrees $_lat.minutes $_lat.ns, $_lng.degrees $_lng.minutes $_lng.ew");
    DMS? la = _busData._lat;
    DMS? lo = _busData._lng;
    if (la == null || lo == null) {
      _spk.add(SpeakPriority.General, 'POS', "Position Unavailable");
      return;
    }

    _spk.add(SpeakPriority.General, 'POS', "Lat ${la.toString()}, Long ${lo.toString()}");
  }

  DateFormat _formatter = new DateFormat('H,mm,ss');

  void _utc() {
    _spk.add(SpeakPriority.General, 'UTC', "UTC " + _formatter.format(_busData.utc ?? DateTime.now()));
  }

  void _waypoint() {
    if ((_busData.wpt??'') == '') {
      _spk.add(SpeakPriority.General, 'WPT', "No active waypoint");
      return;
    }
    _spk.add(SpeakPriority.General, 'WPT',
        """
Waypoint ${_busData.wpt}
B T W ${_hdg(_busData.btw)}, 
D T W ${_dp1(_busData.dtw)},
X T E ${_busData.xte}, 
V M W ${_dp1(_busData.vmw)}""");
  }

  void _heading() {
    String st = "";
    if (_target != null) {
      if (_steer == Steer.Compass) {
        st = "Target compass course ${_hdg(_target)}";
      } else if (_steer == Steer.Wind) {
        st = "Target wind angle ${_hdg(_target)}";
      }
    }
    _spk.add(SpeakPriority.General, 'HDG', """
Compass ${_hdg(_busData.compass)},
C O G ${_hdg(_busData.cog)}, 
A W A ${_hdg(_busData.awa)}
$st""");
  }

  void _speed() {
    _spk.add(SpeakPriority.General, 'SPD',
        "Speed ${_dp1(_busData.bsp)}, S O G ${_dp1(
            _busData.sog)}, V M G ${_dp1(_busData.vmg)}");
  }

  void _trip() {
    _spk.add(SpeakPriority.General, 'TRP',
        "Trip ${_dp1(_busData.trip)}, G P S trip ${_dp1(_busData.gpsTrip)}");
  }

  void _steerTo() {
    setState(() {
      _mode = Mode.Steer;
    });
    _spk.immediate('Steer mode. Press 1 for guidance');
    /*switch (_steer) {
      case Steer.Compass:
        setState(() {
          _steer = Steer.Wind;
        });

        _target = _busData._awa;
        if (_target == null) {
          _speak("No A W A is available, please set a target angle");
          break;
        }
        _speak("Now steering to apparent wind ${_hdg(_target)}");
        break;


      case Steer.Wind:
        setState(() {
          _steer = Steer.Compass;
        });
        _target = _busData._compass;
        if (_target == null) {
          _speak(
              "No compass course is available, please set a target course");
          break;
        }
        _speak("Now steering to compass ${_hdg(_target)}");
        break;
    }*/
  }

  void _depth() {
    _lastReportedDepth = _busData.depth;
    _spk.add(SpeakPriority.General, 'DPT', "Depth ${_dp1(_lastReportedDepth)}");
  }

  void _setMode(Mode m) {
    setState(() => _mode = m);
  }

  void _number() {
    _spk.immediate("Number mode");
    _setMode(Mode.Num);
  }

  void _alter(int num, String wind, String compass) {
    if (_target == null) {
      _spk.immediate("No course set currently");
      return;
    }
    switch (_steer) {
      case Steer.Wind:
        _target = (_target! - num);
        if (_target! < 0) {
          _target = 180 - _target!;
        } else if (_target! > 180) {
          _target = _target! - 180;
        }
        _spk.add(SpeakPriority.General, 'TGT', "Target angle now ${_target.toString()}");
        break;

      case Steer.Compass:
        _target = (_target! + num) % 360;
        _spk.add(SpeakPriority.General, 'TGT', "Target course now ${_hdg(_target)}");
        break;
    }
  }

  void _port() {
    _alter(-10, "Bear away ten degrees", "Ten degrees to port");
  }

  void _stbd() {
    _alter(10, "Luff up 10 degrees", "10 degrees to starboard");
  }

  /// In number mode, change course either relative or absolute
  /// In command mode, switch into option handling (not yet implemented)
  void _enter() {
    switch (_mode) {
      case Mode.Num:
      if (_tot == null) {
        _spk.immediate("No number was entered");
      } else {
        switch (_rel) {
          case Rel.Neg:
            _target = (_target??0 - _tot!) % 360; // XXX: check ??0 is sensible, also below
            break;

          case Rel.Abs:
            _target = _tot! % 360;
            break;

          case Rel.Pos:
            _target = (_target??0 + _tot!) % 360;
            break;
        }
        if (_steer == Steer.Compass) {
          _spk.add(SpeakPriority.General, 'TGT', "Target course ${_hdg(_target)}");
        } else {
          _spk.add(SpeakPriority.General, 'TGT', "Target wind angle ${_hdg(_target)}");
        }
      }
      _tot = null;
      _setMode(Mode.Cmd);
      _rel = Rel.Abs;
      break;

      case Mode.Cmd:
        // switch to options mode:
        _spk.immediate("Options mode. Press 1 for guidance. Press 'Enter' to return to command mode");
        _setMode(Mode.Opt);
        break;

      case Mode.Opt:
        // return to command mode:
        // This isn't actually called,it's handled in _opt below
        _spk.immediate("Now in command mode");
        _setMode(Mode.Cmd);
        break;

      case Mode.Steer:
        // Similarly not called, handled in steerOptions
        break;
    }
  }

  void _opt(String num) async {
    switch (num) {
      case "1": // help
        _spk.immediate("""
        2 decrease pitch, 3 increase pitch.
        5 decrease speed, 6 increase speed.
        8 decrease volume, 9 increase volume.
        0 decrease off-course sensitivity, # increase off-course sensitivity.
        Enter, returns to command mode""");
        break;
      case "3": // pitch up
        pitch += 0.1;
        _spk.setPitch(pitch.toDouble());
        _spk.add(SpeakPriority.Application, 'PITCH', "pitch ${pitch.toStringAsFixed(1)}");
        break;
      case "2": // pitch down
        pitch -= 0.1;
        _spk.setPitch(pitch);
        _spk.add(SpeakPriority.Application, 'PITCH', "pitch ${pitch.toStringAsFixed(1)}");
        break;
      case "6": // speed up
        speechRate += 0.1;
        _spk.setSpeechRate(speechRate);
        _spk.add(SpeakPriority.Application, 'RATE', "rate ${speechRate.toStringAsFixed(1)}");
        break;
      case "5": // speed down
        speechRate -= 0.1;
        _spk.setSpeechRate(speechRate);
        _spk.add(SpeakPriority.Application, 'RATE', "rate ${speechRate.toStringAsFixed(1)}");
        break;
      case "9": // volume up
        volume += 0.1;
        _spk.setVolume(volume);
        _spk.add(SpeakPriority.Application, 'VOL', "volume ${volume.toStringAsFixed(1)}");
        break;
      case "8": // volume down
        volume -= 0.1;
        _spk.setVolume(volume);
        _spk.add(SpeakPriority.Application, 'VOL', "volume ${volume.toStringAsFixed(1)}");
        break;
      case "0": // sensitivity down
        _sensitivity = limit(--_sensitivity, 1, 9).toInt();
        _spk.add(SpeakPriority.Application, 'SENS', "sensitivity $_sensitivity");
        _setBeepFreq();
        break;

      case "#":
        _sensitivity = limit(++_sensitivity, 1, 9);
        _spk.add(SpeakPriority.Application, 'SENS', "sensitivity $_sensitivity");
        _setBeepFreq();
        break;

      case '=':
        await _prefs.setDouble('kanivis.speechRate', _speechRate);
        await _prefs.setDouble('kanivis.volume', _volume);
        await _prefs.setDouble('kanivis.pitch', _pitch);
        await _prefs.setInt('kanivis.seneitivity', _sensitivity);
        _spk.immediate("Command mode");
        _setMode(Mode.Cmd);
        break;
    }
  }

  void _setBeepFreq() {

    switch (_offCourse) {
      case null: return;
      case OffCourse.Error:
      case OffCourse.Hint:

        _beepMs = min(10000, max(1000 * (10 - _sensitivity - (_err??0).abs()~/5), 1000));
        // _beepMs = 1000 + 9000 ~/ max(_sensitivity + (_err??0).abs()~/5, 9);
        break;

      case OffCourse.Periodic:
        _beepMs = 1000 * (10 - _sensitivity);
        break;

      case OffCourse.Beep:
        if (_err != null) {
          double o = offcourse(_err!.abs().toDouble(), 10.0-_sensitivity, 30, 0.5, 5, _sensitivity);
          if (o != 0) {
            _beepMs = 1000~/o;
          } else {
            _beepMs = 10000;
          }
          print("beep err: $_err sens: $_sensitivity ms: $_beepMs");
        }
        break;
    }

    if (_beepMs != 0 && _offCourseTimer == null) {
      _offCourseTimer = Timer(Duration(milliseconds: _beepMs!), _speakOffCourse);
    }
  }

  static T limit<T extends num>(T v, T lo, T hi) {
    if (v<=lo) { return lo; }
    if (v>=hi) { return hi; }
    return v;
  }

  int _normalise(int i) {
    if (i >= 180) return i-360;
    if (i < -180) return i+360;
    return i;
  }

  void _steerMode(String num) {
    switch (num) {
      case '1': // guidance
        _spk.immediate('''
2, to steer to compass with periodic heading announcment.
3, wind steer with periodic angle announcement.

5, compass steer with magnitude-dependent announcement frequency.
6, wind steer with magnitude-dependent announcement frequency.

8, compass steer with off-course report.
9, wind steer with off-wind report.

0, compass steer with beeps
#, wind steer with beeps

Change sensitivity in options mode to control frequency of reporting, and error thresholds.

Enter, return to command mode
        ''');
        break;

      case '2': // hdg (C)
         _steerUsing(Steer.Compass, OffCourse.Periodic);
        break;

      case '3': // hdg (W)
        _steerUsing(Steer.Wind, OffCourse.Periodic);
        break;

      case '5': // hint (C)
        _steerUsing(Steer.Compass, OffCourse.Hint);
        break;
      case '6': // hint (W)
        _steerUsing(Steer.Wind, OffCourse.Hint);
        break;

      case '8': // error (c)
        _steerUsing(Steer.Compass, OffCourse.Error);
        break;
      case '9': // error (w)
        _steerUsing(Steer.Wind, OffCourse.Error);
        break;

      case '0': // beep (c)
        _steerUsing(Steer.Compass, OffCourse.Beep);
        break;
      case '#': // beep (w)
        _steerUsing(Steer.Wind, OffCourse.Beep);
        break;

      case '=': // command mode
        setState(() {
          _mode = Mode.Cmd;
        });
        _spk.immediate('Command mode');
        break;

      default: break;
    }
  }

  void _steerUsing(Steer steer, OffCourse offCourse) {
    _steer = steer;
    _offCourse = offCourse;

    // if (_target == null) {
      if (steer == Steer.Compass) {
        _target = _busData.compass;
        if (_target == null) {
          _spk.add(SpeakPriority.General, 'TGT', 'No compass course available, maybe set it manually using number mode');
          return;
        }
      } else {
        _target = _busData.awa;
        if (_target == null) {
          _spk.add(SpeakPriority.General, 'TGT', 'No wind angle available, maybe set it manually using number mode');
          return;
        }
      }
    // }
    if (_steer == Steer.Compass) {
      _spk.add(SpeakPriority.General, 'TGT', "Now steering to compass ${_hdg(_target)}");
    } else {
      _spk.add(SpeakPriority.General, 'TGT', "Now steering to apparent wind ${_hdg(_target)}");
    }
    // reset beep timer; this will set the beep delay, and also crate a one-shot timer that calls _speakOffCourse if need be
    _setBeepFreq();
  }

  // This does the clever off course stuff, in conjunction with the [_setBeepFreq] method.
  void _speakOffCourse() {
    if (_offCourse == null) { return; } // odd, how did we get invoked?

    switch (_offCourse!) {
      case OffCourse.Beep:
        // beep with increasing rapidity as we go further off course, sign indicates high beep or low beep tone.
        _offCourseBeep(_err?.sign??0);
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
            _spk.add(SpeakPriority.General, 'TGT', _hdg(_busData.awa) + ' ' + (_busData.tack??''));
            break;
        }
        break;

      case OffCourse.Error:
        switch (_steer) {
          case Steer.Compass:
          case Steer.Wind:
            if (_err == 0) {
              _spk.add(SpeakPriority.General, 'TGT', "On course");
            } else {
              // error interpretation : you are too far to ...
              _spk.add(SpeakPriority.General, 'TGT', _err!.abs().toStringAsFixed(0) + (_err! < 0 ? " Port" : " Starboard"));
            }
           break;
        }
        break;
    }
    // and reset the timer:
    _offCourseTimer = Timer(Duration(milliseconds: _beepMs!), _speakOffCourse);
  }
}

class _CommsSettingsState extends State<CommsSettings> {
  String get host => _hc.text..trim();

  int get port => int.parse(_pc.text..trim());

  TextEditingController _hc = TextEditingController();
  TextEditingController _pc = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    _hc.text = widget._nmea.hostname;
    _pc.text = widget._nmea.port.toString();
    return Scaffold(
        appBar: AppBar(title: Text('Settings')),
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _hc,
                decoration: InputDecoration(
                    counterText: 'Hostname or IP address',
                    hintText: 'Hostname'),
                validator: (value) {
                  if (value?.isEmpty??true) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _pc,
                decoration: InputDecoration(
                    counterText: 'Port number',
                    hintText: 'Port number'),
                validator: (value) {
                  try {
                    if (value != null && (int.tryParse(value)??0) > 0) {
                      return null;
                    }
                  } catch (err) {}
                  return 'Please enter positive number';
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() == true) {
                      Navigator.of(context).pop(this);
                    }
                  },
                  child: Text('Submit'),
                ),
              ),
            ],
          ),
        ));
  }
}

class CommsSettings extends StatefulWidget {
  final NMEASocketReader _nmea;
  CommsSettings(this._nmea);

  @override State<StatefulWidget> createState() => _CommsSettingsState();
}
