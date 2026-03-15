import 'package:flutter/material.dart';
import '../api/map_api.dart';
import '../models/map_model.dart';
import '../theme/app_theme.dart';
import '../widgets/map_card.dart';

class MapListScreen extends StatefulWidget {
  const MapListScreen({super.key});

  @override
  State<MapListScreen> createState() => _MapListScreenState();
}

class _MapListScreenState extends State<MapListScreen> {
  int? _selectedIndex;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  final _mapApi = MapApi();

  late Future<List<MapModel>> _mapsFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
    _mapsFuture = _mapApi.getAll();
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
            // 고정 헤더 영역
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
              child: FutureBuilder<List<MapModel>>(
                future: _mapsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '맵 목록을 불러올 수 없습니다',
                            style: TextStyle(color: c.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _mapsFuture = _mapApi.getAll();
                              });
                            },
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    );
                  }

                  final maps = snapshot.data!;
                  if (maps.isEmpty) {
                    return Center(
                      child: Text(
                        '생성된 맵이 없습니다',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: maps.length + 1,
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
                                  '총 ${maps.length}개 맵',
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
                      final map = maps[mapIndex];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: mapIndex < maps.length - 1 ? 10 : 0,
                        ),
                        child: MapCard(
                          name: map.name,
                          description: map.description ?? '',
                          latitude: map.latitudeText,
                          longitude: map.longitudeText,
                          createdAt: map.createdAtText,
                          isSelected: _selectedIndex == mapIndex,
                          onTap: () => setState(() {
                            _selectedIndex =
                                _selectedIndex == mapIndex ? null : mapIndex;
                          }),
                        ),
                      );
                    },
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
