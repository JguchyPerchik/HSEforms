// lib/screens/home_screen.dart
// Main tab shell: My Surveys | Discover | Responses

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/form_field_model.dart';
import '../../../providers/creator_provider.dart';
import '../../../providers/filler_provider.dart';
import '../../../providers/survey_store.dart';
import '../../../screens/creator_screen.dart';
import '../../../screens/filler_screen.dart';

// ─── Color accent helpers ─────────────────────────────────────────────────────

Color _accentOf(FormSchema s) {
  if (s.accentColor == null) return const Color(0xFF6366F1);
  try {
    return Color(int.parse('FF${s.accentColor!.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF6366F1);
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final SurveyStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SurveyStatus.draft     => ('Draft', const Color(0xFFF59E0B)),
      SurveyStatus.published => ('Published', const Color(0xFF10B981)),
      SurveyStatus.closed    => ('Closed', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Survey card ──────────────────────────────────────────────────────────────

class SurveyCard extends StatelessWidget {
  final FormSchema survey;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SurveyCard({
    super.key,
    required this.survey,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentOf(survey);
    final fmt = DateFormat('MMM d, y');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: accent, width: 4),
            top: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
            right: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
            bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  survey.title.isEmpty ? 'Untitled Survey' : survey.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(survey.status),
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.hintColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit'),
                      ])),
                    if (onDelete != null)
                      PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 16,
                            color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      ])),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                ),
              ],
            ]),
            if (survey.description != null && survey.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(survey.description!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.help_outline_rounded, size: 13, color: theme.hintColor),
              const SizedBox(width: 4),
              Text('${survey.questionCount} questions',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              const SizedBox(width: 12),
              Icon(Icons.people_outline_rounded, size: 13, color: theme.hintColor),
              const SizedBox(width: 4),
              Text('${survey.responseCount} responses',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              const Spacer(),
              Text(fmt.format(survey.updatedAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            ]),
            if (onTap != null && survey.status == SurveyStatus.published) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Fill out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() => _currentTab = _tabs.index));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openCreator({FormSchema? existing}) async {
    final creator = context.read<CreatorProvider>();
    if (existing != null) {
      creator.loadExisting(existing);
    } else {
      creator.loadNew();
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatorScreen()),
    );
  }

  void _openFiller(FormSchema survey) async {
    final filler = context.read<FillerProvider>();
    filler.load(survey);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FillerScreen()),
    );
  }

  void _confirmDelete(FormSchema survey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete survey?'),
        content: Text('This will permanently delete "${survey.title}" and all responses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<SurveyStore>().deleteSurvey(survey.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<SurveyStore>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          // ── App bar ──────────────────────────────────────────────────────
          _AppBar(onCreateTap: () => _openCreator()),

          // ── Tabs ─────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: theme.hintColor,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'My Surveys'),
                Tab(text: 'Discover'),
                Tab(text: 'Responses'),
              ],
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── MY SURVEYS ──────────────────────────────────────────────
                _SurveyList(
                  surveys: store.surveys,
                  emptyTitle: 'No surveys yet',
                  emptyMessage: 'Tap + to create your first survey.',
                  emptyIcon: Icons.dynamic_form_outlined,
                  onTap: (s) => s.status == SurveyStatus.published ? _openFiller(s) : _openCreator(existing: s),
                  onEdit: (s) => _openCreator(existing: s),
                  onDelete: (s) => _confirmDelete(s),
                  showEdit: true,
                ),

                // ── DISCOVER (published only) ─────────────────────────────
                _SurveyList(
                  surveys: store.publishedSurveys,
                  emptyTitle: 'No published surveys',
                  emptyMessage: 'Publish a survey to see it here.',
                  emptyIcon: Icons.explore_outlined,
                  onTap: _openFiller,
                  showEdit: false,
                ),

                // ── RESPONSES ───────────────────────────────────────────────
                _ResponsesTab(responses: store.responses, surveys: store.surveys),
              ],
            ),
          ),
        ]),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openCreator(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Survey'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ).animate().scale(begin: const Offset(0.7, 0.7), duration: 300.ms, curve: Curves.elasticOut)
          : null,
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _AppBar({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.dynamic_form_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text('Forms',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, fontSize: 22,
              color: theme.colorScheme.primary,
            )),
        const Spacer(),
      ]),
    );
  }
}

