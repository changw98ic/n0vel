import 'agent_evaluation_release_coordinator.dart' as release_coordinator;

/// Compatibility alias for the only real-provider entry point.
///
/// The coordinator launches the frozen signed application runtime; this
/// wrapper no longer turns a forgeable environment bit into test authority.
Future<void> main(List<String> arguments) =>
    release_coordinator.main(arguments);
