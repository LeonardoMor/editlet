# Editlet project instructions

## Scope and direction
- Editlet is a Wayland popup-editing tool inspired by Ovim's Edit Popup, starting from an nvim-wl-anywhere fork.
- The project must be editor-independent and terminal-independent; the current script still has its inherited Neovim invocation and Alacritty defaults, pending separately authorized work.
- Expose long-form CLI options only; do not add short aliases.
- Avoid unrelated features, dependencies, abstractions, and rewrites.

## Required workflow
- Load and follow the LeanCTX and Bash skills before exploring or editing shell code; use relevant Superpowers skills.
- Verify required tools and skills are available; report blockers instead of silently substituting tools.
- Begin task-focused code exploration with LeanCTX `ctx_compose`; use LeanCTX for reads, searches, and shell commands.
- Respect LeanCTX allowed roots; never bypass a denied reference path.
- Review the entire script against the Bash skill, not only the changed function.
- Use four-space indentation, kebab-case functions, snake_case locals, ALL_CAPS globals, quoted arguments, command arrays, explicit critical failure handling, and safe lifecycle cleanup.
- Do not use `eval`, `set -e`, `set -u`, or blanket `set -euo pipefail`.
- Validate arguments before runtime side effects; help must work without editor, terminal, or Wayland utilities. PR review explicitly approved `cat <<HERE` for help, so the standard `cat` utility is required.
- Preserve text and argument boundaries faithfully.

## Static verification only
- Do not run or add behavioral tests of any kind: automated tests, smoke tests, temporary test harnesses, mocks, or ad hoc CLI test cases. Do not add a test framework or test infrastructure.
- Do not invoke Superpowers TDD for this task; this project-specific policy overrides skill recommendations to test behavior.
- Only static checks are authorized: `bash -n`, ShellCheck when available, `git diff --check`, and review of the code and diff against the Bash checklist.
- Do not execute the script or its parser for verification, even with help/error arguments or intercepted operational commands.
- Remove only test artifacts introduced by the current task; preserve pre-existing files.
- Report unavailable tools and unverified behavior honestly.
- Verified static commands:
  - `bash -n nvim-wl-anywhere.sh`
  - `shellcheck nvim-wl-anywhere.sh`
  - `git diff --check`

## Branch and PR review
- Inspect the working tree and remotes before changing files; preserve unrelated work.
- Identify the user's fork and its default branch rather than assuming a remote or branch name.
- Create a dedicated task branch from the fork's default branch; do not implement directly on the default branch.
- If the requested branch already exists, inspect it and ask before reusing or replacing it.
- For the initial parsing task, use `fix/option-parsing`.
- Keep commits scoped to the authorized correction, related Bash refactoring, documentation, and project instructions.
- After verification and when authorized, commit and push to the user's fork, then submit a PR against that fork's default branch, not upstream.
- Include actual verification results and intentional behavior changes in the PR, and state that behavioral testing was intentionally omitted at the user's request. If checks were performed before this policy was clarified, disclose those checks rather than claiming none occurred.
- Read back the submitted PR to verify repository, base, head, and open status; return its URL.
- Report push/PR blockers honestly, never merge, and stop for user review after submission.
