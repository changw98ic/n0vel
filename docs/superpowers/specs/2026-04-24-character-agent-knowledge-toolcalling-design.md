# Character Agent Knowledge Toolcalling And Editorial Scene Pipeline Design

## Why

The current story-generation flow produces readable scene-shaped prose, but it does not reliably produce reader-believable fiction.

The main failure mode is architectural:

- role agents emit abstract summaries instead of actionable decisions
- prose generation invents connective tissue, facts, and motivations on the fly
- review only blocks hard failures, not weak causality, wrong diction, or AI-style overproduction

This design replaces summary-driven scene prose generation with a fact-driven pipeline:

`task card -> roleplay -> state resolution -> editorial drafting -> language polish -> review`

It also replaces proactive context stuffing with controller-managed knowledge retrieval:

`agent decides what it needs -> controller executes retrieval tools -> controller injects compressed capsules -> agent continues`

This keeps agents in-character, limits prompt bloat, and avoids polluting permanent chat history with raw tool results.

## Goals

- Make each character agent act from role setup, relationship state, social position, and subjective belief state.
- Support gradual disclosure so agents only see what they should know at that moment.
- Support dynamic prompt trimming without forcing brittle static prompt templates.
- Move prose generation from free-form authoring toward professional editorial stitching over resolved facts.
- Preserve current high-level orchestrator boundaries where possible.
- Keep compatibility with the current real-validation workflow while enabling phased migration.

## Non-Goals

- Do not require provider-native tool calling as a prerequisite.
- Do not introduce a full agent framework outside the existing story-generation subsystem.
- Do not solve global novel planning in this phase.
- Do not optimize for maximal literary style before the fact-model is correct.

## Current Gaps

Current code paths:

- `SceneDirectorOutput` is raw text only.
- `DynamicRoleAgentOutput` is raw text only.
- `SceneProseDraft` is the first full prose artifact.
- `SceneReviewCoordinator` reviews for blocking issues only.

Relevant files:

- `lib/features/story_generation/data/story_generation_models.dart`
- `lib/features/story_generation/data/scene_director_orchestrator.dart`
- `lib/features/story_generation/data/dynamic_role_agent_runner.dart`
- `lib/features/story_generation/data/scene_prose_generator.dart`
- `lib/features/story_generation/data/scene_review_coordinator.dart`
- `lib/features/story_generation/data/chapter_generation_orchestrator.dart`

Observed consequences:

- no machine-verifiable fact layer between role output and prose
- no explicit belief model
- no explicit presentation or deception model
- no on-demand retrieval model
- no dedicated lexicon or reader-flow review stage

## Design Principles

1. Facts before prose.
2. Subjective beliefs are first-class data, not hidden inside text.
3. Retrieval should be agent-driven but controller-managed.
4. Tool results should be summarized into temporary capsules, not appended as raw chat history.
5. Editing may reorganize and compress established facts, but may not invent new ones.
6. Polishing may improve language, but may not alter accepted scene facts.

## Runtime Model

### Three State Layers

Every scene turn operates on three parallel layers:

- `TruthState`: what is actually true in the world
- `BeliefState`: what each character believes is true
- `PresentationState`: what each character is trying to make others perceive

The system must keep these separate. Most current AI-feel and logic drift comes from collapsing them into one prose prompt.

### New Scene Flow

For one scene:

1. `director` builds a `SceneTaskCard`
2. each character agent runs one decision turn
3. the `SceneStateResolver` accepts or rejects proposed actions and updates truth state
4. belief deltas are recomputed per character
5. loop until scene exit condition is met
6. `SceneEditor` turns resolved beats into narrative prose
7. `ScenePolishPass` fixes diction, flow, tone, and AI-style artifacts
8. review runs on fact consistency, reader flow, and lexicon/style

## Toolcalling Strategy

### Recommendation

Do not make provider-native tool calling the core architecture.

Instead, implement a controller-managed retrieval loop that behaves like tool calling:

1. agent receives a minimal prompt
2. agent emits either a decision or a retrieval request
3. controller executes retrieval tools
4. controller compresses raw results into one or more `ContextCapsule`s
5. controller rebuilds the next prompt with the new capsules
6. agent continues

This yields the desired behavior without binding the system to a specific LLM API capability.

### Why Not Raw Tool Results In History

Raw tool returns cause:

- prompt inflation
- repeated context duplication
- accidental cross-agent leakage
- role agents behaving like document readers instead of scene participants

