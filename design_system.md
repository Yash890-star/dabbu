# Dabbu Design System & Style Guide

## 1. Design Principles
*   **"Electric & Deep"**: Use deep, rich backgrounds coupled with vibrant, electric accents.
*   **Round & Friendly**: High border radius on cards and buttons.
*   **High Contrast**: Text must always be legible. No subtle gray-on-gray.

## 2. Color Palette
We are extracting the "Deep Teal" aesthetic from the reference image.

### A. Dark Mode (Primary)
Based on the Welcome Screen reference.
| Token | Hex Code (Approx) | Usage |
| :--- | :--- | :--- |
| **Background** | `#0D1619` | Main screen background (Deep Gunmetal/Black). |
| **Surface** | `#1A262B` | Cards, Bottom Sheets, Lists. slightly lighter than BG. |
| **Primary** | `#1CD0EC` | Main Actions (Buttons), Highlights, "Get Started". (Cyan/Teal). |
| **On Primary** | `#000000` | Text inside Primary Buttons. |
| **Secondary** | `#263238` | Badges, inactive states (Blue Grey). |
| **Text Primary** | `#FFFFFF` | Headings, Main Data. |
| **Text Secondary**| `#B0BEC5` | Subtitles, descriptions (Blue Grey Light). |
| **Success** | `#4CAF50` | Income, Positive Trends. |
| **Error** | `#FF5252` | Expenses, Alerts. |

### B. Light Mode (Derived)
Inverted to maintain the "Teal" identity without eye strain.
| Token | Hex Code | Usage |
| :--- | :--- | :--- |
| **Background** | `#F0F4F5` | Main screen background (Cool White). |
| **Surface** | `#FFFFFF` | Cards. |
| **Primary** | `#0097A7` | Slightly darker Cyan for visibility on white. |
| **On Primary** | `#FFFFFF` | Text inside Primary buttons. |
| **Text Primary** | `#102027` | Headings (Deep Blue-Black). |
| **Text Secondary**| `#546E7A` | Subtitles. |

## 3. Typography
**Font Family:** `Inter` (or `Plus Jakarta Sans`) - Recommended.
*Fallback:* `Roboto` (Default Android).

| Style | Weight | Size | Usage |
| :--- | :--- | :--- | :--- |
| **Display Large** | Bold (700) | 32sp | Welcome Titles ("Your money, clear..."). |
| **Display Medium**| Bold (700) | 24sp | Page Headers, Total Budget Amount. |
| **Title Medium** | SemiBold (600)| 18sp | Card Titles, Section Headers. |
| **Body Large** | Medium (500) | 16sp | Transaction Details, Settings items. |
| **Body Medium** | Regular (400) | 14sp | Descriptions, Subtitles. |
| **Label** | Bold (700) | 12sp | Badges, Tiny prompts ("Local storage only"). |

## 4. Components & Shapes

### A. Buttons (Primary)
*   **Shape:** Full Pill (`BorderRadius.circular(30)`).
*   **Height:** 56px (Large user targets).
*   **Shadow:** Glowing hint of Primary color in Dark Mode.
*   **Content:** Uppercase Label + Arrow Icon (from reference).

### B. Cards
*   **Shape:** Rounded (`BorderRadius.circular(20)`).
*   **Elevation:** Low (0 or 2), rely on Color fill (`Surface`) for separation.
*   **Padding:** 16px internal.

### C. Badges (e.g., "Local storage only")
*   **Style:** Outlined or Low-Fill.
*   **Shape:** Pill.
*   **Icon:** Included (e.g., Shield icon).

### D. Feature Cards (Permissions/Settings)
*   **Background:** Surface Color (`#1A262B`) with a subtle border (`#263238`).
*   **Layout:** Leading Icon + Title + Subtitle.
*   **Icon Container:**
    *   Shape: Circle or Soft Square.
    *   Color: Primary with 10-15% Opacity (`#1CD0EC` @ 0.15).
    *   Icon Color: Primary (`#1CD0EC`).

