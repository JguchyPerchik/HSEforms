import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../theme.dart';

class CollaboratorsDialog extends StatefulWidget {
  final int surveyId;
  const CollaboratorsDialog({super.key, required this.surveyId});
  @override
  State<CollaboratorsDialog> createState() => _CollaboratorsDialogState();
}

class _CollaboratorsDialogState extends State<CollaboratorsDialog> {
  late final SurveysApi _api = SurveysApi(context.read<ApiClient>());
  final _email = TextEditingController();
  String _role = 'editor';
  List<Map<String, dynamic>> _list = [];
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { _list = await _api.collaborators(widget.surveyId); setState(() {}); }
    catch (e) { setState(() => _err = e.toString()); }
  }

  Future<void> _add() async {
    setState(() => _err = null);
    try {
      await _api.addCollaborator(widget.surveyId, _email.text.trim(), _role);
      _email.clear();
      await _load();
    } catch (e) { setState(() => _err = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Соавторы опроса'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'viewer', child: Text('Просмотр')),
                DropdownMenuItem(value: 'editor', child: Text('Редактор')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: _add),
          ]),
          if (_err != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_err!, style: const TextStyle(color: HseColors.danger)),
          ),
          const Divider(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _list.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Соавторов нет', style: TextStyle(color: HseColors.muted)))
                : ListView(
                    shrinkWrap: true,
                    children: _list.map((c) => ListTile(
                      title: Text(c['email'] ?? c['full_name'] ?? '#${c['user_id']}'),
                      subtitle: Text(c['role']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async { await _api.removeCollaborator(widget.surveyId, c['user_id']); _load(); },
                      ),
                    )).toList(),
                  ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
    );
  }
}
