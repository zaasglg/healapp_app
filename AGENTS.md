# AGENTS.md

This file contains instructions for AI coding agents (and human developers) working on the HealApp project.

## Project Overview

HealApp is a mobile ecosystem for elderly care, consisting of two applications:
1.  **Client App**: For finding caregivers (Heal Link), ordering care products (Vita Box), and tracking patient health (Diary).
2.  **Specialist App**: For caregivers and nurses to manage tasks and patient diaries.

**Tech Stack**: Flutter (Dart), BLoC (State Management), GoRouter (Navigation), Dio (Network).

## Build & Run Commands

### Development
*   **Run App**: `flutter run`
*   **Get Dependencies**: `flutter pub get`
*   **Clean Build**: `flutter clean`

### Building
*   **Android APK**: `flutter build apk`
*   **iOS Archive**: `flutter build ipa`

### Testing
*   **Run All Tests**: `flutter test`
*   **Run Single Test File**: `flutter test test/path/to/file_test.dart`
*   **Run Test by Name**: `flutter test --name "description of test"`

### Code Quality
*   **Analyze/Lint**: `flutter analyze`
*   **Format Code**: `dart format .` (Run this before committing)

## Code Style & Conventions

### Architecture
The project follows a feature-based or layered architecture:
*   `lib/screens`: UI widgets and pages.
*   `lib/bloc`: Business logic components (BLoC pattern).
*   `lib/repositories`: Data access layer (API calls, database).
*   `lib/models`: Data models (DTOs).
*   `lib/config`: App-wide configuration (colors, constants).

### Naming Conventions
*   **Classes/Types**: `PascalCase` (e.g., `HomePage`, `AuthRepository`).
*   **Variables/Functions**: `camelCase` (e.g., `fetchUserData`, `isLoading`).
*   **Files**: `snake_case` (e.g., `home_page.dart`, `auth_repository.dart`).
*   **Constants**: `camelCase` (e.g., `primaryColor`) or `SCREAMING_SNAKE_CASE` for raw consts if needed.

### Imports
*   Use **relative imports** (e.g., `../models/user.dart`) for files within the same feature or module.
*   Use **package imports** (e.g., `package:healapp_mobile/core/utils.dart`) for shared core utilities or when crossing major architectural boundaries.
*   Group imports: Dart SDK -> Flutter -> Third-party packages -> Project files.

### Error Handling
*   **Repositories**: Catch exceptions and throw custom failures or return `Result` types if implemented.
*   **BLoC**: Catch errors from repositories and emit failure states (e.g., `AuthError`).
*   **UI**: Listen to BLoC states and show `SnackBar` or error dialogs for failures. Do not handle raw exceptions in the UI.

### Formatting
*   Adhere strictly to standard Dart formatting (`dart format`).
*   Use trailing commas `,` in widget trees to ensure proper formatting and readability.

### State Management (BLoC)
*   Events and States should be equitable (`equatable` package).
*   Keep logic out of the UI; UI should only dispatch events and render based on state.

## Testing Guidelines
*   **Unit Tests**: Focus on Repositories and BLoCs. Mock dependencies using `mockito` or `mocktail`.
*   **Widget Tests**: Verify critical UI flows and interactions.
*   Always ensure `flutter test` passes before submitting changes.

## Documentation
*   Add comments only for complex logic or business rules.
*   Update `README.md` if adding new major features or dependencies.
*   Refer to `ТЗ приложения.md` for detailed business requirements and feature specifications.
