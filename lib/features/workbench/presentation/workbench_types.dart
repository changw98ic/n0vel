import 'package:flutter/material.dart';

const Color workbenchAccentColor = Color(0xFFB6813B);

enum WorkbenchUiState {
  defaultHidden,
  menuDrawerOpen,
  apiKeyMissing,
  missingCharacterBinding,
  missingCharacterReference,
  missingWorldReference,
  noSimulationYet,
  contextSynced,
  simulationCompleted,
  simulationFailedSummary,
}

enum WorkbenchToolPanel { resources, ai, settings, runCenter }

enum AiToolMode { rewrite, continueWriting }
