import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../theme.dart';


/// Researcher-facing dialog: configure persona + count + model, then trigger
/// backend to generate AI respondents. Their answers go into the DB exactly
/// like real ones, so analytics picks them up automatically (Response.is_synthetic
/// just flags them for later filtering if needed).
class SyntheticDialog extends StatefulWidget {
  final int surveyId;
  const SyntheticDialog({super.key, required this.surveyId});

  @override
  State<SyntheticDialog> createState() => _SyntheticDialogState();
}

class _Preset {
  final String label;
  final Map<String, String> values;
  const _Preset(this.label, this.values);
}

const _presets = <_Preset>[
  _Preset('Свой профиль', {}),
  _Preset('Студент ВШЭ', {
    'year': '2025',
    'gender': 'male',
    'country': 'Россия',
    'age': '20',
    'education': 'неполное высшее (бакалавриат, 3 курс)',
    'income': 'низкий (стипендия + подработка)',
    'occupation': 'студент',
    'social_class': 'middle',
    'marital_status': 'single',
    'children': '0',
    'religion': 'нет',
    'language': 'русский',
  }),
  _Preset('Московский профессионал', {
    'year': '2025',
    'gender': 'female',
    'country': 'Россия',
    'age': '32',
    'education': 'высшее (магистратура)',
    'income': 'выше среднего',
    'occupation': 'product manager в IT',
    'social_class': 'upper-middle',
    'marital_status': 'married',
    'children': '1',
    'religion': 'нет',
    'language': 'русский',
  }),
  _Preset('Пенсионер из региона', {
    'year': '2025',
    'gender': 'female',
    'country': 'Россия',
    'age': '68',
    'education': 'среднее специальное',
    'income': 'низкий (пенсия)',
    'occupation': 'пенсионер (бывший бухгалтер)',
    'social_class': 'lower-middle',
    'marital_status': 'widowed',
    'children': '2',
    'religion': 'православие',
    'language': 'русский',
  }),
  _Preset('Школьник', {
    'year': '2025',
    'gender': 'male',
    'country': 'Россия',
    'age': '16',
    'education': 'школа, 10 класс',
    'income': 'на иждивении',
    'occupation': 'школьник',
    'social_class': 'middle',
    'marital_status': 'single',
    'children': '0',
    'religion': 'нет',
    'language': 'русский',
  }),
];

/// Hard-coded for now. Бэк сам решает, на какой провайдер слать
/// (см. LLM_PROVIDER в .env). Это имя модели в формате конкретного провайдера:
///   • groq:       'llama-3.3-70b-versatile' (рекоменд., 30 RPM, 14400 RPD free)
///   • openrouter: 'meta-llama/llama-3.3-70b-instruct:free'
const _fixedModel = 'llama-3.3-70b-versatile';

class _SyntheticDialogState extends State<SyntheticDialog> {
  late SurveysApi _api;
  late final Map<String, TextEditingController> _ctrls;

  int _presetIdx = 1; // default: Студент ВШЭ
  final String _model = _fixedModel;
  int _count = 5;
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  static const _fields = <(String key, String label)>[
    ('year', 'Год'),
    ('gender', 'Пол'),
    ('country', 'Страна'),
    ('age', 'Возраст'),
    ('education', 'Образование'),
    ('income', 'Уровень дохода'),
    ('occupation', 'Род занятий'),
    ('social_class', 'Социальный класс'),
    ('marital_status', 'Семейное положение'),
    ('children', 'Дети (кол-во)'),
    ('religion', 'Религия'),
    ('language', 'Язык'),
  ];

