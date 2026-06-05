/// Карточка одного вопроса в аналитике с переключаемыми типами графиков
/// и компактной описательной статистикой над графиком.
///
/// Виды:
///   • categorical (single/multi/dropdown) — bar/hbar/pie/donut/table
///   • numeric (scale/rating/number)       — histogram/line/table
///   • text (short/long)                   — samples/wordFreq
///
/// Базовые показатели:
///   • categorical: N, уникальных, мода и её доля
///   • numeric:    N, среднее, медиана, SD, IQR, диапазон
///                 (медиана/квартили/SD считаются на клиенте, реконструируя
///                 выборку из histogram'а: бекенд уже округлил значения,
///                 потому реконструкция точна для интов и приближена для
///                 нецелых scale — погрешность ≤ 0.5)
///   • text:       N сэмплов, средняя длина ответа
///
/// Стейт типа графика — внутри карточки (StatefulWidget). Один экран
/// аналитики может содержать десятки карточек; держать состояние на уровне
/// AnalyticsScreen означало бы Map<int, ChartType>, лишние setState на весь
/// экран и сложное состояние во время скролла. Атомарная карточка — проще.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme.dart';

// Палитра для категориальных сегментов / pie-слайсов. Подобрана так, чтобы
// первые цвета — фирменные HSE-синие, потом — контрастные акценты для
// случаев, когда вариантов больше пяти. Циклится по модулю, если их ещё
// больше — это лучше, чем подбирать «бесконечный» градиент, у которого
// соседние слайсы становятся неразличимы.
const List<Color> _palette = [
  HseColors.primary,
  HseColors.primaryBright,
  HseColors.accent,
  Color(0xFF06A77D),
  Color(0xFFF77F00),
  Color(0xFFE63946),
  Color(0xFF9B5DE5),
  Color(0xFF00B4D8),
  Color(0xFFFFBE0B),
  Color(0xFF7A5C8F),
];

Color _colorFor(int i) => _palette[i % _palette.length];

// ─────────────────────────── enums типов графика ─────────────────────────

enum _CatChart { bar, hbar, pie, donut, table }
enum _NumChart { histogram, line, table }
enum _TxtChart { samples, words }

extension on _CatChart {
  String get label => switch (this) {
        _CatChart.bar => 'Бар',
        _CatChart.hbar => 'Гор. бар',
        _CatChart.pie => 'Круг',
        _CatChart.donut => 'Кольцо',
        _CatChart.table => 'Таблица',
      };
  IconData get icon => switch (this) {
        _CatChart.bar => Icons.bar_chart,
        _CatChart.hbar => Icons.align_horizontal_left,
        _CatChart.pie => Icons.pie_chart,
        _CatChart.donut => Icons.donut_large,
        _CatChart.table => Icons.table_rows_outlined,
      };
}

extension on _NumChart {
  String get label => switch (this) {
        _NumChart.histogram => 'Гистограмма',
        _NumChart.line => 'Линия',
        _NumChart.table => 'Таблица',
      };
  IconData get icon => switch (this) {
        _NumChart.histogram => Icons.bar_chart,
        _NumChart.line => Icons.show_chart,
        _NumChart.table => Icons.table_rows_outlined,
      };
}

extension on _TxtChart {
  String get label => switch (this) {
        _TxtChart.samples => 'Примеры',
        _TxtChart.words => 'Частота слов',
      };
  IconData get icon => switch (this) {
        _TxtChart.samples => Icons.format_quote,
        _TxtChart.words => Icons.text_fields,
      };
}

// ─────────────────────────── публичный виджет ───────────────────────────

class QuestionAnalyticsCard extends StatefulWidget {
  final Map<String, dynamic> question; // raw item из /analytics
  const QuestionAnalyticsCard({super.key, required this.question});

  @override
  State<QuestionAnalyticsCard> createState() => _QuestionAnalyticsCardState();
}

class _QuestionAnalyticsCardState extends State<QuestionAnalyticsCard> {
  _CatChart _cat = _CatChart.bar;
  _NumChart _num = _NumChart.histogram;
  _TxtChart _txt = _TxtChart.samples;

