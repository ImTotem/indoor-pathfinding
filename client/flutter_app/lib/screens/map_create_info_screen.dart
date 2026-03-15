import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../api/map_api.dart';
import '../theme/app_theme.dart';

class MapCreateInfoScreen extends StatefulWidget {
  const MapCreateInfoScreen({super.key});

  @override
  State<MapCreateInfoScreen> createState() => _MapCreateInfoScreenState();
}

class _MapCreateInfoScreenState extends State<MapCreateInfoScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _mapApi = MapApi();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showNameRequiredDialog();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final map = await _mapApi.create(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_lngController.text),
      );
      if (mounted) {
        Navigator.pushNamed(context, '/map-create-camera', arguments: map.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('맵 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showNameRequiredDialog() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (dialogContext) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 280,
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
                    Icons.edit_outlined,
                    color: c.accentIndigo,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '건물 이름을 입력해주세요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '건물 이름은 필수 입력 항목입니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    width: double.infinity,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.accentIndigo,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.onAccent,
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
            _buildTextField(c, '건물 이름을 입력해주세요', _nameController),
            const SizedBox(height: 16),
            _buildLabel(c, '건물에 대한 설명'),
            const SizedBox(height: 8),
            _buildTextArea(c, '건물에 대한 간단한 설명을 입력해주세요', _descController),
            const SizedBox(height: 16),
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
            Row(
              children: [
                Expanded(child: _buildCoordField(c, '위도 (Latitude)', _latController)),
                const SizedBox(width: 10),
                Expanded(child: _buildCoordField(c, '경도 (Longitude)', _lngController)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accentIndigo,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
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

  Widget _buildTextField(AppColorsExtension c, String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
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

  Widget _buildCoordField(AppColorsExtension c, String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
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

  Widget _buildTextArea(AppColorsExtension c, String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
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
