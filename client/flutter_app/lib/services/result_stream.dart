import 'dart:async';
import 'package:flutter/services.dart';
import '../models/engine_status.dart';

class ResultStream {
  static const _channel =
      EventChannel('com.example.indoor_pathfinding/engine_status');

  Stream<EngineStatus>? _shared;

  /// 단일 broadcast stream — 여러 리스너가 동시에 구독 가능
  Stream<EngineStatus> get statusStream {
    _shared ??= _channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return EngineStatus.fromMap(event);
      }
      return EngineStatus.idle;
    }).asBroadcastStream();
    return _shared!;
  }
}
