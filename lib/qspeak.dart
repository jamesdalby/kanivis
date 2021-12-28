import 'package:collection/collection.dart';
import 'package:flutter_tts/flutter_tts.dart';

/**
 * Priority queue of items to dispatch
 *
 */
class QSpeak {
  static FlutterTts _spk = FlutterTts();
  static PriorityQueue<_SpeakItem> q = PriorityQueue(); // q of items, priority order.  Depth beats everything, for instance.
  static Map<String, String> t = {};  // Message per target; multiple messages of same target type: only last is retained.
  static List<String> _immediate = []; // List of messages, in order, that should be emitted asap, before anything else.

  static final QSpeak _singleton = QSpeak._internal();

  factory QSpeak() => _singleton;

  QSpeak._internal() {
    _spk.completionHandler = _onComplete;
    _spk.startHandler = _onStart;
  }

  add(SpeakPriority pri, String key, String message) {
    print(key + ': '+ message);
    t.update(key, (value) => message, ifAbsent: () {
      q.add(_SpeakItem(pri, key));
      return message;
    });
    if (!_active) {
      _onComplete();
    }
  }

  /**
   * Remove the next item in the priority queue and return its message.
   */
  String? _next() {
    if (_immediate.isNotEmpty) {
      final String ret = _immediate.first;
      _immediate = _immediate.sublist(1);
      return ret;
    }
    if (q.isEmpty) return null;
    return t.remove(q.removeFirst()._key);
  }

  bool _active = false;  // state, maintained by onStart/onComplete, indicates whether speech is active.

  void _onComplete() {
    String? n = _next();
    if (n != null) {
      print('speak: '+n);
      _active = true; // this doubles up on what happens in _onStart, but that's OK, since if there's a delay initiating the _spk.speak, there is a race that can cause lost messages
      _spk.speak(n);
    } else {
      _active = false;
    }
  }

  void _onStart() {
    _active = true; // see above, not strictly needed, but no harm done.
  }


  void immediate(String s) {
    // a message to be sent, in order, as soon as the current message is finished.
    _immediate.add(s);
    if (!_active) {
      _onComplete();
    }
  }

  // delegates:

  // speechRate 1.0 is standard, 2.0 is double speed, etc
  setSpeechRate(double speechRate) => _spk.setSpeechRate(speechRate);

  // volume: range 1 .. 10
  setVolume(int volume) => _spk.setVolume(volume*.1);

  // pitch 1.0 is normal
  setPitch(double pitch) => _spk.setPitch(pitch);

  Future<void> stop() async => _spk.stop();

}


// This represents the relative priorities
// So, if a Depth message is queued and an Application message is queued (irrespective of order) the Depth message will be read first.
// This is not the same things as 'pre-empt' in the speak method: here.
enum SpeakPriority {
  Depth,        // always gets top priority, uninterruptible
  Application,  // Keyboard touch/numbers etc
  General,      // Info from the app: headings, etc
  Low           // Things like help messages; wait til last.
}

class _SpeakItem implements Comparable<_SpeakItem> {
  SpeakPriority _priority;
  String _key;

  _SpeakItem(this._priority, this._key);

  @override int compareTo(_SpeakItem other) {
    return this._priority.index.compareTo(other._priority.index);
  }

  @override
  String toString() {
    return '_SpeakItem{_priority: $_priority, _key: $_key}';
  }
}