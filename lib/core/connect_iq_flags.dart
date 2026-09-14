/// Set via `--dart-define=CIQ_TETHERED=true` (see launch config "Run Android app (CIQ simulator)").
const connectIqTetheredSimulator = bool.fromEnvironment(
  'CIQ_TETHERED',
  defaultValue: false,
);
