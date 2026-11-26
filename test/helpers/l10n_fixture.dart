import 'package:flutter/widgets.dart';
import 'package:materialword/l10n/l10n.dart';

/// The Simplified Chinese resources, for assertions about user-visible text.
///
/// Tests used to hard-code whole sentences (`'选择全部 121 项'`,
/// `'设置冲刺计划'`). Every refinement of the copy in the ARB then turned a
/// behaviour test red for a reason that had nothing to do with behaviour.
/// Reading the same resource the UI reads keeps the assertion about what the
/// app *does* while still pinning the exact sentence that is on screen.
///
/// `lookupAppLocalizations` is synchronous, so this needs no binding and no
/// `await` in the middle of a widget test.
final AppLocalizations zhText = lookupAppLocalizations(const Locale('zh'));
