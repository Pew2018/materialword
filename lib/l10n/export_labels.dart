import '../services/wordbook_export.dart';
import 'l10n.dart';

/// Name of an export format, as shown in the picker.
String exportFormatLabel(AppLocalizations l10n, WordBookExportFormat format) =>
    switch (format) {
      WordBookExportFormat.txt => l10n.exportFormatTxt,
      WordBookExportFormat.csv => l10n.exportFormatCsv,
      WordBookExportFormat.json => l10n.exportFormatJson,
    };
