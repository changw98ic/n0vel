import 'simulation_models.dart';
import 'simulation_snapshot_builder.dart';

/// Encodes simulation state into a JSON-serializable map.
Map<String, Object?> encodeSimulationJson({
  required SimulationTemplate template,
  required SimulationRunMode runMode,
  required Map<SimulationParticipant, String> promptOverrides,
  required List<SimulationChatMessage> extraMessages,
}) {
  return {
    'template': template.name,
    'runMode': runMode.name,
    'promptOverrides': {
      for (final entry in promptOverrides.entries) entry.key.name: entry.value,
    },
    'extraMessages': [
      for (final message in extraMessages)
        {
          'sender': message.sender,
          'title': message.title,
          'body': message.body,
          'tone': message.tone.name,
          'alignEnd': message.alignEnd,
          'kind': message.kind.name,
        },
    ],
  };
}

/// Decodes a template enum from its persisted name.
SimulationTemplate decodeTemplateName(String? name) {
  return switch (name) {
    'runningStepOne' => SimulationTemplate.runningStepOne,
    'runningStepTwo' => SimulationTemplate.runningStepTwo,
    'completed' => SimulationTemplate.completed,
    'failed' => SimulationTemplate.failed,
    _ => SimulationTemplate.none,
  };
}

/// Decodes a run-mode enum from its persisted name.
SimulationRunMode decodeRunModeName(String? name) {
  return switch (name) {
    'realAgents' => SimulationRunMode.realAgents,
    _ => SimulationRunMode.template,
  };
}

/// Decodes prompt overrides from a persisted JSON structure.
Map<SimulationParticipant, String> decodePromptOverrides(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final result = <SimulationParticipant, String>{};
  for (final entry in raw.entries) {
    final participant = SimulationParticipant.values.where(
      (candidate) => candidate.name == entry.key.toString(),
    );
    if (participant.isEmpty || entry.value is! String) {
      continue;
    }
    result[participant.first] = entry.value as String;
  }
  return result;
}

/// Decodes extra messages from a persisted JSON structure.
List<SimulationChatMessage> decodeMessages(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final messages = <SimulationChatMessage>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final toneName = item['tone']?.toString();
    final tone = SimulationChatTone.values.where(
      (candidate) => candidate.name == toneName,
    );
    if (tone.isEmpty) {
      continue;
    }
    messages.add(
      SimulationChatMessage(
        sender: item['sender']?.toString() ?? '',
        title: item['title']?.toString() ?? '',
        body: item['body']?.toString() ?? '',
        tone: tone.first,
        alignEnd: item['alignEnd'] == true,
        kind: decodeMessageKindName(item['kind']?.toString()),
      ),
    );
  }
  return messages;
}

/// Decodes a message kind enum from its persisted name.
SimulationMessageKind decodeMessageKindName(String? name) {
  return switch (name) {
    'intent' => SimulationMessageKind.intent,
    'verdict' => SimulationMessageKind.verdict,
    'summary' => SimulationMessageKind.summary,
    _ => SimulationMessageKind.speech,
  };
}
