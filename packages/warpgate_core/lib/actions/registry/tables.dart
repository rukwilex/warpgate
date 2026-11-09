import 'package:warpgate_core/actions/action_spec.dart';

abstract final class Tables {
  static const hosts = TableSpec('hosts', [
    TableColumn('status', '', format: ColumnFormat.status),
    TableColumn('label', 'LABEL'),
    TableColumn('username', 'USER'),
    TableColumn('address', 'ADDRESS'),
    TableColumn('port', 'PORT', format: ColumnFormat.number),
    TableColumn('auth', 'AUTH'),
    TableColumn('group', 'GROUP'),
  ]);

  static const transfers = TableSpec('transfers', [
    TableColumn('id', 'ID', format: ColumnFormat.id),
    TableColumn('status', 'STATUS'),
    TableColumn('name', 'NAME'),
    TableColumn('done_bytes', 'DONE', format: ColumnFormat.bytes),
    TableColumn('total_bytes', 'TOTAL', format: ColumnFormat.bytes),
    TableColumn('source', 'FROM'),
    TableColumn('target', 'TO'),
  ]);

  static const entries = TableSpec('entries', [
    TableColumn('permissions', 'MODE'),
    TableColumn('owner', 'OWNER'),
    TableColumn('group', 'GROUP'),
    TableColumn('size', 'SIZE', format: ColumnFormat.bytes),
    TableColumn('modified', 'MODIFIED', format: ColumnFormat.time),
    TableColumn('name', 'NAME'),
  ]);
}
