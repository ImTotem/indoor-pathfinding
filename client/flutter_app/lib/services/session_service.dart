import 'package:flutter/services.dart';

class SessionService {
  static const _channel =
      MethodChannel('com.example.indoor_pathfinding/session');

  Future<void> startSensors() async {
    await _channel.invokeMethod('startSensors');
  }

  Future<void> stopSensors() async {
    await _channel.invokeMethod('stopSensors');
  }

  Future<void> startMapping(String mapId) async {
    await _channel.invokeMethod('startMapping', {'mapId': mapId});
  }

  Future<void> startLocalization(String mapId) async {
    await _channel.invokeMethod('startLocalization', {'mapId': mapId});
  }

  /// 캡처 일시정지 (세션은 유지)
  Future<void> pauseCapture() async {
    await _channel.invokeMethod('pauseCapture');
  }

  /// 캡처 재개
  Future<void> resumeCapture() async {
    await _channel.invokeMethod('resumeCapture');
  }

  /// 세션 완전 종료 (gRPC 스트림 닫기 + SessionService.Stop)
  Future<void> stopSession() async {
    await _channel.invokeMethod('stopSession');
  }
}
