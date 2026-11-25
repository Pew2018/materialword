import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../../app/providers.dart';
import '../../services/diagnostics_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/common.dart';

/// Diagnostics moved off the settings list onto its own page.
///
/// These controls are for troubleshooting only (log capture, exporting a
/// report, the device identifier used to read sync logs). Keeping them on a
/// second level is what lets the settings screen stay short enough to scan.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  bool _enabled = DiagnosticsService.instance.enabled;
  bool _busy = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final String id = await ref.read(settingsRepositoryProvider).deviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _export() async {
    if (_busy) return;
    // Captured before the first await; the picker title is needed later.
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final String report = await DiagnosticsService.instance.buildReport(
        ref.read(databaseProvider),
        runtime: <String, Object?>{
          'appVersion': appVersion,
          'buildCommit': buildCommit,
          'flutterVersion': '3.50.1',
          'dartVersion': '3.14.0',
          'diagnosticsEnabled': _enabled,
        },
      );
      final Uri? result = await FilePicker.saveFile(
        fileName: 'materialword-diagnostics.txt',
        bytes: utf8.encode(report),
        mimeType: 'text/plain',
        dialogTitle: l10n.saveDiagnostics,
      );
      if (!mounted) return;
      showMessage(
        context,
        result == null
            ? context.l10n.exportCancelled
            : context.l10n.diagnosticsExported,
      );
    } catch (e) {
      if (!mounted) return;
      showMessage(context, context.l10n.diagnosticsExportFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: ClassicAppBar(title: Text(context.l10n.diagnostics)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SectionHeader(title: context.l10n.logsSection),
          SettingsGroup(
            children: <Widget>[
              SwitchListTile(
                value: _enabled,
                title: Text(context.l10n.detailedLogging),
                subtitle: Text(context.l10n.detailedLoggingHint),
                onChanged: (bool value) async {
                  await DiagnosticsService.instance.setEnabled(
                    ref.read(databaseProvider),
                    value,
                  );
                  if (mounted) setState(() => _enabled = value);
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: context.l10n.exportDiagnosticsReport,
                subtitle: context.l10n.exportDiagnosticsHint,
                trailing: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt),
                onTap: _busy ? null : _export,
              ),
              SettingsTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: context.l10n.clearLogs,
                subtitle: DiagnosticsService.instance.entries.isEmpty
                    ? context.l10n.noLogs
                    : context.l10n.logCount(
                        DiagnosticsService.instance.entries.length,
                      ),
                onTap: () {
                  DiagnosticsService.instance.clear();
                  setState(() {});
                  showMessage(context, context.l10n.logsCleared);
                },
              ),
            ],
          ),
          SectionHeader(title: context.l10n.deviceSection),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.memory_outlined),
                title: context.l10n.deviceIdLabel,
                subtitle: _deviceId ?? context.l10n.reading,
                onTap: _deviceId == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _deviceId!),
                        );
                        if (!context.mounted) return;
                        showMessage(context, context.l10n.deviceIdCopied);
                      },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  context.l10n.diagnosticsPrivacy,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
