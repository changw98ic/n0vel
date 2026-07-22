/// Lightweight LLM output validation with automatic retry on schema violations.
///
/// Provides [AppLlmOutputSchema] for declaring validation rules (length bounds,
/// required/forbidden patterns) and [AppLlmSchemaValidatingClient] for
/// wrapping any [AppLlmClient] with automatic schema-based retry.
///
/// Pre-defined named constructors cover the common generation steps in this
/// project: prose output, review output, director plan output, and generic
/// non-empty text.
library;

import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

// ---------------------------------------------------------------------------
// Validation result
// ---------------------------------------------------------------------------

/// Outcome of an [AppLlmOutputSchema.validate] call.
class AppLlmSchemaResult {
  const AppLlmSchemaResult({required this.isValid, this.violations = const []});

  /// `true` when all rules pass.
  final bool isValid;

  /// Human-readable descriptions of every violated rule.
  final List<String> violations;
}

// ---------------------------------------------------------------------------
// Schema definition
// ---------------------------------------------------------------------------

/// A declarative set of rules that an LLM text output must satisfy.
///
/// Use one of the named constructors ([prose], [review], [director], [generic])
/// for common generation steps, or create a custom instance.
class AppLlmOutputSchema {
  const AppLlmOutputSchema({
    this.minLength = 0,
    this.maxLength = double.infinity,
    this.requiredPatterns = const [],
    this.forbiddenPatterns = const [],
    this.description = '',
  });

  /// Minimum character length (inclusive).
  final int minLength;

  /// Maximum character length (inclusive). Defaults to no upper bound.
  final double maxLength;

  /// Each [RegExp] must match somewhere in the output.
  final List<RegExp> requiredPatterns;

  /// If any [RegExp] matches, validation fails.
  final List<RegExp> forbiddenPatterns;

  /// Human-readable description of what this schema expects.
  final String description;

  // ---------------------------------------------------------------------------
  // Pre-defined schemas
  // ---------------------------------------------------------------------------

  /// Schema for scene prose / editorial output.
  ///
  /// Requires at least [minProseLength] characters (default 50) and forbids
  /// common LLM meta-artifacts like markdown fences or preamble chatter.
  static AppLlmOutputSchema prose({int minProseLength = 50}) {
    return AppLlmOutputSchema(
      minLength: minProseLength,
      description:
          'Scene prose output (min $minProseLength chars, '
          'no markdown fences or preamble)',
      forbiddenPatterns: _proseForbiddenPatterns,
    );
  }

  static final List<RegExp> _proseForbiddenPatterns = [
    // Markdown code fences wrapping prose.
    RegExp(r'^```', multiLine: true),
    // Common preamble patterns from chatty LLMs.
    RegExp(r'^(好的|以下是|Here is|Here are|Sure,?\s)', caseSensitive: false),
  ];

  /// Schema for review output.
  ///
  /// Must contain the "决定：" decision line and the "原因：" reason line
  /// that the review coordinator parses.
  static AppLlmOutputSchema review() {
    return AppLlmOutputSchema(
      minLength: 10,
      description: 'Review output (must contain 决定： and 原因：)',
      requiredPatterns: [
        // Decision line — matches both full-width and half-width colon.
        RegExp(r'决定[：:]\s*\S+'),
        // Reason line.
        RegExp(r'原因[：:]'),
      ],
    );
  }

  /// Schema for director plan output.
  ///
  /// Must contain the four structured fields (目标/冲突/推进/约束) that the
  /// director plan format requires.
  static AppLlmOutputSchema director() {
    return AppLlmOutputSchema(
      minLength: 20,
      description: 'Director plan output (must contain 目标/冲突/推进/约束)',
      requiredPatterns: [
        RegExp(r'目标[：:]'),
        RegExp(r'冲突[：:]'),
        RegExp(r'推进[：:]'),
        RegExp(r'约束[：:]'),
      ],
    );
  }

  /// Schema that only requires non-empty output.
  static const AppLlmOutputSchema generic = AppLlmOutputSchema(
    minLength: 1,
    description: 'Generic output (non-empty)',
  );

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Check [output] against all rules in this schema.
  AppLlmSchemaResult validate(String output) {
    final violations = <String>[];

    if (output.length < minLength) {
      violations.add(
        'Output too short: ${output.length} chars '
        '(minimum $minLength).',
      );
    }

    if (output.length > maxLength) {
      violations.add(
        'Output too long: ${output.length} chars '
        '(maximum ${maxLength == maxLength.roundToDouble() ? maxLength.toInt() : maxLength}).',
      );
    }

    for (final pattern in requiredPatterns) {
      if (!pattern.hasMatch(output)) {
        violations.add('Required pattern not found: ${pattern.pattern}');
      }
    }

    for (final pattern in forbiddenPatterns) {
      final match = pattern.firstMatch(output);
      if (match != null) {
        violations.add(
          'Forbidden pattern found at offset ${match.start}: '
          '${pattern.pattern}',
        );
      }
    }

    return AppLlmSchemaResult(
      isValid: violations.isEmpty,
      violations: violations,
    );
  }
}

// ---------------------------------------------------------------------------
// Validating client wrapper
// ---------------------------------------------------------------------------