Therefore:

- raw tool results live in controller-side sidecar memory
- only compressed capsules enter the active prompt
- capsules may expire after one turn

## New Data Model

### Character Foundations

```dart
class CharacterProfile {
  final String characterId;
  final String name;
  final String role;
  final List<String> coreDrives;
  final List<String> fears;
  final List<String> values;
  final List<String> boundaries;
  final List<String> speechTraits;
  final Map<String, Object?> metadata;
}

class RelationshipState {
  final String sourceCharacterId;
  final String targetCharacterId;
  final double trust;
  final double dependence;
  final double fear;
  final double resentment;
  final double desire;
  final double powerGap;
  final String publicAlignment;
  final String privateAlignment;
  final List<String> sharedSecrets;
  final List<String> recentTriggers;
}

class SocialPositionState {
  final String characterId;
  final String institution;
  final String publicStatus;
  final String legalExposure;
  final List<String> resources;
  final List<String> activeConstraints;
  final List<String> currentLeverage;
  final List<String> watchers;
}
```

### Subjective Cognition

```dart
class BeliefState {
  final String ownerCharacterId;
  final String aboutCharacterId;
  final String perceivedGoal;
  final String perceivedLoyalty;
  final String perceivedCompetence;
  final String perceivedRisk;
  final String perceivedEmotionalState;
  final List<String> perceivedKnowledge;
  final List<String> suspectedSecrets;
  final List<String> misreadPoints;
  final double confidence;
}

class PresentationState {
  final String characterId;
  final String projectedPersona;
  final List<String> concealments;
  final List<String> deceptionGoals;
}
```

### Knowledge And Retrieval

```dart
enum KnowledgeVisibility {
  truthOnly,
  editorOnly,
  resolverOnly,
  agentPrivate,
  publicObservable,
}

class KnowledgeAtom {
  final String id;
  final String type;
  final String content;
  final String ownerScope;
  final KnowledgeVisibility visibility;
  final int priority;
  final int tokenCostEstimate;
  final List<String> tags;
  final Map<String, Object?> unlockCondition;
}

class AgentToolIntent {
  final String toolName;
  final String reason;
  final List<String> targetIds;
  final String question;
  final int priority;
}

class ContextCapsule {
  final String id;
  final String capsuleType;
  final String sourceTool;
  final String summary;
  final List<String> salientFacts;
  final List<String> uncertainties;
  final int expiresAfterTurn;
  final List<String> visibilityScopes;
}
```

### Roleplay And Resolution

```dart
class RolePlayTurnOutput {
  final String characterId;
  final String intent;
  final String spokenLine;
  final String physicalAction;
  final String observation;
  final String proposedStateChange;
  final String riskTaken;
  final List<String> withheldInfo;
}

class ResolvedBeat {
  final int beatIndex;
  final String actorId;
  final bool actionAccepted;
  final String acceptedSpeech;
  final String acceptedAction;
  final List<String> stateDelta;
  final List<String> newPublicFacts;
  final List<String> continuityNotes;
}

class SceneState {
  final String sceneId;
  final int turnIndex;
  final int beatIndex;
  final Map<String, Object?> locationState;
  final Map<String, String> propOwnership;
  final Map<String, List<String>> knownFactsByCharacter;
  final List<String> openThreats;
  final double tensionLevel;
}
```

### Editorial Output

```dart
class SceneEditorialDraft {
  final String text;
  final List<int> beatOrder;
  final String povStrategy;
}

class ScenePolishDraft {
  final String text;
  final List<String> editsSummary;
}
```

## Tool Registry

Start with a small tool surface:

- `get_self_profile`
- `get_relationship_slice`
- `get_social_position_slice`
- `get_belief_slice`
- `get_scene_state_slice`
- `get_recent_turn_delta`

Each tool returns structured data to the controller. The controller is responsible for summarization into capsules.

## Context Assembly Rules

### For Role Agents

The role agent prompt should contain:

- current task card slice
- self profile summary
- relationship slice for in-scene actors only
- social-position slice
- belief slices for relevant actors only
- previous-turn delta capsule
- formatting contract for `RolePlayTurnOutput`

It should not contain:

- full truth state
- other characters' private beliefs
- raw historical tool output
- global world bible unless directly relevant

### For Resolver

The resolver sees:

- full accepted scene truth state
- all role outputs for the current turn
- spatial and rule constraints

