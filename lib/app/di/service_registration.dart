import 'service_registry.dart';
import 'infrastructure_registrations.dart';
import 'core_registrations.dart';
import 'feature_registrations.dart';
import '../../features/story_generation/data/story_pipeline_registration.dart';

/// Register all application-level services into [registry].
///
/// Call this once at app startup, then use [registry.resolve] to obtain
/// instances. Dependencies are resolved lazily — factories run only on
/// first access.
void registerAppServices(ServiceRegistry registry) {
  registerInfrastructureServices(registry);
  registerCoreServices(registry);
  registerStoryGenerationServices(registry);
  registerFeatureServices(registry);
}
