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

class _MapCreateCameraScreenState extends State<MapCreateCameraScreen>
    with WidgetsBindingObserver {
  bool _isRecording = false;
  bool _sessionStarted = false;
  bool _showHud = true;
  bool _isLeftHanded = false;
  bool _queueModalShowing = false;

  int? _textureId;

  static const _cameraChannel =
      MethodChannel('com.example.indoor_pathfinding/camera');

  final _sessionService = SessionService();
  final _resultStream = ResultStream();
  StreamSubscription<EngineStatus>? _statusSub;
  EngineStatus _status = EngineStatus.idle;
  String? _mapId;

  int _lastSendCount = 0;
  int _lastCapCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  double _sendFps = 0;
  double _capFps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // OS 센서 기반 landscape 회전 (자동회전 꺼져있어도 동작)
    _cameraChannel.invokeMethod('setSensorLandscape');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startPreview();
    _sessionService.startSensors(); // HUD에 IMU/기압 표시용

    _statusSub = _resultStream.statusStream.listen((s) {
      if (mounted) {
        _updateFps(s);
        setState(() => _status = s);
        _handleQueueStatus(s);
      }
    });

    // SENSOR_LANDSCAPE 사용 시 OS가 회전하므로 didChangeMetrics로 감지
    _detectOrientation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void didChangeMetrics() {
    _detectOrientation();
  }

  Future<void> _detectOrientation() async {
    try {
      final rotation = await const MethodChannel(
              'com.example.indoor_pathfinding/orientation')
          .invokeMethod<int>('getRotation');
      if (mounted) {
        final lh = rotation == 3;
        final degrees = rotation! * 90; // Surface.ROTATION_* → degrees
        setState(() => _isLeftHanded = lh);
        _cameraChannel.invokeMethod('setOrientation', {'degrees': degrees});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    if (!_sessionStarted) _sessionService.stopSensors();
    _cameraChannel.invokeMethod('stopPreview');
    _cameraChannel.invokeMethod('resetOrientation');
    WidgetsBinding.instance.removeObserver(this);
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
      _sendFps = (s.frameCount - _lastSendCount) * 1000.0 / ms;
      _capFps = (s.totalPushed - _lastCapCount) * 1000.0 / ms;
      _lastSendCount = s.frameCount;
      _lastCapCount = s.totalPushed;
      _lastFpsTime = now;
    }
  }

  // 큐 상태 감지 → 모달 자동 표시/닫기
  void _handleQueueStatus(EngineStatus s) {
    if (s.queueFull && _sessionStarted && _isRecording && !_queueModalShowing) {
      _queueModalShowing = true;
      _showQueueWaitModal();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _sessionService.pauseCapture();
      setState(() => _isRecording = false);
    } else if (_sessionStarted) {
      await _sessionService.resumeCapture();
      setState(() => _isRecording = true);
    } else {
      if (_mapId == null) return;
      _showCountdownModal();
    }
  }

  void _showCountdownModal() {
    final c = context.colors;
    var countdown = 3;
    var sessionReady = false;
    String? sessionError;
    var dismissed = false;

    // 백그라운드에서 세션 시작 (gRPC 연결 + 타임스탬프 동기화)
    _sessionService.startMapping(_mapId!).then((_) {
      sessionReady = true;
    }).catchError((e) {
      sessionError = e.toString();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 1초 타이머
            if (countdown > 0 && !dismissed) {
              Future.delayed(const Duration(seconds: 1), () {
                if (!dismissed) {
                  setModalState(() => countdown--);
                }
              });
            }

            // 에러 발생 시
            if (sessionError != null && !dismissed) {
              dismissed = true;
              Future.microtask(() {
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('세션 시작 실패: $sessionError')),
                  );
                }
              });
            }

            // 카운트다운 완료 + 세션 준비 완료
            if (countdown <= 0 && sessionReady && !dismissed) {
              dismissed = true;
              Future.microtask(() {
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    _isRecording = true;
                    _sessionStarted = true;
                  });
                }
              });
            }

            return Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.timer,
                            color: c.accentIndigo, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        countdown > 0 ? '$countdown' : '시작!',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: c.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('녹화가 곧 시작됩니다',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: c.mutedForeground)),
                      const SizedBox(height: 4),
                      Text('카메라를 안정적으로 잡아주세요',
                          style: TextStyle(
                              fontSize: 12, color: c.mutedForeground)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _beginExit() {
    if (!_sessionStarted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    _sessionService.pauseCapture();
    _sessionService.stopSession();
    _showUploadModal();
  }

  // ── 큐 대기 모달 ──
  void _showQueueWaitModal() {
    final c = context.colors;
    var dismissed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return StreamBuilder<EngineStatus>(
          stream: _resultStream.statusStream,
          initialData: _status,
          builder: (context, snapshot) {
            final s = snapshot.data ?? _status;
            final sent = s.frameCount;
            final total = s.totalPushed;
            final progress = total > 0 ? sent / total : 0.0;

            // 큐 여유 생기면 1회만 닫기
            if (!s.queueFull && !dismissed) {
              dismissed = true;
              Future.microtask(() {
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                Future.delayed(const Duration(seconds: 10), () {
                  _queueModalShowing = false;
                });
              });
            }

            return Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.hourglass_top,
                            color: c.accentIndigo, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text('잠시 대기 중...',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.foreground)),
                      const SizedBox(height: 8),
                      Text(
                        '업로드 큐가 가득 찼습니다.\n데이터 전송이 완료될 때까지\n잠시만 기다려 주세요.',
                        style: TextStyle(
                            fontSize: 13,
                            color: c.mutedForeground,
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('전송 진행률',
                              style: TextStyle(
                                  fontSize: 12, color: c.mutedForeground)),
                          Text('${(progress * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.foreground)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: c.secondary,
                          color: c.accentIndigo,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '큐 공간이 확보되면 자동으로 녹화가 재개됩니다.',
                        style: TextStyle(
                            fontSize: 11, color: c.mutedForeground),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 업로드 모달 ──
  void _showUploadModal() {
    final c = context.colors;
    var dismissed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return StreamBuilder<EngineStatus>(
          stream: _resultStream.statusStream,
          initialData: _status,
          builder: (context, snapshot) {
            final s = snapshot.data ?? _status;
            final sent = s.frameCount;
            final total = s.totalPushed;
            final isDone = s.state == SessionState.idle;
            final progress = isDone ? 1.0 : (total > 0 ? sent / total : 0.0);

            if (isDone && !dismissed) {
              dismissed = true;
              Future.microtask(() {
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                Navigator.of(this.context).popUntil((r) => r.isFirst);
              });
            }

            return Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.cloud_upload,
                            color: c.accentIndigo, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(isDone ? '업로드 완료' : '데이터 업로드 중...',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.foreground)),
                      const SizedBox(height: 8),
                      Text(
                        '큐에 남은 센서 데이터를\n서버로 전송하고 있습니다.',
                        style: TextStyle(
                            fontSize: 13,
                            color: c.mutedForeground,
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('업로드 진행률',
                              style: TextStyle(
                                  fontSize: 12, color: c.mutedForeground)),
                          Text('${(progress * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.foreground)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: c.secondary,
                          color: c.accentIndigo,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$sent / $total 프레임 전송 완료',
                          style: TextStyle(
                              fontSize: 11, color: c.mutedForeground),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 종료 모달 ──
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.close, color: c.accentCoral, size: 24),
                ),
                const SizedBox(height: 16),
                Text('녹화를 종료하시겠습니까?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.foreground),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('현재 세션의 녹화 데이터를\n저장하고 종료합니다.',
                    style: TextStyle(
                        fontSize: 13, color: c.mutedForeground, height: 1.5),
                    textAlign: TextAlign.center),
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
                          border: Border.all(color: c.border),
                        ),
                        alignment: Alignment.center,
                        child: Text('취소',
                            style: TextStyle(
                                fontSize: 14,
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
                        _beginExit();
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
                                fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    // SENSOR_LANDSCAPE가 OS 회전을 처리 → RotatedBox 불필요
    // UI 배치는 _isLeftHanded로 좌우 대칭

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
            // 카메라 프리뷰 — 왼손 모드(landscape-right)일 때 180° 추가 보정
            if (_textureId != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenW = constraints.maxWidth;
                    final screenH = constraints.maxHeight;
                    // 기본 90° 보정 + 왼손 모드 시 추가 180°
                    final turns = lh ? 1 : 3; // 3=반시계90°, 1=시계90°(=반시계270°)
                    return FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: screenW,
                        height: screenH,
                        child: RotatedBox(
                          quarterTurns: turns,
                          child: SizedBox(
                            width: screenH,
                            height: screenW,
                            child: Texture(textureId: _textureId!),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 뱃지
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

            // 닫기 버튼
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
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),

            // 녹화 버튼 + 인디케이터 토글
            Positioned(
              right: lh ? null : 24,
              left: lh ? 24 : null,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

            // HUD
            if (_showHud)
              Positioned(
                bottom: 20,
                left: lh ? null : 16,
                right: lh ? 16 : null,
                child: HudCompactPanel(
                  status: _status,
                  captureFps: _capFps,
                  sendFps: _sendFps,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
