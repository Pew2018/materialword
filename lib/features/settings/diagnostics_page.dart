import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_info.dart';
import '../../app/providers.dart';
import '../../services/diagnostics_service.dart';
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
        dialogTitle: '保存诊断信息',
      );
      if (!mounted) return;
      showMessage(context, result == null ? '已取消导出' : '诊断信息已导出（不含账号与学习内容）');
    } catch (e) {
      if (!mounted) return;
      showMessage(context, '导出失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('诊断信息')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SectionHeader(title: '日志'),
          SettingsGroup(
            children: <Widget>[
              SwitchListTile(
                value: _enabled,
                title: const Text('记录详细运行日志'),
                subtitle: const Text('默认关闭；开启后只保留最近 400 条、24 小时，自动脱敏'),
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
                title: '导出诊断信息',
                subtitle: '版本、数据库与词典统计、同步状态；不含账号和学习内容',
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
                title: '清除已记录的日志',
                subtitle: DiagnosticsService.instance.entries.isEmpty
                    ? '当前没有记录'
                    : '${DiagnosticsService.instance.entries.length} 条记录',
                onTap: () {
                  DiagnosticsService.instance.clear();
                  setState(() {});
                  showMessage(context, '已清除运行日志');
                },
              ),
            ],
          ),
          SectionHeader(title: '设备'),
          SettingsGroup(
            children: <Widget>[
              SettingsTile(
                leading: const Icon(Icons.memory_outlined),
                title: '本机设备标识',
                subtitle: _deviceId ?? '读取中…',
                onTap: _deviceId == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _deviceId!),
                        );
                        if (!context.mounted) return;
                        showMessage(context, '已复制设备标识（仅用于排查同步问题）');
                      },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  '诊断信息不会包含密码、认证信息、词条内容或个人笔记；'
                  '同步配置只记录同步方式，不记录地址、账号或路径。',
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
