import 'package:novel_writer/domain/workspace_models.dart';
export 'package:novel_writer/domain/workspace_models.dart';

// ============================================================================
// UI-only Enums
// ============================================================================

enum StyleInputMode { questionnaire, json }

enum StyleWorkflowState {
  ready,
  empty,
  jsonError,
  unsupportedVersion,
  unknownFieldsIgnored,
  missingRequiredFields,
  validationFailed,
  maxProfilesReached,
  sceneOverrideNotice,
}

enum AuditIssueFilter { all, open, resolved, ignored }

// ============================================================================
// UI State Classes
// ============================================================================

class ProjectStyleState {
  const ProjectStyleState({
    required this.inputMode,
    required this.intensity,
    required this.bindingFeedback,
    required this.questionnaireDraft,
    required this.jsonDraft,
    required this.profiles,
    required this.selectedProfileId,
    required this.workflowState,
    required this.workflowMessage,
    required this.warningMessages,
  });

  final StyleInputMode inputMode;
  final int intensity;
  final String bindingFeedback;
  final Map<String, Object?> questionnaireDraft;
  final String jsonDraft;
  final List<StyleProfileRecord> profiles;
  final String selectedProfileId;
  final StyleWorkflowState workflowState;
  final String workflowMessage;
  final List<String> warningMessages;

  Map<String, Object?> toJson() {
    return {
      'styleInputMode': inputMode.name,
      'styleIntensity': intensity,
      'styleBindingFeedback': bindingFeedback,
      'questionnaireDraft': questionnaireDraft,
      'styleJsonDraft': jsonDraft,
      'styleProfiles': [for (final profile in profiles) profile.toJson()],
      'selectedStyleProfileId': selectedProfileId,
      'styleWorkflowState': workflowState.name,
      'styleWorkflowMessage': workflowMessage,
      'styleWarningMessages': warningMessages,
    };
  }

  ProjectStyleState copyWith({
    StyleInputMode? inputMode,
    int? intensity,
    String? bindingFeedback,
    Map<String, Object?>? questionnaireDraft,
    String? jsonDraft,
    List<StyleProfileRecord>? profiles,
    String? selectedProfileId,
    StyleWorkflowState? workflowState,
    String? workflowMessage,
    List<String>? warningMessages,
  }) {
    return ProjectStyleState(
      inputMode: inputMode ?? this.inputMode,
      intensity: intensity ?? this.intensity,
      bindingFeedback: bindingFeedback ?? this.bindingFeedback,
      questionnaireDraft: questionnaireDraft ?? this.questionnaireDraft,
      jsonDraft: jsonDraft ?? this.jsonDraft,
      profiles: profiles ?? this.profiles,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      workflowState: workflowState ?? this.workflowState,
      workflowMessage: workflowMessage ?? this.workflowMessage,
      warningMessages: warningMessages ?? this.warningMessages,
    );
  }
}

class ProjectAuditUiState {
  const ProjectAuditUiState({
    required this.selectedIssueId,
    required this.selectedIssueIndex,
    required this.filter,
    required this.actionFeedback,
  });

  final String selectedIssueId;
  final int selectedIssueIndex;
  final AuditIssueFilter filter;
  final String actionFeedback;

  Map<String, Object?> toJson() {
    return {
      'selectedAuditIssueId': selectedIssueId,
      'selectedAuditIssueIndex': selectedIssueIndex,
      'auditFilter': filter.name,
      'auditActionFeedback': actionFeedback,
    };
  }

  ProjectAuditUiState copyWith({
    String? selectedIssueId,
    int? selectedIssueIndex,
    AuditIssueFilter? filter,
    String? actionFeedback,
  }) {
    return ProjectAuditUiState(
      selectedIssueId: selectedIssueId ?? this.selectedIssueId,
      selectedIssueIndex: selectedIssueIndex ?? this.selectedIssueIndex,
      filter: filter ?? this.filter,
      actionFeedback: actionFeedback ?? this.actionFeedback,
    );
  }
}

class StyleValidationResult {
  const StyleValidationResult({
    required this.state,
    required this.message,
    required this.warningMessages,
    required this.profileJson,
  });

  final StyleWorkflowState state;
  final String message;
  final List<String> warningMessages;
  final Map<String, Object?> profileJson;
}
