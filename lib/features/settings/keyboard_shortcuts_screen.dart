import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:it_feels_music/core/models/keyboard_shortcut_models.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/utils/windows_shortcut_detector.dart';
import 'package:it_feels_music/services/keyboard_shortcut_service.dart';

class KeyboardShortcutsScreen extends StatefulWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  State<KeyboardShortcutsScreen> createState() => _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState extends State<KeyboardShortcutsScreen> {
  final KeyboardShortcutService _shortcutService = KeyboardShortcutService();

  @override
  void initState() {
    super.initState();
    _shortcutService.addListener(_onShortcutsChanged);
  }

  @override
  void dispose() {
    _shortcutService.removeListener(_onShortcutsChanged);
    super.dispose();
  }

  void _onShortcutsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      backgroundColor: context.themeBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.themeTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Keyboard Shortcuts",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.themeTextColor,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.restore_rounded, size: 18, color: context.themeMutedTextColor),
            label: Text(
              "Reset All",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.themeMutedTextColor,
              ),
            ),
            onPressed: _confirmResetAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.themeAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.themeAccentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.keyboard_rounded, color: context.themeAccentColor, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWindows ? "Windows Keyboard & Global Hotkeys" : "Keyboard Shortcuts",
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.themeTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isWindows
                            ? "Control playback with custom hotkeys. Windows system overlaps and conflicting hotkeys are automatically detected and flagged."
                            : "Press keys to quickly pause, skip, seek, and adjust volume throughout the app.",
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: context.themeMutedTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          _buildCategorySection(PlayerActionCategory.playback),
          const SizedBox(height: 20),
          _buildCategorySection(PlayerActionCategory.volume),
          const SizedBox(height: 20),
          _buildCategorySection(PlayerActionCategory.navigation),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCategorySection(PlayerActionCategory category) {
    final actions = PlayerAction.values.where((a) => a.category == category).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            category.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.themeMutedTextColor,
            ),
          ),
        ),
        Material(
          color: context.themeCardColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.themeMutedTextColor.withValues(alpha: 0.1)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 0.5,
                color: context.themeMutedTextColor.withValues(alpha: 0.12),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final action = actions[index];
                final combo = _shortcutService.getCombination(action);
                final isDefault = combo == action.defaultCombination;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    action.label,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.themeTextColor,
                    ),
                  ),
                  subtitle: Text(
                    action.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.themeMutedTextColor,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildShortcutBadge(combo),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit_rounded, size: 18, color: context.themeAccentColor),
                        tooltip: "Remap shortcut",
                        onPressed: () => _openRemapDialog(action),
                      ),
                      if (!isDefault)
                        IconButton(
                          icon: Icon(Icons.restore_rounded, size: 18, color: context.themeMutedTextColor),
                          tooltip: "Reset to default",
                          onPressed: () => _shortcutService.resetBinding(action),
                        ),
                    ],
                  ),
                  onTap: () => _openRemapDialog(action),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutBadge(KeyboardShortcutCombination combo) {
    final keys = <String>[];
    if (combo.ctrl) keys.add('Ctrl');
    if (combo.alt) keys.add('Alt');
    if (combo.shift) keys.add('Shift');
    if (combo.meta) keys.add('Win');

    String cleanKey = combo.keyLabel;
    if (cleanKey.toLowerCase() == 'arrowright' || cleanKey == 'Arrow Right') cleanKey = '→';
    if (cleanKey.toLowerCase() == 'arrowleft' || cleanKey == 'Arrow Left') cleanKey = '←';
    if (cleanKey.toLowerCase() == 'arrowup' || cleanKey == 'Arrow Up') cleanKey = '↑';
    if (cleanKey.toLowerCase() == 'arrowdown' || cleanKey == 'Arrow Down') cleanKey = '↓';
    keys.add(cleanKey);

    return Wrap(
      spacing: 4,
      children: keys.map((k) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.themeBackgroundColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.themeMutedTextColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            k,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.themeTextColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmResetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.themeCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Reset All Shortcuts?", style: GoogleFonts.outfit(color: context.themeTextColor)),
        content: Text(
          "This will restore all player keyboard shortcuts to their factory default bindings.",
          style: GoogleFonts.inter(color: context.themeMutedTextColor, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.themeAccentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Reset All"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _shortcutService.resetAllToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All keyboard shortcuts reset to defaults")),
        );
      }
    }
  }

  Future<void> _openRemapDialog(PlayerAction action) async {
    final currentCombo = _shortcutService.getCombination(action);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _RemapShortcutDialog(
        action: action,
        currentCombo: currentCombo,
        allBindings: _shortcutService.bindings,
        onSave: (newCombo) async {
          await _shortcutService.updateBinding(action, newCombo);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Mapped "${action.label}" to ${newCombo.displayLabel}')),
            );
          }
        },
      ),
    );
  }
}

