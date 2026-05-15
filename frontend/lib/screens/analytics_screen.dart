import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../theme.dart';

class AnalyticsScreen extends StatefulWidget {
  final int surveyId;
  const AnalyticsScreen({super.key, required this.surveyId});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/')),
        title: const Text('Аналитика', style: TextStyle(fontFamily: 'HSESans')),
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
                      _questionCard(q),
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

String _pluralAnswers(int n) {
  if (n % 100 >= 11 && n % 100 <= 19) return '$n ответов';
  switch (n % 10) {
    case 1: return '$n ответ';
    case 2: case 3: case 4: return '$n ответа';
    default: return '$n ответов';
  }
}

  Widget _questionCard(Map<String, dynamic> q) {
    final type = q['type'] as String;
    final dist = (q['distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q['title'] as String? ?? '',
              style: const TextStyle(
                  fontFamily: 'HSESans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text(_pluralAnswers(q['total_answers'] as int), 
              style: const TextStyle(
                  fontFamily: 'HSESans', color: HseColors.muted, fontSize: 12)),
          const SizedBox(height: 16),
          if (q['total_answers'] == 0)
            const Text('Нет данных',
                style: TextStyle(fontFamily: 'HSESans', color: HseColors.muted))
          else
            _chart(type, dist),
        ]),
      ),
    );
  }

  Widget _chart(String type, Map<String, dynamic> dist) {
    if (type == 'single_choice' ||
        type == 'multiple_choice' ||
        type == 'dropdown') {
      final entries = dist.entries.toList();
      final maxV = entries
          .fold<num>(0, (m, e) => (e.value as num) > m ? e.value : m)
          .toDouble();
      return SizedBox(
        height: (entries.length * 36 + 40).clamp(120, 300).toDouble(),
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxV,
          barTouchData: BarTouchData(enabled: true),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    if (v != v.roundToDouble())
                      return const SizedBox();
                    return Text(v.toInt().toString(),
                        style: const TextStyle(
                            fontFamily: 'HSESans', fontSize: 11));
                  }),
            ),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entries[i].key,
                      style:
                          const TextStyle(fontFamily: 'HSESans', fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                );
              },
            )),
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
                  color: HseColors.secondary,
                  width: 22,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        )),
      );
    }
    if (type == 'scale' || type == 'rating' || type == 'number') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'Среднее: ${(dist['avg'] ?? 0).toStringAsFixed(2)} · Мин: ${dist['min']} · Макс: ${dist['max']} · N: ${dist['count']}',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        if (dist['histogram'] is Map)
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (final e in (dist['histogram'] as Map).entries.toList()
                  ..sort((a, b) => int.parse(a.key.toString())
                      .compareTo(int.parse(b.key.toString()))))
                  BarChartGroupData(x: int.parse(e.key.toString()), barRods: [
                    BarChartRodData(
                        toY: (e.value as num).toDouble(),
                        color: HseColors.primary,
                        width: 18),
                  ]),
              ],
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                )),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            )),
          ),
      ]);
    }
    final samples = (dist['sample'] as List?)?.cast<String>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Примеры ответов:',
          style: TextStyle(
              fontFamily: 'HSESans', color: HseColors.muted, fontSize: 12)),
      const SizedBox(height: 6),
      for (final s in samples.take(20))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('• $s'),
        ),
    ]);
  }
}
