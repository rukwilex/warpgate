import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class PathBarSuggestions extends StatelessWidget {
  const new({
    required this.link,
    required this.suggestions,
    required this.highlight,
    required this.onPick,
    super.key,
  });

  final LayerLink link;
  final List<String> suggestions;
  final int highlight;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final width = link.leaderSize?.width ?? sizes.completionList;
    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomLeft,
      offset: Offset(0, space.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Material(
            color: colors.raised,
            borderRadius: context.radii.mdAll,
            child: Container(
              constraints: BoxConstraints(maxHeight: sizes.completionList),
              decoration: BoxDecoration(
                borderRadius: context.radii.mdAll,
                border: Border.all(color: colors.hairlineStrong),
              ),
              child: ListView.builder(
                padding: EdgeInsets.all(space.xs),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) => WgPressable(
                  semanticLabel: suggestions[index],
                  selected: index == highlight,
                  borderRadius: context.radii.smAll,
                  onPressed: () => onPick(suggestions[index]),
                  builder: (context, state) => Container(
                    height: sizes.rowCompact,
                    padding: EdgeInsets.symmetric(horizontal: space.sm),
                    decoration: BoxDecoration(
                      color: index == highlight || state.highlighted
                          ? colors.pressed
                          : colors.transparent,
                      borderRadius: context.radii.smAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          WgIcons.folder,
                          size: sizes.icon,
                          color: colors.textSecondary,
                        ),
                        SizedBox(width: space.sm),
                        Expanded(
                          child: Text(
                            suggestions[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.monoSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
