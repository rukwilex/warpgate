import 'package:warpgate/features/terminal/data/terminal_session.dart';

String folderHookMessage(FolderHookResult result, String host) =>
    switch (result) {
      FolderHookResult.installed =>
        'Folder tracking is on. New shells on $host report their folder',
      FolderHookResult.unsupported =>
        'The shell on $host is not bash, zsh or fish. The panel checks the folder every few seconds instead',
      FolderHookResult.failed => 'Could not write the startup file on $host',
    };
