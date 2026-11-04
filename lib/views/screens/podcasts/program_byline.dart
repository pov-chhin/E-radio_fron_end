import '../../../data/models/program.dart';
import '../../../l10n/gen/app_localizations.dart';

/// "by Dr. Serey Roth • Health & Mind": the host, then the category, each only
/// when the show has it. Null when it has neither.
String? programByline(AppLocalizations l10n, Program program) {
  final hostName = program.hostName;
  final categoryName = program.categoryName;
  final parts = [
    if (hostName != null && hostName.isNotEmpty) l10n.byHost(hostName),
    if (categoryName != null && categoryName.isNotEmpty) categoryName,
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}
