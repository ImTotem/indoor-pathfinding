import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/map_card.dart';

class _MapData {
  final String name;
  final String description;
  final String latitude;
  final String longitude;
  final String createdAt;

  const _MapData({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });
}

const _mockMaps = [
  _MapData(name: '관리관 A동', description: '본관 1~4층, 북문 주출입구', latitude: '37.5665', longitude: '126.9780', createdAt: '2026-03-13'),
  _MapData(name: '공학관 B동', description: '지하1층~지상5층, 동문 접근', latitude: '좌표 정보 없음', longitude: '좌표 정보 없음', createdAt: '2026-03-11'),
  _MapData(name: '도서관 C동', description: '지상3층, 열람실 및 스터디룸', latitude: '37.5670', longitude: '126.9785', createdAt: '2026-03-10'),
  _MapData(name: '학생회관', description: '지하1층~지상4층, 식당 및 편의시설', latitude: '37.5660', longitude: '126.9775', createdAt: '2026-03-09'),
  _MapData(name: '체육관', description: '지상2층, 실내 체육시설', latitude: '37.5655', longitude: '126.9790', createdAt: '2026-03-08'),
  _MapData(name: '기숙사 D동', description: '지상10층, 남학생 기숙사', latitude: '37.5680', longitude: '126.9770', createdAt: '2026-03-07'),
  _MapData(name: '연구동 E동', description: '지상6층, 연구실 및 세미나실', latitude: '37.5675', longitude: '126.9795', createdAt: '2026-03-06'),
  _MapData(name: '예술관 F동', description: '지상3층, 전시실 및 강의실', latitude: '좌표 정보 없음', longitude: '좌표 정보 없음', createdAt: '2026-03-05'),
];

class MapListScreen extends StatefulWidget {
  const MapListScreen({super.key});

  @override
  State<MapListScreen> createState() => _MapListScreenState();
}

class _MapListScreenState extends State<MapListScreen> {
  int? _selectedIndex;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  static const _headerHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더 영역 - ValueListenableBuilder로 스크롤 시에만 리빌드
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, _) {
                final collapseProgress =
                    (offset / _headerHeight).clamp(0.0, 1.0);
                final collapsed = collapseProgress >= 1.0;
                final headerOpacity =
                    (1.0 - collapseProgress * 2).clamp(0.0, 1.0);
                final collapsedOpacity =
                    ((collapseProgress - 0.5) * 2).clamp(0.0, 1.0);

                return Container(
                  color: c.bg,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 36,
                        child: Stack(
                          children: [
                            // 펼쳐진 상태: ← 맵 목록 조회
                            Opacity(
                              opacity: headerOpacity,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_back,
                                        size: 24, color: c.textPrimary),
                                    const SizedBox(width: 12),
                                    Text(
                                      '맵 목록 조회',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 접힌 상태: ← 뒤로가기
                            if (collapsed)
                              Opacity(
                                opacity: collapsedOpacity,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_back,
                                          size: 24, color: c.textPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        '뒤로가기',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 설명 텍스트 (접히면 사라짐)
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          heightFactor:
                              (1.0 - collapseProgress).clamp(0.0, 1.0),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Opacity(
                              opacity: headerOpacity,
                              child: Text(
                                '맵 생성 시 입력한 정보와 함께 저장된 맵을 확인하세요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            ),
            // 스크롤 가능한 컨텐츠
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _mockMaps.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '총 ${_mockMaps.length}개 맵',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.accentIndigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final mapIndex = index - 1;
                  final map = _mockMaps[mapIndex];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: mapIndex < _mockMaps.length - 1 ? 10 : 0,
                    ),
                    child: MapCard(
                      name: map.name,
                      description: map.description,
                      latitude: map.latitude,
                      longitude: map.longitude,
                      createdAt: map.createdAt,
                      isSelected: _selectedIndex == mapIndex,
                      onTap: () => setState(() {
                        _selectedIndex =
                            _selectedIndex == mapIndex ? null : mapIndex;
                      }),
                    ),
                  );
                },
              ),
            ),
            // Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(
                  top: BorderSide(color: c.strokeSubtle, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedIndex != null
                      ? () =>
                          Navigator.pushNamed(context, '/pathfinding-camera')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accentIndigo,
                    foregroundColor: c.onAccent,
                    disabledBackgroundColor: c.surface,
                    disabledForegroundColor: c.textTertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '이 맵으로 길찾기 시작',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
