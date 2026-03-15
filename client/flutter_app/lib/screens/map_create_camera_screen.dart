import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/engine_status.dart';
import '../services/session_service.dart';
import '../services/result_stream.dart';
import '../theme/app_theme.dart';
import '../widgets/hud_overlay.dart';

class MapCreateCameraScreen extends StatefulWidget {
  const MapCreateCameraScreen({super.key});

  @override
  State<MapCreateCameraScreen> createState() => _MapCreateCameraScreenState();
}

class _MapCreateCameraScreenState extends State<MapCreateCameraScreen> {
  bool _isRecording = false;
  bool _showHud = true;
  bool _isLeftHanded = false;

  int? _textureId;

  static const _cameraChannel =
      MethodChannel('com.example.indoor_pathfinding/camera');
  static const _orientationChannel =
      EventChannel('com.example.indoor_pathfinding/device_orientation');

  final _sessionService = SessionService();
  final _resultStream = ResultStream();
  StreamSubscription<EngineStatus>? _statusSub;
  StreamSubscription? _orientationSub;
  EngineStatus _status = EngineStatus.idle;
  String? _mapId;

  int _lastFrameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startPreview();

    _statusSub = _resultStream.statusStream.listen((s) {
      if (mounted) {
        _updateFps(s);
        setState(() => _status = s);
      }
    });

    _orientationSub =
        _orientationChannel.receiveBroadcastStream().listen((e) {
      if (mounted) setState(() => _isLeftHanded = (e as int) == 90);
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
    _orientationSub?.cancel();
    if (_isRecording) _sessionService.stopSession();
    _cameraChannel.invokeMethod('stopPreview');
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _startPreview() async {
    try {
      final id = await _cameraChannel.invokeMethod<int>('startPreview');
      if (mounted && id != null) setState(() => _textureId = id);
    } catch (e) {
      debugPrint('Camera preview failed: $e');
    }
  }

  void _updateFps(EngineStatus s) {
    final now = DateTime.now();
    final ms = now.difference(_lastFpsTime).inMilliseconds;
    if (ms >= 1000) {
      _fps = (s.frameCount - _lastFrameCount) * 1000.0 / ms;
      _lastFrameCount = s.frameCount;
      _lastFpsTime = now;
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _sessionService.stopSession();
      setState(() => _isRecording = false);
    } else {
      if (_mapId == null) return;
      try {
        await _sessionService.startMapping(_mapId!);
        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('세션 시작 실패: $e')),
          );
        }
      }
    }
  }

  void _exitToHome() {
    if (_isRecording) _sessionService.stopSession();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _showExitModal() {
    final c = context.colors;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('녹화를 종료하시겠습니까?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.foreground)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('취소',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.secondaryForeground)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _exitToHome();
                      },
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.accentCoral,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('종료',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.onAccent)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 왼손 모드: RotatedBox(2)로 전체 180° 회전 + 위치 좌우 스왑
  // → 텍스트/카메라 정방향 유지 + 좌우 대칭 레이아웃

  @override
  Widget build(BuildContext context) {
    final lh = _isLeftHanded;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _showExitModal();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 카메라 프리뷰 — 반시계 90° 고정 (왼손 모드 영향 안 받음)
            if (_textureId != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: Texture(textureId: _textureId!),
                    ),
                  ),
                ),
              ),

            // UI 레이어 — 왼손 모드일 때 180° 회전 + 위치 스왑
            RotatedBox(
              quarterTurns: lh ? 2 : 0,
              child: Stack(
                children: [

              // 뱃지: 오른손=좌상단, 왼손=우상단(스왑)
              Positioned(
                top: 12,
                left: lh ? null : 16,
                right: lh ? 16 : null,
                child: HudBadge(
                  modeText: lh ? '왼손 모드' : '오른손 모드',
                  isRecording: _isRecording,
                  isLeftHanded: lh,
                ),
              ),

              // 닫기: 오른손=우상단, 왼손=좌상단(스왑)
              Positioned(
                top: 12,
                right: lh ? null : 16,
                left: lh ? 16 : null,
                child: GestureDetector(
                  onTap: _showExitModal,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),

              // 녹화 버튼 + 인디케이터 토글: 오른손=우측, 왼손=좌측(스왑)
              // 녹화 버튼은 정중앙, 인디케이터는 그 아래
              Positioned(
                right: lh ? null : 24,
                left: lh ? 24 : null,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 보정 spacer: indicator(44) + gap(12) = 56
                    const SizedBox(height: 56),
                    RecordButton(
                      isRecording: _isRecording,
                      onTap: _toggleRecording,
                    ),
                    const SizedBox(height: 12),
                    IndicatorToggleButton(
                      onTap: () => setState(() => _showHud = !_showHud),
                    ),
                  ],
                ),
              ),

              // HUD: 오른손=좌하단, 왼손=우하단(스왑)
              if (_showHud)
                Positioned(
                  bottom: 20,
                  left: lh ? null : 16,
                  right: lh ? 16 : null,
                  child: HudCompactPanel(status: _status, fps: _fps),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
