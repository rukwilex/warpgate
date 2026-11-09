List<String> parseHostTags(String text) => text
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toSet()
    .toList();
