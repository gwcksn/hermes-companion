import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'icons.dart';

const _nunito = HFonts.body;

TextStyle hText(double size, {FontWeight weight = FontWeight.w700, Color color = HColors.text, double? height}) =>
    TextStyle(fontFamily: _nunito, fontSize: size, fontWeight: weight, color: color, height: height);

TextStyle hDisplay(double size, {FontWeight weight = FontWeight.w500, Color color = HColors.text, double? height}) =>
    TextStyle(fontFamily: HFonts.display, fontSize: size, fontWeight: weight, color: color, height: height);

/// 8x8 status dot + 13px label, e.g. "Connected".
class StatusLine extends StatelessWidget {
  const StatusLine(this.label, {super.key, this.dotColor = HColors.mint, this.textColor = HColors.muted});

  final String label;
  final Color dotColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: hText(13, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Small rounded label, e.g. "Yogyakarta · WIB" or the recording timer.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.color = HColors.muted,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.radius = 16,
  });

  final String label;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: HColors.surface, borderRadius: BorderRadius.circular(radius)),
      child: Text(label, style: hText(13, color: color)),
    );
  }
}

enum PillStyle { primary, secondary, secondaryMint }

/// 48dp pill button: peach primary, surface secondary.
class PillButton extends StatelessWidget {
  const PillButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = PillStyle.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final EdgeInsets padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      PillStyle.primary => (HColors.peach, HColors.onPeach),
      PillStyle.secondary => (HColors.surface, HColors.text),
      PillStyle.secondaryMint => (HColors.surface, HColors.mint),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(HRadii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(HRadii.button),
        onTap: onPressed,
        child: Container(
          height: HSizes.buttonHeight,
          padding: padding,
          alignment: Alignment.center,
          width: expand ? double.infinity : null,
          child: Text(label, style: hText(15, color: fg)),
        ),
      ),
    );
  }
}

/// Circular icon button (send, mic, stop).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 48,
    this.iconSize = 22,
  });

  final HIcon icon;
  final Color iconColor;
  final Color background;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: HIconView(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparent 44x44 tap target around an icon (sliders, back).
class IconTap extends StatelessWidget {
  const IconTap({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color = HColors.muted,
  });

  final HIcon icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox.square(
          dimension: HSizes.minTouch,
          child: Center(child: HIconView(icon, color: color)),
        ),
      ),
    );
  }
}

/// 13px label above a 44dp filled field (Settings, Setup 1).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.readOnly = false,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final bool readOnly;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label, style: hText(13, color: HColors.muted)),
        ),
        SizedBox(
          height: HSizes.inputHeight,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            obscureText: obscure,
            enableSuggestions: !obscure,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onTap: onTap,
            enabled: enabled,
            autocorrect: false,
            style: hText(15, weight: FontWeight.w600),
            cursorColor: HColors.mint,
            decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 14)),
          ),
        ),
      ],
    );
  }
}

/// 44dp pill with a label and a 40x24 switch (Settings).
class SwitchPill extends StatelessWidget {
  const SwitchPill({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: Material(
        color: HColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onChanged(!value),
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: hText(14), overflow: TextOverflow.ellipsis),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: value ? HColors.mint : HColors.dim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: value ? HColors.onMint : HColors.muted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Peach 22x8 active dot / dim 8x8 inactive dots.
class PageDot extends StatelessWidget {
  const PageDot({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(color: active ? HColors.peach : HColors.dim, borderRadius: BorderRadius.circular(4)),
    );
  }
}

/// A selectable 44dp chip (Setup 3 profile picker).
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? HColors.mint : HColors.surface,
        borderRadius: BorderRadius.circular(HRadii.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(HRadii.chip),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Text(label, style: hText(15, color: selected ? HColors.onMint : HColors.text)),
          ),
        ),
      ),
    );
  }
}

/// Compact two-or-more option switcher (e.g. Today | Next) for in-page tabs.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({super.key, required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: HColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, label) in labels.indexed)
            Semantics(
              button: true,
              selected: i == selected,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? HColors.peach : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(label, style: hText(13, color: i == selected ? HColors.onPeach : HColors.body)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Centered title / detail / optional action, used for loading, empty, error and permission states.
class PanelMessage extends StatelessWidget {
  const PanelMessage({super.key, required this.title, this.detail, this.actionLabel, this.onAction, this.onTap});

  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Makes the whole message tappable (e.g. tap to retry).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: hText(20)),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: hText(13, color: HColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            IntrinsicWidth(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Container(
                  height: HSizes.minTouch,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: HColors.peach, borderRadius: BorderRadius.circular(HRadii.button)),
                  child: Semantics(
                    button: true,
                    label: actionLabel,
                    child: Text(actionLabel!, style: hText(15, color: HColors.onPeach)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? body : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body);
  }
}
