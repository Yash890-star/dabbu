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
    2.  **Permissions Primer:** Explain *why* we need SMS/Notification permissions (Privacy emphasis: "We read, we analyze, we discard. Nothing leaves your phone.").
    3.  **Initial Setup:**
        *   Set "Monthly Budget".
        *   Ask "When does your salary cycle start?" (Date picker).
        *   Perform the *first sync* with a visually pleasing loading animation ("Crunching numbers...").

### B. Dashboard (Home Screen)
*   **Goal:** Instant financial health check.
*   **Key Elements:**
    1.  **The "Pulse" (Budget Gauge):** A central visual element showing *Remaining Budget*.
        *   *Interaction:* Swipe left/right to change months. Tap to edit budget.
        *   *Vibe:* Green = Good, Yellow = Caution, Red = Danger.
    2.  **Recent Activity:** A short list of the last 3-5 transactions.
    3.  **Smart Insights:** "Safe to Spend: ₹500/day" or "You've saved ₹2k more than last month!" (Micro-copy is key here).
    4.  **Floating Action Button (FAB):** Multi-expandable.
        *   Primary: Add Cash Transaction.
        *   Secondary: Tally (Reconciliation).

### C. Transaction Details (Redesign)
*   **Current Pain Point:** Cluttered. Too many fields.
*   **Goal:** Clean, focused editing.
*   **UX Needs:**
    *   **Header:** Large Amount, Merchant Name, & Date.
    *   **"Smart Actions" Toolbar:** Group related actions cleanly.
        *   *Magic Wand:* Create Auto-Rule (for this merchant).
        *   *Split:* Split bill (if added later).
        *   *Ignore:* "Exclude from Budget".
    *   **Categorization:** Large, easy-to-tap category pill. changing it should be delightful (icon grid).
    *   **Edit Mode:** Fields (Notes, Tags) should look editable but clean.

### D. Tally (Reconciliation Mode) - "The Health Checkup"
*   **Current Pain Point:** Feels like a spreadsheet/tool. Hard to understand "Liquid" vs "Non-Liquid".
*   **Concept:** Make it a "Wizard" flow.
*   **Steps:**
    1.  **"Let's Check Your Pockets":** Ask for current balances of specific accounts (Cash, Bank, Wallet).
    2.  **The Reveal:** "Dabbu thought you had ₹5000. You actually have ₹4800."
    3.  **The Fix:** "Where did the ₹200 go?" -> Options: "Forgot to track (Add Expense)", "Adjustment", "Ignore".
*   **Visuals:** Calm, focused. Step-by-step cards.

### E. Goals & Savings
*   **Current Pain Point:** Dry list.
*   **Goal:** Gamification.
*   **Visuals:**
    *   Progress Bars that fill up like liquid.
    *   Celebratory animation when a goal is reached.
    *   "Drag and Drop" money into goals (metaphorically).

### F. Settings & "Training" (Refactor)
*   **Current Pain Point:** Deeply nested. Hard to find "SMS Patterns".
*   **New Structure:**
    *   **Account:** Profile, Data Export.
    *   **Preferences:** Theme, Currency, Start Date.
    *   **"The Brain" (Auto-Categorization):** A dedicated section to manage Rules and Keywords.
        *   Show a list of "Learned Rules".
        *   Allow user to manually teach new Merchant names.
        *   *Visual:* Chat-bubble style interface? "If message says 'Starbucks', mark as 'Coffee'."

## 4. Key Improvements requested
1.  **Unified Colors:** Define a primary Brand Color (e.g., Electric Indigo or Teal) and stick to it.
2.  **Typography:** Use a modern, geometric Sans-Serif (e.g., Inter, Poppins, or Plus Jakarta Sans). High readability is crucial for numbers.
3.  **Empty States:** Never show a blank screen. If there are no transactions, show a friendly illustration "All quiet here...".
4.  **Feedback**: When an SMS is parsed, a small, subtle confirmation toast or snackbar that doesn't block the screen.

## 5. Deliverables for Designer
*   **High-fidelity Mockups** for the screens listed above.
*   **Design System:** Color palette (Hex codes for Light/Dark), Typography scale, Component library (Buttons, Cards, Inputs).
*   **Prototype:** Key transition animations (e.g., expanding the FAB, swiping the Month gauge).
