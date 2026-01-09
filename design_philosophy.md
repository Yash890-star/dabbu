# Design Philosophy: The Bento Style

This project employs a **Bento Grid** design philosophy, characterized by modular, highly structured, and visually distinct content blocks ("cards") that form a cohesive dashboard.

## Core Design Principles

### 1. Modular "Blocks" (The Bento Box)
Everything in the UI is encapsulated in a rounded container, referred to as an `AppCard`. This creates a clean separation of concerns where each "block" serves a single, distinct purpose (e.g., "Welcome", "Budget Gauge", "Quick Action").

### 2. Physicality & Depth
- **Light Mode**: Uses subtle shadows (`blurRadius: 10`, `offset: (0, 4)`) to lift blocks off the background, simulating cards floating on a surface.
- **Dark Mode**: Uses thin, semi-transparent borders (`Colors.white.withValues(alpha: 0.1)`) instead of shadows to define edges against the dark background, maintaining contrast without visual "muddiness".

### 3. standardized Geometry
- **Corner Radius**: **24.0** is the magic number. All top-level blocks (`AppCard`) use `BorderRadius.circular(24)`.
    - Inner elements (like icons or progress bars) use smaller, relative radii (e.g., 10 or 4) to maintain visual harmony.
- **Spacing**: A consistent **16.0** gap is maintained between blocks (both main and cross axis) and as internal padding within blocks.

### 4. Layout Strategy
- **Uniform Grid**: Used for homogenous content (e.g., Categories) via `BentoGrid` (wrapping `GridView.count`).
- **Asymmetric rows**: Used for dashboard layouts via `BentoRow`. This allows for "spanning" blocks (e.g., a 2:1 width gauge next to a 1:1 stat card) to create visual interest and hierarchy, breaking the monotony of a rigid grid.
- **Responsive Sizing**: Blocks often use `Expanded` or `flex` factors to fill available width.

## Key Components

| Component | Role | Implementation Details |
| :--- | :--- | :--- |
| **`AppCard`** | The Base Atom | The fundamental container. Handles theme-aware styling (shadows vs borders, colors). Defaults to 24px radius. |
| **`BentoGrid`** | Uniform Wrapper | Wraps homogeneous items (like the Category list) in a fixed 2-column grid. |
| **`BentoRow`** | Flexible Wrapper | Allows creating specific row layouts (e.g., `flex: [2, 1]` for a wide block next to a narrow one). |
| **`WelcomeBlock`** | Header Block | A full-width block emphasizing user identity and primary interactions (Notification, Scan). |
| **`StatCard`** | Metric Block | A 1x1 or 1xN block focused on a single metric (Income/Expense) with an icon and vibrant color. |

## Implementation Rules for New Features
When adding new screens or sections:
1.  **Wrap it in an `AppCard`**: Never place raw text or widgets directly on the scaffold background (unless it's a list item in a specifically non-bento list).
2.  **Use 24px Radius**: Ensure `borderRadius: BorderRadius.circular(24)` is used for the container.
3.  **Respect the Grid**: If placing multiple items, align them to the 16px grid. Use `BentoRow` to manage horizontal space.
4.  **Focused Content**: Each block should do *one* thing well. Don't overstuff a single card; split it into two if needed.
