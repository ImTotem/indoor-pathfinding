import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showHud = true;
  bool _isLeftHanded = false;

  static const _orientationChannel =
      MethodChannel('com.example.indoor_pathfinding/orientation');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _detectOrientation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _detectOrientation();
  }

  Future<void> _detectOrientation() async {
    try {
      final rotation =
          await _orientationChannel.invokeMethod<int>('getRotation');
      if (mounted) {
        setState(() {
          _isLeftHanded = rotation == 3;
        });
      }
    } catch (_) {
      if (mounted) {
        final vp = MediaQuery.of(context).viewPadding;
        setState(() {
          _isLeftHanded = vp.right > vp.left;
        });
      }
    }
  }

  void _exitToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool> _onWillPop() async {
    _showExitModal();
    return false;
  }

  void _showExitModal() {
    final c = context.colors;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border, width: 1),
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
                  child: Icon(
                    Icons.close,
                    color: c.accentCoral,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '녹화를 종료하시겠습니까?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '현재 세션의 녹화 데이터를\n저장하고 종료합니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.mutedForeground,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.secondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.secondaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _exitToHome();
                        },
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.accentCoral,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '종료',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
          child: Stack(
            children: [
              // Badge - top left (오른손) or top right (왼손)
              Positioned(
                top: 12,
                left: _isLeftHanded ? null : 16,
                right: _isLeftHanded ? 16 : null,
                child: HudBadge(
                  modeText: _isLeftHanded ? '왼손 모드' : '오른손 모드',
                  isRecording: _isRecording,
                  isLeftHanded: _isLeftHanded,
                ),
              ),
              // Exit button - opposite corner from badge
              Positioned(
                top: 12,
                right: _isLeftHanded ? null : 16,
                left: _isLeftHanded ? 16 : null,
                child: _buildExitButton(),
              ),
              // Controls - RecordButton
              Positioned(
                right: _isLeftHanded ? null : 24,
                left: _isLeftHanded ? 24 : null,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 44 + 12),
                    RecordButton(
                      isRecording: _isRecording,
                      onTap: () =>
                          setState(() => _isRecording = !_isRecording),
                    ),
                    const SizedBox(height: 12),
                    IndicatorToggleButton(
                      onTap: () => setState(() => _showHud = !_showHud),
                    ),
                  ],
                ),
              ),
              // HUD panel
              if (_showHud)
                Positioned(
                  bottom: 20,
                  left: _isLeftHanded ? null : 16,
                  right: _isLeftHanded ? 16 : null,
                  child: const HudCompactPanel(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return GestureDetector(
      onTap: _showExitModal,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
