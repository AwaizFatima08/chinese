import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/links.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  void _open(String url) => unawaited(
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l.appName,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => Text(
              snap.hasData
                  ? l.aboutVersion(
                      '${snap.data!.version}+${snap.data!.buildNumber}',
                    )
                  : '',
              style: context.text.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          Text(l.aboutBody, style: context.text.bodyLarge),
          const SizedBox(height: 12),
          Text(l.aboutAds, style: context.text.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _open(AppLinks.privacy),
                child: Text(l.aboutPrivacy),
              ),
              OutlinedButton(
                onPressed: () => _open(AppLinks.deleteData),
                child: Text(l.aboutDeleteData),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.aboutCredits, style: context.text.titleMedium),
          const SizedBox(height: 8),
          if (content != null)
            for (final a in content.pack.attribution)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    a.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${a.use}\n${a.license}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => unawaited(
                    launchUrl(
                      Uri.parse(a.url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: const Text(
                'CMU Pronouncing Dictionary',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(l.aboutSpeakCredit),
              isThreeLine: true,
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _open('https://github.com/cmusphinx/cmudict'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _showLicenceText(context, ref),
            child: Text(l.aboutLicenceText),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                showLicensePage(context: context, applicationName: l.appName),
            child: Text(l.aboutOpenLicences),
          ),
        ],
      ),
    );
  }

  Future<void> _showLicenceText(BuildContext context, WidgetRef ref) async {
    final pack = ref.read(contentProvider).value?.pack;
    final files = [...?pack?.licenseFiles, 'assets/licenses/speak-cmudict.txt'];
    final texts = [for (final f in files) await rootBundle.loadString(f)];
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.aboutLicenceText),
        content: SingleChildScrollView(
          child: Text(texts.join('\n\n————————\n\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
