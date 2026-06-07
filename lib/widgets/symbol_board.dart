import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_language.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/pictograms.dart';
import '../state/composer_controller.dart';
import '../state/language_controller.dart';
import '../state/settings_controller.dart';

/// Symbols mode (IMPLEMENTATION_PLAN Task 6): a category rail plus a pictogram
/// grid. Tapping a symbol appends its active-language word to the message.
class SymbolBoard extends StatefulWidget {
  const SymbolBoard({super.key});

  @override
  State<SymbolBoard> createState() => _SymbolBoardState();
}

class _SymbolBoardState extends State<SymbolBoard> {
  String _categoryId = kCategories.first.id;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageController>().language;
    final pics = kPictograms[_categoryId] ?? const [];
    final category =
        kCategories.firstWhere((c) => c.id == _categoryId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 168, child: _CategoryRail(
          selectedId: _categoryId,
          lang: lang,
          onSelect: (id) => setState(() => _categoryId = id),
        )),
        const SizedBox(width: AppTokens.s12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cols = (constraints.maxWidth / 150).floor().clamp(3, 8);
              return GridView.builder(
                padding: const EdgeInsets.only(right: 2, bottom: 2),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: AppTokens.s12,
                  crossAxisSpacing: AppTokens.s12,
                  childAspectRatio: 1,
                ),
                itemCount: pics.length,
                itemBuilder: (context, i) => _PictogramTile(
                  pictogram: pics[i],
                  lang: lang,
                  color: category.color,
                  onTap: () {
                    if (context.read<SettingsController>().haptics) {
                      HapticFeedback.selectionClick();
                    }
                    context
                        .read<ComposerController>()
                        .appendWord(pics[i].word(lang));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.selectedId,
    required this.lang,
    required this.onSelect,
  });

  final String selectedId;
  final AppLanguage lang;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.separated(
      itemCount: kCategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
      itemBuilder: (context, i) {
        final c = kCategories[i];
        final active = c.id == selectedId;
        return Material(
          color: active ? c.color.withValues(alpha: 0.16) : colors.surface2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(c.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s12,
                vertical: AppTokens.s12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? c.color : colors.divider,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(c.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppTokens.s8),
                  Expanded(
                    child: Text(
                      c.label(lang),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PictogramTile extends StatelessWidget {
  const _PictogramTile({
    required this.pictogram,
    required this.lang,
    required this.color,
    required this.onTap,
  });

  final Pictogram pictogram;
  final AppLanguage lang;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppTokens.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rCard),
            border: Border.all(color: colors.divider, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(pictogram.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: AppTokens.s8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  pictogram.word(lang),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
