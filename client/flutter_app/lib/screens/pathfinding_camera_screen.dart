import 'dart:async';
import 'package:flutter/material.dart';
import '../models/engine_status.dart';
import '../services/session_service.dart';
import '../services/result_stream.dart';
import '../theme/app_theme.dart';

class PathfindingCameraScreen extends StatefulWidget {
  const PathfindingCameraScreen({super.key});

  @override
  State<PathfindingCameraScreen> createState() =>
      _PathfindingCameraScreenState();
}

class _PathfindingCameraScreenState extends State<PathfindingCameraScreen> {
  bool _isGuiding = false;

  final _sessionService = SessionService();
  final _resultStream = ResultStream();
  StreamSubscription<EngineStatus>? _statusSub;
  EngineStatus _status = EngineStatus.idle;
  String? _mapId;

  @override
  void initState() {
    super.initState();
    _statusSub = _resultStream.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    if (_isGuiding) {
      _sessionService.stopSession();
    }
    super.dispose();
  }

  Future<void> _startGuiding() async {
    if (_mapId == null) return;
    try {
      await _sessionService.startLocalization(_mapId!);
      setState(() => _isGuiding = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('세션 시작 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pose = _status.pose;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              children: [
                Expanded(
                  child: _isGuiding
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '현재 위치 파악을 위해 주변을\n촬영해 주세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF8FAFC),
                                  height: 1.4,
                                ),
                              ),
                              if (pose != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'x: ${pose.x.toStringAsFixed(2)}, y: ${pose.y.toStringAsFixed(2)}, z: ${pose.z.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Frames: ${_status.frameCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isGuiding ? null : _startGuiding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accentIndigo,
                      foregroundColor: c.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isGuiding ? '위치 분석 중...' : '길찾기 시작',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
