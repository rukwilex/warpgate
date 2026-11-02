import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/components/wg_controls.dart';
import 'package:warpgate/design_system/components/wg_feedback.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/design_system/components/wg_keycap.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

@immutable
class WgSearchItem<T> {
  const new({
    required this.value,
    required this.title,
    this.subtitle,
    this.section,
    this.leading,
    this.shortcut,
    this.meta,
  });

  final T value;
  final String title;
  final String? subtitle;
  final String? section;
  final Widget? leading;
  final SingleActivator? shortcut;
  final String? meta;
}

class WgSearchList<T> extends StatefulWidget {
  const new({
    required this.items,
    required this.onSelected,
    required this.placeholder,
    super.key,
    this.emptyTitle = 'Nothing matches',
    this.emptyBody,
    this.emptyAction,
    this.onCancel,
    this.maxHeight,
  });

  final List<WgSearchItem<T>> Function(String query) items;
  final ValueChanged<T> onSelected;
  final String placeholder;
  final String emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;
  final VoidCallback? onCancel;
  final double? maxHeight;

  @override
  State<WgSearchList<T>> createState() => _WgSearchListState<T>();
}

class _WgSearchListState<T> extends State<WgSearchList<T>> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _index = 0;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta, int length) {
    if (length == 0) return;
    setState(() => _index = (_index + delta) % length);
    final rowExtent = context.sizes.row;
    final target = _index * rowExtent;
    if (_scroll.hasClients) {
      final viewport = _scroll.position.viewportDimension;
      if (target < _scroll.offset) {
        _scroll.jumpTo(target);
      } else if (target + rowExtent > _scroll.offset + viewport) {
        _scroll.jumpTo(target + rowExtent - viewport);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items(_query);
    final space = context.space;
    final colors = context.colors;
    if (_index >= items.length) _index = 0;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) {
              _move(intent.delta, items.length);
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onCancel?.call();
              return null;
            },
          ),
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(space.sm),
              child: WgTextField(
                controller: _controller,
                autofocus: true,
                placeholder: widget.placeholder,
                leadingIcon: WgIcons.search,
                textInputAction: TextInputAction.go,
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _index = 0;
                }),
                onSubmitted: (_) {
                  if (items.isNotEmpty) widget.onSelected(items[_index].value);
                },
              ),
            ),
            const WgHairline(),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.maxHeight ?? context.sizes.listMax,
                ),
                child: items.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: space.xxl),
                        child: WgEmptyState(
                          title: widget.emptyTitle,
                          body: widget.emptyBody,
                          action: widget.emptyAction,
                        ),
                      )
                    : Semantics(
                        label: '${items.length} results',
                        child: ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: EdgeInsets.all(space.xs),
                          itemCount: items.length,
                          itemExtent: context.sizes.row,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final showSection =
                                item.section != null &&
                                (index == 0 ||
                                    items[index - 1].section != item.section);
                            return WgListRow(
                              title: item.title,
                              meta:
                                  item.meta ??
                                  (showSection ? item.section : null),
                              leading: item.leading,
                              selected: index == _index,
                              semanticLabel: [
                                item.title,
                                ?item.subtitle,
                              ].join(', '),
                              trailing: item.shortcut == null
                                  ? (item.subtitle == null
                                        ? null
                                        : ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: context.sizes.sidebar,
                                            ),
                                            child: Text(
                                              item.subtitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.type.monoSmall
                                                  .copyWith(
                                                    color: colors.textMuted,
                                                  ),
                                            ),
                                          ))
                                  : WgKeycap(item.shortcut!),
                              onPressed: () => widget.onSelected(item.value),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const new(this.delta);

  final int delta;
}

class WgFloatingPanel extends StatelessWidget {
  const new({required this.child, super.key, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: context.sizes.paletteTop,
          left: context.space.lg,
          right: context.space.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width ?? context.sizes.palette),
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: context.radii.lgAll,
              side: BorderSide(color: colors.hairlineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            shadowColor: colors.shadow,
            child: child,
          ),
        ),
      ),
    );
  }
}
