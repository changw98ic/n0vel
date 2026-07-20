# Literary Quality WP0 Source Admission Migration Report

Date: 2026-07-20

Tracking: [GitHub issue #102](https://github.com/changw98ic/n0vel/issues/102)

## Scope

This report records the WP0 migration from named third-party writing reference
roots to source-ledger admission. It covers only source admission, prompt
reference safety, and migration impact. It does not change quality thresholds,
candidate finalization, or proof anchoring.

## Previous behavior

- The default style reference configuration selected the `jianlai` writing
  reference root when no explicit profile override was supplied.
- Profile routing recognized named work/profile aliases for `jianlai`, `guimi`,
  and `tigui`, then routed to matching `artifacts/writing_reference/*` roots.
- Material reference retrieval could surface excerpt snippets from a selected
  reference root.
- Processing manifests under `artifacts/writing_reference/*/manifest.json`
  described derived corpus/index files, but they did not contain a source
  ledger determination for license status, allowed uses, provenance review, or
  generation admission.

## New WP0 behavior

- Production reference roots are represented by
  `assets/novels/source_manifest.json`.
- The covered roots are:
  - `artifacts/writing_reference/jianlai`
  - `artifacts/writing_reference/guimi`
  - `artifacts/writing_reference/tigui`
- Each covered root is marked `licenseStatus: "unknown"` with
  `allowedUses: []` because no license evidence has been recorded in the source
  ledger.
- Unknown sources fail closed for generation prompts, calibration, training,
  excerpt retrieval, and release evidence.
- Processing manifests cannot masquerade as authorization. Only records that
  satisfy `assets/novels/source_manifest.schema.json` and include license,
  allowed-use, provenance hash, and review fields have admission effect.
- Import resume preparation now performs source admission before hashing or
  opening `atoms.jsonl`; the importer repeats the check immediately before
  indexing.
- The default runtime reference posture becomes neutral/disabled unless a
  source-ledger entry explicitly allows the requested use.
- Prompt rendering may carry only abstract project-voice fields from admitted
  bundles. It must not render source title, creator, root path, provenance
  label, or raw excerpt for unknown third-party sources.
- Admitted excerpt prompts use prompt-local identifiers (`ref_1`, `ref_2`, ...)
  instead of corpus chunk IDs. Licensed excerpts require an explicit positive
  source-ledger character limit; restricted sources cannot claim excerpt use.
- Before an admitted excerpt becomes a prompt hit, the retriever removes source
  title, creator, source id, provenance path, runtime root, and their basename
  aliases. A hit that contains no literary content after redaction is dropped.

## Prompt and baseline impact

WP0 intentionally changes prompt content where previous prompts depended on
named third-party roots or excerpts. This migration must not be reported as a
byte-identical generation baseline.

Expected safe differences:

- named reference sections are absent or replaced by neutral project-voice
  constraints;
- unknown third-party excerpts are omitted;
- author/work imitation targets are rejected, abstracted, or routed to manual
  review before prompt rendering;
- source-policy events may record denial reason codes without copying source
  text.

## Unchanged behavior

- Existing `legacy95` quality threshold behavior is unchanged.
- Existing `90` draft keep/repair policy behavior is unchanged.
- Candidate finalization behavior is unchanged.
- Candidate proof and acceptance anchoring are unchanged.
- `shadowV2` and `enforceV2` are not enabled by this migration report.

## Baseline evidence note

The GLM 5.2 real-model canary performed before this implementation produced
candidate scores of `86` and `85`. That run is a pre-spec baseline for literary
quality calibration only. It is not source-admission certification and does not
authorize any third-party reference source.

## Verification record

- `flutter analyze --no-pub`: passed with no issues.
- WP0 source-ledger, resolver, imitation, reproduction-risk, style-reference,
  retriever, and importer tests: `61/61` passed.
- Existing `95/90`, finalization, proof, ledger, and checkpoint contract tests:
  `63/63` passed.
- Both source-manifest JSON files parse successfully, and all three recorded
  provenance SHA-256 values match the tracked source files.
- A full-repository test attempt reached `3061` passing and `16` skipped tests
  before it was stopped after `25` failures in pre-existing release-harness,
  ledger-evidence, shader-runtime, and timing-sensitive test areas. No WP0 test
  failed in that run; the known ledger integration failure was separately
  reproduced on the clean pre-WP0 revision.

## Follow-up requirements

- Add or update source-ledger entries only when license status, allowed uses,
  provenance hash, jurisdiction, and reviewer fields are available.
- Keep public and CI evidence to source id, license status, hash, metrics, and
  reason codes. Do not copy source prose into reports.
- Re-run focused source-admission and prompt-lint tests whenever a new
  reference root or allowed use is introduced.
