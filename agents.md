# Pin and Paper

## Team Members

- Claude
- Codex
- Gemini
- BlueKitty (the human dev who is project manager)

When you make notes and suggestions in documentation, please sign your individual suggestions/notes with "- 'your name'"

Since we are a team of ai and a coffee powered human, we don't need to worry about unrealistic timelines for implementation, we only need to ensure that the scope of each phase/subphase stays manageable and split into logical groupings. 

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

This directory contains the planning and design documents for **Pin and Paper**, a cross-platform task management and journaling application.

**Current Status:** ✅ **Phase 2 Stretch Goals Complete** (All core AI features + enhancements shipped)

The directory serves as a comprehensive blueprint for the app, detailing everything from the core philosophy and feature set to the technical architecture and visual design.

### Key Documentation Files

**Stable Files (root directory):**
- `README.md` - Public GitHub page (don't change)
- `agents.md` - This file - quick reference for AI team

**Planning & Documentation:**
- `docs/PROJECT_SPEC.md` - **THE authoritative planning document** (single source of truth)
- `docs/visual-design.md` - Complete aesthetic specification (colors, lighting, interactions)
- `docs/color-palettes.html` - Visual color reference tool
- `docs/future/` - Future phase planning and research

**Completed Work:**
- `archive/phase-01/` - Phase 1 MVP documentation
- `archive/phase-02/` - Phase 2 AI Integration documentation
- `archive/plan-original.md` - Historical: original project vision
- `archive/project-plan-original.md` - Historical: technical analysis

**Important Note on Living Documents:**
Phase-specific documentation (e.g., `phase-3.md`, `phase-3-issues.md`) lives in `docs/phases/` during active development. When a phase is complete, these documents are consolidated and moved to `archive/phase-XX/` (where XX is the phase number) to keep active documentation clean and focused on current/future work.

## Project Overview

**Pin and Paper** is an aesthetic, ADHD-friendly, AI-enhanced task management workspace built with Flutter. It prioritizes zero-friction thought capture, flexible spatial organization, and a beautiful, customizable "witchy scholarly cottagecore" visual design.

The core concept is to provide a digital workspace that feels like a physical desk, allowing users to organize tasks and ideas as torn paper strips, index cards, and connect them with "conspiracy strings."

### Key Technologies
*   **Framework:** Flutter
*   **Language:** Dart
*   **Database:** SQLite (for local, offline-first storage)
*   **State Management:** Provider (initially), migrating to Riverpod later.
*   **AI Integration:** Claude API for natural language task processing.

### AI Team Tools - MCP Server Documentation Access

**For Claude:** You have access to a context7 MCP server with up-to-date documentation for all 17 core libraries used in this project. Query these whenever you're uncertain about current best practices, API changes, or implementation patterns.

**For Codex & Gemini:** Note that you may not have access to the MCP server due to sandboxing/config issues. If you need current documentation, ask BlueKitty or coordinate with Claude.

**Available Libraries (17 total):**

*Core Framework:*
- `websites/main-api_flutter_dev` - Flutter
- `websites/dart_dev` - Dart

*Database:*
- `websites/www_sqlite_org-docs.html` - SQLite official docs
- `tekartik/sqflite` - Flutter SQLite package

*State Management:*
- `websites/pub_dev_packages_provider` - Current (Phase 1-2)
- `websites/riverpod_dev` - Planned migration (Phase 3+)

*AI Integration:*
- `websites/docs_anthropic_com-en-home` - Claude API

*Security:*
- `websites/pub_dev_packages_flutter_secure_storage` - API key storage

*Networking:*
- `websites/pub_dev_packages_http` - HTTP requests
- `websites/pub_dev_packages_connectivity_plus` - Network status

*Utilities:*
- `websites/pub_dev_packages_intl` - Internationalization/formatting
- `websites/pub_dev_packages_uuid` - UUID generation
- `websites/pub_dev_path_provider` - File system access

*Development Tools:*
- `websites/pub_dev_packages_flutter_lints` - Code quality
- `mockito/mockito` - Testing framework
- `websites/pub_dev-packages` - General pub.dev reference
- `websites/pub_dev-help` - pub.dev help docs

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

```
UI Layer (Flutter Widgets)
    ↓
Business Logic (Services)
    ↓
Data Layer (SQLite)
```

### Key Architectural Decisions

**Why Flutter?**
- Cross-platform (Android, iOS, iPad, Desktop, Web)
- Skia rendering engine perfect for aesthetic effects (torn paper, shadows, lighting)
- Hot reload for rapid iteration (1-2 second UI updates)
- Strong gesture support for spatial interactions

**Why SQLite?**
- Relational data with complex queries (tags, search, filtering, nesting)
- Offline-first (no internet required for core functionality)
- Battle-tested, mature, reliable
- Better than Hive for our use case (relationships, search performance)

**Why Provider → Riverpod?**
- Start simple with Provider for MVP (less boilerplate, faster development)
- Migrate to Riverpod when complexity increases (better testing, compile-time safety)
- Don't over-engineer early phases

**Why Service Layer (not REST API yet)?**
- Local-first architecture for MVP (no server needed)
- Service layer encapsulates business logic cleanly
- Can add REST API later for sync without major refactoring
- Faster MVP development (defer API to Phase 5+)

**Why Bounded Workspace (not infinite canvas)?**
- Performance: Easier viewport culling, pre-calculated bounds
- UX: Users understand edges better than infinite space
- Technical: Simpler hit testing and gesture handling
- Can expand when user runs out of space (but not truly infinite)

### Development Workflow

**Starting Work:**
1. Read `agents.md` (this file) for current status and quick reference
2. Check `docs/PROJECT_SPEC.md` for detailed phase planning
3. Review `docs/visual-design.md` if working on UI/aesthetic features
4. Check `docs/future/` for future phase details

**During Development:**
1. Work from `pin_and_paper/` directory (contains `pubspec.yaml`)
2. Use `make` commands for common tasks (doctor, analyze, test, format)
3. Keep files under 500 lines (split if larger)
4. Follow DRY principles (reusable components)
5. Test on Samsung Galaxy S21 Ultra (primary device)

**When Completing a Phase:**
1. Consolidate phase documentation into single markdown file
2. Move completed phase docs to `archive/phase-XX/` (create subdirectory)
3. Update this file (agents.md) with new current status
4. Update `docs/PROJECT_SPEC.md` with phase completion notes

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

## Development Status

### ✅ Phase 1: MVP (Complete)
**Status:** Shipped to production
**Date:** October 25, 2025
**Features:**
- Task creation and management
- Task completion toggling
- SQLite database (version 1)
- Provider state management
- Basic UI with theme

**Documentation:** `archive/phase-01/`

### ✅ Phase 2: AI Integration (Complete)
**Status:** Shipped to production
**Date:** October 27, 2025
**Version:** 0.2.0
**Features:**
- Claude AI integration for task extraction
- Settings screen with API key management
- Brain Dump screen for thought capture
- Task Suggestion Preview with approval/editing
- Secure API key storage (Android Keystore)
- Draft persistence (never lose text)
- Database migration (v1 → v2)
- Bulk task creation (performance optimized)

**Key Stats:**
- ~2,000 lines of production code
- 4 commits (backend → UI → fixes)
- 9 new files, 6 modified files
- 100% AI team review issues resolved
- Cost: ~$0.01 per brain dump
- Test Connection: 10 tokens (~$0.0003)

**Documentation:**
- Implementation: `docs/phases/phase-2-ai.md`
- Issues/Review: `docs/phases/issues-phase-2.md`
- Completion Report: `docs/phases/phase-2-complete.md`

**User Feedback:**
> "Wow, it works! And... it's super cool!!! :D I'm kind of shocked at how well it works haha." — BlueKitty

### ✅ Phase 2 Stretch Goals (Complete)
**Branch:** `phase-2-stretch` → `main`
**Status:** Shipped to production
**Date:** October 28, 2025
**Features:**
- Hide completed tasks (time-based with customizable threshold)
- Natural language task completion (local fuzzy matching)
- Draft management UI (multi-select, combine drafts)
- Brain dump review bottom sheet (view original text)
- Cost tracking dashboard (API usage monitoring)
- Improved loading states & animations

**Documentation:** `archive/phase-02/`

### 📅 Future Phases
**Phase 3:** Mobile Polish & Voice Input
**Phase 4:** Bounded Workspace View (spatial organization)
**Phase 5:** Sync & Backup (multi-device support)
**Phase 6:** Aesthetic Enhancement (dynamic lighting, textures, customization)
**Phase 7:** Journal & History (temporal awareness, productivity tracking)
**Phase 8:** iPad & Desktop Optimization (Apple Pencil, keyboard shortcuts)
**Phase 9:** Advanced Features (manila folders, flippable cards, themes)
**Phase 10:** MCP Server & API Layer (Claude integration, external APIs)

See `docs/PROJECT_SPEC.md` for complete phase roadmap and `docs/future/` for detailed research.
