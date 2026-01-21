// =============================================================================
// analysis_result_screen.dart - AI 분석 결과 전용 화면 (#26)
// =============================================================================
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../app_localizations.dart';
import '../providers/analysis_provider.dart';
import '../services/ai_analysis_service.dart';
// #31: 플랫폼별 이미지 저장 - 조건부 import
import '../utils/image_saver_stub.dart'
    if (dart.library.html) '../utils/image_saver_web.dart'
    if (dart.library.io) '../utils/image_saver_io.dart' as image_saver;

class AnalysisResultScreen extends StatefulWidget {
  final AnalysisRecord record;
  final String language;

  const AnalysisResultScreen({
    super.key,
    required this.record,
    required this.language,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  // #27: 이미지 캡처를 위한 GlobalKey
  final GlobalKey _captureKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final result = widget.record.result;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(loc.tr('analysisResult')),
          ],
        ),
        actions: [
          // #27: 이미지 내보내기 버튼
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            tooltip: loc.tr('exportImage'),
            onPressed: _isExporting ? null : () => _exportAsImage(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _captureKey,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 분석 정보 카드
                _buildInfoCard(context, loc, dateFormat),
                const SizedBox(height: 16),

                // 한 마디 요약
                if (result.oneLiner.isNotEmpty) _buildOneLinerCard(context, result.oneLiner),
                const SizedBox(height: 16),

                // 요약
                _buildSectionCard(
                  context,
                  title: loc.tr('summary'),
                  icon: Icons.summarize,
                  iconColor: Theme.of(context).colorScheme.primary,
                  child: Text(result.summary, style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
                const SizedBox(height: 12),

                // 인사이트
                if (result.insights.isNotEmpty) ...[
                  _buildListSectionCard(context, title: loc.tr('insights'), icon: Icons.lightbulb, iconColor: Colors.amber, items: result.insights),
                  const SizedBox(height: 12),
                ],

                // 경고
                if (result.warnings.isNotEmpty) ...[
                  _buildListSectionCard(context, title: loc.tr('warnings'), icon: Icons.warning, iconColor: Colors.orange, items: result.warnings),
                  const SizedBox(height: 12),
                ],

                // 제안
                if (result.suggestions.isNotEmpty) ...[
                  _buildListSectionCard(context, title: loc.tr('suggestions'), icon: Icons.tips_and_updates, iconColor: Colors.green, items: result.suggestions),
                  const SizedBox(height: 12),
                ],

                // #13: 지출 계획
                if (result.spendingPlan.isNotEmpty) ...[
                  _buildSectionCard(
                    context,
                    title: loc.tr('spendingPlan'),
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue,
                    child: Text(result.spendingPlan, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                  const SizedBox(height: 12),
                ],

                // 소비 패턴
                _buildPatternCard(context, loc, result.pattern),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, AppLocalizations loc, DateFormat dateFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(loc.tr('analysisPeriod'), '${dateFormat.format(widget.record.startDate)} ~ ${dateFormat.format(widget.record.endDate)}'),
            const Divider(height: 16),
            _buildInfoRow(loc.tr('responseTone'), _getToneLabel(widget.record.tone, loc)),
            const Divider(height: 16),
            _buildInfoRow(loc.tr('analyzedAt'), DateFormat('yyyy.MM.dd HH:mm').format(widget.record.analyzedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildOneLinerCard(BuildContext context, String oneLiner) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.format_quote, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              oneLiner,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildListSectionCard(BuildContext context, {required String title, required IconData icon, required Color iconColor, required List<String> items}) {
    return _buildSectionCard(
      context,
      title: title,
      icon: icon,
      iconColor: iconColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 14, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPatternCard(BuildContext context, AppLocalizations loc, SpendingPattern pattern) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(loc.tr('spendingPattern'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            _buildPatternRow(loc.tr('mainCategory'), pattern.mainCategory),
            const Divider(height: 16),
            _buildPatternRow(loc.tr('spendingTrend'), _getTrendText(pattern.spendingTrend, loc)),
            const Divider(height: 16),
            _buildPatternRow(loc.tr('savingPotential'), context.formatCurrency(pattern.savingPotential)),
            const Divider(height: 16),
            _buildPatternRow(loc.tr('riskLevel'), _getRiskText(pattern.riskLevel, loc), riskLevel: pattern.riskLevel),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternRow(String label, String value, {String? riskLevel}) {
    Color? valueColor;
    if (riskLevel != null) {
      switch (riskLevel) {
        case 'low': valueColor = Colors.green;
        case 'medium': valueColor = Colors.orange;
        case 'high': valueColor = Colors.red;
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  String _getToneLabel(String tone, AppLocalizations loc) {
    switch (tone) {
      case 'gentle': return loc.tr('toneGentle');
      case 'praise': return loc.tr('tonePraise');
      case 'factual': return loc.tr('toneFactual');
      case 'coach': return loc.tr('toneCoach');
      case 'humorous': return loc.tr('toneHumorous');
      default: return tone;
    }
  }

  String _getTrendText(String trend, AppLocalizations loc) {
    switch (trend) {
      case 'increasing': return loc.tr('trendIncreasing');
      case 'decreasing': return loc.tr('trendDecreasing');
      case 'stable': return loc.tr('trendStable');
      default: return trend;
    }
  }

  String _getRiskText(String risk, AppLocalizations loc) {
    switch (risk) {
      case 'low': return loc.tr('riskLow');
      case 'medium': return loc.tr('riskMedium');
      case 'high': return loc.tr('riskHigh');
      default: return risk;
    }
  }

  // #27, #31: 이미지로 내보내기 (웹/네이티브 플랫폼 분기 처리)
  Future<void> _exportAsImage(BuildContext context) async {
    final loc = context.loc;

    setState(() => _isExporting = true);

    try {
      // 위젯을 이미지로 캡처
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Capture failed');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Image conversion failed');
      }

      final bytes = byteData.buffer.asUint8List();
      final fileName = 'budget_analysis_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

      // #31: 플랫폼별 저장/공유 처리
      final success = await image_saver.saveAndShareImage(
        bytes,
        fileName,
        loc.tr('analysisResult'),
      );

      if (!success && context.mounted) {
        throw Exception('Save failed');
      }

      // #31: 웹에서는 다운로드 성공 메시지 표시
      if (kIsWeb && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.tr('downloadStarted'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.tr('exportFailed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
