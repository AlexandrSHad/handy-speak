import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/composer_controller.dart';
import 'keyboard_view.dart';
import 'message_bar.dart';
import 'phrase_strip.dart';
import 'settings_sheet.dart';
import 'symbol_board.dart';
import 'top_bar.dart';

/// The app shell, laid out for a landscape tablet (IMPLEMENTATION_PLAN Task 3).
/// Uses Expanded/Flexible so keyboard + message bar + phrase strip + symbol
/// grid all fit a 16:9 panel without overflow (§6.1.3).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ComposerController, InputMode>((c) => c.mode);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            children: [
              TopBar(onOpenSettings: () => showSettingsSheet(context)),
              const SizedBox(height: AppTokens.s16),
              const MessageBar(),
              const SizedBox(height: AppTokens.s12),
              const PhraseStrip(),
              const SizedBox(height: AppTokens.s12),
              Expanded(
                child: mode == InputMode.keyboard
                    ? const KeyboardView()
                    : const SymbolBoard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
