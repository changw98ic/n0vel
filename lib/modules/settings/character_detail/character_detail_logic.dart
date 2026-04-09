import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/data/base_business/base_controller.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/domain/character_profile.dart';
import '../../../features/settings/data/character_repository.dart';
import 'character_detail_state.dart';

class CharacterDetailLogic extends BaseController with GetTickerProviderStateMixin {
  final CharacterDetailState state = CharacterDetailState();
  late String characterId;
  late String workId;

  @override
  void onInit() {
    super.onInit();
    characterId = Get.parameters['characterId'] ?? '';
    workId = Get.parameters['workId'] ?? '';
    state.tabController.value = TabController(length: 4, vsync: this);
    loadData();
  }

  @override
  void onClose() {
    state.tabController.value?.dispose();
    super.onClose();
  }

  Future<void> loadData() async {
    state.isLoading.value = true;
    state.loadError.value = null;

    try {
      final repository = Get.find<CharacterRepository>();
      final character = await repository.getCharacterById(characterId);
      if (character == null) {
        state.loadError.value = 'Character not found';
        state.isLoading.value = false;
        return;
      }
      final profile = await repository.getProfile(characterId);

      state.character.value = character;
      state.profile.value = profile;
      state.isLoading.value = false;
    } catch (e) {
      state.loadError.value = e;
      state.isLoading.value = false;
    }
  }

  void navigateToProfileEdit() {
    Get.toNamed('/work/$workId/characters/$characterId/profile/edit');
  }

  String simulateResponse(Character character, CharacterProfile profile, String situation) {
    final traits = profile.personalityKeywords.join('、');
    final values = profile.coreValues ?? '未设定';

    return '''
基于角色档案分析：
- 性格特质：$traits
- 核心价值观：$values

在"$situation"这种情境下，${character.name}可能的反应：
1. 根据其性格特质，会倾向于${profile.behaviorPatterns.firstOrNull?.behavior ?? '谨慎观察'}
2. 考虑到其核心价值观，可能会${values.contains('正义') ? '选择维护正义' : '优先考虑自身利益'}
3. 语言风格上，可能会表现出${profile.speechStyle?.toneStyle ?? '平静'}的语气

（完整推演需要 AI 服务支持）
''';
  }
}
