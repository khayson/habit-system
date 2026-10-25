import 'package:flutter/material.dart';

import '../../config/habit_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_icons.dart';
import '../../domain/habit_icons.dart';

/// A53: the picker for a habit's icon, a bottom sheet over create and edit (no design; built
/// from the app's own parts, approved by Khay Studios). Every free Hugeicons glyph, searched on
/// the device; the featured ones first under "Suggested". Returns the picked key, or null when
/// dismissed. [current] is the key the habit shows (its own or its category's default).
Future<String?> pickHabitIcon(BuildContext context, {required String current}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _IconPicker(current: current),
    );

class _IconPicker extends StatefulWidget {
  final String current;

  const _IconPicker({required this.current});

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final results = HabitIconCatalog.search(_query);
    final featured = HabitIconCatalog.featuredCount;
    final browsing = _query.trim().isEmpty;

    SliverGrid grid(List<String> keys) => SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: HabitSpace.s8,
        crossAxisSpacing: HabitSpace.s8,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) => _Cell(iconKey: keys[i], selected: keys[i] == widget.current),
    );

    Widget heading(String label) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: HabitSpace.s16, bottom: HabitSpace.s8),
        child: Semantics(header: true, child: Text(label, style: text.titleSmall)),
      ),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          HabitSpace.margin,
          0,
          HabitSpace.margin,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Semantics(
                header: true,
                child: Text(l10n.iconPickerTitle, style: text.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: HabitSpace.s16),
                child: TextField(
                  key: const ValueKey('icon-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: l10n.iconPickerSearch,
                    // The prefix slot is tight: centred, the glyph keeps its size.
                    prefixIcon: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: AppIcon(AppIcons.search, size: 22, color: tokens.muted),
                    ),
                  ),
                ),
              ),
            ),
            if (browsing) ...[
              heading(l10n.iconPickerSuggested),
              grid(results.sublist(0, featured)),
              heading(l10n.iconPickerAll),
              grid(results.sublist(featured)),
            ] else if (results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: HabitSpace.s24),
                  child: Text(
                    l10n.iconPickerNoMatch(_query.trim()),
                    style: text.bodyMedium?.copyWith(color: tokens.muted),
                  ),
                ),
              )
            else ...[
              const SliverToBoxAdapter(child: SizedBox(height: HabitSpace.s16)),
              grid(results),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: HabitSpace.s24)),
          ],
        ),
      ),
    );
  }
}

/// One icon: at least 48 px, read by TalkBack as its label; the selected one carries a check
/// and a border, never colour alone (A12).
class _Cell extends StatelessWidget {
  final String iconKey;
  final bool selected;

  const _Cell({required this.iconKey, required this.selected});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return Semantics(
      key: ValueKey('icon-cell-$iconKey'),
      container: true,
      button: true,
      selected: selected,
      label: HabitIconCatalog.label(iconKey),
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(iconKey),
      child: Material(
        color: selected ? tokens.positiveBg : tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HabitRadius.r16),
          side: BorderSide(
            color: selected ? tokens.primary : tokens.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HabitRadius.r16),
          onTap: () => Navigator.of(context).pop(iconKey),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Stack(
              children: [
                Center(
                  child: AppIcon(
                    AppIcons.habit(iconKey),
                    size: 26,
                    color: selected ? tokens.primary : tokens.ink,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: AppIcon(AppIcons.check, size: 14, color: tokens.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
