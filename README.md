# novel_writer

Desktop-first Flutter prototype for local novel writing workflows.

## Local verification

Use the standard macOS verification entrypoint:

```bash
make verify-macos
```

It runs:

- `flutter analyze`
- `flutter test -r compact`
- `flutter build macos`
- `xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -destination "platform=macOS,arch=$(uname -m)"`

This is the recommended path because it uses an explicit macOS destination and a low-noise native test command.
The CI workflow reads the Flutter version from `pubspec.yaml`, so the repo-declared version stays aligned with the GitHub Actions setup.

## CI

The repository also runs the same macOS verification flow in GitHub Actions via `.github/workflows/verify-macos.yml`.

## Branch And Release

The repository now uses `main` as the default branch and a simple local-first branch/release workflow.

Recommended branch prefixes:

- `feat/<topic>`
- `fix/<topic>`
- `docs/<topic>`
- `chore/<topic>`
- `release/<version>`

Release baseline and tagging flow are documented here:

- [Branch And Release Workflow](/Users/chengwen/dev/novel-wirter/docs/release-workflow.md)

## Real Three-Chapter Validation

If story-generation behavior matters for a verification run, put your cloud
Ollama `/v1` credentials in a local `setting.json` file, then run the gated
real validation test:

```bash
cat > setting.json <<'EOF'
OLLAMA_API_KEY=...
OLLAMA_BASE_URL=https://ollama.com/v1
REAL_AI_MODEL=kimi-k2.6
REAL_AI_TIMEOUT_MS=180000
REAL_AI_MAX_CONCURRENT_REQUESTS=1
EOF

RUN_REAL_STORY_VALIDATION=1 \
flutter test test/real_three_chapter_generation_test.dart
```

The validation uses the app's real generation modules plus the provider
configuration from `setting.json`. It writes repo-visible artifacts under
`artifacts/real_validation/three_chapter_run/`, including:

- `inputs/three_chapter_outline.md`
- `chapters/chapter-01.md`
- `chapters/chapter-02.md`
- `chapters/chapter-03.md`
- `reports/run-report.md`
- `reports/artifact-index.md`
- `runtime/settings.snapshot.json`
- `runtime/live-status.md`

`OLLAMA_*` environment variables can still override the local file when needed.
