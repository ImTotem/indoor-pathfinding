import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PathfindingCameraScreen extends StatefulWidget {
  const PathfindingCameraScreen({super.key});

  @override
  State<PathfindingCameraScreen> createState() =>
      _PathfindingCameraScreenState();
}

class _PathfindingCameraScreenState extends State<PathfindingCameraScreen> {
  bool _isGuiding = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                          child: AnimatedOpacity(
                            opacity: _isGuiding ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: const Text(
                              '현재 위치 파악을 위해 주변을\n촬영해 주세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF8FAFC),
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_isGuiding) {
                        setState(() => _isGuiding = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accentIndigo,
                      foregroundColor: c.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '길찾기 시작',
                      style: TextStyle(
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
