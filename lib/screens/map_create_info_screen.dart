import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class MapCreateInfoScreen extends StatelessWidget {
  const MapCreateInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '맵 생성 정보 입력',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '건물 정보를 입력하고 위치를 선택하세요.',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel(c, '건물 이름 *'),
            const SizedBox(height: 8),
            _buildTextField(c, '건물 이름을 입력해주세요'),
            const SizedBox(height: 16),
            _buildLabel(c, '건물에 대한 설명'),
            const SizedBox(height: 8),
            _buildTextArea(c, '건물에 대한 간단한 설명을 입력해주세요'),
            const SizedBox(height: 16),
            // GPS 위치 찾기 버튼
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.locateFixed, size: 16, color: c.accentIndigo),
                  const SizedBox(width: 6),
                  Text(
                    'GPS로 위치 찾기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.accentIndigo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 좌표 입력
            Row(
              children: [
                Expanded(child: _buildCoordField(c, '위도 (Latitude)')),
                const SizedBox(width: 10),
                Expanded(child: _buildCoordField(c, '경도 (Longitude)')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/map-create-camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accentIndigo,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '다음 화면으로',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(AppColorsExtension c, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
    );
  }

  Widget _buildTextField(AppColorsExtension c, String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accentIndigo, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 13, color: c.textPrimary),
    );
  }

  Widget _buildCoordField(AppColorsExtension c, String hint) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accentIndigo, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 13, color: c.textPrimary),
    );
  }

  Widget _buildTextArea(AppColorsExtension c, String hint) {
    return TextField(
      maxLines: 3,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.strokeSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accentIndigo, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 13, color: c.textPrimary),
    );
  }
}
