import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';

/// Диалог импорта структуры опроса из Google Forms / Яндекс Форм по URL.
///
/// Один TextField + кнопка «Импортировать» + место под ошибку и
/// под отчёт-статистику. Сознательно не показываем preview импортированных
/// вопросов до подтверждения: бэкенд их в любом случае дописывает в конец
/// (а не заменяет), а полноценный UI выбора «какие импортировать»
/// — это уже отдельная фича, в курсовую не закладывалась.
///
/// После успеха закрывает диалог и через [onImported] отдаёт наверх
/// обновлённый Survey — экран билдера обновляет своё состояние без
/// дополнительного запроса.
class ImportDialog extends StatefulWidget {
  final int surveyId;
  final void Function(Survey updated) onImported;

  const ImportDialog({
    super.key,
    required this.surveyId,
    required this.onImported,
  });

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _urlCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Вставьте ссылку на форму');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _api.importFromUrl(widget.surveyId, url);
      if (!mounted) return;
      widget.onImported(res.survey);
      Navigator.of(context).pop();
      // Показываем отчёт в snackbar родительского Scaffold — это удобнее,
      // чем держать диалог открытым после успеха.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _formatReport(res.provider, res.importedCount, res.skippedCount),
          style: const TextStyle(fontFamily: 'HSESans'),
        ),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanError(e);
        _busy = false;
      });
    }
  }

  /// Превращает голую error-обёртку с бэкенда (там обычно «ApiException:
  /// 400 — текст») в просто текст для пользователя.
  String _humanError(Object e) {
    final s = e.toString();
    final idx = s.indexOf(':');
    final tail = idx >= 0 ? s.substring(idx + 1).trim() : s;
    return tail.isEmpty ? s : tail;
  }

  String _formatReport(String provider, int imported, int skipped) {
    final name = switch (provider) {
      'google' => 'Google Forms',
      'yandex' => 'Яндекс Формы',
      _ => provider,
    };
    final parts = <String>[
      'Импортировано из $name: $imported вопрос(ов)',
    ];
    if (skipped > 0) {
      parts.add('пропущено $skipped (неподдерживаемые типы — '
          'сетки, дата/время, file upload и т.п.)');
    }
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Импорт опроса',
        style: TextStyle(fontFamily: 'HSESans'),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Вставьте ссылку на публичный опрос Google Forms или Яндекс Форм. '
              'Импортируются только поддерживаемые типы вопросов: текст, '
              'выбор одного / нескольких вариантов, выпадающий список, шкала, '
              'разделитель. Вопросы дописываются в конец текущего опроса.',
              style: TextStyle(
                fontFamily: 'HSESans',
                fontSize: 13.5,
                color: HseColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              enabled: !_busy,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'https://docs.google.com/forms/d/.../viewform',
                labelText: 'Ссылка на форму',
              ),
              onSubmitted: (_) => _busy ? null : _run(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HseColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(HseRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: HseColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontFamily: 'HSESans',
                          color: HseColors.danger,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена',
              style: TextStyle(fontFamily: 'HSESans')),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_download_outlined, size: 18),
          label: Text(_busy ? 'Импортируем…' : 'Импортировать',
              style: const TextStyle(fontFamily: 'HSESans')),
        ),
      ],
    );
  }
}
