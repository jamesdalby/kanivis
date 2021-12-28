import 'package:kanivis/qspeak.dart';

void main() {
  var q = QSpeak();

  q.add(SpeakPriority.Application, "app", "shouldn't see this");
  q.add(SpeakPriority.Application, "app", "or this");
  q.add(SpeakPriority.Application, "app", "this is the last added at this priority so you should see it");
  q.add(SpeakPriority.Application, "app2", "you should see this, because different source (app2)");
  q.add(SpeakPriority.Depth, "dpt", "shouldn't see this");
  q.add(SpeakPriority.Depth, "dpt", "this is the last depth message, you should see it first out of the box");
  q.add(SpeakPriority.General, "lala", "a general lala message");
  q.add(SpeakPriority.Low, "flooble", "a low priority message");
  q.add(SpeakPriority.Application, "app", "shouldn't see this");
  q.add(SpeakPriority.Application, "app", "or this");
  q.add(SpeakPriority.Application, "app", "this is the last added at this priority so you should see it");
  q.add(SpeakPriority.Application, "app2", "you should see this, because different source (app2)");
  q.add(SpeakPriority.Depth, "dpt", "shouldn't see this");
  q.add(SpeakPriority.Depth, "dpt", "this is the last depth message, you should see it first out of the box");
  q.add(SpeakPriority.General, "lala", "a general lala message");
  q.add(SpeakPriority.Low, "flooble", "a low priority message");
  q.add(SpeakPriority.Application, "app", "shouldn't see this");
  q.add(SpeakPriority.Application, "app", "or this");
  q.add(SpeakPriority.Application, "app", "this is the last added at this priority so you should see it");
  q.add(SpeakPriority.Application, "app2", "you should see this, because different source (app2)");
  q.add(SpeakPriority.Depth, "dpt", "shouldn't see this");
  q.add(SpeakPriority.Depth, "dpt", "this is the last depth message, you should see it first out of the box");
  q.add(SpeakPriority.General, "lala", "a general lala message");
  q.add(SpeakPriority.Low, "flooble", "a low priority message");


}