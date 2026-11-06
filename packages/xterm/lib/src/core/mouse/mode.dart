enum MouseMode {
  none,

  clickOnly,

  upDownScroll(reportScroll: true),

  upDownScrollDrag(reportScroll: true),

  upDownScrollMove(reportScroll: true);

  const MouseMode({this.reportScroll = false});

  final bool reportScroll;
}

enum MouseReportMode { normal, utf, sgr, urxvt }