  @override
  void initState() {
    super.initState();
    _api = SurveysApi(context.read<ApiClient>());
    _ctrls = {
      for (final f in _fields) f.$1: TextEditingController(),
    };
    _applyPreset(_presetIdx);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(int idx) {
    final preset = _presets[idx];
    setState(() {
      _presetIdx = idx;
      if (preset.values.isEmpty) {
        // "Свой профиль" — leave existing values, just switch indicator.
        return;
      }
      for (final f in _fields) {
        _ctrls[f.$1]!.text = preset.values[f.$1] ?? '';
      }
    });
  }

  Map<String, dynamic> _personaPayload() {
    final out = <String, dynamic>{};
    for (final f in _fields) {
      final v = _ctrls[f.$1]!.text.trim();
      if (v.isNotEmpty) out[f.$1] = v;
    }
    return out;
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await _api.runSynthetic(
        widget.surveyId,
        persona: _personaPayload(),
        count: _count,
        model: _model,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: HseColors.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Синтетические респонденты',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  const Text(
                    'AI пройдёт опрос за выбранную персону. Ответы попадут в аналитику как реальные.',
                    style: TextStyle(color: HseColors.muted, fontSize: 12.5),
                  ),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _busy ? null : () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: _result != null ? _buildResult() : _buildForm(),
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1AE05656),
                  borderRadius: BorderRadius.circular(HseRadius.sm),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: HseColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: HseColors.danger, fontSize: 13))),
                ]),
              ),
            ),
            Row(children: [
              if (_result != null) TextButton(
                onPressed: () => setState(() { _result = null; _error = null; }),
                child: const Text('Запустить ещё'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              const SizedBox(width: 8),
              if (_result == null) GradientButton(
                icon: Icons.play_arrow_rounded,
                onPressed: _busy ? null : _run,
                child: Text(_busy ? 'Генерируем…' : 'Запустить ($_count шт.)'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Preset chips
      const Text('ПРЕСЕТ', style: TextStyle(
          color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 0; i < _presets.length; i++) ChoiceChip(
          label: Text(_presets[i].label),
          selected: _presetIdx == i,
          onSelected: _busy ? null : (_) => _applyPreset(i),
        ),
      ]),
      const SizedBox(height: 18),

      // Persona fields
      const Text('ПЕРСОНА', style: TextStyle(
          color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 4.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          for (final f in _fields) TextField(
            controller: _ctrls[f.$1],
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: f.$2,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) {
              // any edit → switch preset to "Свой профиль"
              if (_presetIdx != 0) setState(() => _presetIdx = 0);
            },
          ),
        ],
      ),

      const SizedBox(height: 20),

      // Generation params
      const Text('ПАРАМЕТРЫ ЗАПУСКА', style: TextStyle(
          color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(
          width: 140,
          child: TextField(
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Количество', isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            controller: TextEditingController(text: '$_count'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v.trim());
              if (n != null && n > 0 && n <= 50) _count = n;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: HseColors.surface,
              borderRadius: BorderRadius.circular(HseRadius.sm),
            ),
            child: Row(children: [
              const Icon(Icons.smart_toy_outlined, size: 16, color: HseColors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _model,
                style: const TextStyle(fontSize: 12.5, color: HseColors.inkSoft, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HseColors.surfaceAlt,
          borderRadius: BorderRadius.circular(HseRadius.sm),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: HseColors.muted),
          SizedBox(width: 8),
          Expanded(child: Text(
            'Запрос к OpenRouter тарифицируется по аккаунту админа. '
            'Лимит — 50 респондентов за раз, генерация ~1–3 сек на каждого.',
            style: TextStyle(color: HseColors.inkSoft, fontSize: 12),
          )),
        ]),
      ),
    ]);
  }

  Widget _buildResult() {
    final r = _result!;
    final succeeded = (r['succeeded'] ?? 0) as int;
    final failed = (r['failed'] ?? 0) as int;
    final results = (r['results'] as List?) ?? const [];
    final errors = [
      for (final x in results)
        if (x is Map && x['ok'] == false && x['error'] != null) x['error'].toString()
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _stat('Запрошено', '${r['requested'] ?? 0}', HseColors.primary),
        const SizedBox(width: 10),
        _stat('Создано', '$succeeded', HseColors.success),
        const SizedBox(width: 10),
        _stat('Ошибок', '$failed', failed > 0 ? HseColors.danger : HseColors.muted),
      ]),
      const SizedBox(height: 18),
      Text('Модель: ${r['model']}',
          style: const TextStyle(color: HseColors.inkSoft, fontSize: 12.5)),
      const SizedBox(height: 12),
      if (errors.isNotEmpty) ...[
        const Text('ОШИБКИ', style: TextStyle(
            color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
        const SizedBox(height: 6),
        for (final e in errors.take(10)) Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x1AE05656),
            borderRadius: BorderRadius.circular(HseRadius.sm),
          ),
          child: Text(e, style: const TextStyle(color: HseColors.danger, fontSize: 12)),
        ),
        if (errors.length > 10) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('… ещё ${errors.length - 10} ошибок',
              style: const TextStyle(color: HseColors.muted, fontSize: 12)),
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x1A2E9D6E),
            borderRadius: BorderRadius.circular(HseRadius.sm),
          ),
          child: const Row(children: [
            Icon(Icons.check_circle_rounded, color: HseColors.success, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Все ответы записаны в БД. Откройте «Аналитику», чтобы увидеть их.',
              style: TextStyle(color: HseColors.success, fontWeight: FontWeight.w600, fontSize: 13),
            )),
          ]),
        ),
    ]);
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(HseRadius.md),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: HseColors.inkSoft, fontSize: 12)),
        ]),
      ),
    );
  }
}