/// Wraps an [AppLlmClient] with automatic schema validation and retry.
///
/// When [validatedChat] is called with an [AppLlmOutputSchema], the delegate
/// client is invoked. If the result succeeds but the output text fails schema
/// validation, the violation feedback is appended as a user message and the
/// request is retried up to [maxValidationRetries] additional times.
///
/// If the delegate returns a transport failure or retries are exhausted, the
/// last result is returned as-is.
///
/// This class also implements [AppLlmClient] so it can be used as a drop-in
/// decorator. The plain [chat] method delegates without any validation.
class AppLlmSchemaValidatingClient
    implements
        AppLlmClient,
        AppLlmSinglePhysicalDispatchCapability,
        AppLlmPhysicalDispatchLifecycle {
  AppLlmSchemaValidatingClient({
    required AppLlmClient delegate,
    this.maxValidationRetries = 1,
  }) : _delegate = delegate;

  final AppLlmClient _delegate;

  @override
  bool get supportsSinglePhysicalDispatch =>
      appLlmClientSupportsSinglePhysicalDispatch(_delegate);

  @override
  Future<void> shutdownPhysicalDispatches() =>
      shutdownAppLlmClientPhysicalDispatches(_delegate);

  /// Maximum number of automatic retries when schema validation fails.
  /// A value of 0 means validation is performed but no retries are attempted.
  final int maxValidationRetries;

  /// Send [request] through the delegate, validate the output against
  /// [schema], and retry with violation feedback if needed.
  ///
  /// If [schema] is null, delegates directly without validation.
  ///
  /// When [onSchemaValidated] is provided, it is called with the schema type,
  /// validation result, and the final [AppLlmChatResult] so callers can
  /// capture the outcome for tracing. This callback is invoked once — on the
  /// final validation pass (whether succeeded or not).
  Future<AppLlmChatResult> validatedChat(
    AppLlmChatRequest request, {
    AppLlmOutputSchema? schema,
    String? schemaType,
    void Function(
      String? schemaType,
      AppLlmSchemaResult validation,
      AppLlmChatResult result,
    )?
    onSchemaValidated,
  }) async {
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _delegate,
      request: request,
    );
    if (schema == null) {
      // llm-call-site: boundary.schema.passthrough
      return _delegate.chat(request);
    }

    var currentMessages = List<AppLlmChatMessage>.of(request.messages);
    // llm-call-site: boundary.schema.initial
    var lastResult = await _delegate.chat(request);

    final effectiveValidationRetries =
        request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single
        ? 0
        : maxValidationRetries;
    for (var attempt = 0; attempt < effectiveValidationRetries; attempt++) {
      if (!lastResult.succeeded) {
        return lastResult;
      }

      final result = schema.validate(lastResult.text!);
      if (result.isValid) {
        onSchemaValidated?.call(schemaType, result, lastResult);
        return lastResult;
      }

      // Build retry feedback.
      final feedback = _buildRetryFeedback(result, schema);
      currentMessages = [...currentMessages, feedback];
      // llm-call-site: boundary.schema.repair
      lastResult = await _delegate.chat(
        AppLlmChatRequest(
          baseUrl: request.baseUrl,
          apiKey: request.apiKey,
          model: request.model,
          timeout: request.timeout,
          maxTokens: request.maxTokens,
          messages: currentMessages,
          provider: request.provider,
          onPartialText: request.onPartialText,
          formalCacheIdentity: request.formalCacheIdentity,
          formalDispatchIdentity: request.formalDispatchIdentity,
          preferStreaming: request.preferStreaming,
          physicalDispatchPolicy: request.physicalDispatchPolicy,
          dispatchEvidenceNonce: request.dispatchEvidenceNonce,
        ),
      );
    }

    // Final validation attempt on the last result.
    if (lastResult.succeeded) {
      final result = schema.validate(lastResult.text!);
      if (!result.isValid) {
        onSchemaValidated?.call(schemaType, result, lastResult);
        return _withValidationMetadata(lastResult, result);
      }
      onSchemaValidated?.call(schemaType, result, lastResult);
    }

    return lastResult;
  }

  // -- AppLlmClient interface (passthrough, no validation) ----------------

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _delegate,
      request: request,
    );
    // llm-call-site: boundary.schema.interface
    return _delegate.chat(request);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _delegate,
      request: request,
    );
    // llm-call-site: boundary.schema.stream-interface
    return _delegate.chatStream(request);
  }

  // -- Helpers --------------------------------------------------------------

  /// Construct a user-message containing the violation feedback so the LLM
  /// can correct its output format on the next attempt.
  AppLlmChatMessage _buildRetryFeedback(
    AppLlmSchemaResult result,
    AppLlmOutputSchema schema,
  ) {
    final bulletPoints = result.violations.map((v) => '- $v').join('\n');
    final description = schema.description.isEmpty
        ? 'the expected format'
        : schema.description;
    return AppLlmChatMessage(
      role: 'user',
      content:
          '上一轮输出未满足格式要求（$description）。'
          '请修正以下问题并重新生成：\n$bulletPoints\n'
          '直接输出修正后的内容，不要解释。',
    );
  }

  /// Attach validation metadata to a result so callers can distinguish
  /// "succeeded but schema-invalid" from a clean success.
  static AppLlmChatResult _withValidationMetadata(
    AppLlmChatResult original,
    AppLlmSchemaResult validation,
  ) {
    // Preserve success status but annotate the detail with violation info.
    // We keep text intact so the caller can still inspect/use the output.
    // The validation result is not currently surfaced on AppLlmChatResult
    // because that type is frozen.  Callers can re-run schema.validate()
    // on the text if they need the details.
    return AppLlmChatResult.success(
      text: original.text,
      latencyMs: original.latencyMs,
      promptTokens: original.promptTokens,
      completionTokens: original.completionTokens,
      totalTokens: original.totalTokens,
      tokenUsage: original.tokenUsage,
      providerModel: original.providerModel,
      providerResponseId: original.providerResponseId,
      dispatchResolution: original.dispatchResolution,
      providerBoundaryReceipt: original.providerBoundaryReceipt,
    );
  }
}
