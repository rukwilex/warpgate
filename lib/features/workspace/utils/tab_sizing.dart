abstract final class TabSizing {
  static double width({
    required double available,
    required int count,
    required double min,
    required double max,
  }) {
    if (count <= 0) return max;
    return (available / count).floorToDouble().clamp(min, max);
  }
}
