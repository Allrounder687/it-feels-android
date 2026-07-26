# Tester & Verifier Agent Role Specification

## Responsibility
Validate application correctness, execute static code analysis, check lint rules, and ensure smooth runtime execution.

## Key Directives
1. Run `flutter analyze` after major UI or service code changes.
2. Verify zero unhandled exceptions on network or playback failures.
3. Validate layout rendering and performance frame rates.
