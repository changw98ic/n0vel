import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/data/base_business/base_page.dart';
import '../view/relationship_dialogs.dart';
import 'relationship_logic.dart';
import 'relationship_widgets.dart';

class RelationshipView extends GetView<RelationshipLogic> with BasePage {
  const RelationshipView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings_relationshipListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => CreateRelationshipDialog(
                workId: controller.workId,
                onCreated: controller.loadRelationships,
              ),
            ),
            tooltip: s.settings_newRelationship,
          ),
        ],
      ),
      body: Column(
        children: [
          RelationshipFilterBar(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return loadingIndicator();
              }
              if (controller.hasError) {
                return errorState(
                  controller.errorMessage.value,
                  onRetry: controller.loadRelationships,
                );
              }
              return RelationshipList(controller: controller);
            }),
          ),
        ],
      ),
    );
  }
}
