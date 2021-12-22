import 'package:collection/collection.dart';
import 'package:flutter_tts/flutter_tts.dart';

/**
 * Priority queue of items to dispatch
 *
 */
class QSpeak {
  static FlutterTts _spk = FlutterTts();
  static PriorityQueue<_SpeakItem> q = PriorityQueue();
  static Map<String, String> t = {};
  static List<String> _immediate = [];

  static final QSpeak _singleton = QSpeak._internal();

  factory QSpeak() => _singleton;

  QSpeak._internal() {
    _spk.completionHandler = _onComplete;
    _spk.startHandler = _onStart;
  }

  add(SpeakPriority pri, String key, String message) {
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

  bool _active = false;

  void _onComplete() {
    _active = false;
    String? n = _next();
    if (n != null) {
      _spk.speak(n);
    }
  }

  void _onStart() {
    _active = true;
  }


  void immediate(String s) {
    // a message to be sent, in order, as soon as the current message is finished.
    _immediate.add(s);
    if (!_active) {
      _onComplete();
    }
  }

  // delegates:
  setSpeechRate(double speechRate) => _spk.setSpeechRate(speechRate);
  setVolume(double volume) => _spk.setVolume(volume);
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
}