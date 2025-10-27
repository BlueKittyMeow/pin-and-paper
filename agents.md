# Pin and Paper

## Team Members

- Claude
- Codex
- Gemini
- BlueKitty (the human dev who is project manager)

When you make notes and suggestions in documentation, please sign your individual suggestions/notes with "- 'your name'"

## Flutter app location & commands

This repo’s Flutter app lives in `pin_and_paper/` (underscore).  
Run all Flutter/Dart commands **from that directory** (it contains `pubspec.yaml`).

### Quick start

```bash
cd pin_and_paper
make doctor   # flutter doctor -v
make analyze  # analyze lib/ and test/
make fix      # apply safe Dart fixes
make format   # format sources
make test     # run tests with expanded output
make check    # doctor + analyze + test
```

## Directory Overview

This directory contains the planning and design documents for **Pin and Paper**, a cross-platform task management and journaling application. The project is currently in the pre-development phase.

The directory serves as a comprehensive blueprint for the app, detailing everything from the core philosophy and feature set to the technical architecture and visual design.

## Project Overview

**Pin and Paper** is an aesthetic, ADHD-friendly, AI-enhanced task management workspace built with Flutter. It prioritizes zero-friction thought capture, flexible spatial organization, and a beautiful, customizable "witchy scholarly cottagecore" visual design.

The core concept is to provide a digital workspace that feels like a physical desk, allowing users to organize tasks and ideas as torn paper strips, index cards, and connect them with "conspiracy strings."

### Key Technologies
*   **Framework:** Flutter
*   **Language:** Dart
*   **Database:** SQLite (for local, offline-first storage)
*   **State Management:** Provider (initially), migrating to Riverpod later.
*   **AI Integration:** Claude API for natural language task processing.

### Stack & Component Versions

**Core:**
*   **Flutter:** 3.35.7 (stable channel)
*   **Dart:** 3.9.2
*   **SDK Constraint:** `>=3.5.0 <4.0.0` (supports Flutter 3.24+ through current stable)
*   **Database Version:** 2 (Phase 2)

**Phase 1 Dependencies:**
*   **sqflite:** ^2.3.0 (SQLite database)
*   **path_provider:** ^2.1.0 (File system paths)
*   **provider:** ^6.1.0 (State management)
*   **uuid:** ^4.0.0 (Unique ID generation)
*   **intl:** ^0.19.0 (Date formatting)
*   **path:** ^1.9.1 (Path manipulation)

**Phase 2 Additional Dependencies:**
*   **http:** ^1.2.0 (HTTP requests to Claude API)
*   **flutter_secure_storage:** ^9.0.0 (Secure API key storage)
*   **connectivity_plus:** ^6.0.0 (Internet connectivity checking - uses List API)

**Dev Dependencies:**
*   **flutter_test:** (from Flutter SDK)
*   **flutter_lints:** ^5.0.0 (Dart linting)
*   **mockito:** ^5.4.0 (Testing mocks)

**Target Device:**
*   **Primary:** Samsung Galaxy S21 Ultra (Android)
*   **Display:** 120Hz, 1440x3088 pixels
*   **Performance Target:** 120fps native, 60fps minimum

**Important Version Notes:**
*   All dependencies use `^` (caret) syntax to allow compatible minor/patch updates
*   connectivity_plus ^6.0.0 uses List-based API (not single ConnectivityResult)
*   PopScope used instead of deprecated WillPopScope (Flutter 3.12+)

### Architecture
The application will be built using a service-oriented architecture, with a clear separation between the UI, business logic, and data layers. An API-first approach is planned for the long-term to support multi-device sync and external integrations, but the initial MVP will focus on a local service layer to ensure rapid development.

## Building and Running

This is a pre-development project, so there are no build or run commands yet. Based on the project plan, the following commands will be used once the project is initialized:

*   **Run the app (development):** `flutter run`
*   **Build the app (release):** `flutter build`
*   **Run tests:** `flutter test`

## Development Conventions

The project plan outlines a clear set of development conventions:

*   **File Size:** Keep files under 500 lines to ensure they are focused and manageable.
*   **DRY (Don't Repeat Yourself):** Use reusable components and avoid code duplication.
*   **Separation of Concerns:** Maintain a clear distinction between UI, business logic, and data layers.
*   **API-First:** Design and document the API layer alongside feature development to prepare for future integrations.
*   **Hot Reload:** Structure code to take full advantage of Flutter's hot reload functionality for rapid iteration.
*   **Mobile-First:** Prioritize the user experience on Android (specifically Galaxy phones) and then adapt for larger screens.

## Key Files

*   `PROJECT_SPEC.md`: **The authoritative planning document** - consolidated vision, technical analysis, and phase-by-phase development plan.
*   `visual-design.md`: A comprehensive guide to the app's aesthetic, including color palettes, the dynamic lighting system, interaction patterns, and component rendering.
*   `color-palettes.html`: A supplemental file for the visual design, likely containing HTML/CSS representations of the color schemes.
*   `README.md`: A brief, high-level summary of the project.
*   `archive/`: Contains earlier planning iterations (plan.md, project-plan.md, issues.md) - now superseded by PROJECT_SPEC.md.
