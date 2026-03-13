import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Top Actions - 설정 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.strokeSubtle, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.settings, size: 16, color: c.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            '설정',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '실내 길찾기',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '건물 안에서도 목적지까지 가장 빠른 길을 안내해요.',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ActionCard(
                icon: LucideIcons.map,
                iconBg: c.accentIndigo,
                iconColor: c.onAccent,
                title: '맵 생성 시작',
                description: '건물 정보 입력 후 카메라 수집 단계로 이동해요',
                onTap: () => Navigator.pushNamed(context, '/map-create-info'),
              ),
              const SizedBox(height: 24),
              ActionCard(
                icon: LucideIcons.navigation,
                iconBg: c.surfaceAlt,
                iconColor: c.accentIndigo,
                title: '길찾기',
                description: '맵을 먼저 선택한 뒤 출발지와 목적지를 설정해 길찾기를 시작해요',
                showBorder: false,
                onTap: () => Navigator.pushNamed(context, '/map-list'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
