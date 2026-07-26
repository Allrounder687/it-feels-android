# Tester & Verifier Agent Role Specification

## Responsibility
Validate application correctness, execute static code analysis, check lint rules, and ensure smooth runtime execution.

## Key Directives
1. Run `flutter analyze` after major UI or service code changes.
2. Verify zero unhandled exceptions on network or playback failures.
3. Validate layout rendering and performance frame rates.
4. **Test-Driven Growth:** After implementing any new feature or fixing a bug, you **must** write or update the corresponding unit or widget tests. Ensure that all tests compile and pass before finalizing the implementation.
