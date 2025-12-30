# Dabbu Codebase Analysis

This document provides a detailed breakdown of the Dabbu Flutter application codebase, focusing on screens, components, and their functions.

## Project Structure Overview
The project follows a standard Flutter architecture with a clear separation of concerns:
- **`screens/`**: Contains the UI pages/screens of the app.
- **`widgets/`**: Contains reusable UI components and feature-specific widgets.
- **`viewmodels/`**: (Inferred) Likely contains business logic and state management for screens (MVVM pattern seen in code).
- **`utils/`**: Helper functions, constants (CMS), and themes.
- **`services/`**: Backend/Database services.

## Screens & Components Breakdown

### 1. Main Entry & Navigation
**File**: `lib/main.dart`
- **Purpose**: App entry point. Sets up `ThemeController` and decides the initial screen (`InitialSetupScreen` vs `MainScreen`) based on `initialSetupDone` preference.
- **Key Components**:
    - `MaterialApp`: Configures themes (Light/Dark) and routes.
    - `MyApp`: Root widget.

**File**: `lib/screens/main_screen.dart`
- **Purpose**: The persistent persistent shell for the main app navigation.
- **Key Functions**:
    - Manages a `PageView` and `NavigationBar`.
    - Handles tab switching between Home, Analytics, and Settings.
    - `_onItemTapped`: Jumps to page and triggers data refresh on the target page.
- **Components Used**:
    - `HomePage`
    - `AnalyticsScreen`
    - `SettingsPage`

### 2. Dashboard
**File**: `lib/screens/home_page.dart`
- **Purpose**: The main dashboard showing financial overview.
- **Key Functions**:
    - `refreshData`: Refreshes the `HomeViewModel`.
    - `_syncMessages`: Scans SMS for new transactions.
    - `_showAddMenu`: specific bottom sheet to add Transaction or Smart Pattern.
- **Components Used**:
    - `WelcomeBlock`: Header with user name and scan button.
    - `BudgetGaugeBlock`: Visual gauge of monthly budget vs spend.
    - `StatCard`: Quick stats for Income and Expense.
    - `ActionStrip`: Quick action buttons (Add Transaction, Add Goal, Goals List).
    - `SublimitBlock`: Categorized spending limits view.
    - `RecentTransactionsBlock`: List of latest transactions.
    - `ShimmerLoading`: Loading state placeholder.
    - `FadeInEntry`: Animation wrapper.

### 3. Analytics & Visualization
**File**: `lib/screens/analytics_screen.dart`
- **Purpose**: Detailed visual analysis of income/expenses over time.
- **Key Functions**:
    - Time range selection (Month navigation).
    - Income/Expense toggling.
    - Category filtering.
    - **Pattern/Sender Name Filtering**: Filter by specific sender or pattern name.
    - **Sorting**: Sort by Date (Newest/Oldest) or Amount (High/Low).
    - **Summary Stats**: View total spent, earned, and transaction count for the current view.
- **Components Used**:
    - `FilteredSummaryBlock`: Dashboard showing Date, Count, Spent, and Earned stats.
    - `SenderFilterBlock`: Horizontal list of chips for filtering by name.
    - `HeatMapBlock`: Calendar view of daily spending intensity.
    - `ChartBlock`: Pie chart for category breakdown.
    - `CategoryBento`: Horizontal scrollable list of category stats.
    - `InsightBlock`: Automatic insights (e.g., "Food spend up 20%").
    - `AppCard`: Container for sections.
    - `TransactionDetailScreen`: Navigation target for list items.

### 4. Transactions Management
**File**: `lib/screens/all_transactions_screen.dart`
- **Purpose**: A complete list of history transactions grouped by date.
- **Components Used**:
    - Standard `ListView` with `ListTile`.
    - `TransactionDetailScreen`: Navigation target.

**File**: `lib/screens/transaction_detail_screen.dart`
- **Purpose**: detailed view of a specific transaction with editing capabilities.
- **Key Functions**:
    - Edit Amount, Date, Note.
    - `_updateCategory`: Assign/Change transaction category.
    - `_updateGoal`: Link transaction to a savings goal (add/subtract funds).
    - `_confirmDelete`: Deletes the transaction.
- **Components Used**:
    - `TicketModal`: Visual container resembling a physical receipt.
    - `TextField`, `DatePicker`.

**File**: `lib/screens/add_transaction_screen.dart`
- **Purpose**: Manual entry form for new transactions.
- **Key Functions**:
    - Input validation for Amount.
    - Toggle between Income/Expense/Goal Adjustment.
- **Components Used**:
    - Standard Form fields (`TextField`, `InputDecorator`).
    - `ChoiceChip`: For selecting transaction type.

### 5. Goal Tracking
**File**: `lib/screens/goals_list_screen.dart`
- **Purpose**: Grid view of all active savings goals.
- **Key Functions**:
    - Displays progress percentage and amount saved vs target.
- **Components Used**:
    - `BentoGrid`: Flexible grid layout.
    - `AppCard`: Goal cards.
    - `AddGoalDialog`: Dialog to create new goals.

**File**: `lib/screens/goal_history_screen.dart`
- **Purpose**: Details and history for a specific goal.
- **Key Functions**:
    - `_toggleArchive`: Archive/Unarchive goal.
    - `_showAddFundsOptions`: Add manual deposit or link existing transaction.
    - `_showLinkTransactionPicker`: Select from unlinked transactions.
