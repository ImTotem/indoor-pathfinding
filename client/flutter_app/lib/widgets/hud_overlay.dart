import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  const HudCompactPanel({super.key});

  @override
  Widget build(BuildContext context) {
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
              _buildRow('FPS 29.8', Colors.white, 10, FontWeight.w700),
              const SizedBox(height: 2),
              _buildRow('통신 41ms', Colors.white, 10, FontWeight.w700),
              const SizedBox(height: 4),
              _buildRow(
                'IMU a(x,y,z): 0.03, -0.01, 9.79',
                Colors.white.withValues(alpha: 0.8),
                9,
                FontWeight.w500,
              ),
              const SizedBox(height: 2),
              _buildRow(
                'Gyro r/p/y: 0.12, -0.04, 1.31',
                Colors.white.withValues(alpha: 0.8),
                9,
                FontWeight.w500,
              ),
            ],
          ),
        ),
      ),
    );
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
