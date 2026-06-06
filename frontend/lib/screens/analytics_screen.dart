import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/analytics_charts.dart';

class AnalyticsScreen extends StatefulWidget {
  final int surveyId;
  const AnalyticsScreen({super.key, required this.surveyId});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
  late final ExportsApi _exports = ExportsApi(context.read<ApiClient>());
  Map<String, dynamic>? data;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      data = await _api.analytics(widget.surveyId);
      setState(() {});
    } catch (e) {
      setState(() => _err = e.toString());
    }
  }

  Future<void> _openExportSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExportSheet(
        onExport: (fmt, incompl, synth) async {
          // Закрываем шит сразу — скачивание идёт в фоне, прогресс показываем
          // SnackBar'ом; иначе пользователь не понимает, что что-то происходит.
          Navigator.of(context).pop();
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(SnackBar(
            content: Row(children: const [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Готовим файл...', style: TextStyle(fontFamily: 'HSESans')),
            ]),
            duration: const Duration(minutes: 2),
          ));
          try {
            await _exports.download(
              widget.surveyId, fmt,
              includeIncomplete: incompl,
              includeSynthetic: synth,
            );
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(SnackBar(
              content: Text('Файл «${fmt.label}» скачан',
                  style: const TextStyle(fontFamily: 'HSESans')),
              duration: const Duration(seconds: 3),
            ));
          } catch (e) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(SnackBar(
              content: Text('Ошибка экспорта: $e',
                  style: const TextStyle(fontFamily: 'HSESans')),
              backgroundColor: Colors.red.shade700,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/')),
        title: const Text('Аналитика', style: TextStyle(fontFamily: 'HSESans')),
        actions: [
          // Активируем кнопку только когда есть данные — иначе кнопка
          // позволила бы скачать пустой/неполный датасет до загрузки.
          TextButton.icon(
            onPressed: data == null ? null : _openExportSheet,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Экспорт',
                style: TextStyle(fontFamily: 'HSESans')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _err != null
          ? Center(child: Text(_err!))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          _stat('Всего ответов',
                              data!['total_responses'].toString()),
                          const SizedBox(width: 32),
                          _stat('Завершённых',
                              data!['completed_responses'].toString()),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final q in (data!['questions'] as List))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: QuestionAnalyticsCard(
                          question: (q as Map).cast<String, dynamic>(),
                          // trend_bin — шаг бакетов для тренда, общий
                          // для всего опроса. Бэк выбирает авто по
                          // разбросу submitted_at. Фолбэк на 'day' нужен
                          // на случай, если фронт пересоберут с новым
                          // кодом раньше, чем выкатят backend (старый
                          // ответ не содержит этого поля).
                          trendBin:
                              (data!['trend_bin'] as String?) ?? 'day',
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'HSESans', color: HseColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontFamily: 'HSESans',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: HseColors.primary)),
      ]);

}

/// Modal bottom sheet выбора формата экспорта.
///
/// Stateful, потому что чекбоксы фильтров должны помнить выбор между
/// тапами по форматам. Логика скачивания вынесена в callback, чтобы шит
/// не зависел от ApiClient напрямую — проще тестировать.
class _ExportSheet extends StatefulWidget {
  final Future<void> Function(ExportFormat fmt, bool incomplete, bool synthetic) onExport;
  const _ExportSheet({required this.onExport});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _includeIncomplete = true;
  bool _includeSynthetic = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 4,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Экспорт ответов',
                  style: TextStyle(
                      fontFamily: 'HSESans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Выберите формат — файл скачается в этом окне браузера.',
                style: TextStyle(
                    fontFamily: 'HSESans', color: HseColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Глобальные фильтры. Применяются только к форматам, которые
              // их поддерживают (codebook/aggregated — нет). Делаем это
              // явно visible-disabled, а не молча скрываем — пользователь
              // должен понимать, что фильтры есть, но к codebook не лепятся.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HseColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(HseRadius.md),
                ),
                child: Column(children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Включить незавершённые ответы',
                        style: TextStyle(fontFamily: 'HSESans', fontSize: 14)),
                    subtitle: const Text(
                      'Те, кто открыл опрос, но не нажал «Отправить»',
                      style: TextStyle(
                          fontFamily: 'HSESans',
                          color: HseColors.muted,
                          fontSize: 12),
                    ),
                    value: _includeIncomplete,
                    onChanged: (v) => setState(() => _includeIncomplete = v ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Включить AI-сгенерированных респондентов',
                        style: TextStyle(fontFamily: 'HSESans', fontSize: 14)),
                    subtitle: const Text(
                      'Помечены `is_synthetic=1` в датасете',
                      style: TextStyle(
                          fontFamily: 'HSESans',
                          color: HseColors.muted,
                          fontSize: 12),
                    ),
                    value: _includeSynthetic,
                    onChanged: (v) => setState(() => _includeSynthetic = v ?? true),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Список форматов. Каждый — отдельная карточка-кнопка, чтобы
              // тач-таргет был большим (мобильные устройства тоже).
              for (final f in ExportsApi.formats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FormatTile(
                    format: f,
                    filtersApplied: f.supportsFilters,
                    onTap: () => widget.onExport(f, _includeIncomplete, _includeSynthetic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final ExportFormat format;
  final bool filtersApplied;
  final VoidCallback onTap;
  const _FormatTile({
    required this.format,
    required this.filtersApplied,
    required this.onTap,
  });

  IconData get _icon {
    switch (format.id) {
      case 'csv_wide':
      case 'csv_long':
      case 'codebook':
        return Icons.table_chart_outlined;
      case 'xlsx':
        return Icons.grid_on_outlined;
      case 'sav':
        return Icons.science_outlined;
      case 'json_raw':
      case 'json_aggregated':
        return Icons.data_object_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HseRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: HseColors.border),
          borderRadius: BorderRadius.circular(HseRadius.md),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: HseColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: HseColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(format.label,
                      style: const TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (!filtersApplied) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HseColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('фильтры не применяются',
                          style: TextStyle(
                              fontFamily: 'HSESans',
                              fontSize: 10,
                              color: HseColors.muted)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(format.description,
                    style: const TextStyle(
                        fontFamily: 'HSESans',
                        color: HseColors.muted,
                        fontSize: 12.5,
                        height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.download_rounded, color: HseColors.muted, size: 20),
        ]),
      ),
    );
  }
}
