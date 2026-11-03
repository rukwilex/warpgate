enum AppThemeMode { system, light, dark }

enum WgDensity { compact, comfortable }

enum WgAccent {
  amber('Amber'),
  cobalt('Cobalt'),
  teal('Teal'),
  moss('Moss');

  new(this.label);

  final String label;
}

enum WgTerminalScheme {
  followApp('Follow app'),
  graphiteNight('Graphite night'),
  graphiteDay('Graphite day');

  new(this.label);

  final String label;
}
