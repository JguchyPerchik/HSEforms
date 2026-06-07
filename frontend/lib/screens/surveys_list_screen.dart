import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/share_dialog.dart';

class SurveysListScreen extends StatefulWidget {
  const SurveysListScreen({super.key});
  @override
  State<SurveysListScreen> createState() => _SurveysListScreenState();
}

class _SurveysListScreenState extends State<SurveysListScreen> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
  Future<List<Survey>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _api.list();
    });
  }

  Future<void> _create() async {
    final s = await _api.create();
    if (mounted) context.go('/builder/${s.id}');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final initial =
        (user?['full_name'] ?? user?['email'] ?? '?').toString().trim();
    final letter =
        initial.isEmpty ? '?' : initial.characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: HseColors.surface,
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                gradient: HseColors.gradient,
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Text('HSE',
                style: TextStyle(
                    fontFamily: 'HSESans',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          const Text('Forms',
              style: TextStyle(
                  fontFamily: 'HSESans',
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HseColors.primary,
                  child: Text(letter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'HSESans',
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text(user['full_name'] ?? user['email'] ?? '',
                    style: const TextStyle(
                        color: HseColors.ink,
                        fontFamily: 'HSESans',
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthState>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новый опрос',
            style: TextStyle(fontFamily: 'HSESans', fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Survey>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                  child: Text('Ошибка: ${snap.error}',
                      style: const TextStyle(
                          fontFamily: 'HSESans', color: HseColors.danger)));
            }
            final list = snap.data ?? [];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 96),
                  children: [
                    Text('Привет!',
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      list.isEmpty
                          ? 'Создайте свой первый опрос — это займёт пару минут.'
                          : 'У вас ${list.length} опрос(ов). Соберите данные, проведите эксперимент, посмотрите аналитику.',
                      style: const TextStyle(
                          fontFamily: 'HSESans',
                          color: HseColors.inkSoft,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    if (list.isEmpty)
                      _EmptyState(onCreate: _create)
                    else
                      ...list.map((s) => _SurveyCard(
                            survey: s,
                            onOpen: () => context.go('/builder/${s.id}'),
                            onAnalytics: () => context.go('/analytics/${s.id}'),
                            onPreview: () => context.go('/s/${s.slug}'),
                            onShare: () => showDialog(
                                context: context,
                                builder: (_) => ShareDialog(survey: s)),
                            onDuplicate: () async {
                              await _api.duplicate(s.id);
                              _refresh();
                            },
                            onDelete: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Удалить опрос?',
                                      style: TextStyle(fontFamily: 'HSESans')),
                                  content: Text(
                                      '«${s.title}» и все ответы будут удалены.',
                                      style: TextStyle(fontFamily: 'HSESans')),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Отмена',
                                            style: TextStyle(
                                                fontFamily: 'HSESans'))),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: HseColors.danger),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Удалить',
                                          style:
                                              TextStyle(fontFamily: 'HSESans')),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await _api.delete(s.id);
                                _refresh();
                              }
                            },
                          )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(36),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: HseColors.gradient,
              borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Создайте первый опрос',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Текстовые поля, выбор, шкалы, условная логика, A/B-эксперименты — всё доступно сразу.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'HSESans',
              color: HseColors.inkSoft,
              fontSize: 14,
              height: 1.4),
        ),
        const SizedBox(height: 18),
        GradientButton(
            icon: Icons.add_rounded,
            onPressed: onCreate,
            child: const Text('Новый опрос',
                style: TextStyle(fontFamily: 'HSESans'))),
      ]),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final Survey survey;
  final VoidCallback onOpen,
      onAnalytics,
      onPreview,
      onShare,
      onDuplicate,
      onDelete;
  const _SurveyCard({
    required this.survey,
    required this.onOpen,
    required this.onAnalytics,
    required this.onPreview,
    required this.onShare,
    required this.onDuplicate,
    required this.onDelete,
  });

  Color get _statusColor => switch (survey.status) {
        SurveyStatus.published => HseColors.success,
        SurveyStatus.closed => HseColors.danger,
        SurveyStatus.draft => HseColors.muted,
      };

  IconData get _statusIcon => switch (survey.status) {
        SurveyStatus.published => Icons.public_rounded,
        SurveyStatus.closed => Icons.lock_outline_rounded,
        SurveyStatus.draft => Icons.edit_note_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SoftCard(
        padding: const EdgeInsets.only(
          top: 10,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon, size: 12, color: _statusColor),
                const SizedBox(width: 6),
                Text(survey.status.human,
                    style: TextStyle(
                        fontFamily: 'HSESans',
                        color: _statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
            const Spacer(),
            SizedBox(
              height: 36,
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.ios_share_rounded),
                    tooltip: 'Поделиться',
                    onPressed: onShare),
                IconButton(
                    icon: const Icon(Icons.bar_chart_rounded),
                    tooltip: 'Аналитика',
                    onPressed: onAnalytics),
                IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    tooltip: 'Предпросмотр',
                    onPressed: onPreview),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) {
                    if (v == 'duplicate') onDuplicate();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'duplicate',
                        child: Row(children: [
                          Icon(Icons.copy_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Дублировать')
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: HseColors.danger),
                          SizedBox(width: 10),
                          Text('Удалить',
                              style: TextStyle(
                                  fontFamily: 'HSESans',
                                  color: HseColors.danger))
                        ])),
                  ],
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            survey.title.isEmpty ? 'Без названия' : survey.title,
            style: const TextStyle(
                fontFamily: 'HSESans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HseColors.ink),
          ),
          if (survey.description != null && survey.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(survey.description!,
                style: const TextStyle(
                    fontFamily: 'HSESans',
                    color: HseColors.inkSoft,
                    fontSize: 14)),
          ],
        ]),
      ),
    );
  }
}
