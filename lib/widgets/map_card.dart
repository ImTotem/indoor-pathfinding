import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapCard extends StatelessWidget {
  final String name;
  final String description;
  final String latitude;
  final String longitude;
  final String createdAt;
  final bool isSelected;
  final VoidCallback? onTap;

  const MapCard({
    super.key,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.accentIndigo : c.strokeSubtle,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: c.accentIndigo.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '위도: $latitude',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '경도: $longitude',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '생성일: $createdAt',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
