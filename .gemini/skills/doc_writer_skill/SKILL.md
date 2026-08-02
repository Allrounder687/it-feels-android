---
name: doc-writer-skill
description: Assists with generating, updating, and maintaining project documentation, ensuring consistency and adherence to project standards.
---

# Documentation Writer Skill Guide

## 1. Overview
This skill provides guidelines and utilities for AI agents to effectively manage documentation within the IT Feels Music project. It aims to streamline documentation tasks, promote consistency, and ensure all project documentation is up-to-date and aligns with the [STEERING_PATH.md](../../../docs/STEERING_PATH.md) guidelines.

## 2. Capabilities

### 2.1. Generate Documentation Outline
*   **Purpose**: Create a structured outline for new documentation files (e.g., for new features, modules, or architectural components).
*   **Directive**: When a new feature or module is introduced, and a new documentation file is required, generate an initial Markdown outline including sections like Introduction, Purpose, Usage, Architecture, Testing, and Future Considerations.

### 2.2. Summarize Content
*   **Purpose**: Condense lengthy code sections, commit messages, or existing documentation into concise summaries.
*   **Directive**: When asked to summarize a given text or code block, extract key information and present it in a clear, brief format, suitable for changelogs or overview documents.

### 2.3. Ensure Documentation Consistency
*   **Purpose**: Verify that documentation adheres to project-wide standards, including formatting, terminology, and cross-references.
*   **Directive**: After any documentation update, check for consistency with `STEERING_PATH.md` and `ARCHITECTURE.md`. Ensure proper Markdown formatting and consistent use of terminology.

### 2.4. Update Changelog
*   **Purpose**: Assist in updating `CHANGELOG.md` with new features, fixes, and refactorings.
*   **Directive**: When a task is completed, generate a `CHANGELOG.md` entry following the existing format, including version number (if applicable), and a concise description of changes.

### 2.5. Generate Code Review Summary
*   **Purpose**: Create concise summaries of code changes for documentation, changelogs, or pull request descriptions.
*   **Directive**: Given a description of code changes (e.g., commit messages, diff summaries), generate a high-level summary highlighting the main impact, new features, bug fixes, or refactorings. This summary should be suitable for direct use in `CHANGELOG.md` or PR comments.