### E. Action Containers (Smart Actions)
*   **Style:** Dark, Pill-shaped container holding multiple circular action buttons.
*   **Button Style:** Circular, dark surface, light icon.
*   **Label:** Small text below icon.

### F. Inputs & Forms
*   **Style:** Minimalist. No heavy borders.
*   **Background:** Filled (`Surface` or slightly darker `#151E22`).
*   **Text:** Large, Centered (for amounts) or Left-Aligned (for text).
*   **Placeholder:** `#B0BEC5` (Text Secondary).

### G. Data Visualization (Dashboard)
*   **Budget Gauge:**
    *   Style: Circular Progress.
    *   Color: Gradient Cyan (`#1CD0EC` -> `#0097A7`).
    *   Effect: "Glow" shadow behind the active arc.
    *   Center Content: Large "Remaining" amount.
*   **Insight Card:**
    *   Style: Deep Teal Surface (`#15282D`) - different from standard surface to pop.
    *   Icon: Sparkle/Star icon in a circle.
    *   Content: "Safe to spend" calculated text.

### H. Navigation Elements
*   **Step Indicator:** Pill shape, segmented. Active segment in Primary Cyan (`#1CD0EC`), inactive in Dark Grey (`#263238`).
*   **Bottom Nav:** Minimalist. No text labels if possible, or very small. Active icon is Filled + Primary Color.

### H. Goal & Savings Components
*   **Savings Header:**
    *   Dark Card with gradient glow.
    *   Content: "Total Savings Balance" (Aggregated from all goals).
    *   Action: "Manage Funds" (Circular Button).
*   **Goal Card:**
    *   Style: Bento Grid (mix of square/rectangle).
    *   Background: **Deep Gradients** (e.g., Cyberpunk Blue, Sunset Orange) instead of images.
    *   Progress: Large percentage text (e.g., "75%") is the hero.
    *   Status: "On Track" (Implied by color intensity).

### I. Tally (Reconciliation) Components
*   **Comparison Card (The Reveal):**
    *   Style: Split Card (Left/Right).
    *   Left: "Dabbu Thought" (Grey/Muted).
    *   Right: "Your Reality" (Cyan/highlighted).
    *   Center: "Difference" Badge (Red for negative, Green for positive).
*   **Process Wizard:**
    *   Step 1: Input Fields matching the "Feature Cards" style.
    *   Step 3: Large Option Tiles ("Forgot to track", "Adjustment", "Ignore") with icons.

### J. Settings & "The Brain"
*   **Rule Setup:**
    *   Style: Standard Wizard (Step 1, Step 2, Step 3).
    *   **Keyword Selector:** Tokenized text block (Clickable words).
    *   **Category Grid:** Standard Bento Grid of icons.
*   **Tabs:**
    *   Style: Segmented Control (Pill shape).
    *   States: Teach (Active) | My Rules (Inactive).

### K. Analytics Components
*   **Heatmap Calendar:**
    *   **Grid:** 7-column grid (Sun-Sat).
    *   **Cell Style:** Rounded Square (Soft border radius).
    *   **Cell Content:** Date Number (Small, centered).
    *   **Colors:**
        *   Level 0 (No Spend): Surface (`#1A262B`).
        *   Level 1: Muted Cyan (`#006064`).
        *   Level 2: Primary Cyan (`#1CD0EC`).
        *   Level 3: Bright/White (`#E0F7FA`).

## 5. Iconography
*   **Style:** Rounded, Filled (for active) / Outlined (for inactive).
*   **Pack:** Material Symbols Rounded.

## Implementation Notes
*   **Gradients:** Use subtle gradients on the Primary CTA (Cyan -> slightly lighter Cyan) to add depth like the reference.
*   **Illustrations:** 3D rendered coins/wallets set the premium tone. We may need to use `generate_image` or generic assets if 3D assets aren't available.
