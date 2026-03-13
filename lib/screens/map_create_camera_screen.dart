import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          // ROTATION_90 = 1 = landscapeLeft = USB on right = 오른손 모드
          // ROTATION_270 = 3 = landscapeRight = USB on left = 왼손 모드
          _isLeftHanded = rotation == 3;
        });
      }
    } catch (_) {
      // 폴백: viewPadding 비대칭 확인
      if (mounted) {
        final vp = MediaQuery.of(context).viewPadding;
        setState(() {
          _isLeftHanded = vp.right > vp.left;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            // Badge - top corner
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
            // Controls - RecordButton이 화면 세로 정중앙
            Positioned(
              right: _isLeftHanded ? null : 24,
              left: _isLeftHanded ? 24 : null,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 아래 indicator+gap 높이만큼 상단 보정 → RecordButton이 정중앙
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
            // HUD panel - bottom, same side as badge
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
    );
  }
}
