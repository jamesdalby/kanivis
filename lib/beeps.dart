// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:typed_data';
import 'package:wave_generator/wave_generator.dart';

void main() async {
  var generator = WaveGenerator(
    /* sample rate */
      44100,
      BitDepth.Depth8bit
  );

  var note = Note(
    /* frequency */
      220,
      /* msDuration */ 100,
      /* waveform */ Waveform.Sine,
      /* volume */ 0.5
  );

  Uint8List bytes = Uint8List(4410);
  int n =0;
  await for (int byte in generator.generate(note)) {
    bytes.add(byte);
    n++;
  }
print ("$n");
  // AudioPlayer _audioPlayer = AudioPlayer();
  // _audioPlayer.onPlayerError.listen((e) => print("Error $e"));
  // await _audioPlayer.playBytes(bytes);
}