import 'package:flutter/widgets.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

IconData fileIcon(FileEntry entry) {
  if (entry.isDirectory) return WgIcons.folder;
  if (entry.isLink) return WgIcons.link;
  if (entry.looksLikeImage) return WgIcons.image;
  if (entry.looksLikeText) return WgIcons.fileText;
  return WgIcons.file;
}
