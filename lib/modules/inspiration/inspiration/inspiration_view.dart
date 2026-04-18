import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'inspiration_logic.dart';
import 'inspiration_widgets.dart';

/// 鐏垫劅绱犳潗搴撻〉闈?
class InspirationView extends GetView<InspirationLogic> with BasePage {
  const InspirationView({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    searchController.addListener(() {
      controller.setSearchQuery(searchController.text.trim());
    });

    return AppPageScaffold(
      title: '绱犳潗搴?',
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inspiration_fab',
        onPressed: () => showInspirationCreateDialog(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: const Text('鏂板缓绱犳潗'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => InspirationSearchField(
              controller: searchController,
              searchQuery: controller.state.searchQuery.value,
              onClear: () {
                searchController.clear();
                controller.clearSearch();
              },
            ),
          ),
          SizedBox(height: 12.h),
          InspirationCategoryChips(controller: controller),
          SizedBox(height: 16.h),
          Expanded(
            child: InspirationContentList(
              controller: controller,
              onCreate: () => showInspirationCreateDialog(context, controller),
            ),
          ),
        ],
      ),
    );
  }
}
