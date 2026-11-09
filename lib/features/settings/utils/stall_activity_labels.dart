abstract final class StallActivityLabels {
  static String label(String name) => switch (name) {
    'idle' => 'Not doing anything in particular',
    'terminalIngest' => 'Reading terminal output',
    'terminalResize' => 'Resizing a terminal',
    'transfer' => 'Updating transfers',
    'fileList' => 'Listing files',
    'ssh' => 'SSH traffic',
    'storage' => 'Reading or writing the database',
    'ipc' => 'A command line request',
    'mcp' => 'An MCP request',
    'memoryTrim' => 'Freeing memory',
    _ => 'Drawing the window',
  };
}
