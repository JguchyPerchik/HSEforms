import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../models/models.dart';
import '../theme.dart';

class ShareDialog extends StatelessWidget {
  final Survey survey;
  const ShareDialog({super.key, required this.survey});

  String get _link {
    final origin = web.window.location.origin;
    // Path-based URL — go_router у нас работает без hash-режима. Если оставить
    // `/#/s/...`, у респондента в браузере fragment отбросится при первом
    // запросе, на сервер уйдёт `/`, фронт уведёт его на /login и опрос не
    // откроется. Перед раздачей убедитесь, что в Caddy/nginx настроен
    // SPA-fallback `try_files {path} /index.html` — иначе на F5 будет 404.
    return '$origin/s/${survey.slug}';
  }

  String get _title => survey.title.isEmpty ? 'Опрос HSE Forms' : survey.title;

  void _open(String url) {
    web.window.open(url, '_blank');
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notPublished = survey.status != SurveyStatus.published;
    final encUrl = Uri.encodeComponent(_link);
    final encText = Uri.encodeComponent('$_title — пройдите опрос');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: HseColors.gradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.ios_share_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text('Поделиться опросом', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 20),
            if (notPublished) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1AE05656),
                borderRadius: BorderRadius.circular(HseRadius.md),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: HseColors.danger, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Опрос ещё не опубликован — респонденты увидят 404. Опубликуйте перед рассылкой.',
                  style: TextStyle(color: HseColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                )),
              ]),
            ),
            if (notPublished) const SizedBox(height: 16),
            Text('ССЫЛКА', style: TextStyle(color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(
                color: HseColors.surface,
                borderRadius: BorderRadius.circular(HseRadius.md),
              ),
              child: Row(children: [
                Expanded(
                  child: SelectableText(
                    _link,
                    maxLines: 1,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: HseColors.ink),
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(HseRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(HseRadius.sm),
                    onTap: () => _copy(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.content_copy_rounded, size: 16, color: HseColors.primary),
                        SizedBox(width: 6),
                        Text('Копировать', style: TextStyle(color: HseColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('ПОДЕЛИТЬСЯ В', style: TextStyle(color: HseColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _SocialBtn(
                label: 'Telegram', icon: Icons.send_rounded, color: const Color(0xFF229ED9),
                onTap: () => _open('https://t.me/share/url?url=$encUrl&text=$encText'),
              ),
              _SocialBtn(
                label: 'WhatsApp', icon: Icons.chat_rounded, color: const Color(0xFF25D366),
                onTap: () => _open('https://api.whatsapp.com/send?text=$encText%20$encUrl'),
              ),
              _SocialBtn(
                label: 'VK', icon: Icons.public_rounded, color: const Color(0xFF0077FF),
                onTap: () => _open('https://vk.com/share.php?url=$encUrl&title=$encText'),
              ),
              _SocialBtn(
                label: 'Email', icon: Icons.mail_outline_rounded, color: HseColors.primary,
                onTap: () => _open('mailto:?subject=$encText&body=$encUrl'),
              ),
              _SocialBtn(
                label: 'Twitter / X', icon: Icons.alternate_email_rounded, color: HseColors.ink,
                onTap: () => _open('https://twitter.com/intent/tweet?text=$encText&url=$encUrl'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SocialBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(HseRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(HseRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ]),
        ),
      ),
    );
  }
}
