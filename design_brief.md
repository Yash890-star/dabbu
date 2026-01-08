# Product Design Brief: Dabbu - Intelligent Expense Tracker

## 1. Executive Summary
**Product Name:** Dabbu
**Platform:** Android Mobile (Primary)
**Core Value:** A privacy-first, automated expense tracker that works by parsing SMS transaction messages. It runs entirely offline/local-first.
**Goal:** Redesign the application to look "Premium," "Modern," and "User-Friendly." The current app feels utilitarian and inconsistent. We need a design that delights users and makes financial tracking feel effortless, not like a chore.

## 2. Design Philosophy & Requirements
*   **Aesthetic:** Modern, Clean, High-Contrast. Avoid generic "Material Design 1.0" looks. Think "Fintech Startup" (e.g., Cred, Revolut, Monzo) but with a warmer, more personal touch.
*   **Theme:** **Strictly enforce cohesive Dark and Light modes.**
    *   *Problem:* Current app has poor contrast in dark mode and inconsistent colors.
    *   *Requirement:* accessible text contrast, distinct background layers (surface, background, container), and vibrant accent colors that look good in both modes.
*   **Navigation:** Flatten the hierarchy.
    *   *Problem:* Settings are too deep. "Tally" and "Goals" feel disconnected.
    *   *Requirement:* Use a modern Bottom Navigation Bar or intuitive Gesture Navigation. Critical features should be 1 tap away.

## 3. Core User Flows & Screen Specifications

### A. Onboarding (New Feature)
*   **Goal:** Guide the user from "Zero" to "Ready" without overwhelming them.
*   **UX Needs:**
    1.  **Welcome:** Friendly hook. "Your money, clear and simple."
    2.  **Permissions Primer (The "Seamless & Secure" Screen):**
        *   *Concept:* Before triggering system dialogs, show a beautiful "Feature List" page.
        *   *Content:*
            *   "SMS Parsing": Explain automation.
            *   "Smart Alerts": Explain notifications.
            *   "Privacy Promise": Reassure user (Shield icon).
        *   *Action:* "Allow Permissions" (Primary) and "Maybe Later" (Text).
    3.  **Initial Setup (The "Wizard" Flow):**
        *   *Visual Style:* Use the "Step 1 of 3" pill at the top (from reference).
        *   **Step 1: The Baseline (Input)**
            *   "Monthly Budget Goal": Large input.
            *   "Salary Cycle": Horizontal Day Picker.
            *   *Action:* "Next" -> slides to Step 2.
        *   **Step 2: The Crunch (Sync)**
            *   *Content:* The circular loader from the reference image.
            *   *Copy:* "Crunching numbers...", showing a live counter of found transactions.
            *   *Tech:* Requires streaming sync service.
        *   **Step 3: All Set (Success)**
            *   *Content:* "You're all set!" with a summary ("Found 120 transactions").
            *   *Action:* "Go into Dabbu" (Enter Dashboard).

### B. Dashboard (Home Screen)
*   **Goal:** Instant financial health check.
*   **Visual Style:** Deep background, Glowing central element.
*   **Key Elements:**
    1.  **Top Bar & Month Selector:**
        *   Profile Icon (Left).
        *   Month Carousel (Center): explicit `< October >` arrows for clarity.
        *   *Privacy Toggle (Eye Icon):* Hides all monetary values (Blur effect). *New Feature*.
    2.  **The "Glow" Gauge:**
        *   Central circular progress.
        *   Text: "Remaining ₹X" (Large).
        *   Action: Small "Modify Budget" pill button below the gauge.
    3.  **Smart Insight Card (The "Star" Card):**
        *   *Content:* "Safe to spend: ₹500/day".
        *   *Logic:* (Remaining Budget) / (Days Left in Month). This is a new calculation we need to add to `HomeViewModel`.
    4.  **Recent Activity:** Standard list, but highly stylized (Dark Tiles).
    5.  **FAB:** Standard `+` button, Cyan color.

### C. Transaction Details (Redesign)
*   **Visual Style:** Centralized "Smart Card" aesthetic.
*   **Header:** Dynamic Icon (Category), Merchant Name, Large Amount (Cyan).
*   **"Smart Actions" Row:** A pill-shaped container with quick actions.
    *   *Supported:* "Auto-Rule" (Magic Wand), "Ignore" (exclude), "Delete".
    *   *Not Supported (Yet):* "Split Bill" (Remove from design), "Map Location" (Remove).
*   **Data Fields:**
    *   Category: Wide pill button.
    *   Note: Dark text area.
    *   Tags: We currently don't use a "Tag" system, only Categories. *Decision: Omit Tags for now to keep it clean, or use this space for "Bank Source".*
*   **Footer Actions:** Large "Save Changes" (Primary) and small "Delete" (Destructive Icon).

