import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_pressable.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgSegment<T> {
  const new(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class WgSegmented<T> extends StatelessWidget {
  const new({
    required this.segments,
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
    this.iconsOnly = false,
  });

  final List<WgSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final inner = context.radii.md - space.hair;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: Semantics(
        label: label,
        container: true,
        child: Container(
          padding: EdgeInsets.all(space.hair),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final segment in segments)
                WgPressable(
                  semanticLabel: segment.label,
                  selected: segment.value == value,
                  borderRadius: BorderRadius.circular(inner),
                  onPressed: () => onChanged(segment.value),
                  builder: (context, state) {
                    final active = segment.value == value;
                    final ink = active
                        ? colors.textPrimary
                        : colors.textSecondary;
                    return AnimatedContainer(
                      duration: context.motion.fast,
                      curve: context.motion.curve,
                      constraints: BoxConstraints(
                        minHeight: context.sizes.control - space.xs,
                        minWidth: context.sizes.control - space.xs,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: iconsOnly ? space.xs : space.md,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? colors.surface
                            : state.highlighted
                            ? colors.pressed
                            : colors.transparent,
                        borderRadius: BorderRadius.circular(inner),
                        border: Border.all(
                          color: active
                              ? colors.hairlineStrong
                              : colors.transparent,
                        ),
                      ),
                      child: iconsOnly && segment.icon != null
                          ? Tooltip(
                              message: segment.label,
                              excludeFromSemantics: true,
                              child: Icon(
                                segment.icon,
                                size: context.sizes.icon,
                                color: ink,
                              ),
                            )
                          : Text(
                              segment.label,
                              style: context.type.label.copyWith(color: ink),
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