// ─── Survey list ──────────────────────────────────────────────────────────────

class _SurveyList extends StatelessWidget {
  final List<FormSchema> surveys;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(FormSchema) onTap;
  final void Function(FormSchema)? onEdit;
  final void Function(FormSchema)? onDelete;
  final bool showEdit;

  const _SurveyList({
    required this.surveys,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    required this.showEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (surveys.isEmpty) {
      return _EmptyState(title: emptyTitle, message: emptyMessage, icon: emptyIcon);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: surveys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => SurveyCard(
        key: ValueKey(surveys[i].id),
        survey: surveys[i],
        onTap: () => onTap(surveys[i]),
        onEdit: showEdit ? () => onEdit?.call(surveys[i]) : null,
        onDelete: showEdit ? () => onDelete?.call(surveys[i]) : null,
      ).animate(delay: Duration(milliseconds: 40 * i))
          .slideY(begin: 0.15, duration: 300.ms, curve: Curves.easeOut)
          .fade(),
    );
  }
}

// ─── Responses tab ────────────────────────────────────────────────────────────

class _ResponsesTab extends StatelessWidget {
  final List<FormResponse> responses;
  final List<FormSchema> surveys;

  const _ResponsesTab({required this.responses, required this.surveys});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return const _EmptyState(
        title: 'No responses yet',
        message: 'Fill out a survey to see your responses here.',
        icon: Icons.inbox_outlined,
      );
    }

    final sorted = [...responses]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final r = sorted[i];
        final schema = surveys.where((s) => s.id == r.formId).firstOrNull;
        return _ResponseCard(response: r, schema: schema)
            .animate(delay: Duration(milliseconds: 40 * i))
            .slideY(begin: 0.1, duration: 280.ms)
            .fade();
      },
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final FormResponse response;
  final FormSchema? schema;
  const _ResponseCard({required this.response, this.schema});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = schema != null ? _accentOf(schema!) : theme.colorScheme.primary;

    return ExpansionTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      backgroundColor: theme.cardColor,
      collapsedBackgroundColor: theme.cardColor,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: accent.withOpacity(0.15),
        child: Icon(Icons.check_circle_outline_rounded, size: 18, color: accent),
      ),
      title: Text(
        response.formTitle.isEmpty ? 'Survey Response' : response.formTitle,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        DateFormat('MMM d, y • h:mm a').format(response.submittedAt),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
      children: [
        Divider(height: 1, color: theme.dividerColor),
        if (schema != null)
          ...schema!.fields
              .where((f) => !f.type.isStructural && response.answers.containsKey(f.id))
              .map((f) => _AnswerRow(field: f, answer: response.answers[f.id], schema: schema!))
        else
          ...response.answers.entries.map((e) => ListTile(
                dense: true,
                title: Text(e.key, style: theme.textTheme.bodySmall),
                subtitle: Text('${e.value}'),
              )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final FormFieldModel field;
  final dynamic answer;
  final FormSchema schema;

  const _AnswerRow({required this.field, required this.answer, required this.schema});

  String _formatAnswer() {
    if (answer == null) return '—';
    if (answer is List) {
      final ids = List<String>.from(answer as List);
      return ids.map((id) {
        final opt = field.options.where((o) => o.id == id).firstOrNull;
        return opt?.label ?? id;
      }).join(', ');
    }
    if (answer is String && field.type.hasOptions) {
      final opt = field.options.where((o) => o.id == answer).firstOrNull;
      return opt?.label ?? answer.toString();
    }
    if (answer is DateTime) return DateFormat('MMM d, y').format(answer as DateTime);
    if (answer is int && field.type == FormFieldType.rating) return '$answer ⭐';
    return answer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(_formatAnswer(), style: theme.textTheme.bodyMedium),
        const Divider(height: 16),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  const _EmptyState({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: theme.colorScheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    ).animate().fade(duration: 400.ms);
  }
}
