import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:kanivis/offcourse.dart';
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

  static DMS latitude(double lat) {
    String ns = 'n';
    if (lat < 0) {
      lat = -lat;
      ns = 'S';
    }
    int deg = lat.truncate();
    double min = (lat - deg) * 60;

    return DMS(deg, min, ns);
  }

  static DMS longitude(double lng) {
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
  int _awa, _twa;
  String _tack;
  double _aws, _tws;
  // double _twd; // true wind direction - use to compute twa?
  DMS _lat, _lng;
  DateTime _utc;
  int _btw;
  double _dtw, _xte, _vmw;
  String _wpt;

  // int _heading;
  int _cog;
  int _compass;
  double _bsp, _sog, _vmg;
  double _trip, _gpsTrip;
  double _depth;

  int get btw => _btw;

  int get awa => _awa;

  String get tack => _tack;

  int get twa => _twa;

  double get aws => _aws;

  double get tws => _tws;

  int get latDeg => _lat.deg;

  double get latMS => _lat.ms;

  int get lngDeg => _lng.deg;

  double get lngMS => _lng.ms;

  double get depth => _depth;

  DateTime get utc => _utc;

  double get dtw => _dtw;

  int get cog => _cog;

  // int get heading => _heading;

  int get compass => _compass;

  double get bsp => _bsp;

  double get sog => _sog;

  double get vmg => _vmg;

  double get trip => _trip;

  double get gpsTrip => _gpsTrip;

  String get wpt => _wpt ?? 'not set';

  // Cross track error as a string suitable for speaking using TTS
  String get xte {
    if (_xte == null) {
      return "Unavailable";
    }
    if (_xte < 0) {
      return (-_xte).toStringAsFixed(2) + ", to port";
    }
    return _xte.toStringAsFixed(2) + ", to starboard";
  }

  double get vmw => _vmw;

  void handleNMEA(var msg) {
    // arriving message - exciting!
    // print(msg.toString());

    // Pos is a mixin, not exclusive:
    if (msg is Pos) {
      _lat = DMS.latitude(msg.lat);
      _lng = DMS.longitude(msg.lng);
    }

    if (msg is RMB) {
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
      if (msg.depthKeel != null) {
        _depth = msg.depthKeel;
      }

    } else if (msg is DBT) {
      // DBT m = msg;
      // _depth = m.metres; // transducer?

    } else if (msg is DBS) {
      // depth below surface - ignore?

    } else if (msg is DBK) {
      // depth below keel
      _depth = msg.depthKeel;

    } else if (msg is HDG) {
      _compass = msg.heading.toInt();
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
        _xte = msg.crossTrackError * (msg.directionToSteer == 'L' ? 1 : -1);
      }

    } else {
      print('msg : ' + msg.runtimeType.toString());
    }
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

/// Convert [num] to a three digit (zero padded) number suitable for passing to TTS
String _hdg(int num) {
  if (num == null) {
    return "Unavailable";
  }
  return num.toString().padLeft(3, '0').split('').join(' ');
}

/// Convert [num] to a decimal with 1 digit after the decimal point
String _dp1(double num) {
  if (num == null) {
    return "Unavailable";
  }
  return num.toStringAsFixed(1);
}

/// Whether currently in command-entry mode or number-entry mode.
enum Mode { Num, Cmd, Opt }

/// During number entry, + or - switch into Relative (Neg, Pos) mode, otherwise Absolute
enum Rel { Neg, Abs, Pos }

/// Currently selected steering mode
enum Steer { Compass, Wind }

class _MyHomePageState extends State<MyHomePage> {
  // initialise test-to-speech magic
  static FlutterTts spk = FlutterTts();

  /// Update [_latReportedDepth] whenever the user has been told of the depth (not when it's sent on NMEA)
  double _lastReportedDepth;

  /// incoming NMEA data stashed in here.
  BusData _busData = new BusData();

  NMEASocketReader _nmea;

  /// current user-defined target course or target wind angle, used to detect deviation therefrom.
  int _target;

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

  static SharedPreferences _prefs;

  /// initialise text-to-speech stuff to default/sensible values
  static _initTTS() async {
    // await spk.setLanguage("en-US");
    // await spk.setVoice()

    print(await spk.getVoices);

    speechRate = _prefs.get('kanivis.speechRate')??1.0;
    await spk.setSpeechRate(speechRate);

    volume = _prefs.get('kanivis.volume')??1.0;
    await spk.setVolume(volume);

    pitch = _prefs.get('kanivis.pitch')??1.0;
    await spk.setPitch(pitch);

    spk.speak('Knowles Audible Navigation Information for Visually Impaired Sailors');
  }

  /// Speak the given text aloud
  void _speak(String text, [bool noInteruption = false]) async {
    // TODO: uninterruptible TTS - depth (and beeps?)
    print(text);
    await spk.speak(text);
  }

  static AudioPlayer _audioPlayer;
  static AudioCache _audioCache;

  static void _initBeep() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerError.listen((e) => print("Error $e"));

    // _audioPlayer.onPlayerStateChanged.listen((e) => print("State $e"));

    _audioCache = AudioCache(prefix: 'beeps/', fixedPlayer: _audioPlayer);

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
    spk.stop();
  }

  /// current mode, command or number-entry, starts off in command mode.
  Mode _mode = Mode.Cmd;

  /// Whether tracking errors are measured against AWA or Compass
  Steer _steer = Steer.Wind;

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

      Timer.periodic(Duration(seconds: 1), (t) => _checkHdg(t));
    });
  }

  Timer _offCourseTimer;
  double _beepFreq;
  int _sensitivity = 3;
  int _err;

  void _offCourseBeep(int sign) {
    if (sign < 0) {
      _audioCache.play('low-1.mp3');
    } else {
      _audioCache.play('high-1.mp3');
    }
  }

  // This method is invoked when beping is needed
  // the (singleton) _offCourseTimer is set to the one-shot timer,
  // when the timer fires, it beeps and then sets a new timer to run with the possibly changed) _beepFreq
  // if _BeepFreq is zero, nothing is reset (normally this won't happen, the timer will be cancelled elsewhere, but this bolsters up for a tiny race condition.)
  void _trun() {
    if (_beepFreq == 0) { return; }
    _offCourseTimer = Timer(
        Duration(milliseconds: 1000 ~/ _beepFreq),
            () {
          _offCourseBeep(_err.sign);
          _trun();
        });
  }

  void _checkHdg(Timer t) {
    if (_busData.depth != null && _busData.depth != 0) {
      if (_lastReportedDepth != null) {
        double ratio = _busData.depth / _lastReportedDepth;
        if (ratio >= 1.1) {
          if (_depthReport) {
            _audioCache.play('upchirp.mp3');
          }
          _lastReportedDepth = _busData.depth;
        } else if (ratio < 0.9) {
          if (_depthReport) {
            _audioCache.play('downchirp.mp3');
          }
          _lastReportedDepth = _busData.depth;
        }
      } else {
        _lastReportedDepth = _busData.depth;
      }
    }

    if (_target != null) {

      // -180 <= _err < 180
      // if _err > 0 then we should steer right
      // if _err > 0 then we should steer left
      // if _err is null then either compass or wind angle isn't available.
      // When steering to wind, the tack is relevant
      //
      if (_steer == Steer.Compass) {
        if (_busData.compass != null) {
          _err = _normalise(_busData.compass - _target);
        } else {
          _err = null;
        }
      } else {
        if (_busData.awa != null) {
          _err = _normalise(_busData.awa - _target);
          if (_busData.tack == 'S') { _err = -_err; }
        } else {
          _err = null;
        }
      }
    }
    if (_err == null) {
      if (_offCourseTimer != null) {
        _offCourseTimer.cancel();
        _offCourseTimer = null;
      }
    } else {
        _beepFreq = offcourse(_err.toDouble().abs(), 10, 30, 0.5, 5, _sensitivity);

      if (_beepFreq != 0) {
        // We need to beep:
        if (_offCourseTimer == null) {
          // create a new timer if it's needed, this will assign the Timer to _offCourseTimer
          _trun();
        }
        // the timer will reference '_beepFreq' to decide how often to beep
        // so the act of changing it is enough (when the timer is already running)
      } else {
        // No beeping
        if (_offCourseTimer != null) {
          // cancel any existing timer - stops all beeps.
          _offCourseTimer.cancel();
          _offCourseTimer = null;
        }
      }
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
                              _v('1', "App Wind", "Guidance", _apparentWind),
                              _v('2', "True Wind", "Pitch-", _trueWind),
                              _v('3', "AIS", "Pitch+", _aisInfo),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('4', "Pos", "", _pos),
                              _v('5', "UTC", "Speed-", _utc),
                              _v('6', "Waypoint", "Speed+",_waypoint),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('7', "Heading", "", _heading),
                              _v('8', "Speed", "Vol-", _speed),
                              _v('9', "Trip", "Vol+", _trip),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('*', "Steer", "", _steerTo),
                              _v('0', "Depth", "Sensitivity-", _depth, longPress: changeDepthReporting),
                              _v('#', "Number", "Sensitivity+", _number),

                            ]
                        ),
                      ),
                      Expanded(
                        child: Row(
                            children:[
                              _v('-', "Port", "", _port, wind: "Bear Away"),
                              _v('=', "Enter", "Cmd", _enter),
                              _v('+', "Stbd", "", _stbd, wind: "Luff"),

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
    _speak(
        "Depth warnings are now " + (_depthReport ? 'enabled' : 'silenced'));
  }

  Widget _t(void longPress(), Widget w) {
    if (longPress == null) {
      return w;
    }
    return GestureDetector(
        child: w,
        onLongPress: longPress
    );
  }

  Widget _v(String num, String label, String option, void op(), { void longPress(), String wind }) =>
      Expanded(
        child: RaisedButton(
                  onPressed: () async {
                    switch (_mode) {
                      case Mode.Cmd: op(); break;
                      case Mode.Num: _acc(num); break;
                      case Mode.Opt: _opt(num); break;
                    }
                  },
                  //padding: const EdgeInsets.all(2.0),
                  child: Center(
                      child: _t(longPress,
                          Text(
                              _mode == Mode.Cmd ? _wlabel(label,wind) :
                              _mode == Mode.Opt ? option :
                                                  num,
                              style: TextStyle(fontSize: 20)
                          )
                      )
                  )
        ),
      );

  int _tot;
  Rel _rel = Rel.Abs;

  String _wlabel(final String label, final String wind) {
    if (wind == null) return label;
    if (_steer == Steer.Wind) { return wind; }
    return label;
  }
  void _acc(String n) async {
    await spk.speak(n);
    if (n.compareTo('0') >= 0 && n.compareTo('9') <= 0) {
      // it's a digit, accumulate it
      _tot = (_tot ?? 0) * 10 + int.parse(n);
      if (_tot > 359 || _tot < -359) {
        _speak("Invalid number, returning to command mode");
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);
      }
      return;
    }

    switch (n) {
      case '-':
        if (_tot == null) {
          _rel = Rel.Neg;
        }
        break;

      case '+':
        if (_tot == null) {
          _rel = Rel.Pos;
        }
        break;

      case '=':
        _enter();
        spk.speak('Command mode');
        break;

      case '#':
        spk.speak("Number entry cancelled, now in command mode");
        _rel = Rel.Abs;
        _tot = null;
        _setMode(Mode.Cmd);

        break;
    }
  }

  void _apparentWind() {
    _speak("""
 A W A ${_hdg(_busData.awa)} ${_busData.tack ?? ''},
 A W S ${_dp1(_busData.aws)}
 """);
  }

  void _trueWind() {
    _speak("T W A ${_hdg(_busData.twa)} ${_busData.tack ?? ''}, T W S ${_dp1(_busData.tws)}");
  }

  void _aisInfo() {
    _speak("A I S currently unimplemented, sorry");
  }

  void _pos() {
    // _speak("Lat $_lat.degrees $_lat.minutes $_lat.ns, $_lng.degrees $_lng.minutes $_lng.ew");
    DMS la = _busData._lat;
    DMS lo = _busData._lng;
    if (la == null || lo == null) {
      _speak("Position Unavailable");
      return;
    }

    _speak("Lat ${la.toString()}, Long ${lo.toString()}");
  }

  DateFormat _formatter = new DateFormat('H,mm,ss');

  void _utc() {
    _speak("UTC " + _formatter.format(_busData?.utc ?? DateTime.now()));
  }

  void _waypoint() {
    _speak(
        """
Waypoint ${_busData.wpt}
B T W ${_hdg(_busData.btw)}, 
D T W ${_dp1(_busData.dtw)},
X T E ${_busData.xte}, 
V M W ${_dp1(_busData.vmw)}""");
  }

  void _heading() {
    // TODO Target awa, target compass
    //Heading ${_hdg(_busData.heading)},
    String st = "";
    if (_target != null) {
      if (_steer == Steer.Compass) {
        st = "Target compass course ${_hdg(_target)}";
      } else if (_steer == Steer.Wind) {
        st = "Target wind angle ${_hdg(_target)}";
      }
    }
    _speak("""
Compass ${_hdg(_busData.compass)},
C O G ${_hdg(_busData.cog)}, 
A W A ${_hdg(_busData.awa)}
$st""");
  }

  void _speed() {
    _speak(
        "Speed ${_dp1(_busData.bsp)}, S O G ${_dp1(
            _busData.sog)}, V M G ${_dp1(_busData.vmg)}");
  }

  void _trip() {
    _speak(
        "Trip ${_dp1(_busData.trip)}, G P S trip ${_dp1(_busData.gpsTrip)}");
  }

  void _steerTo() {
    switch (_steer) {
      case Steer.Compass:
        _steer = Steer.Wind;
        _target = _busData._awa;
        if (_target == null) {
          _speak("No A W A is available, please set a target angle");
          break;
        }
        _speak("Now steering to apparent wind ${_hdg(_target)}");
        break;


      case Steer.Wind:
        _steer = Steer.Compass;
        _target = _busData._compass;
        if (_target == null) {
          _speak(
              "No compass course is available, please set a target course");
          break;
        }
        _speak("Now steering to compass ${_hdg(_target)}");
        break;
    }
  }

  void _depth() {
    _lastReportedDepth = _busData.depth;
    _speak("Depth ${_dp1(_lastReportedDepth)}");
  }

  void _setMode(Mode m) {
    setState(() => _mode = m);
  }

  void _number() {
    _speak("Number mode");
    _setMode(Mode.Num);
  }

  void _alter(int num, String wind, String compass) {
    if (_target == null) {
      _speak("No course set currently");
      return;
    }
    // XXX: This is wrong (for wind) need to work out whether on port or stbd currently.
    switch (_steer) {
      case Steer.Wind:
        _target = (_target + num);
        if (_target < 0) {
          _target = 180 - _target;
        } else if (_target > 180) {
          _target = _target - 180;
        }
        _speak(wind);
        break;

      case Steer.Compass:
        _target = (_target + num) % 360;
        _speak(compass);
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
        _speak("No number was entered");
      } else {
        switch (_rel) {
          case Rel.Neg:
            _target = (_target - _tot) % 360;
            break;

          case Rel.Abs:
            _target = _tot % 360;
            break;

          case Rel.Pos:
            _target = (_target + _tot) % 360;
            break;
        }
        if (_steer == Steer.Compass) {
          _speak("Target course ${_hdg(_target)}");
        } else {
          _speak("Target wind angle ${_hdg(_target)}");
        }
      }
      _tot = null;
      _setMode(Mode.Cmd);
      _rel = Rel.Abs;
      break;

      case Mode.Cmd:
        // switch to options mode:
        _speak("Options mode. Press 1 for guidance. Press 'Enter' to return to command mode");
        _setMode(Mode.Opt);
        break;

      case Mode.Opt:
        // return to command mode:
        // This isn't actually called,it's handled in _opt below
        _speak("Now in command mode");
        _setMode(Mode.Cmd);
        break;
    }
  }

  void _opt(String num) async {
    switch (num) {
      case "1": // help
        _speak("""
        2 decrease pitch, 3 increase pitch.
        5 decrease speed, 6 increase speed.
        8 decrease volume, 9 increase volume.
        0 decrease off-course sensitivity, # increase off-course sensitivity.
        Enter, returns to command mode""");
        break;
      case "3": // pitch up
        pitch += 0.1;
        spk.setPitch(pitch);
        _speak("pitch ${pitch.toStringAsFixed(1)}");
        break;
      case "2": // pitch down
        pitch -= 0.1;
        spk.setPitch(pitch);
        _speak("pitch ${pitch.toStringAsFixed(1)}");
        break;
      case "6": // speed up
        speechRate += 0.1;
        spk.setSpeechRate(speechRate);
        _speak("rate ${speechRate.toStringAsFixed(1)}");
        break;
      case "5": // speed down
        speechRate -= 0.1;
        spk.setSpeechRate(speechRate);
        _speak("rate ${speechRate.toStringAsFixed(1)}");
        break;
      case "9": // volume up
        volume += 0.1;
        spk.setVolume(volume);
        _speak("volume ${volume.toStringAsFixed(1)}");
        break;
      case "8": // volume down
        volume -= 0.1;
        spk.setVolume(volume);
        _speak("volume ${volume.toStringAsFixed(1)}");
        break;
      case "0": // sensitivity down
        _sensitivity = limit(--_sensitivity, 1, 9);
        _speak("sensitivity $_sensitivity");
        break;
      case "#":
        _sensitivity = limit(++_sensitivity, 1, 9);
        _speak("sensitivity $_sensitivity");
        break;
      case '=':
        await _prefs.setDouble('kanivis.speechRate', _speechRate);
        await _prefs.setDouble('kanivis.volume', _volume);
        await _prefs.setDouble('kanivis.pitch', _pitch);
        await _prefs.setInt('kanivis.seneitivity', _sensitivity);
        _speak("Command mode");
        _setMode(Mode.Cmd);
        break;
    }
  }

  static num limit(num v, num lo, num hi) {
    if (v<=lo) { return lo; }
    if (v>=hi) { return hi; }
    return v;
  }

  int _normalise(int i) {
    if (i >= 180) return i-360;
    if (i < -180) return i+360;
    return i;
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
    _hc.text = widget._nmea.hostname ?? 'localhost';
    _pc.text = (widget._nmea.port??10110).toString();
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
                  if (value.isEmpty) {
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
                    if (int.parse(value) > 0) {
                      return null;
                    }
                  } catch (err) {}
                  return 'Please enter positive number';
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: RaisedButton(
                  onPressed: () {
                    if (_formKey.currentState.validate() == true) {
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
