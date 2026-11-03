import 'dart:io';

Future<T> withFileLock<T>(String path, Future<T> Function() body) async {
  final file = await File(path).open(mode: FileMode.append);
  try {
    await file.lock(FileLock.blockingExclusive);
    return await body();
  } finally {
    await file.unlock();
    await file.close();
  }
}
