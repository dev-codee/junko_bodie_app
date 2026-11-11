/// Shared with the web: Ready, 3, 2, 1 and GO each last 1.5 seconds.
const privateCountdownBeat = Duration(milliseconds: 1500);
const privateCountdownDuration = Duration(milliseconds: 7500);

enum PrivateCountdownStep {
  ready('Ready?', null),
  three('3', 3),
  two('2', 2),
  one('1', 1),
  go('GO!', 0),
  done('GO!', null);

  const PrivateCountdownStep(this.label, this.beat);
  final String label;
  final int? beat;
}

PrivateCountdownStep privateCountdownStep(Duration elapsed) {
  final index = elapsed.inMilliseconds ~/ privateCountdownBeat.inMilliseconds;
  return PrivateCountdownStep.values[index.clamp(0, 5)];
}
