import 'package:flutter/services.dart';
import '../models/engine_status.dart';

class ResultStream {
  static const _channel =
      EventChannel('com.example.indoor_pathfinding/engine_status');

  /// 100ms 간격 EngineStatus 스트림
  Stream<EngineStatus> get statusStream {
    return _channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return EngineStatus.fromMap(event);
      }
      return EngineStatus.idle;
    });
  }
}
