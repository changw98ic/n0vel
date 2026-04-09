import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../../../app/widgets/app_shell.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/domain/character_profile.dart';
import '../view/relationship_timeline.dart';
import 'character_detail_logic.dart';

class CharacterDetailView extends GetView<CharacterDetailLogic> with BasePage {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.state.isLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.state.loadError.value != null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('加载失败: ${controller.state.loadError.value}')),
        );
      }

      final character = controller.state.character.value;
      if (character == null) {
        return const Scaffold(
          body: Center(child: Text('角色不存在')),
        );
      }

      return buildContent(character, controller.state.profile.value);
    });
  }

  Widget buildContent(Character character, CharacterProfile? profile) {
    return AppPageScaffold(
      title: character.name,
      subtitle: character.identity,
      constrainWidth: false,
      bodyPadding: EdgeInsets.zero,
      bottom: TabBar(
        controller: controller.state.tabController.value,
        tabs: const [
          Tab(text: '档案'),
          Tab(text: '关系'),
          Tab(text: '出场'),
          Tab(text: '推演'),
        ],
      ),
      child: TabBarView(
        controller: controller.state.tabController.value,
        children: [
          ProfileTab(character: character, profile: profile),
          RelationshipsTab(
            characterId: character.id,
            workId: character.workId,
          ),
          AppearancesTab(characterId: character.id),
          SimulationTab(character: character, profile: profile),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final Character character;
  final CharacterProfile? profile;

  const ProfileTab({
    required this.character,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    if (profile == null && character.tier.requiresProfile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 48.sp),
            SizedBox(height: 16.h),
            const Text('需要完善深度档案'),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {
                Get.toNamed('/work/${character.workId}/characters/${character.id}/profile/edit');
              },
              child: const Text('开始填写'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        InfoCard(
          title: '基本信息',
          items: [
            InfoItem(label: '性别', value: character.gender ?? '未知'),
            InfoItem(label: '年龄', value: character.age ?? '未知'),
            InfoItem(label: '身份', value: character.identity ?? '未知'),
          ],
        ),
        SizedBox(height: 16.h),
        if (character.bio != null) ...[
          InfoCard(
            title: '角色简介',
            content: character.bio!,
          ),
          SizedBox(height: 16.h),
        ],
        if (profile != null) ...[
          PersonalitySection(profile: profile!),
          SizedBox(height: 16.h),
          SpeechStyleSection(profile: profile!),
          SizedBox(height: 16.h),
          BehaviorSection(profile: profile!),
        ],
      ],
    );
  }
}

class RelationshipsTab extends StatelessWidget {
  final String characterId;
  final String workId;

  const RelationshipsTab({
    required this.characterId,
    required this.workId,
  });

  @override
  Widget build(BuildContext context) {
    return RelationshipTimelineView(
      characterId: characterId,
      workId: workId,
    );
  }
}

class AppearancesTab extends StatelessWidget {
  final String characterId;

  const AppearancesTab({required this.characterId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('出场记录将在这里显示'));
  }
}

class SimulationTab extends GetView<CharacterDetailLogic> {
  final Character character;
  final CharacterProfile? profile;

  const SimulationTab({
    required this.character,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Center(
        child: Text('需要完善深度档案才能进行角色推演'),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        ElevatedButton.icon(
          onPressed: () {
            showSimulationDialog(context);
          },
          icon: const Icon(Icons.psychology),
          label: const Text('开始角色推演'),
        ),
      ],
    );
  }

  void showSimulationDialog(BuildContext context) {
    final situationController = TextEditingController();
    final responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text('${character.name} - 角色推演'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('输入情境，预测角色反应：'),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: situationController,
                    decoration: const InputDecoration(
                      hintText: '例如：遇到突然袭击时的反应...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16.h),
                  if (responseController.text.isNotEmpty) ...[
                    const Text('预测反应：'),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(responseController.text),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    responseController.text = controller.simulateResponse(
                      character,
                      profile!,
                      situationController.text,
                    );
                  });
                },
                child: const Text('推演'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final List<InfoItem>? items;
  final String? content;

  const InfoCard({
    required this.title,
    this.items,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12.h),
            if (items != null)
              ...items!.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                        Expanded(child: Text(item.value)),
                      ],
                    ),
                  )),
            if (content != null) Text(content!),
          ],
        ),
      ),
    );
  }
}

class InfoItem {
  final String label;
  final String value;

  InfoItem({required this.label, required this.value});
}

class PersonalitySection extends StatelessWidget {
  final CharacterProfile profile;

  const PersonalitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: '性格特质',
      items: [
        if (profile.mbti != null)
          InfoItem(label: 'MBTI', value: profile.mbti!.name),
        if (profile.coreValues != null)
          InfoItem(label: '核心价值观', value: profile.coreValues!),
        if (profile.fears != null)
          InfoItem(label: '恐惧', value: profile.fears!),
        if (profile.desires != null)
          InfoItem(label: '渴望', value: profile.desires!),
      ],
    );
  }
}

class SpeechStyleSection extends StatelessWidget {
  final CharacterProfile profile;

  const SpeechStyleSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final style = profile.speechStyle;
    if (style == null) return const SizedBox.shrink();

    return InfoCard(
      title: '说话风格',
      items: [
        if (style.languageStyle != null)
          InfoItem(label: '语言风格', value: style.languageStyle!),
        if (style.toneStyle != null)
          InfoItem(label: '语气', value: style.toneStyle!),
        if (style.catchphrases?.isNotEmpty == true)
          InfoItem(
            label: '口头禅',
            value: style.catchphrases!.join('、'),
          ),
      ],
    );
  }
}

class BehaviorSection extends StatelessWidget {
  final CharacterProfile profile;

  const BehaviorSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.behaviorPatterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '行为模式',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12.h),
            ...profile.behaviorPatterns.map((pattern) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '触发：${pattern.trigger}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4.h),
                      Text('反应：${pattern.behavior}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
