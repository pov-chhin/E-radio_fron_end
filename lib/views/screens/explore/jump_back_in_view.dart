import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/see_all_header.dart';
import '../../widgets/explore/jump_back_in_section.dart';

/// Jump Back In's See All: everything the person has played lately as the
/// same two-column grid of compact cards Home shows the newest few of.
class JumpBackInView extends ConsumerWidget {
  const JumpBackInView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = jumpBackInItems(ref);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SeeAllHeader(title: l10n.jumpBackIn),
            Expanded(
              child: items == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? Center(child: Text(l10n.noRecentlyPlayed))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: JumpBackInCard.height,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          JumpBackInCard(item: items[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
