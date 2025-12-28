# Dabbu - Intelligent Expense Tracker (100% Vibe Coded)

Dabbu is a privacy-first, automated expense tracker built with Flutter. It leverages local SMS parsing to automatically record financial transactions without ever sending your data to the cloud.

## 🚀 Key Features

-   **Automated Tracking**: Parses bank SMS notifications using custom, user-defined regex patterns.
-   **Privacy Focused**: 100% offline. Data is stored locally using SQLite.
-   **Rich Analytics**: visualize spending habits with interactive charts and Bento-grid dashboards.
-   **Budgeting & Goals**: Set monthly budgets and track savings goals.
-   **High-Contrast UI**: Designed with a sleek, dark-mode-first aesthetic for clarity.

---

## 🛠️ Developer Guide (Contribution)

This section documents the core architecture to help new developers understand and adapt the codebase.

### 1. Architecture Overview
The app follows a **MVVM (Model-View-ViewModel)** architecture:
-   **Screens (`lib/screens/`)**: minimal logic, responsible for UI layout and listening to ViewModels.
-   **ViewModels (`lib/viewmodels/`)**: Handle business logic, state management, and communication with services. They extend `ChangeNotifier`.
-   **Services (`lib/services/`)**: Data access layers (Database, SMS reader).
-   **Widgets (`lib/widgets/`)**: Reusable UI components.

### 2. Core Modules

#### A. SMS Parsing Engine
The heart of the automation lies in `lib/screens/sms_parsing_screen.dart` and `lib/viewmodels/sms_parsing_view_model.dart`.

**How it works:**
1.  **Selection**: The user selects an SMS.
2.  **Tokenization**: The message body is split into tokens (words).
3.  **Pattern Creation**:
    -   **Amount**: The user taps the token representing the transaction value.
    -   **Anchors**: The user selects static words (e.g., "debited", "Purchase", "Bank") that uniquely identify this message type.
    -   **Wildcards**: The `SmsParsingViewModel` treats the space between non-adjacent anchors as wildcards.
    
**Regex Construction Logic:**
If you need to debug why a specific SMS isn't matching, check `_generateRegex()` in `SmsParsingViewModel`.
-   It sorts selected indices (Anchors + Amount).
-   It iterates through them:
    -   **Adjacent tokens**: Joined by `\s+` (whitespace).
    -   **Gaps**: Filled with `\s+(?:.*?)\s+` (non-greedy wildcard).
    -   **Amount**: Replaced with capture group `(?:[^0-9\n]*)([0-9.,]+)` to handle currency symbols.

#### B. Local Database
Data persistence is handled by `lib/services/database_helper.dart` using `sqflite`.

**Key Tables:**
-   **`transactions`**: The ledger. Linking a transaction to a `patternId` means it was auto-detected.
-   **`patterns`**: Stores the compiled regex string (`patternRegex`) and metadata (`senderId`, `messageType`).
-   **`budget_overrides`**: Stores historical budget settings per month.

**Query Logic:**
-   `getFilteredTransactions()`: The central query builder. Supports dynamic filtering by multiple Categories, Patterns, Dates, and Wallet types. It constructs a dynamic `WHERE` clause based on non-null arguments.

#### C. Custom UI Components
-   **`BentoGrid`**: A flexible grid layout used in `AnalyticsScreen` via `flutter_staggered_grid_view`.
-   **`ShimmerLoading`**: Provides skeletal loading states.
-   **`FadeInEntry`**: A wrapper that triggers a staggered opacity/slide animation on entry.

### 3. Debugging Tips
-   **Regex Issues**: Use the "Regex Preview" box in the `SmsParsingScreen`. It shows the live-generated raw regex string.
-   **Navigation**: Primary navigation uses a `PageController` with `jumpToPage` in `MainScreen` to prevent tab flickering.
-   **Linting**: The project uses strict lints. Run `dart analyze` before committing.
