// =============================================================================
// widget_settings_screen.dart - 위젯 설정 화면
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../app_localizations.dart';
import '../providers/budget_provider.dart';
import '../services/widget_service.dart';

/// 위젯 설정 화면
/// Small/Medium 위젯에 표시할 예산/세부예산 선택
class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  // 저장된 설정
  String? _smallBudgetId;
  String? _smallSubBudgetId;
  String? _mediumBudgetId;

  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 저장된 설정 로드
  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('widget_settings');
    setState(() {
      _smallBudgetId = _settingsBox.get('small_budgetId');
      _smallSubBudgetId = _settingsBox.get('small_subBudgetId');
      _mediumBudgetId = _settingsBox.get('medium_budgetId');
    });
  }

  /// 설정 저장 및 위젯 업데이트
  Future<void> _saveAndUpdate() async {
    // async 전에 provider 캡처
    final provider = context.read<BudgetProvider>();

    // 설정 저장
    await _settingsBox.put('small_budgetId', _smallBudgetId);
    await _settingsBox.put('small_subBudgetId', _smallSubBudgetId);
    await _settingsBox.put('medium_budgetId', _mediumBudgetId);

    // 위젯 업데이트
    await WidgetService.updateAllWidgets(
      provider: provider,
      smallBudgetId: _smallBudgetId,
      smallSubBudgetId: _smallSubBudgetId,
      mediumBudgetId: _mediumBudgetId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.tr('widgetUpdated'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('widgetSettings')),
        actions: [
          // 저장 버튼
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAndUpdate,
          ),
        ],
      ),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, child) {
          final budgets = provider.currentBudgets;

          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.widgets_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(loc.tr('addBudgetFirst'), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Small 위젯 설정
              _buildWidgetSection(
                context: context,
                title: loc.tr('smallWidget'),
                description: loc.tr('smallWidgetDesc'),
                icon: Icons.crop_square,
                child: _buildSmallWidgetSettings(provider, loc),
              ),

              const SizedBox(height: 24),

              // Medium 위젯 설정
              _buildWidgetSection(
                context: context,
                title: loc.tr('mediumWidget'),
                description: loc.tr('mediumWidgetDesc'),
                icon: Icons.crop_landscape,
                child: _buildMediumWidgetSettings(provider, loc),
              ),

              const SizedBox(height: 24),

              // Large 위젯 설명
              _buildWidgetSection(
                context: context,
                title: loc.tr('largeWidget'),
                description: loc.tr('largeWidgetDesc'),
                icon: Icons.crop_din,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    loc.tr('largeWidgetInfo'),
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 위젯 추가 안내
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(loc.tr('howToAddWidget'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(loc.tr('widgetAddGuide')),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 위젯 섹션 카드
  Widget _buildWidgetSection({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 설정 내용
          child,
        ],
      ),
    );
  }

  /// Small 위젯 설정 (예산 + 세부예산 선택)
  Widget _buildSmallWidgetSettings(BudgetProvider provider, AppLocalizations loc) {
    final budgets = provider.currentBudgets;
    final subBudgets = _smallBudgetId != null ? provider.getSubBudgets(_smallBudgetId!) : <dynamic>[];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 예산 선택
          DropdownButtonFormField<String?>(
            initialValue: _smallBudgetId,
            decoration: InputDecoration(
              labelText: loc.tr('selectBudget'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(loc.tr('notSelected'))),
              ...budgets.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
            ],
            onChanged: (value) {
              setState(() {
                _smallBudgetId = value;
                _smallSubBudgetId = null; // 예산 변경 시 세부예산 초기화
              });
            },
          ),

          // 세부예산 선택 (선택사항)
          if (_smallBudgetId != null && subBudgets.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _smallSubBudgetId,
              decoration: InputDecoration(
                labelText: loc.tr('selectSubBudgetOptional'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(loc.tr('entireBudget'))),
                ...subBudgets.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
              ],
              onChanged: (value) {
                setState(() => _smallSubBudgetId = value);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Medium 위젯 설정 (예산 선택)
  Widget _buildMediumWidgetSettings(BudgetProvider provider, AppLocalizations loc) {
    final budgets = provider.currentBudgets;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String?>(
        initialValue: _mediumBudgetId,
        decoration: InputDecoration(
          labelText: loc.tr('selectBudget'),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(loc.tr('notSelected'))),
          ...budgets.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
        ],
        onChanged: (value) {
          setState(() => _mediumBudgetId = value);
        },
      ),
    );
  }
}
