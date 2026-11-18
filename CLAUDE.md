# Repository instructions

Daktela fork of dart-sip-ua, hosted at https://github.com/Daktela-Dev/dart-sip-ua.
This is a shared SIP library, not the Flutter application repository.

## Project facts

- **Main branch:** `master`, the pull request target. Verify origin/HEAD before changing the target.
- **Shared branches:** `master`, `main`, `release/*` and existing version/maintenance branches. Never commit code directly to them.
- **Worktree:** use the existing task checkout/branch; create another worktree only when isolation is needed.
- **Never in a fix or feature:** the package `version:` in pubspec.yaml, release tags, publication changes or unrelated generated example files. Release metadata belongs to a separate release step.
- **Before committing code:** `flutter-tooling:code-review`; run affected tests and analyzer. Native transport changes also require real-network acceptance before the consuming application release.
- **Review checklist:** use the shared code-review checks. Preserve nullable settings defaults, strict TLS verification on the normal path, native/web separation and resource ownership; do not add application-specific intervals to the library.
- **Checks:** use a compatible Flutter SDK through FVM. Current task validation uses Flutter 3.41.9: `fvm spawn 3.41.9 test --no-pub test/all_test.dart test/websocket_dart_impl_test.dart` and `fvm spawn 3.41.9 analyze --no-pub lib/src/sip_ua_helper.dart lib/src/transports/websocket_dart_impl.dart test/websocket_dart_impl_test.dart`. Resolve dependencies before first use; a fresh clone may not have an FVM project pin.
- **Before the MR:** for Daktela app work, use `flutter-tooling:task-report` on the existing app ClickUp task and distinguish library support from enabled application behavior.
- **Task report:** no local app QA configuration. Use the consuming app's report file and approved plan; keep required release and live-testing gates explicit.
- **Investigations:** no local investigation directory. Link the consuming application's investigation/PR when applicable; do not duplicate its report into this repository.
- **Delivery:** GitHub pull request from the task branch into master; use the shared commit subject/ID conventions and request squash on merge. Adapt GitLab-specific CLI/push options to GitHub; GitLab merge_request push options do not apply here. Creating a PR does not authorize merging or releasing.

## Release boundaries

The inspected fork history uses plain numeric tags such as `1.0.26`; that release
commit updates pubspec.yaml and CHANGELOG.md, and consumers pin the Git tag.
Do not assume that a tag or release exists because its number appears in a plan.
Keep unreleased changes under `[Unreleased]` until the release operation.

The checked-in `.github/workflows/publish.yaml` is a separate pub.dev publication
workflow triggered by tags matching `v[0-9]+.[0-9]+.[0-9]+*`. Its trigger differs
from the numeric tags used by this fork. Do not change tag format, publish to
pub.dev, or infer a release process from this workflow without an explicit
release request and verified repository-specific procedure.

This repository currently has no local release skill/script. Do not borrow the
Flutter application's app-release flow or invent a library release command.
After the library change is reviewed and merged, the release owner selects and
publishes the version/tag. flutter_core then adopts that real tag and follows
its own release skill; the app adopts the released core version afterwards.

## CI and tests

`.github/workflows/dart.yml` currently targets `main` and runs formatting/import
checks; the fork's main branch is `master`. Do not claim that a PR to master
automatically runs the test suite. Report the local checks and actual PR status.
Changing CI triggers is separate work unless explicitly requested.

Loopback transport tests exercise real dart:io ping/pong; they do not replace
cloud/on-prem TLS, macOS/Windows network interruption, long-call or mobile QA.
No credentials, release numbers or machine-specific dependency overrides belong
in a feature commit.
