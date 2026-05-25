import 'dart:io';

import '../../features/import_export/data/markdown_importer.dart';

enum GitCoordinatorStatus {
  /// The directory is a Git worktree and has no uncommitted changes.
  clean,

  /// The directory is a Git worktree and has uncommitted changes.
  dirty,

  /// The directory is not inside a Git worktree.
  nonGit,

  /// Git command failed (non-zero exit, missing executable, or other error).
  gitUnavailable,

  /// Import was blocked by a blocking issue (e.g., missing project.n0vel.json).
  importBlocked,
}

class GitCoordinatorIssue {
  const GitCoordinatorIssue({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'GitCoordinatorIssue($code: $message)';
}

class GitCoordinatorResult {
  const GitCoordinatorResult({
    required this.status,
    this.isGitWorktree = false,
    this.hasUncommittedChanges = false,
    this.changedFiles = const [],
    this.importResult,
    this.issues = const [],
  });

  final GitCoordinatorStatus status;
  final bool isGitWorktree;
  final bool hasUncommittedChanges;
  final List<String> changedFiles;
  final MarkdownImportResult? importResult;
  final List<GitCoordinatorIssue> issues;

  bool get isClean => status == GitCoordinatorStatus.clean;
  bool get isDirty => status == GitCoordinatorStatus.dirty;
  bool get isNonGit => status == GitCoordinatorStatus.nonGit;
  bool get isGitUnavailable => status == GitCoordinatorStatus.gitUnavailable;
  bool get isImportBlocked => status == GitCoordinatorStatus.importBlocked;

  @override
  String toString() =>
      'GitCoordinatorResult(status: $status, isGitWorktree: $isGitWorktree, '
      'hasUncommittedChanges: $hasUncommittedChanges, '
      'changedFiles: ${changedFiles.length}, issues: ${issues.length})';
}

abstract class GitCommand {
  const GitCommand();

  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

class _DefaultGitCommand implements GitCommand {
  const _DefaultGitCommand();

  @override
  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }
}

class GitCoordinator {
  GitCoordinator({GitCommand? commandRunner})
    : _commandRunner = commandRunner ?? const _DefaultGitCommand();

  final GitCommand _commandRunner;

  Future<GitCoordinatorResult> checkStatus(Directory directory) async {
    final isInsideResult = await _isInsideWorkTree(directory);
    if (!isInsideResult.isSuccess) {
      return GitCoordinatorResult(
        status: GitCoordinatorStatus.gitUnavailable,
        issues: [isInsideResult.issue!],
      );
    }

    if (!isInsideResult.isInsideWorkTree) {
      return const GitCoordinatorResult(
        status: GitCoordinatorStatus.nonGit,
        isGitWorktree: false,
      );
    }

    final statusResult = await _getGitStatus(directory);
    if (!statusResult.isSuccess) {
      return GitCoordinatorResult(
        status: GitCoordinatorStatus.gitUnavailable,
        isGitWorktree: true,
        issues: [statusResult.issue!],
      );
    }

    final hasChanges = statusResult.changedFiles.isNotEmpty;
    return GitCoordinatorResult(
      status: hasChanges
          ? GitCoordinatorStatus.dirty
          : GitCoordinatorStatus.clean,
      isGitWorktree: true,
      hasUncommittedChanges: hasChanges,
      changedFiles: statusResult.changedFiles,
    );
  }

  Future<GitCoordinatorResult> syncImport(Directory directory) async {
    // Check Git status to catch current state
    final latestStatusResult = await checkStatus(directory);

    // Always import to get the plan, even if there are no changes
    final importer = MarkdownImporter();
    final importResult = await importer.importProject(directory);

    // Check for blocking import issues
    if (importResult.plan.hasBlockingIssues) {
      return GitCoordinatorResult(
        status: GitCoordinatorStatus.importBlocked,
        isGitWorktree: latestStatusResult.isGitWorktree,
        hasUncommittedChanges: latestStatusResult.hasUncommittedChanges,
        changedFiles: latestStatusResult.changedFiles,
        importResult: importResult,
        issues: [
          ...latestStatusResult.issues,
          ...importResult.plan.blockingIssues.map(
            (issue) =>
                GitCoordinatorIssue(code: issue.code, message: issue.message),
          ),
        ],
      );
    }

    return GitCoordinatorResult(
      status: latestStatusResult.status,
      isGitWorktree: latestStatusResult.isGitWorktree,
      hasUncommittedChanges: latestStatusResult.hasUncommittedChanges,
      changedFiles: latestStatusResult.changedFiles,
      importResult: importResult,
      issues: latestStatusResult.issues,
    );
  }

  Future<_IsInsideResult> _isInsideWorkTree(Directory directory) async {
    try {
      final result = await _commandRunner('git', [
        '-C',
        directory.path,
        'rev-parse',
        '--is-inside-work-tree',
      ]);

      if (result.exitCode != 0) {
        // Exit code 128 typically means "not a git repository"
        final stderr = (result.stderr as String).toLowerCase();
        if (result.exitCode == 128 &&
            (stderr.contains('not a git repository') ||
                stderr.contains('not a git directory'))) {
          return const _IsInsideResult.success(false);
        }
        return _IsInsideResult.failure(
          GitCoordinatorIssue(
            code: 'git_rev_parse_failed',
            message: 'Git rev-parse failed with exit code ${result.exitCode}',
          ),
        );
      }

      final output = (result.stdout as String).trim();
      final isInside = output == 'true';

      return _IsInsideResult.success(isInside);
    } on ProcessException catch (e) {
      return _IsInsideResult.failure(
        GitCoordinatorIssue(
          code: 'git_executable_not_found',
          message: 'Git executable not found or failed to run: $e',
        ),
      );
    } on Object catch (e) {
      return _IsInsideResult.failure(
        GitCoordinatorIssue(
          code: 'git_unknown_error',
          message: 'Unknown Git error: $e',
        ),
      );
    }
  }

  Future<_GitStatusResult> _getGitStatus(Directory directory) async {
    try {
      final result = await _commandRunner('git', [
        '-C',
        directory.path,
        'status',
        '--porcelain',
      ]);

      if (result.exitCode != 0) {
        return const _GitStatusResult.failure(
          GitCoordinatorIssue(
            code: 'git_status_failed',
            message: 'Git status failed with non-zero exit code',
          ),
        );
      }

      final lines = (result.stdout as String).split('\n');
      final changedFiles = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          // Extract just the file path from porcelain output
          // Format: XY filename
          // X = staged status, Y = unstaged status
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            changedFiles.add(parts.sublist(1).join(' '));
          } else if (parts.length == 1 && parts[0].isNotEmpty) {
            changedFiles.add(parts[0]);
          }
        }
      }

      return _GitStatusResult.success(changedFiles);
    } on ProcessException catch (e) {
      return _GitStatusResult.failure(
        GitCoordinatorIssue(
          code: 'git_status_exception',
          message: 'Git status failed with exception: $e',
        ),
      );
    } on Object catch (e) {
      return _GitStatusResult.failure(
        GitCoordinatorIssue(
          code: 'git_status_unknown_error',
          message: 'Unknown Git status error: $e',
        ),
      );
    }
  }
}

class _IsInsideResult {
  const _IsInsideResult.success(this.isInsideWorkTree)
    : isSuccess = true,
      issue = null;

  const _IsInsideResult.failure(this.issue)
    : isSuccess = false,
      isInsideWorkTree = false;

  final bool isSuccess;
  final bool isInsideWorkTree;
  final GitCoordinatorIssue? issue;
}

class _GitStatusResult {
  const _GitStatusResult.success(this.changedFiles)
    : isSuccess = true,
      issue = null;

  const _GitStatusResult.failure(this.issue)
    : isSuccess = false,
      changedFiles = const [];

  final bool isSuccess;
  final List<String> changedFiles;
  final GitCoordinatorIssue? issue;
}