It does not need literary style guidance.

### For Editor

The editor sees:

- resolved beats
- permitted POV strategy
- scene-level style target
- observable facts only, unless omniscient narration is explicitly allowed

It should not consume raw role prompts.

### For Polish

The polish pass sees:

- editorial draft
- lexicon rules
- style rules
- explicit anti-AI constraints

It should not query role cognition tools.

## Capsule Policy

Capsules are ephemeral by default.

Suggested policy:

- turn-critical capsules expire after `1` turn
- stable self-identity capsules may persist across the whole scene
- relationship and belief capsules may persist until invalidated by a resolved beat
- raw tool results remain in sidecar memory only

## Migration Plan

### Phase 1: Introduce New Models Without Breaking Current Flow

Files:

- extend `story_generation_models.dart` or split into:
  - `story_generation_models.dart`
  - `story_generation_knowledge_models.dart`
  - `story_generation_scene_models.dart`

Changes:

- keep legacy `text` fields for compatibility
- add structured fields beside them
- add telemetry for new stages

### Phase 2: Replace Role Summary With Structured Roleplay

Files:

- replace `dynamic_role_agent_runner.dart` internals
- add `agent_turn_controller.dart`
- add `knowledge_tool_registry.dart`
- add `context_capsule_store.dart`

Result:

- role agents output `RolePlayTurnOutput`
- controller-managed retrieval loop is active

### Phase 3: Add Resolver Layer

Files:

- add `scene_state_resolver.dart`
- add `belief_state_updater.dart`

Result:

- accepted scene facts become explicit
- scene progression no longer depends on prose inventing transitions

### Phase 4: Split Prose Into Editor And Polish

Files:

- replace `scene_prose_generator.dart` with:
  - `scene_editor.dart`
  - `scene_polish_pass.dart`

Result:

- editor drafts only from resolved beats
- polish cleans language without changing facts

### Phase 5: Expand Review

Files:

- evolve `scene_review_coordinator.dart`

Add review lanes:

- `fact_review`
- `reader_flow_review`
- `lexicon_review`

Current `judge` and `consistency` may remain as legacy aliases during migration.

## File-Level Mapping

### Keep

- `chapter_generation_orchestrator.dart` as top-level conductor
- `scene_cast_resolver.dart` as cast entry filter

### Evolve

- `scene_director_orchestrator.dart` -> outputs `SceneTaskCard`
- `dynamic_role_agent_runner.dart` -> becomes roleplay turn runner
- `scene_review_coordinator.dart` -> multi-lane review coordinator

### Replace

- `scene_prose_generator.dart` -> editor + polish

### Add

- `knowledge_tool_registry.dart`
- `agent_turn_controller.dart`
- `context_capsule_store.dart`
- `scene_state_resolver.dart`
- `belief_state_updater.dart`
- `scene_editor.dart`
- `scene_polish_pass.dart`

## Testing Strategy

### Unit Tests

- knowledge visibility and disclosure policy
- budget trimming and capsule assembly
- role tool-intent loop behavior
- resolver acceptance and rejection rules
- belief-state updates after resolved beats
- editor does not invent unseen facts
- polish does not alter accepted facts

### Integration Tests

- one scene with two agents and one misinformation edge
- one scene where beliefs change after a failed bluff
- one scene where the editor must stitch multi-turn beats without inventing facts

### Real Validation Extensions

Extend the existing real validation to log:

- tool intents per role
- capsules produced per role
- resolved beats per scene
- review failures by lane

## Risks

- The first structured roleplay schema may be too verbose; keep fields minimal.
- Resolver complexity may grow quickly; enforce a narrow first version.
- Editor quality may initially feel flatter because invention is restricted; this is acceptable in the short term because factual integrity is the current priority.
- Belief updates can drift if not validated; add deterministic tests early.

## Open Questions

- Should one scene allow multiple roleplay turns by default, or only when the resolver marks the scene unresolved?
- Should the editor be restricted to close-third POV first, with omniscient editing added later?
- Should capsules be cached across scenes for recurring relationship pressure, or only across turns inside one scene?

## Recommendation

Start with one narrow vertical slice:

- scene 1 with two agents
- structured roleplay output
- resolver
- editor
- no polish yet

Once that slice produces fact-consistent prose, add polish and richer retrieval tools.

This keeps the architecture grounded and avoids optimizing language before the behavior model is correct.
