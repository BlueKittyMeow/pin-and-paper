# GEMINI.md: Pin and Paper

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