### D. Tally (Reconciliation Mode) - "The Health Checkup"
*   **Flow:** 3-Step Wizard.
    1.  **Check Your Pockets:**
        *   Ask user for *actual* balances.
        *   *Constraint:* We currently track one global "Liquid Balance". UI should allow entering "Total Cash" + "Total Bank", but we sum it up for the logic.
    2.  **The Reveal:**
        *   "Dabbu Thought you had ₹X" vs "You actually have ₹Y".
        *   Show the *Deviation* (e.g., "-₹200").
    3.  **The Fix:** "Where did the difference go?"
        *   *Forgot to track:* Opens "Add Transaction" screen.
        *   *Adjustment:* Auto-adds a system transaction "Balance Correction".
        *   *Ignore:* Dismisses the discrepancy (Reset baseline).
*   **Visuals:** Dark, Focused, Step-by-step.

### E. Goals & Savings (The "Vault")
*   **Visual Style:** Bento Grid layout + Glassmorphism.
*   **Key Elements:**
    1.  **"Total Savings" Header:**
        *   Display the sum of all *saved* amounts across all goals.
        *   *Style:* Dark Card with gradient glow (Visual only, no "Unallocated" logic yet).
    2.  **Active Goals Grid:**
        *   Cards showing Name, Target, Saved Amount, and Percentage.
        *   *Visuals:* Use **Beautiful Gradients** as backgrounds. No user images for V1.
    3.  **Interaction:** Tap a card to see History.
    4.  **Completed Goals:** Distinct visual style (Gold/Yellow) at the bottom. Start celebrating wins!

### F. Settings & "Training" (Refactor)
*   **Current Pain Point:** Deeply nested. Hard to find "SMS Patterns".
*   **New Structure:**
    *   **Account:** Profile, Data Export.
    *   **Preferences:** Theme, Currency, Start Date.
    *   **"The Brain" (Auto-Categorization):** A dedicated section to manage Rules and Keywords.
    *   "The Brain" (Auto-Categorization): A dedicated section to manage Rules and Keywords.
        *   *Tabs:* "Teach" (New Rule) vs "My Rules" (List).
        *   *Flow:* Standard 3-Step Wizard.
            1.  **Select Source:** User picks a recent SMS or types a raw keyword.
            2.  **Define Rule:** User highlights the specific keyword (e.g., "Starbucks") from the text.
            3.  **Assign Category:** User selects the target category (e.g., "Food").
        *   *Visual:* Clean cards, big clickable areas. No "Chat" gimmicks.
        *   *My Rules:* A clean list of "Keyword -> Category" cards with a delete option.

### G. Analytics & Insights
*   **Visual Style:** Deep Dashboard.
*   **Spending Heatmap (Refine Existing):**
    *   *Current State:* We already have `HeatMapBlock`.
    *   *Redesign Goal:* Apply the new cyan/dark theme and ensure date numbers are visible.
    *   *Interaction:* Tap a day to see transaction breakdown below.
*   **Charts:** Keep it simple. Don't overwhelm. Pie chart for categories is enough for V1.
*   **Filters:** "Top Categories", "Income vs Expense", "Date Range".

### H. Subscriptions Manager (Recovered Feature)
*   **Goal:** Manage recurring payments (Netflix, Rent, SIPs).
*   **Visual Style:** "List of Cards" look.
*   **Features:**
    *   **Auto-Scan:** Button to scan past transactions for patterns.
    *   **List:** standard cards showing Name, Amount, Frequency (Monthly/Yearly), and "Days Left" countdown.
    *   **Manual Add:** Form to add a subscription manually.

### I. Archived Goals (The Vault)
*   **Location:** Accessed via "Goals" screen (top right menu or bottom of list).
*   **Style:** Muted/Grayscale cards.
*   **Action:** "Restore" or "Delete Permanently".

### J. Advanced Budgeting (Budget Overrides)
*   **Concept:** Life isn't static. Allow setting a *different* budget for specific months (e.g., December = High Spend).
*   **UI:** Inside "Modify Budget" dialog, add "One-time override for [Month]" option.

## 4. Key Improvements requested
1.  **Unified Colors:** Define a primary Brand Color (e.g., Electric Indigo or Teal) and stick to it.
2.  **Typography:** Use a modern, geometric Sans-Serif (e.g., Inter, Poppins, or Plus Jakarta Sans). High readability is crucial for numbers.
3.  **Empty States:** Never show a blank screen. If there are no transactions, show a friendly illustration "All quiet here...".
4.  **Feedback**: When an SMS is parsed, a small, subtle confirmation toast or snackbar that doesn't block the screen.

## 5. Deliverables for Designer
*   **High-fidelity Mockups** for the screens listed above.
*   **Design System:** Color palette (Hex codes for Light/Dark), Typography scale, Component library (Buttons, Cards, Inputs).
*   **Prototype:** Key transition animations (e.g., expanding the FAB, swiping the Month gauge).
