import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/links.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'account_controller.dart';

/// Settings tiles for optional sign-in, sync and account deletion. Renders
/// nothing when Firebase is not available on this build or device.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(accountProvider.notifier);
    if (!controller.available) return const SizedBox.shrink();
    final l = context.l10n;
    final account = ref.watch(accountProvider);

    final issueText = switch (account.issue) {
      AccountIssue.none => null,
      AccountIssue.signInFailed => l.accErrSignIn,
      AccountIssue.offline => l.accErrOffline,
      AccountIssue.syncFailed => l.accErrSync,
      AccountIssue.deleteFailed => l.accErrDelete,
    };

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(
          l.setAccount.toUpperCase(),
          style: context.text.labelMedium?.copyWith(
            color: context.scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ];

    if (!account.signedIn) {
      children.addAll([
        ListTile(
          leading: const Icon(Icons.cloud_sync_rounded),
          title: Text(l.accSignInTitle),
          subtitle: Text(l.accSignInBody),
          isThreeLine: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: account.busy ? null : controller.signIn,
              icon: account.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(l.accSignInButton),
            ),
          ),
        ),
      ]);
    } else {
      final user = account.user!;
      final when = account.lastSynced;
      final status = account.busy
          ? l.accSyncing
          : when == null
          ? l.accNeverSynced
          : l.accLastSynced(_format(context, when));
      children.addAll([
        ListTile(
          leading: const Icon(Icons.account_circle_rounded),
          title: Text(l.accSignedInAs(user.email ?? user.name ?? user.uid)),
          subtitle: Text(status),
        ),
        ListTile(
          leading: const Icon(Icons.sync_rounded),
          title: Text(l.accSyncNow),
          enabled: !account.busy,
          onTap: controller.sync,
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: Text(l.accSignOut),
          enabled: !account.busy,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            await controller.signOut();
            messenger.showSnackBar(SnackBar(content: Text(l.accSignedOut)));
          },
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_rounded,
            color: context.scheme.error,
          ),
          title: Text(
            l.accDelete,
            style: TextStyle(color: context.scheme.error),
          ),
          enabled: !account.busy,
          onTap: () => _confirmDelete(context, controller),
        ),
      ]);
    }

    if (issueText != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            issueText,
            style: context.text.bodyMedium?.copyWith(
              color: context.scheme.error,
            ),
          ),
        ),
      );
    }
    children.add(
      ListTile(
        dense: true,
        title: Text(l.accPrivacyNote, style: context.text.bodySmall),
        onTap: () => unawaited(
          launchUrl(
            Uri.parse(AppLinks.privacy),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
    return Column(children: children);
  }

  static String _format(BuildContext context, DateTime when) {
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatMediumDate(when)}, '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(when))}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AccountController controller,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.accDeleteConfirmTitle),
        content: Text(l.accDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.accDeleteConfirm),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final done = await controller.deleteAccount();
    if (done) messenger.showSnackBar(SnackBar(content: Text(l.accDeleted)));
  }
}
