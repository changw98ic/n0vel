import 'package:get/get.dart';

import '../../app/pages/main_shell_page.dart';
import '../config/app_routes.dart';
// 新 module 路径
import '../../modules/dashboard/dashboard_binding.dart';
import '../../modules/inspiration/inspiration/inspiration_binding.dart';
import '../../modules/work/work_list/work_list_binding.dart';
import '../../modules/work/work_detail/work_detail_binding.dart';
import '../../modules/work/work_detail/work_detail_view.dart';
import '../../modules/work/work_form/work_form_binding.dart';
import '../../modules/work/work_form/work_form_view.dart';
import '../../modules/work/search/search_binding.dart';
import '../../modules/work/search/search_view.dart';
import '../../modules/editor/chapter_editor/chapter_editor_binding.dart';
import '../../modules/editor/chapter_editor/chapter_editor_view.dart';
import '../../modules/settings/settings_panel/settings_panel_binding.dart';
import '../../modules/settings/settings_panel/settings_panel_view.dart';
import '../../modules/settings/character_list/character_list_binding.dart';
import '../../modules/settings/character_list/character_list_view.dart';
import '../../modules/settings/character_detail/character_detail_binding.dart';
import '../../modules/settings/character_detail/character_detail_view.dart';
import '../../modules/settings/character_form/character_form_binding.dart';
import '../../modules/settings/character_form/character_form_view.dart';
import '../../modules/settings/faction_list/faction_list_binding.dart';
import '../../modules/settings/faction_list/faction_list_view.dart';
import '../../modules/settings/item_list/item_list_binding.dart';
import '../../modules/settings/item_list/item_list_view.dart';
import '../../modules/settings/location_list/location_list_binding.dart';
import '../../modules/settings/location_list/location_list_view.dart';
import '../../modules/settings/relationship/relationship_binding.dart';
import '../../modules/settings/relationship/relationship_view.dart';
import '../../modules/ai_config/ai_config/ai_config_binding.dart';
import '../../modules/ai_config/ai_config/ai_config_view.dart';
import '../../modules/ai_config/usage_stats/usage_stats_binding.dart';
import '../../modules/ai_config/usage_stats/usage_stats_view.dart';
import '../../modules/ai_detection/ai_detection/ai_detection_binding.dart';
import '../../modules/ai_detection/ai_detection/ai_detection_view.dart';
import '../../modules/review/review_center/review_center_binding.dart';
import '../../modules/review/review_center/review_center_view.dart';
import '../../modules/timeline/timeline/timeline_binding.dart';
import '../../modules/timeline/timeline/timeline_view.dart';
import '../../modules/pov/pov_generation/pov_generation_binding.dart';
import '../../modules/pov/pov_generation/pov_generation_view.dart';
import '../../modules/reading_mode/reader/reader_binding.dart';
import '../../modules/reading_mode/reader/reader_view.dart';
import '../../modules/statistics/statistics/statistics_binding.dart';
import '../../modules/statistics/statistics/statistics_view.dart';
import '../../modules/ai_chat/ai_chat_binding.dart';
import '../../modules/workflow/view/workflow_task_list_page.dart';
import '../../modules/workflow/view/workflow_task_page.dart';
// 旧 binding（仍需用于仓库注入）
import '../../features/work/bindings/work_binding.dart';

final getPages = [
  // ── 主 Shell（仪表盘 + 作品列表 + 素材 + 设置）──
  GetPage(
    name: AppRoutes.root,
    page: () => const MainShellPage(),
    bindings: [WorkBinding(), DashboardBinding(), WorkListBinding(), InspirationBinding(), AIChatBinding(), AIConfigBinding()],
  ),

  // ── 搜索 ──
  GetPage(
    name: AppRoutes.search,
    page: () => SearchView(),
    binding: SearchBinding(),
  ),

  // ── 作品 ──
  GetPage(
    name: AppRoutes.workDetail,
    page: () => WorkDetailView(),
    binding: WorkDetailBinding(),
  ),
  GetPage(
    name: AppRoutes.workEdit,
    page: () => WorkFormView(),
    binding: WorkFormBinding(),
  ),
  GetPage(
    name: AppRoutes.workNew,
    page: () => WorkFormView(),
    binding: WorkFormBinding(),
  ),

  // ── 章节 ──
  GetPage(
    name: AppRoutes.chapterEditor,
    page: () => ChapterEditorView(
      chapterId: Get.parameters['chapterId']!,
    ),
    binding: ChapterEditorBinding(),
  ),

  // ── 设置面板 ──
  GetPage(
    name: AppRoutes.workSettings,
    page: () => SettingsPanelView(),
    binding: SettingsPanelBinding(),
  ),

  // ── 角色 ──
  GetPage(
    name: AppRoutes.workCharacters,
    page: () => CharacterListView(),
    binding: CharacterListBinding(),
  ),
  GetPage(
    name: AppRoutes.workCharacterNew,
    page: () => CharacterFormView(),
    binding: CharacterFormBinding(),
  ),
  GetPage(
    name: AppRoutes.workCharacterDetail,
    page: () => CharacterDetailView(),
    binding: CharacterDetailBinding(),
  ),

  // ── 关系 / 物品 / 地点 / 势力 ──
  GetPage(
    name: AppRoutes.workRelationships,
    page: () => RelationshipView(),
    binding: RelationshipBinding(),
  ),
  GetPage(
    name: AppRoutes.workItems,
    page: () => ItemListView(),
    binding: ItemListBinding(),
  ),
  GetPage(
    name: AppRoutes.workLocations,
    page: () => LocationListView(),
    binding: LocationListBinding(),
  ),
  GetPage(
    name: AppRoutes.workFactions,
    page: () => FactionListView(),
    binding: FactionListBinding(),
  ),

  // ── AI ──
  GetPage(
    name: AppRoutes.aiConfig,
    page: () => AIConfigView(),
    binding: AIConfigBinding(),
  ),
  GetPage(
    name: AppRoutes.aiUsageStats,
    page: () => UsageStatsView(),
    binding: UsageStatsBinding(),
  ),
  GetPage(
    name: AppRoutes.aiDetection,
    page: () => AIDetectionView(),
    binding: AIDetectionBinding(),
  ),

  // ── 审稿 ──
  GetPage(
    name: AppRoutes.review,
    page: () => const ReviewCenterView(),
    binding: ReviewCenterBinding(),
  ),

  // ── 时间线 ──
  GetPage(
    name: AppRoutes.timeline,
    page: () => const TimelineView(),
    binding: TimelineBinding(),
  ),

  // ── POV ──
  GetPage(
    name: AppRoutes.pov,
    page: () => const POVGenerationView(),
    binding: POVGenerationBinding(),
  ),

  // ── 阅读 ──
  GetPage(
    name: AppRoutes.read,
    page: () => const ReaderView(),
    binding: ReaderBinding(),
  ),

  // ── 统计 ──
  GetPage(
    name: AppRoutes.stats,
    page: () => const StatisticsView(),
    binding: StatisticsBinding(),
  ),

  // ── Workflow 任务 ──
  GetPage(
    name: AppRoutes.workflowTasks,
    page: () => WorkflowTaskListPage(
      workId: Get.parameters['workId']!,
    ),
  ),
  GetPage(
    name: AppRoutes.workflowTask,
    page: () => WorkflowTaskPage(
      taskId: Get.parameters['taskId']!,
    ),
  ),
];
