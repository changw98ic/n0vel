import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/settings/domain/character_profile.dart';

class CharacterDetailState {
  final tabController = Rx<TabController?>(null);
  final character = Rx<Character?>(null);
  final profile = Rx<CharacterProfile?>(null);
  final isLoading = true.obs;
  final loadError = Rx<Object?>(null);
}
