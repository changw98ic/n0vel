# Desktop Preview Builds

This document is the preview packaging path for n0vel desktop testers. It is
intentionally conservative: preview archives are built locally from source, do
not include API keys, and should be described as unsigned preview artifacts
until signing/notarization is added.

## Current Release Policy

- `1.0.x` releases are still preview releases for technical testers and early
  writers; the package version is not a claim of signed or production-ready
  distribution.
- Testers must bring their own OpenAI-compatible model provider and API key.
- The app stores local project data on the user's machine; preview archives must
  not bundle private sample projects, API keys, or local settings files.
- Local event diagnostics redact manuscript/prompt excerpts by default. They
  can be cleared or pruned by the app's maintenance API; they are not a
  substitute for a hosted telemetry-retention policy.
- Web/Chrome preview is not advertised until issue #10 is fixed.

## Prerequisites

- Flutter stable `3.41.9` or the version pinned in CI.
- Platform toolchain for the target desktop:
  - macOS: Xcode command line tools.
  - Windows: Visual Studio desktop C++ workload.
  - Linux: Flutter Linux desktop prerequisites for the distribution.

Run the standard checks before publishing a preview build:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub -r compact
```

On macOS, the repository verification path is:

```bash
make verify-macos
```

## macOS Preview Archive

Create a local unsigned macOS preview archive:

```bash
make package-macos-preview
```

The script writes ignored artifacts under `dist/`:

```text
dist/NovelWriter-macos-arm64-preview.zip
dist/NovelWriter-macos-arm64-preview.zip.sha256
```

On Intel Macs the archive name uses `x86_64` instead of `arm64`.

The packaging script disables Flutter icon tree shaking for preview builds. This
keeps the local packaging path usable even when a developer's Flutter engine
cache is missing the optional `const_finder` snapshot; the tradeoff is a larger
preview archive.

Before attaching the archive to a GitHub release:

1. Confirm the release notes say this is a preview.
2. Confirm the notes say users must bring their own OpenAI-compatible provider.
3. Include the SHA-256 file contents.
4. State that the archive is unsigned and not notarized.
5. Do not include local `settings.json`, API keys, private project data, or
   personal writing content.

## Windows and Linux Build Commands

These commands are useful for maintainers on the target platforms, but the
current CI only verifies macOS.

Windows:

```powershell
flutter pub get
flutter build windows --release --no-pub
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath dist\NovelWriter-windows-x64-preview.zip
Get-FileHash dist\NovelWriter-windows-x64-preview.zip -Algorithm SHA256
```

Linux:

```bash
flutter pub get
flutter build linux --release --no-pub
mkdir -p dist
tar -C build/linux/x64/release -czf dist/NovelWriter-linux-x64-preview.tar.gz bundle
sha256sum dist/NovelWriter-linux-x64-preview.tar.gz > dist/NovelWriter-linux-x64-preview.tar.gz.sha256
```

## Known Preview Limitations

- No signed or notarized installer is available yet.
- macOS Gatekeeper may warn about locally built archives.
- Windows and Linux packaging commands are documented but not covered by the
  current GitHub Actions workflows.
- Web/Chrome preview remains blocked by native SQLite/FFI storage paths; see
  issue #10.
- Live AI generation requires a user-provided provider endpoint, model name, and
  API key or local-compatible endpoint.