  String _pluralAnswers(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return '$n ответов';
    return switch (n % 10) {
      1 => '$n ответ',
      2 || 3 || 4 => '$n ответа',
      _ => '$n ответов',
    };
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final type = q['type'] as String? ?? '';
    final total = (q['total_answers'] as num?)?.toInt() ?? 0;
    final dist = (q['distribution'] as Map?)?.cast<String, dynamic>() ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q['title'] as String? ?? '',
                style: const TextStyle(
                    fontFamily: 'HSESans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            Text(_pluralAnswers(total),
                style: const TextStyle(
                    fontFamily: 'HSESans',
                    color: HseColors.muted,
                    fontSize: 12)),
            if (total > 0) ...[
              const SizedBox(height: 12),
              _statsRow(type, dist),
              const SizedBox(height: 12),
              _chipBar(type),
              const SizedBox(height: 12),
              _chartBody(type, dist),
            ] else ...[
              const SizedBox(height: 16),
              const Text('Нет данных',
                  style: TextStyle(
                      fontFamily: 'HSESans', color: HseColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────── переключатель типов графика ──────────────────────

  Widget _chipBar(String type) {
    if (_isCat(type)) {
      return _ChartChipBar<_CatChart>(
        values: _CatChart.values,
        selected: _cat,
        onChanged: (v) => setState(() => _cat = v),
        labelOf: (v) => v.label,
        iconOf: (v) => v.icon,
      );
    }
    if (_isNum(type)) {
      return _ChartChipBar<_NumChart>(
        values: _NumChart.values,
        selected: _num,
        onChanged: (v) => setState(() => _num = v),
        labelOf: (v) => v.label,
        iconOf: (v) => v.icon,
      );
    }
    return _ChartChipBar<_TxtChart>(
      values: _TxtChart.values,
      selected: _txt,
      onChanged: (v) => setState(() => _txt = v),
      labelOf: (v) => v.label,
      iconOf: (v) => v.icon,
    );
  }

  // ────────────────────────── базовая статистика ────────────────────────

  Widget _statsRow(String type, Map<String, dynamic> dist) {
    final badges = <String>[];
    if (_isCat(type)) {
      final s = _CatStats.from(dist);
      badges.add('N=${s.total}');
      badges.add('уникальных: ${s.unique}');
      if (s.modeKey != null && s.total > 0) {
        final pct = (s.modeCount / s.total * 100).toStringAsFixed(0);
        badges.add('мода: «${_truncate(s.modeKey!, 24)}» ($pct%)');
      }
    } else if (_isNum(type)) {
      final s = _NumStats.from(dist);
      badges.add('N=${s.n}');
      badges.add('M=${s.mean.toStringAsFixed(2)}');
      badges.add('Mdn=${_fmtNum(s.median)}');
      badges.add('SD=${s.std.toStringAsFixed(2)}');
      badges.add('IQR: ${_fmtNum(s.q1)}–${_fmtNum(s.q3)}');
      badges.add('диапазон: ${_fmtNum(s.min)}–${_fmtNum(s.max)}');
    } else {
      final samples = (dist['sample'] as List?)?.cast<String>() ?? const [];
      if (samples.isNotEmpty) {
        final avg = samples.fold<int>(0, (a, s) => a + s.length) / samples.length;
        badges.add('N сэмплов: ${samples.length}');
        badges.add('ср. длина: ${avg.toStringAsFixed(0)} симв.');
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [for (final b in badges) _Badge(text: b)],
    );
  }

  // ────────────────────────── тело графика ──────────────────────────────

  Widget _chartBody(String type, Map<String, dynamic> dist) {
    if (_isCat(type)) {
      switch (_cat) {
        case _CatChart.bar:
          return _CategoricalBar(dist: dist, horizontal: false);
        case _CatChart.hbar:
          return _CategoricalBar(dist: dist, horizontal: true);
        case _CatChart.pie:
          return _CategoricalPie(dist: dist, donut: false);
        case _CatChart.donut:
          return _CategoricalPie(dist: dist, donut: true);
        case _CatChart.table:
          return _CategoricalTable(dist: dist);
      }
    }
    if (_isNum(type)) {
      final hist = (dist['histogram'] as Map?) ?? const {};
      switch (_num) {
        case _NumChart.histogram:
          return _NumericBars(hist: hist);
        case _NumChart.line:
          return _NumericLine(hist: hist);
        case _NumChart.table:
          return _NumericTable(stats: _NumStats.from(dist), hist: hist);
      }
    }
    // text
    final samples = (dist['sample'] as List?)?.cast<String>() ?? const [];
    return _txt == _TxtChart.samples
        ? _TextSamples(samples: samples)
        : _TextWordFreq(samples: samples);
  }

  static bool _isCat(String t) =>
      t == 'single_choice' || t == 'multiple_choice' || t == 'dropdown';
  static bool _isNum(String t) =>
      t == 'scale' || t == 'rating' || t == 'number';

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';
  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ─────────────────────────── чипы переключателя ─────────────────────────

class _ChartChipBar<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  const _ChartChipBar({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    required this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final v in values) ...[
            _chip(v),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _chip(T v) {
    final isSel = v == selected;
    return InkWell(
      onTap: () => onChanged(v),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? HseColors.primary : HseColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSel ? HseColors.primary : HseColors.border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(iconOf(v),
              size: 14, color: isSel ? Colors.white : HseColors.inkSoft),
          const SizedBox(width: 6),
          Text(labelOf(v),
              style: TextStyle(
                  fontFamily: 'HSESans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : HseColors.inkSoft)),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HseColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              fontFamily: 'HSESans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HseColors.inkSoft)),
    );
  }
}

// ─────────────────────────── статистика ─────────────────────────────────

class _CatStats {
  final int total, unique, modeCount;
  final String? modeKey;
  const _CatStats({
    required this.total,
    required this.unique,
    required this.modeKey,
    required this.modeCount,
  });

  factory _CatStats.from(Map<String, dynamic> dist) {
    if (dist.isEmpty) {
      return const _CatStats(total: 0, unique: 0, modeKey: null, modeCount: 0);
    }
    int total = 0, modeCount = 0;
    String? modeKey;
    dist.forEach((k, v) {
      final c = (v as num).toInt();
      total += c;
      if (c > modeCount) {
        modeCount = c;
        modeKey = k;
      }
    });
    return _CatStats(
        total: total, unique: dist.length, modeKey: modeKey, modeCount: modeCount);
  }
}

class _NumStats {
  final int n;
  final double mean, median, std, min, max, q1, q3;
  const _NumStats({
    required this.n,
    required this.mean,
    required this.median,
    required this.std,
    required this.min,
    required this.max,
    required this.q1,
    required this.q3,
  });

  factory _NumStats.from(Map<String, dynamic> dist) {
    final hist = (dist['histogram'] as Map?) ?? const {};
    final mean = (dist['avg'] as num?)?.toDouble() ?? 0.0;
    final minV = (dist['min'] as num?)?.toDouble() ?? 0.0;
    final maxV = (dist['max'] as num?)?.toDouble() ?? 0.0;

    // Реконструируем выборку из histogram'а — он у нас целочисленный
    // ({"3": 12, "4": 30, ...}), так что реконструкция полностью точная
    // для интов и приближённая для нецелых scale (которые backend округлил
    // в _aggregate; погрешность ≤ 0.5).
    final samples = <double>[];
    hist.forEach((k, v) {
      final x = double.tryParse(k.toString());
      final c = (v as num?)?.toInt() ?? 0;
      if (x == null) return;
      for (int i = 0; i < c; i++) samples.add(x);
    });
    samples.sort();
    final n = samples.length;
    if (n == 0) {
      return _NumStats(
          n: 0, mean: 0, median: 0, std: 0, min: 0, max: 0, q1: 0, q3: 0);
    }
    final median = _percentile(samples, 0.5);
    final q1 = _percentile(samples, 0.25);
    final q3 = _percentile(samples, 0.75);
    // Sample std (n-1 в знаменателе) — стандарт для социальных наук.
    final variance = n > 1
        ? samples.fold<double>(0, (a, x) => a + (x - mean) * (x - mean)) /
            (n - 1)
        : 0.0;
    return _NumStats(
      n: n,
      mean: mean,
      median: median,
      std: math.sqrt(variance),
      min: minV,
      max: maxV,
      q1: q1,
      q3: q3,
    );
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final idx = p * (sorted.length - 1);
    final lo = idx.floor();
    final hi = idx.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
  }
}

// ─────────────────────────── категориальные графики ─────────────────────

class _CategoricalBar extends StatelessWidget {
  final Map<String, dynamic> dist;
  final bool horizontal;
  const _CategoricalBar({required this.dist, required this.horizontal});

  @override
  Widget build(BuildContext context) {
    final entries = dist.entries.toList();
    final maxV =
        entries.fold<num>(0, (m, e) => (e.value as num) > m ? e.value : m).toDouble();
    if (maxV == 0) return const SizedBox.shrink();

    if (horizontal) {
      // Горизонтальный бар — полезен когда подписи длинные. fl_chart не имеет
      // отдельного «горизонтального» режима, поэтому делаем вручную
      // через ряды с прогресс-барами — это и проще читается, чем повёрнутый
      // BarChart, и не требует RotatedBox-хаков.
      return Column(
        children: [
          for (int i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 120,
                  child: Text(entries[i].key,
                      style: const TextStyle(
                          fontFamily: 'HSESans', fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (entries[i].value as num) / maxV,
                      minHeight: 16,
                      backgroundColor: HseColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(_colorFor(i)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text((entries[i].value as num).toInt().toString(),
                      style: const TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ]),
            ),
        ],
      );
    }

    return SizedBox(
      height: (entries.length * 36 + 60).clamp(160, 320).toDouble(),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV * 1.1, // запас сверху, чтобы лейблы не липли к крышке
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: _niceStep(maxV),
                getTitlesWidget: (v, _) {
                  if (v != v.roundToDouble()) return const SizedBox();
                  return Text(v.toInt().toString(),
                      style: const TextStyle(
                          fontFamily: 'HSESans', fontSize: 11));
                }),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 70,
                    child: Text(entries[i].key,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'HSESans', fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (int i = 0; i < entries.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: (entries[i].value as num).toDouble(),
                color: _colorFor(i),
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      )),
    );
  }

  // Грубо подбирает шаг для оси Y, чтобы лейблы не сливались (1, 2, 5, 10,
  // 20, 50, ...). Без этого fl_chart с дробным interval рендерит ось каждые
  // 0.x — рябит в глазах.
  static double _niceStep(double maxV) {
    if (maxV <= 5) return 1;
    if (maxV <= 10) return 2;
    if (maxV <= 50) return 5;
    if (maxV <= 100) return 10;
    if (maxV <= 500) return 50;
    return (maxV / 5).roundToDouble();
  }
}

class _CategoricalPie extends StatelessWidget {
  final Map<String, dynamic> dist;
  final bool donut;
  const _CategoricalPie({required this.dist, required this.donut});

  @override
  Widget build(BuildContext context) {
    final entries = dist.entries.toList();
    final total =
        entries.fold<num>(0, (a, e) => a + (e.value as num)).toDouble();
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 240,
      child: Row(children: [
        // Сам круг
        Expanded(
          flex: 5,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: donut ? 50 : 0,
            sections: [
              for (int i = 0; i < entries.length; i++)
                PieChartSectionData(
                  value: (entries[i].value as num).toDouble(),
                  color: _colorFor(i),
                  // Маленькие сегменты (<5%) скрываем подпись, чтобы не
                  // ломать визуал; для них есть легенда справа.
                  title: (entries[i].value as num) / total >= 0.05
                      ? '${((entries[i].value as num) / total * 100).round()}%'
                      : '',
                  radius: donut ? 56 : 90,
                  titleStyle: const TextStyle(
                      fontFamily: 'HSESans',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
            ],
          )),
        ),
        const SizedBox(width: 8),
        // Легенда
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _colorFor(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entries[i].key,
                            style: const TextStyle(
                                fontFamily: 'HSESans', fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text(
                          '${(entries[i].value as num).toInt()} · ${((entries[i].value as num) / total * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontFamily: 'HSESans',
                              fontSize: 11,
                              color: HseColors.muted)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _CategoricalTable extends StatelessWidget {
  final Map<String, dynamic> dist;
  const _CategoricalTable({required this.dist});

  @override
  Widget build(BuildContext context) {
    final entries = dist.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final total =
        entries.fold<num>(0, (a, e) => a + (e.value as num)).toDouble();
    if (total == 0) return const SizedBox.shrink();

    TextStyle head() => const TextStyle(
        fontFamily: 'HSESans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: HseColors.inkSoft);
    TextStyle body() =>
        const TextStyle(fontFamily: 'HSESans', fontSize: 13);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: HseColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HseColors.surfaceAlt,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Expanded(flex: 6, child: Text('Вариант', style: head())),
            Expanded(flex: 2, child: Text('N', style: head(), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('%', style: head(), textAlign: TextAlign.right)),
          ]),
        ),
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: HseColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                flex: 6,
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _colorFor(i),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entries[i].key,
                        style: body(), overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
              Expanded(
                flex: 2,
                child: Text((entries[i].value as num).toInt().toString(),
                    style: body(), textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(
                    '${((entries[i].value as num) / total * 100).toStringAsFixed(1)}%',
                    style: body(), textAlign: TextAlign.right),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────── числовые графики ───────────────────────────

class _NumericBars extends StatelessWidget {
  final Map hist;
  const _NumericBars({required this.hist});

  @override
  Widget build(BuildContext context) {
    final entries = hist.entries.toList()
      ..sort((a, b) => int.parse(a.key.toString())
          .compareTo(int.parse(b.key.toString())));
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxV =
        entries.fold<num>(0, (m, e) => (e.value as num) > m ? e.value : m).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV * 1.1,
        barGroups: [
          for (final e in entries)
            BarChartGroupData(x: int.parse(e.key.toString()), barRods: [
              BarChartRodData(
                toY: (e.value as num).toDouble(),
                color: HseColors.primary,
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      )),
    );
  }
}

class _NumericLine extends StatelessWidget {
  final Map hist;
  const _NumericLine({required this.hist});

  @override
  Widget build(BuildContext context) {
    final entries = hist.entries.toList()
      ..sort((a, b) => int.parse(a.key.toString())
          .compareTo(int.parse(b.key.toString())));
    if (entries.isEmpty) return const SizedBox.shrink();
    final spots = [
      for (final e in entries)
        FlSpot(double.parse(e.key.toString()), (e.value as num).toDouble()),
    ];
    final maxY =
        spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);

    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: HseColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: HseColors.primary.withOpacity(0.12),
            ),
          ),
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true, reservedSize: 24, interval: 1)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: HseColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
      )),
    );
  }
}

class _NumericTable extends StatelessWidget {
  final _NumStats stats;
  final Map hist;
  const _NumericTable({required this.stats, required this.hist});

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    // Описательные показатели + распределение по значениям.
    final rows = <(String, String)>[
      ('N (наблюдений)', stats.n.toString()),
      ('Среднее (M)', _fmt(stats.mean)),
      ('Медиана (Mdn)', _fmt(stats.median)),
      ('Стандартное отклонение (SD)', _fmt(stats.std)),
      ('Минимум', _fmt(stats.min)),
      ('1-й квартиль (Q1)', _fmt(stats.q1)),
      ('3-й квартиль (Q3)', _fmt(stats.q3)),
      ('Максимум', _fmt(stats.max)),
      ('Межквартильный размах (IQR)', _fmt(stats.q3 - stats.q1)),
      ('Размах', _fmt(stats.max - stats.min)),
    ];

    final histEntries = hist.entries.toList()
      ..sort((a, b) => int.parse(a.key.toString())
          .compareTo(int.parse(b.key.toString())));
    final total = histEntries.fold<num>(0, (a, e) => a + (e.value as num));

    return Column(children: [
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: HseColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: HseColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  flex: 6,
                  child: Text(rows[i].$1,
                      style: const TextStyle(
                          fontFamily: 'HSESans', fontSize: 13)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(rows[i].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: HseColors.primary)),
                ),
              ]),
            ),
          ],
        ]),
      ),
      if (histEntries.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Распределение по значениям',
              style: TextStyle(
                  fontFamily: 'HSESans',
                  fontSize: 12,
                  color: HseColors.muted)),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: HseColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HseColors.surfaceAlt,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(children: const [
                Expanded(
                  flex: 4,
                  child: Text('Значение',
                      style: TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('N',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontFamily: 'HSESans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            for (int i = 0; i < histEntries.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: HseColors.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  Expanded(
                    flex: 4,
                    child: Text(histEntries[i].key.toString(),
                        style: const TextStyle(
                            fontFamily: 'HSESans', fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                        (histEntries[i].value as num).toInt().toString(),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'HSESans', fontSize: 13)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                        '${((histEntries[i].value as num) / total * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'HSESans',
                            fontSize: 13,
                            color: HseColors.muted)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }
}

// ─────────────────────────── текстовые виды ─────────────────────────────

class _TextSamples extends StatelessWidget {
  final List<String> samples;
  const _TextSamples({required this.samples});
  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Text('Нет данных',
          style: TextStyle(fontFamily: 'HSESans', color: HseColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in samples.take(20))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(
                        fontFamily: 'HSESans',
                        color: HseColors.muted,
                        fontSize: 14)),
                Expanded(
                  child: Text(s,
                      style: const TextStyle(
                          fontFamily: 'HSESans', fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        if (samples.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('и ещё ${samples.length - 20}…',
                style: const TextStyle(
                    fontFamily: 'HSESans',
                    color: HseColors.muted,
                    fontSize: 12)),
          ),
      ],
    );
  }
}

class _TextWordFreq extends StatelessWidget {
  final List<String> samples;
  const _TextWordFreq({required this.samples});

  // Базовые стоп-слова, чтобы топ не забивался служебной лексикой.
  // Список намеренно консервативный — лучше показать «лишнее», чем выкинуть
  // значимое слово.
  static const _stop = {
    // ru
    'это', 'для', 'как', 'что', 'был', 'была', 'были', 'было', 'или', 'ещё',
    'все', 'есть', 'так', 'тоже', 'этот', 'эта', 'мне', 'мой', 'моя', 'наш',
    'они', 'их', 'нет', 'мы', 'он', 'она', 'но', 'уже', 'про', 'чтобы',
    // en
    'the', 'and', 'for', 'with', 'this', 'that', 'have', 'has', 'was', 'were',
    'are', 'you', 'your', 'our', 'their', 'they', 'them', 'from', 'not',
  };

  List<MapEntry<String, int>> _freq() {
    final re = RegExp(r'[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё\-]{2,}');
    final freq = <String, int>{};
    for (final s in samples) {
      for (final m in re.allMatches(s.toLowerCase())) {
        final w = m.group(0)!;
        if (_stop.contains(w)) continue;
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(30).toList();
  }

  @override
  Widget build(BuildContext context) {
    final words = _freq();
    if (words.isEmpty) {
      return const Text('Слов не найдено',
          style: TextStyle(fontFamily: 'HSESans', color: HseColors.muted));
    }
    final maxV = words.first.value.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Подсчитано по сэмплу ответов (до 50 шт.), без учёта стоп-слов.',
          style: TextStyle(
              fontFamily: 'HSESans',
              color: HseColors.muted,
              fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = 0; i < words.length; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _colorFor(i).withOpacity(
                      0.15 + 0.45 * (words[i].value / maxV)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${words[i].key} · ${words[i].value}',
                  style: TextStyle(
                    fontFamily: 'HSESans',
                    fontSize: 12 + 4 * (words[i].value / maxV),
                    fontWeight: FontWeight.w600,
                    color: HseColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
