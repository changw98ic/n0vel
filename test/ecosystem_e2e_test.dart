// ============================================================================
// M8-08 Ecosystem Integration Validation
// ============================================================================
//
// End-to-end test validating that M8 ecosystem features work together:
// - Plugin manifest/installer/registry participation in a complete flow
// - Template catalog/application path applying a template to project metadata
// - Lore graph representing cross-project relationships
// - Review package export/viewable payload generation
// - DefaultModelRouter selecting a valid model route without leaking secrets

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/model_router.dart';
import 'package:novel_writer/app/lore/lore_graph.dart';
import 'package:novel_writer/app/plugin/plugin.dart';
import 'package:novel_writer/app/template/template.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/audit/data/review_package.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';

void main() {
  group('M8-08 Ecosystem Integration', () {
    group('Plugin Flow', () {
      test(
        'manifest parsing, installer plan, and registry hook discovery',
        () async {
          // 1. Parse a valid plugin manifest
          final manifest = PluginManifest.fromJson({
            'schemaVersion': 1,
            'pluginId': 'com.example.cross-project-linker',
            'displayName': 'Cross-Project Linker',
            'version': '1.0.0',
            'description': 'Links related content across projects.',
            'runtime': {'kind': 'templateOnly'},
            'permissions': [
              'project:read',
              'character:read',
              'world:read',
              'memory:preview',
            ],
            'hooks': [
              {
                'id': 'link.scan',
                'type': 'command.palette',
                'title': 'Scan Cross-Project Links',
                'command': 'link.scan',
              },
              {
                'id': 'link.export',
                'type': 'project.export',
                'title': 'Export Linked Content',
              },
            ],
            'templates': [
              {
                'templateId': 'cross-project-seed',
                'path': 'templates/linked-project.json',
              },
            ],
            'minimumAppVersion': '0.9.0',
          });

          expect(manifest.pluginId, 'com.example.cross-project-linker');
          expect(manifest.runtime.kind, PluginRuntimeKind.templateOnly);
          expect(
            manifest.permissions,
            contains(PluginPermission.characterRead),
          );
          expect(manifest.hooks, hasLength(2));
          expect(manifest.templates.single.templateId, 'cross-project-seed');

          // 2. Create install plan (simulated with in-memory validation)
          final testBundleDir = Directory.systemTemp.createTempSync(
            'plugin_bundle_',
          );
          try {
            final manifestFile = File(
              '${testBundleDir.path}/plugin.n0vel.json',
            );
            await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

            final readmeFile = File('${testBundleDir.path}/README.md');
            await readmeFile.writeAsString(
              '# Cross-Project Linker\n\nA test plugin.',
            );

            // Create the template file referenced by the plugin manifest
            final templatesDir = Directory('${testBundleDir.path}/templates');
            await templatesDir.create();
            final templateFile = File(
              '${testBundleDir.path}/templates/linked-project.json',
            );
            await templateFile.writeAsString(
              '{"templateId": "cross-project-seed"}',
            );

            const installer = PluginInstaller();
            final plan = await installer.createInstallPlan(testBundleDir);

            expect(plan.bundleRootPath, testBundleDir.path);
            expect(plan.manifest.pluginId, manifest.pluginId);
            expect(plan.manifestDigest, startsWith('sha256:'));
            expect(plan.referencedFiles, hasLength(3));

            // 3. Install into registry and discover hooks
            final registry = PluginRegistry();
            registry.install(
              InstalledPluginRecord(
                manifest: plan.manifest,
                bundlePath: plan.bundleRootPath,
                manifestDigest: plan.manifestDigest,
                installedAt: DateTime.utc(2026, 5, 26),
                enabled: true,
              ),
            );

            final commandHooks = registry.hooksForType(
              PluginHookType.commandPalette,
            );
            expect(commandHooks, hasLength(1));
            expect(commandHooks.single.hook.id, 'link.scan');

            final exportHooks = registry.hooksForType(
              PluginHookType.projectExport,
            );
            expect(exportHooks, hasLength(1));
            expect(exportHooks.single.hook.id, 'link.export');

            // 4. Verify template contribution is discoverable
            final installedPlugin = registry.find(manifest.pluginId);
            expect(installedPlugin, isNotNull);
            expect(installedPlugin!.manifest.templates, hasLength(1));
            expect(
              installedPlugin.manifest.templates.single.path,
              'templates/linked-project.json',
            );
          } finally {
            testBundleDir.deleteSync(recursive: true);
          }
        },
      );
    });

    group('Template Flow', () {
      test('catalog installation and project seed application', () async {
        // 1. Create a template bundle
        final testBundleDir = Directory.systemTemp.createTempSync(
          'template_bundle_',
        );
        try {
          final manifest = TemplateManifest.fromJson({
            'schemaVersion': 1,
            'templateId': 'shared-universe-seed',
            'displayName': 'Shared Universe Seed',
            'version': '1.0.0',
            'locale': 'en-US',
            'minimumAppVersion': '0.9.0',
            'description': 'A project template optimized for shared universes.',
            'genre': 'science-fiction',
            'tags': ['shared-world', 'multi-project'],
            'projectSeed': {
              'title': 'Untitled Shared Universe',
              'genre': 'science-fiction',
              'language': 'en-US',
              'targetWordCount': 80000,
            },
          });

          final manifestFile = File(
            '${testBundleDir.path}/template.n0vel.json',
          );
          await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

          final readmeFile = File('${testBundleDir.path}/README.md');
          await readmeFile.writeAsString(
            '# Shared Universe Seed\n\nA test template.',
          );

          // 2. Create install plan and add to catalog
          const installer = TemplateInstaller();
          final plan = await installer.createInstallPlan(testBundleDir);

          final catalog = TemplateCatalog();
          final entry = TemplateCatalogEntry.fromInstallPlan(
            plan,
            installedAt: DateTime.utc(2026, 5, 26),
          );
          catalog.install(entry);

          // 3. Verify catalog discovery
          final found = catalog.find('shared-universe-seed');
          expect(found, isNotNull);
          expect(found!.source, TemplateCatalogSource.local);
          expect(found.manifest.displayName, 'Shared Universe Seed');

          // 4. Verify project seed metadata can be applied
          final seed = found.manifest.projectSeed;
          expect(seed.title, 'Untitled Shared Universe');
          expect(seed.genre, 'science-fiction');
          expect(seed.language, 'en-US');
          expect(seed.targetWordCount, 80000);
        } finally {
          testBundleDir.deleteSync(recursive: true);
        }
      });
    });

    group('Lore Graph Flow', () {
      test('cross-project relationships and projection', () {
        // 1. Build a lore graph with two project nodes and cross-project relations
        final graph = LoreGraph.empty
            .upsertNode(
              const LoreGraphNode(
                id: 'project:alpha',
                projectId: 'alpha',
                label: 'Project Alpha',
                type: LoreNodeType.project,
              ),
            )
            .upsertNode(
              const LoreGraphNode(
                id: 'project:beta',
                projectId: 'beta',
                label: 'Project Beta',
                type: LoreNodeType.project,
              ),
            )
            .upsertNode(
              const LoreGraphNode(
                id: 'char:hero-alpha',
                projectId: 'alpha',
                label: 'Alex Chen',
                type: LoreNodeType.character,
                description: 'Protagonist of Alpha',
              ),
            )
            .upsertNode(
              const LoreGraphNode(
                id: 'char:mentor-beta',
                projectId: 'beta',
                label: 'Dr. Sarah Vance',
                type: LoreNodeType.character,
                description: 'Mentor figure in Beta',
              ),
            )
            .upsertNode(
              const LoreGraphNode(
                id: 'place:shared-institute',
                projectId: 'alpha',
                label: 'Institute of Advanced Research',
                type: LoreNodeType.location,
              ),
            )
            .addManualRelation(
              sourceNodeId: 'char:hero-alpha',
              targetNodeId: 'char:mentor-beta',
              kind: 'mentor',
              label: 'mentored by',
            )
            .addManualRelation(
              sourceNodeId: 'char:mentor-beta',
              targetNodeId: 'place:shared-institute',
              kind: 'works-at',
              label: 'works at',
            );

        // 2. Verify cross-project relationships are tracked
        expect(graph.projectIds, containsAll(['alpha', 'beta']));
        expect(graph.nodesForProject('alpha'), hasLength(3));
        expect(graph.nodesForProject('beta'), hasLength(2));

        final crossProjectRelations = graph.crossProjectRelations();
        expect(crossProjectRelations, hasLength(2));
        expect(crossProjectRelations.first.sourceNodeId, 'char:hero-alpha');
        expect(crossProjectRelations.first.targetNodeId, 'char:mentor-beta');
        expect(crossProjectRelations.last.sourceNodeId, 'char:mentor-beta');
        expect(
          crossProjectRelations.last.targetNodeId,
          'place:shared-institute',
        );

        // 3. Verify projection produces viewable structured data
        final projection = const LoreGraphProjector().project(graph);

        expect(projection.clusters, hasLength(2));
        expect(projection.nodes, hasLength(5));
        expect(projection.relations, hasLength(2));

        final crossProjectVisualRelation = projection.relations.firstWhere(
          (r) => r.crossProject,
        );
        expect(crossProjectVisualRelation.kind, 'mentor');
        expect(
          crossProjectVisualRelation.direction,
          LoreRelationDirection.directed,
        );

        // 4. Verify project summaries
        final summaries = graph.projectSummaries();
        expect(summaries, hasLength(2));
        final alphaSummary = summaries.firstWhere(
          (s) => s.projectId == 'alpha',
        );
        expect(alphaSummary.nodeCount, 3);
        expect(alphaSummary.relationCount, 2);
      });
    });

    group('Review Package Flow', () {
      test('export produces viewable structured data', () {
        // 1. Create a review package with project/review/candidate evidence
        final exportedAt = DateTime.utc(2026, 5, 26, 10, 30);
        final package = const ReviewPackageExporter().exportPackage(
          metadata: ReviewPackageMetadata(
            packageId: 'ecosystem-validation-001',
            projectId: 'alpha',
            projectTitle: 'Project Alpha',
            exportedAt: exportedAt,
            sourceBranch: 'feature/m8-08-validation',
            sourceCommit: 'abc123def456',
            appVersion: '0.9.0',
          ),
          auditIssues: const [
            AuditIssueRecord(
              id: 'issue-consistency-001',
              title: 'Character Inconsistency',
              evidence: 'Alex Chen age differs between chapters.',
              target: 'Chapter 3, Scene 5',
              status: AuditIssueStatus.open,
              lastAction: 'Detected by consistency checker',
              ignoreReason: '',
            ),
          ],
          reviewTasks: [
            ReviewTask(
              id: 'task-pacing-001',
              severity: ReviewTaskSeverity.info,
              status: ReviewTaskStatus.open,
              title: 'Consider adding transition scene',
              body: 'The jump from the institute to the showdown feels abrupt.',
              reference: ReviewTaskReference(
                projectId: 'alpha',
                chapterId: 'chapter-8',
                chapterTitle: 'Chapter 8',
                sceneId: 'scene-3',
                sceneTitle: 'Confrontation',
              ),
              source: ReviewTaskSource(
                kind: 'pacing_analysis',
                reviewId: 'review-pacing-001',
                runId: 'run-2026-05-26',
                passName: 'pacing-check',
                metadata: {'score': '0.65'},
              ),
              createdAt: DateTime.utc(2026, 5, 26, 9),
              updatedAt: DateTime.utc(2026, 5, 26, 10),
            ),
          ],
        );

        // 2. Verify package structure
        expect(package.schemaVersion, 1);
        expect(package.kind, 'n0vel.reviewPackage');
        expect(package.metadata.projectId, 'alpha');
        expect(package.metadata.projectTitle, 'Project Alpha');

        // 3. Verify issues are included
        expect(package.issues, hasLength(1));
        expect(package.issues.single.id, 'issue-consistency-001');
        expect(package.issues.single.isOpen, isTrue);
        expect(package.issues.single.source.kind, 'audit_issue');

        // 4. Verify suggestions are included
        expect(package.suggestions, hasLength(1));
        expect(package.suggestions.single.id, 'task-pacing-001');
        expect(package.suggestions.single.severity, 'info');
        expect(package.suggestions.single.isOpen, isTrue);
        expect(package.suggestions.single.source.kind, 'pacing_analysis');

        // 5. Verify summary is accurate
        expect(package.summary.issueCount, 1);
        expect(package.summary.suggestionCount, 1);
        expect(package.summary.openCount, 2);

        // 6. Verify export produces viewable JSON
        final jsonText = package.toShareableJson();
        final decoded = jsonDecode(jsonText) as Map<String, Object?>;

        expect(decoded['kind'], 'n0vel.reviewPackage');
        expect(decoded['schemaVersion'], 1);
        expect(decoded['format'], isA<Map<String, Object?>>());
        expect(
          decoded['format'],
          containsPair('description', contains('Review package export')),
        );
        expect(decoded['metadata'], containsPair('projectId', 'alpha'));
        expect(decoded['summary'], containsPair('openCount', 2));
        expect(decoded['issues'], isA<List<Object?>>());
        expect(decoded['suggestions'], isA<List<Object?>>());
      });
    });

    group('Model Router Flow', () {
      test('selects valid route without leaking secrets in trace', () {
        // 1. Create a representative routing scenario
        const request = ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.sceneDraft,
          estimatedInputTokens: 2000,
          estimatedOutputTokens: 1500,
          profiles: [
            ModelRouteProfile(
              id: 'local-llama',
              providerName: 'ollama',
              baseUrl: 'http://127.0.0.1:11434/v1',
              model: 'llama3.2',
              hasApiKey: false,
              qualityScore: 0.86,
              inputCostPerMillionTokens: 0,
              outputCostPerMillionTokens: 0,
              latencyP95Ms: 1200,
              capabilities: {
                ModelRouteCapability.chat,
                ModelRouteCapability.streaming,
              },
            ),
            ModelRouteProfile(
              id: 'cloud-gpt4',
              providerName: 'openai',
              baseUrl: 'https://api.openai.com/v1',
              model: 'gpt-4-turbo',
              hasApiKey: true,
              qualityScore: 0.96,
              inputCostPerMillionTokens: 10,
              outputCostPerMillionTokens: 30,
              latencyP95Ms: 800,
              capabilities: {
                ModelRouteCapability.chat,
                ModelRouteCapability.streaming,
                ModelRouteCapability.jsonMode,
              },
            ),
          ],
          privacyMode: ModelRoutePrivacyMode.projectDefault,
          budgetMode: ModelRouteBudgetMode.qualityFirst,
        );

        // 2. Route and verify selection
        const router = DefaultModelRouter();
        final decision = router.choose(request);

        expect(decision.status, ModelRouteDecisionStatus.selected);
        expect(decision.selectedProfileId, isNotEmpty);
        expect(decision.reasonCodes, contains('quality_sensitive_task'));
        expect(decision.estimatedCostUsd, greaterThan(0));

        // 3. Critical: Verify trace does NOT leak sensitive data
        final trace = decision.toTraceJson();
        final traceText = jsonEncode(trace);

        // These sensitive patterns must NOT appear in the trace
        final sensitivePatterns = [
          'apiKey',
          'api_key',
          'Authorization',
          'authorization',
          'Bearer',
          'bearer',
          'sk-',
          'messages',
          'prompt',
          'https://api.openai.com',
          'http://127.0.0.1:11434', // Local URLs should also be redacted
          '11434',
        ];

        for (final pattern in sensitivePatterns) {
          expect(
            traceText,
            isNot(contains(pattern)),
            reason: 'Trace should not contain sensitive pattern: $pattern',
          );
        }

        // Verify trace contains only safe, structural data
        expect(trace['kind'], 'model_route_decision');
        expect(trace['taskKind'], 'sceneDraft');
        expect(trace['status'], 'selected');
        expect(trace['selectedProfileId'], isNotEmpty);
        expect(trace['reasonCodes'], isA<List<Object?>>());
        expect(trace['estimatedCostUsd'], isA<double>());
        expect(trace['expectedQuality'], isA<double>());
      });

      test('respects privacy mode for local-only routing', () {
        const request = ModelRouteRequest(
          taskKind: ModelRoutingTaskKind.sceneDraft,
          estimatedInputTokens: 2000,
          estimatedOutputTokens: 1500,
          privacyMode: ModelRoutePrivacyMode.localOnly,
          profiles: [
            ModelRouteProfile(
              id: 'remote-gpt4',
              providerName: 'openai',
              baseUrl: 'https://api.openai.com/v1',
              model: 'gpt-4',
              hasApiKey: true,
              qualityScore: 0.96,
              inputCostPerMillionTokens: 10,
              outputCostPerMillionTokens: 30,
              capabilities: {
                ModelRouteCapability.chat,
                ModelRouteCapability.streaming,
              },
            ),
            ModelRouteProfile(
              id: 'local-llama',
              providerName: 'ollama',
              baseUrl: 'http://127.0.0.1:11434/v1',
              model: 'llama3.2',
              hasApiKey: false,
              qualityScore: 0.88,
              inputCostPerMillionTokens: 0,
              outputCostPerMillionTokens: 0,
              capabilities: {
                ModelRouteCapability.chat,
                ModelRouteCapability.streaming,
              },
            ),
          ],
        );

        final decision = const DefaultModelRouter().choose(request);

        expect(decision.status, ModelRouteDecisionStatus.selected);
        expect(decision.selectedProfileId, 'local-llama');
        expect(decision.rejectedProfileIds, contains('remote-gpt4'));
        expect(
          decision.rejectionReasons['remote-gpt4'],
          contains('privacy_local_only'),
        );
      });
    });
  });
}
