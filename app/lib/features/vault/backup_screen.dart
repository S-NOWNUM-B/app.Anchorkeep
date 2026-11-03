// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:anchorkeep/features/vault/backup_workspace.dart';
import 'package:anchorkeep/features/vault/restore_flow_workspace.dart';
import 'package:anchorkeep/app/theme.dart';
import 'package:flutter/material.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) => BackupWorkspace(
    restoreBuilder: (onBack, bytes) =>
        VaultRestoreFlow(onCancel: onBack, initialBytes: bytes),
  );
}

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VaultColors.of(context).canvas,
    body: const VaultRestoreFlow(standalone: true),
  );
}
