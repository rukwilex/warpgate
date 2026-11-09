import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FilePermissionsDialog extends StatefulWidget {
  const new({required this.entry, super.key});

  final FileEntry entry;

  @override
  State<FilePermissionsDialog> createState() => _FilePermissionsDialogState();
}

class _FilePermissionsDialogState extends State<FilePermissionsDialog> {
  late int _mode =
      (widget.entry.mode ?? FileBrowserConstants.defaultFileMode) &
      FileBrowserConstants.permissionBitsMask;
  late final _octal = TextEditingController(text: Format.octal(_mode));

  @override
  void dispose() {
    _octal.dispose();
    super.dispose();
  }

  void _setBit(int bit, {required bool on}) {
    setState(() {
      _mode = on ? _mode | (1 << bit) : _mode & ~(1 << bit);
      _octal.text = Format.octal(_mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    const who = ['Owner', 'Group', 'Others'];
    const what = ['Read', 'Write', 'Run'];
    return WgDialog(
      title: 'Permissions for ${widget.entry.name}',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop(_mode),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final label in what)
                    Center(child: Text(label, style: context.type.caption)),
                ],
              ),
              for (final (row, label) in who.indexed)
                TableRow(
                  children: [
                    Text(label, style: context.type.body),
                    for (var column = 0; column < 3; column++)
                      Center(
                        child: WgCheckbox(
                          label: '$label ${what[column].toLowerCase()}',
                          value: _mode & (1 << (8 - row * 3 - column)) != 0,
                          onChanged: (value) =>
                              _setBit(8 - row * 3 - column, on: value),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _octal,
            label: 'Octal',
            mono: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-7]')),
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (value) {
              final parsed = int.tryParse(value, radix: 8);
              if (parsed != null && value.length == 3) {
                setState(() => _mode = parsed);
              }
            },
          ),
          SizedBox(height: context.space.sm),
          Text(
            Format.mode(_mode),
            style: context.type.mono.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
