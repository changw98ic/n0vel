part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSnapshotMapping on StoryGenerationRunStore {
  StoryGenerationRunSnapshot _idleSnapshotForCurrentScene() {
    final scene = _workspaceStore.currentSceneOrNull;
    return StoryGenerationRunSnapshot(
      status: StoryGenerationRunStatus.idle,
      phase: StoryGenerationRunPhase.draft,
      sceneId: scene?.id ?? '',
      sceneLabel: scene != null ? _sceneLabel() : '',
      headline: '还没有 AI 试写记录',
      summary: '你可以继续写正文，或点击「让 AI 写本章」生成初稿。',
      stageSummary: '未开始',
    );
  }

  List<StoryGenerationRunParticipant> _participantsForBrief(SceneBrief brief) {
    return [
      const StoryGenerationRunParticipant(
        id: 'director',
        name: '导演',
        role: '固定编排代理',
        summary: '负责整理本章的写作目标，并协调出场人物。',
        statusSummary: '等待发放任务卡',
      ),
      for (final cast in brief.cast)
        StoryGenerationRunParticipant(
          id: cast.characterId,
          name: cast.name,
          role: cast.role,
          summary: cast.metadata['summary']?.toString() ?? cast.role,
          statusSummary: '等待进入人物视角',
        ),
    ];
  }

  StoryGenerationRunSnapshot _snapshotFromOutput(SceneRuntimeOutput output) {
    final roleTurnsByCharacter = {
      for (final turn in output.roleTurns) turn.characterId: turn,
    };
    final participants = [
      StoryGenerationRunParticipant(
        id: 'director',
        name: '导演',
        role: '固定编排代理',
        summary: output.director.taskCard?.sceneGoal ?? output.director.text,
        statusSummary: '任务卡已生成',
      ),
      for (final member in output.resolvedCast)
        StoryGenerationRunParticipant(
          id: member.characterId,
          name: member.name,
          role: member.role,
          summary:
              roleTurnsByCharacter[member.characterId]?.intent ?? member.role,
          statusSummary:
              roleTurnsByCharacter[member.characterId]?.proposedStateChange ??
              '已完成当前人物视角',
        ),
    ];
    return StoryGenerationRunSnapshot(
      status: StoryGenerationRunStatus.completed,
      phase: StoryGenerationRunPhase.feedback,
      sceneId: output.brief.sceneId,
      sceneLabel: _sceneLabel(),
      headline: 'AI 试写完成',
      summary:
          '${output.resolvedCast.length} 位出场人物完成本章，候选内容已保留为记录，检查结果：${output.review.decision.name}。',
      stageSummary: output.review.feedback.isEmpty
          ? '候选稿已生成，等待作者采纳'
          : output.review.feedback,
      turnLabel: output.roleTurns.isEmpty
          ? '第 0 回合'
          : '第 ${output.sceneState?.turnIndex ?? 1} 回合',
      participants: participants,
      messages: [
        ..._authorFeedbackMessages(),
        StoryGenerationRunMessage(
          title: '写作任务',
          body: output.director.text,
          kind: StoryGenerationRunMessageKind.director,
          participantId: 'director',
        ),
        for (final turn in output.roleTurns)
          StoryGenerationRunMessage(
            title:
                '${_participantName(output.resolvedCast, turn.characterId)} · 人物视角',
            body: turn.toLegacyRoleText(),
            kind: StoryGenerationRunMessageKind.roleTurn,
            participantId: turn.characterId,
          ),
        for (final beat in output.resolvedBeats)
          StoryGenerationRunMessage(
            title: '拍 ${beat.beatIndex} · 情节推进',
            body: beat.actionAccepted
                ? [
                    if (beat.acceptedAction.trim().isNotEmpty)
                      beat.acceptedAction.trim(),
                    if (beat.acceptedSpeech.trim().isNotEmpty)
                      beat.acceptedSpeech.trim(),
                    if (beat.stateDelta.isNotEmpty)
                      '状态变化：${beat.stateDelta.join(' / ')}',
                  ].join('\n')
                : beat.rejectionReason,
            kind: StoryGenerationRunMessageKind.beat,
            participantId: beat.actorId,
          ),
        if (output.editorialDraft != null)
          StoryGenerationRunMessage(
            title: '编辑稿',
            body: output.editorialDraft!.text,
            kind: StoryGenerationRunMessageKind.editorial,
          ),
        StoryGenerationRunMessage(
          title: '审查结果',
          body: output.review.feedback.isEmpty
              ? output.review.decision.name
              : output.review.feedback,
          kind: StoryGenerationRunMessageKind.review,
        ),
      ],
    );
  }

  List<StoryGenerationRunMessage> _authorFeedbackMessages() {
    return [
      for (final feedback
          in _directorFeedbackBySceneScope[_activeSceneScopeId] ??
              const <String>[])
        StoryGenerationRunMessage(
          title: '作者反馈',
          body: feedback,
          kind: StoryGenerationRunMessageKind.authorFeedback,
        ),
    ];
  }

  List<StoryGenerationRunMessage> _revisionRequestMessages(
    List<AuthorFeedbackItem> revisionRequests,
  ) {
    return [
      for (final request in revisionRequests)
        StoryGenerationRunMessage(
          title: '已纳入修订请求',
          body: request.note,
          kind: StoryGenerationRunMessageKind.authorFeedback,
        ),
    ];
  }

  String _participantName(
    List<ResolvedSceneCastMember> cast,
    String characterId,
  ) {
    for (final member in cast) {
      if (member.characterId == characterId) {
        return member.name;
      }
    }
    return characterId;
  }
}
