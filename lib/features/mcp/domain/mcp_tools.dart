import 'package:warpgate/features/mcp/data/mcp_protocol.dart';

abstract final class McpTools {
  static const _string = {'type': 'string'};
  static const Map<String, Object> _timeout = {
    'type': 'integer',
    'description': 'Maximum run time in milliseconds. Defaults to 30000',
    'minimum': 1000,
    'maximum': 600000,
  };

  static const all = <McpToolSpec>[
    McpToolSpec(
      name: 'list_hosts',
      title: 'List hosts',
      description: 'Saved hosts Claude Code may use, with id, address, user, group, tags and permission level.',
      properties: {},
      readOnly: true,
    ),
    McpToolSpec(
      name: 'list_groups',
      title: 'List host groups',
      description: 'Host groups and the ids of hosts in each.',
      properties: {},
      readOnly: true,
    ),
    McpToolSpec(
      name: 'list_workspaces',
      title: 'List workspaces',
      description: 'Workspaces in the app and which one is active.',
      properties: {},
      readOnly: true,
    ),
    McpToolSpec(
      name: 'list_sessions',
      title: 'List terminal sessions',
      description: 'Open SSH terminal sessions, with host, workspace, status and who opened them.',
      properties: {},
      readOnly: true,
    ),
    McpToolSpec(
      name: 'open_session',
      title: 'Open terminal session',
      description: 'Opens a new SSH terminal tab on a host. The tab is marked as opened by Claude Code.',
      properties: {
        'host_id': _string,
        'workspace_id': {
          'type': 'string',
          'description': 'Workspace to open it in. Defaults to the active one',
        },
      },
      required: ['host_id'],
    ),
    McpToolSpec(
      name: 'close_session',
      title: 'Close terminal session',
      description: 'Closes a terminal session and its pane.',
      properties: {'session_id': _string},
      required: ['session_id'],
      destructive: true,
    ),
    McpToolSpec(
      name: 'run_command',
      title: 'Run command',
      description:
          'Runs a non-interactive command on a separate exec channel and returns stdout, stderr and the exit code. '
          "It never types into the user's terminal. Pass host_id, or session_id to use that session's host.",
      properties: {
        'host_id': _string,
        'session_id': _string,
        'command': _string,
        'timeout_ms': _timeout,
      },
      required: ['command'],
      destructive: true,
    ),
    McpToolSpec(
      name: 'run_on_hosts',
      title: 'Run command on several hosts',
      description: 'Runs one command on several hosts in parallel and returns per-host results.',
      properties: {
        'host_ids': {'type': 'array', 'items': _string},
        'group_id': _string,
        'command': _string,
        'timeout_ms': _timeout,
      },
      required: ['command'],
      destructive: true,
    ),
    McpToolSpec(
      name: 'read_terminal',
      title: 'Read terminal',
      description:
          'Returns the last lines of a terminal session as plain text.',
      properties: {
        'session_id': _string,
        'lines': {'type': 'integer', 'minimum': 1, 'maximum': 5000},
      },
      required: ['session_id'],
      readOnly: true,
    ),
    McpToolSpec(
      name: 'send_input',
      title: 'Type into terminal',
      description:
          r'Types text into a terminal session. Include \r to press Enter.',
      properties: {'session_id': _string, 'text': _string},
      required: ['session_id', 'text'],
      destructive: true,
    ),
    McpToolSpec(
      name: 'sftp_list',
      title: 'List remote folder',
      description:
          'Lists a folder on a host over SFTP. "~" is the home folder.',
      properties: {'host_id': _string, 'path': _string},
      required: ['host_id'],
      readOnly: true,
    ),
    McpToolSpec(
      name: 'sftp_read_file',
      title: 'Read remote file',
      description: 'Reads a text file on a host. Files above max_bytes, at most 1 MB, are refused.',
      properties: {
        'host_id': _string,
        'path': _string,
        'max_bytes': {'type': 'integer', 'minimum': 1, 'maximum': 1048576},
      },
      required: ['host_id', 'path'],
      readOnly: true,
    ),
    McpToolSpec(
      name: 'sftp_write_file',
      title: 'Write remote file',
      description: 'Creates or replaces a text file on a host.',
      properties: {'host_id': _string, 'path': _string, 'content': _string},
      required: ['host_id', 'path', 'content'],
      destructive: true,
    ),
    McpToolSpec(
      name: 'sftp_upload',
      title: 'Upload file',
      description: 'Queues an upload from this device to a host and returns the transfer id.',
      properties: {
        'host_id': _string,
        'local_path': _string,
        'remote_path': _string,
      },
      required: ['host_id', 'local_path', 'remote_path'],
    ),
    McpToolSpec(
      name: 'sftp_download',
      title: 'Download file',
      description: 'Queues a download from a host to this device and returns the transfer id.',
      properties: {
        'host_id': _string,
        'remote_path': _string,
        'local_path': _string,
      },
      required: ['host_id', 'remote_path', 'local_path'],
    ),
    McpToolSpec(
      name: 'transfer_between_hosts',
      title: 'Copy between hosts',
      description: 'Streams a file or folder from one host to another without saving it on this device. Returns the transfer id.',
      properties: {
        'source_host_id': _string,
        'source_path': _string,
        'target_host_id': _string,
        'target_path': _string,
      },
      required: [
        'source_host_id',
        'source_path',
        'target_host_id',
        'target_path',
      ],
    ),
    McpToolSpec(
      name: 'list_transfers',
      title: 'List transfers',
      description: 'Recent transfers with status and progress.',
      properties: {},
      readOnly: true,
    ),
    McpToolSpec(
      name: 'cancel_transfer',
      title: 'Cancel transfer',
      description: 'Cancels a queued or running transfer.',
      properties: {'transfer_id': _string},
      required: ['transfer_id'],
      destructive: true,
    ),
  ];
}