- **Components Used**:
    - `GoalHeroCard`: Large visual card showing goal status and motivation.
    - `HistoryTimeline`: Vertical timeline of contributions.

### 6. Subscriptions
**File**: `lib/screens/subscriptions_screen.dart`
- **Purpose**: Manage recurring payments.
- **Key Functions**:
    - `_scanForSubscriptions`: Smart scan algorithm to find recurring patterns in history.
    - `_showAddDialog`: Manual addition of subscriptions.
- **Components Used**:
    - Standard `ListView`.

### 7. Settings & Configuration
**File**: `lib/screens/settings_page.dart`
- **Purpose**: App-wide settings and data management.
- **Key Functions**:
    - Categories Management: Budget limits, Colors, Icons.
    - Pattern Management: Edit/Delete SMS parsing patterns.
    - General: Theme toggle, Monthly Budget, Archived Goals.
- **Components Used**:
    - `SettingsSection`: Grouped list tiles.
    - `SmsParsingScreen`, `SmsSetupScreen`, `SubscriptionsScreen`.

**File**: `lib/screens/initial_setup_screen.dart`
- **Purpose**: Onboarding flow.
- **Key Functions**:
    - Collects User Name and initial Budget.
- **Components Used**:
    - Info Cards (Bento style).

### 8. SMS Parsing Engine (Core Feature)
**File**: `lib/screens/sms_setup_screen.dart`
- **Purpose**: Permissions and initial scan setup.
- **Key Functions**:
    - Request SMS permissions.
    - Select date range for scan.
    - `_fetchSmsAndContinue`: Loads SMS inbox.

**File**: `lib/screens/sms_list_screen.dart`
- **Purpose**: List of raw SMS messages to select for parsing.
- **Key Functions**:
    - Search/Filter messages.

**File**: `lib/screens/sms_parsing_screen.dart`
- **Purpose**: The "Visual Editor" for creating Regex patterns from SMS.
- **Key Functions**:
    - `_savePatternAndContinue`: Generates and saves regex.
    - `_addNewCategory`: Inline category creation.
- **Components Used**:
    - `SmsCodeBlock`: Custom interactive text view where users tap words to select "Amount" or "Anchor Text".
    - `SelectionTab`: Toggle between Amount/Anchor selection modes.
    - `ChoiceChip`: Select Sender ID info.

## Key Shared Widgets
- **`AppCard`**: The fundamental building block of the UI, providing consistent styling (border radius, elevation/border).
- **`BentoGrid`**: A layout widget that arranges children in a responsive grid, used heavily in Goals and Home screens.
- **`FadeInEntry`**: Adds entrance animations to widgets for a polished feel.
- **`ShimmerLoading`**: Skeleton loading screen for async data fetching.
- **`TicketModal`**: Unique styling for transaction details to look like a receipt/ticket.

## Business Logic & Core Engines

### 1. Regex Generation Engine
**Location**: `lib/viewmodels/sms_parsing_view_model.dart`
The app uses a user-friendly token selection system to generate complex Regex patterns without requiring user Regex knowledge.
- **Tokenization**: The SMS body is split into individual words (tokens) using `RegExp(r'\s+')`.
- **Selection Modes**:
    - **Amount Selection**: One element is identified as the numeric value. In the regex, this is converted to a capture group `(?:[^0-9\n]*)([0-9.,]+)` to handle currency symbols and noise.
    - **Anchor Selection**: Users select static words (e.g., "Spent", "HDFC") to anchor the pattern. These are escaped and treated as literals.
- **Gap Handling**: 
    - **Adjacent Selection**: If two selected tokens are next to each other, a simple `\s+` (whitespace) match is inserted.
    - **Non-Adjacent Selection**: If there are unselected words between two anchors, a wildcard `\s+(?:.*?)\s+` is inserted, making the pattern robust against dynamic content (like merchant names or reference numbers) appearing in between.
- **Auto-Categorization**: The engine scans selected anchors for keywords like "spent", "debited" (Debit) or "credited", "received" (Credit) to automatically set the transaction type.

### 2. SMS Parsing & Matching Engine
**Location**: `lib/services/message_helper.dart`
This core service handles the periodic scanning of the user's SMS inbox to find new transactions.
- **Sync Strategy**:
    - **Incremental Sync**: Stores the timestamp of the last successful sync. Only fetches SMS messages newer than this timestamp to optimize performance.
    - **Sender Filtering**: To avoid running every regex on every message, patterns are first grouped by `senderId`. An incoming SMS is first checked against the list of known bank Sender IDs (e.g., "AX-HDFCBK"). Only matching patterns are executed.
- **Execution Flow**:
    1. Fetch Inbox (filtered by date).
    2. Filter patterns relevant to the message's sender address.
    3. Execute regex patterns sequentially.
    4. **Duplicate Detection**: Before insertion, the app checks the database for an existing transaction with the same `sender`, `amount`, and exact `timestamp`. This prevents duplicates if the same SMS is scanned twice.
    5. **Insertion**: If valid and unique, a new transaction is created in the local SQLite database.

### 3. Transaction Management
- **Goal Linking**: Transactions can be linked to Savings Goals. This logic (in `TransactionDetailViewModel` or similar) updates the `savedAmount` of the goal and marks the transaction as 'linked', sometimes changing its visual representation to show goal contribution.
- **Category Assignment**: Transactions are assigned a `categoryId`. Default is provided by the pattern, but users can manually update this.
