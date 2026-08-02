# Testing Strategy

This document outlines the recommended testing strategy for the PixelPlayer Flutter application. A robust testing approach is crucial for maintaining application stability, especially when integrating with external, unofficial APIs like JioSaavn.

---

## 1. Testing Frameworks

The project utilizes the standard Flutter testing framework:
*   **`flutter_test`:** The primary testing framework for unit, widget, and integration tests.
*   **`mockito` / `mocktail`:** For mocking dependencies (e.g., API services, storage services) to isolate components during testing.

---

## 2. Testing Tiers

### A. Unit Tests
*   **Purpose:** Test individual classes, functions, or methods in isolation.
*   **Focus:**
    *   **Data Models:** Verify JSON serialization/deserialization logic in `Song`, `Playlist`, etc.
    *   **Utilities:** Test decryption (`DesDecryptor`), parsing (`LrcParser`), and transliteration (`HinglishTransliterator`).
    *   **Services:** Test business logic within `LyricsService` (without actual network calls by mocking `http`).
*   **Location:** `test/unit/`

### B. Widget Tests
*   **Purpose:** Test individual UI widgets in isolation.
*   **Focus:**
    *   Verify widget rendering, user interaction (e.g., `WavySeekBar` gesture handling), and state-based UI updates.
*   **Location:** `test/widgets/`

### C. Integration / Provider Tests
*   **Purpose:** Test how different components work together, specifically focusing on providers.
*   **Focus:**
    *   Test `AudioPlayerProvider`, `HomeProvider`, etc., ensuring that state changes correctly propagate after API calls or playback actions.
    *   Mocking API service responses is essential here to test different scenarios (e.g., successful API response, API error, no lyrics found).
*   **Location:** `test/integration/` or `test/providers/`

### D. End-to-End (E2E) Tests
*   **Purpose:** Test critical user flows in the complete application.
*   **Focus:**
    *   Example: Searching for a song, clicking it to play, and verifying that the player controls appear and progress updates.
*   **Framework:** `integration_test` (Flutter's E2E testing package)
*   **Location:** `integration_test/`

---

## 3. Recommended Coverage Goals

While 100% coverage is often impractical, the following goals are recommended:
*   **Unit Tests:** > 80% coverage of core business logic (decryption, parsing, models).
*   **Widget Tests:** Coverage for all major UI components (player controls, search bar, list items).
*   **Integration Tests:** Coverage for critical user flows (playing a song, searching).

---

## 4. Running Tests

To run the existing tests:
```bash
flutter test
```

To run a specific test file:
```bash
flutter test test/path/to/test_file.dart
```

To run E2E integration tests:
```bash
flutter test integration_test/app_test.dart
```

---

## 5. Future Testing Initiatives

*   **Mocking:** Standardize mocking by using `mocktail` throughout the codebase.
*   **Coverage Reporting:** Integrate coverage reporting tools to track progress and identify untested code paths.
*   **Continuous Testing:** Integrate automated test execution into the CI/CD pipeline.
