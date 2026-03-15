import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/engine_status.dart';
import '../theme/app_theme.dart';

class HudBadge extends StatelessWidget {
  final String modeText;
  final bool isRecording;
  final bool isLeftHanded;

  const HudBadge({
    super.key,
    required this.modeText,
    this.isRecording = false,
    this.isLeftHanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isRecording
            ? const Color(0xFFF87171)
            : Colors.white.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
    );

    final text = Text(
      modeText,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.25,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: isLeftHanded
                ? [text, const SizedBox(width: 6), dot]
                : [dot, const SizedBox(width: 6), text],
          ),
        ),
      ),
    );
  }
}

class HudCompactPanel extends StatelessWidget {
  final EngineStatus? status;
  final double captureFps;
  final double sendFps;

  const HudCompactPanel({
    super.key,
    this.status,
    this.captureFps = 0,
    this.sendFps = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s = status;
    final frameCount = s?.frameCount ?? 0;
    final pose = s?.pose;
    final stateLabel = s != null ? _stateLabel(s.state) : '--';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 176,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow(
                'Cap ${captureFps.toStringAsFixed(1)}  Send ${sendFps.toStringAsFixed(1)}  $stateLabel',
                Colors.white,
                10,
                FontWeight.w700,
              ),
              const SizedBox(height: 2),
              _buildRow(
                'Sent ${s?.frameCount ?? 0} / Cap ${s?.totalPushed ?? 0}',
                Colors.white,
                10,
                FontWeight.w700,
              ),
              if (s?.accel != null) ...[
                const SizedBox(height: 4),
                _buildRow(
                  'IMU ${_f(s!.accel![0])}, ${_f(s.accel![1])}, ${_f(s.accel![2])}',
                  Colors.white.withValues(alpha: 0.8),
                  9,
                  FontWeight.w500,
                ),
              ],
              if (s?.gyro != null) ...[
                const SizedBox(height: 2),
                _buildRow(
                  'Gyro ${_f(s!.gyro![0])}, ${_f(s.gyro![1])}, ${_f(s.gyro![2])}',
                  Colors.white.withValues(alpha: 0.8),
                  9,
                  FontWeight.w500,
                ),
              ],
              if (s?.pressure != null) ...[
                const SizedBox(height: 2),
                _buildRow(
                  'Baro ${s!.pressure!.toStringAsFixed(4)} hPa',
                  Colors.white.withValues(alpha: 0.8),
                  9,
                  FontWeight.w500,
                ),
              ],
              if (pose != null) ...[
                const SizedBox(height: 4),
                _buildRow(
                  'Pos ${_f(pose.x)}, ${_f(pose.y)}, ${_f(pose.z)}',
                  Colors.white.withValues(alpha: 0.8),
                  9,
                  FontWeight.w500,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _f(double v) => v.toStringAsFixed(2);

  String _stateLabel(SessionState state) {
    switch (state) {
      case SessionState.idle:
        return 'Idle';
      case SessionState.mapping:
        return 'Mapping';
      case SessionState.localizing:
        return 'Localizing';
      case SessionState.error:
        return 'Error';
    }
  }

  Widget _buildRow(
      String text, Color color, double fontSize, FontWeight weight) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        height: 1.2,
      ),
    );
  }
}

class RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback? onTap;

  const RecordButton({super.key, this.isRecording = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: isRecording
                  ? const Color(0xFF4C78A8)
                  : c.accentCoral,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IndicatorToggleButton extends StatelessWidget {
  final VoidCallback? onTap;

  const IndicatorToggleButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child:
                const Icon(LucideIcons.gauge, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