class _RemapShortcutDialog extends StatefulWidget {
  final PlayerAction action;
  final KeyboardShortcutCombination currentCombo;
  final Map<PlayerAction, KeyboardShortcutCombination> allBindings;
  final Future<void> Function(KeyboardShortcutCombination) onSave;

  const _RemapShortcutDialog({
    required this.action,
    required this.currentCombo,
    required this.allBindings,
    required this.onSave,
  });

  @override
  State<_RemapShortcutDialog> createState() => _RemapShortcutDialogState();
}

class _RemapShortcutDialogState extends State<_RemapShortcutDialog> {
  final FocusNode _focusNode = FocusNode();
  KeyboardShortcutCombination? _capturedCombo;
  ShortcutConflict? _conflict;

  @override
  void initState() {
    super.initState();
    _capturedCombo = widget.currentCombo;
    _evaluateConflict(_capturedCombo!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _evaluateConflict(KeyboardShortcutCombination combo) {
    _conflict = WindowsShortcutDetector.checkConflict(
      combo,
      currentAction: widget.action,
      allBindings: widget.allBindings,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Ignore standalone modifier presses alone until a real key is hit
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return KeyEventResult.handled;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    setState(() {
      _capturedCombo = KeyboardShortcutCombination(
        keyId: key.keyId,
        keyLabel: key.keyLabel,
        ctrl: isCtrl,
        alt: isAlt,
        shift: isShift,
        meta: isMeta,
      );
      _evaluateConflict(_capturedCombo!);
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _conflict;

    Color badgeColor = Colors.green;
    IconData badgeIcon = Icons.check_circle_rounded;

    if (conflict != null && conflict.hasConflict) {
      if (conflict.severity == ConflictSeverity.critical) {
        badgeColor = Colors.redAccent;
        badgeIcon = Icons.error_rounded;
      } else if (conflict.severity == ConflictSeverity.warning) {
        badgeColor = Colors.amber;
        badgeIcon = Icons.warning_amber_rounded;
      } else {
        badgeColor = Colors.blueAccent;
        badgeIcon = Icons.info_outline_rounded;
      }
    }

    final canSave = _capturedCombo != null &&
        (conflict == null || conflict.severity != ConflictSeverity.critical);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: AlertDialog(
        backgroundColor: context.themeCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Remap Shortcut",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.themeTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.action.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.themeAccentColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                "Press any key combination on your keyboard",
                style: GoogleFonts.inter(fontSize: 12.5, color: context.themeMutedTextColor),
              ),
              const SizedBox(height: 16),

              // Recording Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.themeBackgroundColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.themeAccentColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _capturedCombo != null
                      ? Text(
                          _capturedCombo!.displayLabel,
                          style: GoogleFonts.robotoMono(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.themeTextColor,
                            letterSpacing: 1.0,
                          ),
                        )
                      : Text(
                          "Recording keys...",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: context.themeMutedTextColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Conflict / Status Warning Banner
              if (conflict != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conflict.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              conflict.message,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: context.themeTextColor.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("Reset Default", style: TextStyle(color: context.themeMutedTextColor)),
            onPressed: () {
              setState(() {
                _capturedCombo = widget.action.defaultCombination;
                _evaluateConflict(_capturedCombo!);
              });
            },
          ),
          TextButton(
            child: Text("Cancel", style: TextStyle(color: context.themeMutedTextColor)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? context.themeAccentColor : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: canSave
                ? () {
                    widget.onSave(_capturedCombo!);
                    Navigator.pop(context);
                  }
                : null,
            child: const Text("Save Shortcut"),
          ),
        ],
      ),
    );
  }
}
