---
trigger: always_on
glob: "**/*"
description: Core rules for error checking and comprehensive task execution.
---

# Core Development Rules

## 1. Post-Edit Validation
**After modifying ANY file, you MUST immediately check for and fix errors.**
- Do not proceed to edit the next file until the current file is free of syntax errors, compilation errors, or serious lint issues introduced by your changes.
- If an edit causes an error, investigate and resolve it immediately within the same step or the very next step.

## 2. Comprehensive Task Execution
**When a task involves applying changes to multiple files (e.g., "replace X with Y in all files"):**
1.  **Discovery**: First, explicitly list ALL files that need modification using search tools (e.g., `grep_search`, `find_by_name`). Do not guess; find the exact set of files.
2.  **Sequential Processing**: Process the files ONE BY ONE.
    - Edit File A.
    - Verify File A (check for errors).
    - Fix File A if needed.
    - Only then move to File B.
3.  **Final Verification**: After all files are processed, perform a final global search to ensure no instances were missed. If any misses are found, fix them immediately using the same process.
