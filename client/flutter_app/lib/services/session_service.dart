import 'package:flutter/services.dart';

class SessionService {
  static const _channel =
      MethodChannel('com.example.indoor_pathfinding/session');

  /// 매핑 세션 시작 — 센서 캡처 + gRPC 스트리밍 시작
  /// 반환: session_id (UUID)
  Future<String> startMapping(String mapId) async {
    final sessionId = await _channel.invokeMethod<String>(
      'startMapping',
      {'mapId': mapId},
    );
    return sessionId!;
  }

  /// Localization 세션 시작
  /// 반환: session_id (UUID)
  Future<String> startLocalization(String mapId) async {
    final sessionId = await _channel.invokeMethod<String>(
      'startLocalization',
      {'mapId': mapId},
    );
    return sessionId!;
  }

  /// 현재 세션 종료
  Future<void> stopSession() async {
    await _channel.invokeMethod('stopSession');
  }
}
