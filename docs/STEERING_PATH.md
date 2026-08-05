# Agent Steering Path for IT Feels Music Project

This document provides a comprehensive guide for all AI agents contributing to the IT Feels Music project. It outlines architectural principles, development workflows, coding standards, and best practices to ensure consistent, high-quality, and maintainable contributions.

## 1. Introduction
The IT Feels Music project is a premium Flutter Android music application leveraging AI capabilities and a Cloudflare Worker-based backend. This steering path aims to align all agent-driven development with the project's vision, technical requirements, and existing infrastructure.

## 2. Core Principles
*   **Zero Cognitive Overload UX**: Prioritize user experience by ensuring graceful empty states, smooth animations, and intuitive interactions.
*   **Performance First**: Optimize for speed and responsiveness, especially for audio streaming, UI rendering, and network operations.
*   **Scalability & Maintainability**: Design solutions that are easily extensible and maintainable by both human and AI developers.
*   **Security by Design**: Implement robust security measures, particularly for API interactions and data handling (e.g., `X-Feels-Secret` header, API key management).
*   **Test-Driven Growth**: Every new feature or bug fix must be accompanied by comprehensive tests.

## 3. Architectural Overview
The project follows a layered architecture:
*   **Flutter Presentation (UI)**: Views and widgets in `lib/views/` and `lib/core/widgets/`.
*   **Provider State Layer**: State management using Flutter Provider (or Riverpod) in `lib/providers/` and `lib/features/`.
*   **Services Layer**: Business logic, API communication, downloads, encryption in `lib/data/services/` and `lib/services/`.
*   **Core Utilities**: Shared utilities like DES decryption, transliteration, LRC parsing in `lib/core/utils/`.
*   **Backend (Cloudflare Worker)**: Edge caching, API proxies, AI playlist generation, telemetry in `backend/src/index.ts`.
*   **AI Agent Definitions**: Role specifications in `agents/` and skills in `.gemini/skills/`.

## 4. Agent Interaction Guidelines
Agents are expected to operate autonomously but adhere to the following:
*   **Understand Context**: Before making changes, thoroughly read `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `ROADMAP.md`, and `CHANGELOG.md`.
*   **Single Responsibility Principle**: Each agent (or agent task) should have a clearly defined, narrow responsibility.
*   **Iterative Development**: Work in small, verifiable steps.
*   **Test Before Commit**: Always ensure all tests pass before proposing changes.
*   **Document Everything**: Update relevant documentation (`README.md`, `CHANGELOG.md`, `AGENTS.md`, and any new feature docs) for every significant change.
*   **Use Existing Skills**: Leverage skills defined in `.gemini/skills/` where applicable.
*   **Cost-Efficiency**: When interacting with external AI providers, prioritize cost-efficient models as specified in `api_integrator.md`.

## 5. Development Workflow
Always follow this cycle for new features and bug fixes:
1.  **Plan**: Define the task clearly, referencing this `STEERING_PATH.md`.
2.  **Code**: Implement the feature or fix.
3.  **Test**: Write or update unit/integration/widget tests.
4.  **Verify**: Run `flutter analyze` and `flutter test`. Ensure all tests pass.
5.  **Document**: Update `CHANGELOG.md` and any other affected documentation.
6.  **Commit**: Create a local `git commit` with a clear message.
7.  **Release/Patch Management (Shorebird)**: Follow strict rules for OTA updates vs App Store binary updates based on official Shorebird patterns:
    *   **Native code/Assets/Flutter Upgrades**: Require a full binary release. Use `shorebird release [platform]` (or bump `pubspec.yaml` version and trigger the CI release pipeline).
    *   **Dart code only**: Can be patched OTA. Use `shorebird patch [platform]` (or trigger the CI patch pipeline on an *existing* version).
    *   **CRITICAL PATTERN**: A `shorebird patch` MUST target an existing `shorebird release`. If you bump the app version in `pubspec.yaml`, the previous release no longer matches. You **cannot patch a new version that hasn't been released yet**. The CI pipeline uses `--no-codesign` and a fallback mechanism, but always ensure you differentiate between a Patch and a Release correctly. Do NOT use `deploy_ota.bat` directly.

## 6. Code Standards
*   **Dart Formatting**: Adhere to `flutter format`.
*   **Linting**: Ensure `flutter analyze` reports zero errors or warnings.
*   **Null Safety**: Maintain strict null safety.
*   **Responsive UI**: Use `Expanded`, `Flexible`, `LayoutBuilder`, `MediaQuery.of(context).size` for responsive layouts. Avoid hardcoded sizes for dynamic elements.
*   **SafeArea**: Always wrap top-level layout boundaries or floating widgets in `SafeArea`.
*   **State Management**: Follow existing patterns (Provider/Riverpod Notifier<State>).
*   **Error Handling**: Implement robust error handling for network requests, audio playback, and file operations.

## 7. Documentation Standards
*   **`README.md`**: High-level overview, features, getting started.
*   **`CHANGELOG.md`**: Detailed changes for each version.
*   **`AGENTS.md`**: Summary of agent iterations and high-level directives.
*   **`ARCHITECTURE.md`**: System architecture diagrams and project structure.
*   **Inline Comments**: Use clear, concise comments for complex logic.

## 8. Tooling & Environment
*   **Flutter SDK**: Version 3.x+
*   **Android SDK**: API Level 21+
*   **IDE**: VS Code or Android Studio with Flutter/Dart plugins.
*   **Version Control**: Git.
*   **CI/CD**: GitHub Actions (`.github/workflows/`).

This `STEERING_PATH.md` will evolve with the project. Agents should re-read it periodically for updates.


## 9. Current Active Focus (v3.5.22+)
*   **UI Consolidation**: Use AppScaffold and AppDimensions.bottomClearance for standardizing the padding across all UI screens instead of raw padding values.
*   **Decoupling Logic**: Keep business logic out of UI files. Use Notifier or StateNotifier for Riverpod to bridge UI and services (e.g. storageProvider, lastfmProvider). No direct locator<Service>() calls should happen in widget uild() or onPressed() methods.
*   **Strict Test Quality**: Ensure all tests (especially lutter test) remain passing before any commit.
