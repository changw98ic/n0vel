import 'memory_models.dart';

/// Retrieves memory packs for scene context enrichment.
///
/// Kept in app/rag so reusable RAG infrastructure does not depend on the
/// story_generation feature boundary.
abstract interface class StoryMemoryRetrievalService {
  Future<StoryRetrievalPack> retrieve(StoryMemoryQuery query);
}
