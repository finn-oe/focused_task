# Focused Task

Focused Task is a cross-platform task management application designed to enhance personal productivity through structured timeboxing, day/week scheduling, and session tracking. 

## 🏗 Architecture & Tech Stack

This project is built using a highly scalable, **feature-first Clean Architecture**, ensuring excellent separation of concerns, testability, and maintainability across the codebase.

*   **Framework:** [Flutter](https://flutter.dev/) & Dart
*   **Database:** [Drift (SQLite)](https://drift.simonbinder.eu/) for robust, type-safe local data persistence.
*   **State Management:** Reactive Notifier/State pattern (via `flutter_riverpod` or similar providers).
*   **Theming:** Custom responsive UI with seamless Light and Dark mode support.

## ✨ Core Features

*   **Plan Mode:** Comprehensive day and week scheduling views. Users can easily draft their upcoming tasks using the intuitive task form modal.
*   **Focus Mode:** Advanced session tracking timers. Includes active task timers, pause functionality, and a dedicated "finished for today" state to encourage healthy work boundaries.
*   **Statistics:** Visual insights and historical tracking of completed tasks and focus sessions.
*   **Background Services:** Native alarm service integration for reliable timer notifications.
*   **Fractional Indexing:** Efficient task reordering and list management capabilities.

## 📂 Project Structure

The source code is organized by feature to keep domain logic, presentation, and data layers highly cohesive:

```text
lib/
├── core/                   # Shared utilities, themes, routing, and DB setup
│   ├── database/           # Drift app database and table definitions
│   ├── providers/          # Global dependency injection/providers
│   ├── routing/            # App routing logic
│   ├── services/           # Shared services (e.g., AlarmService)
│   └── ui/                 # Global UI components and Light/Dark themes
└── features/               # Feature-first modules
    ├── settings/           # App configuration and preferences
    └── tasks/              # Core task domain
        ├── data/           # Task repository implementations
        ├── domain/         # Task entities and repository interfaces
        └── presentation/   # UI layer for tasks
            ├── focus_mode/ # Session timers and focus screens
            ├── plan_mode/  # Scheduling, task lists, and creation modals
            └── stats/      # Productivity analytics screens
