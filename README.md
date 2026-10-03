# nvim-wl-anywhere

![showcase](assets/showcase.gif)

Edit text anywhere on **Wayland** using **Neovim**, then paste it into any text field via **`wtype`**

This tool is inspired by [vim-anywhere](https://github.com/cknadler/vim-anywhere), but designed specifically for **Neovim** + **Wayland**.

---

## Features

- Launch a temporary **Neovim** buffer from anywhere.
- Automatically paste edited text back into the currently focused text field.
- Supports optional file extensions for syntax highlighting.
- Can work in two modes:
  - **Clipboard Mode (default)** → Ctrl + v to paste.
  - **Keystroke Mode (`--keystroke-mode`)** → Sends keystrokes directly using `wtype` (useful when clipboard-based paste doesn’t work in certain apps).
- Edits the currently selected text if any (with `--copy-selected`)
- Cleans up temporary files automatically if requested.

---

## Installation

```bash
git clone https://github.com/abdullah-albanna/nvim-wl-anywhere.git
cd nvim-wl-anywhere
chmod +x nvim-wl-anywhere.sh
```

---

## Configuration

### Hyprland

Bind the script to a Hyprland key combination (example below with `SUPER+N`):

```bash
bind = SUPER, N, exec, /path/to/nvim-wl-anywhere.sh
```

---

#### Window Rules (Optional)

For a smoother workflow, add window rules to make the editor float and stay focused:

```bash
windowrulev2 = float, class:nvim-wl-anywhere
windowrulev2 = pin, class:nvim-wl-anywhere
windowrulev2 = stayfocused, class:nvim-wl-anywhere
windowrulev2 = size 70% 70%, class:nvim-wl-anywhere
```

---

## Command-line options

The inherited script currently launches Neovim, with Alacritty as the default
terminal. Editor/terminal independence is Editlet's project direction; this
parsing refactor does not implement an editor abstraction.

Options are long-form only:

| Option | Behavior |
| --- | --- |
| `--help` | Print usage and exit successfully, before runtime operations. |
| `--ask-ext` | Prompt for a file extension; cancellation is an error. |
| `--rm-tmp` | Delete the buffer after successful use; retain edits on failure or interruption. |
| `--copy-selected` | Prefill from the Wayland primary selection without changing the clipboard. |
| `--keystroke-mode` | Type the edited buffer with `wtype`; newlines may submit input in some applications. |
| `--font-size SIZE` | Positive integer or decimal font size, default `25`; affects default terminal options. |
| `--term EXECUTABLE` | Terminal executable name or path, default `alacritty`; not a shell command string. |
| `--term-opts ARG` | Repeat once per terminal argument to replace all default terminal options. |
| `--` | End options; positional arguments are not accepted. |

Value options also accept `--option=VALUE`. Supply terminal long flags with
`--term-opts=--flag`. Each value is one exact argument: quoting preserves spaces
and glob characters, and no shell splitting or evaluation occurs. Replace old
space-separated `--term-opts` strings/lists with repeated occurrences, for example:

```bash
./nvim-wl-anywhere.sh --font-size 18
./nvim-wl-anywhere.sh --term foot \
    --term-opts=--app-id --term-opts=nvim-wl-anywhere --term-opts=-e
./nvim-wl-anywhere.sh \
    --term-opts=-o --term-opts='font.size=18' \
    --term-opts=--class --term-opts='nvim-wl-anywhere' --term-opts=-e
```

Default terminal arguments are `-o font.size=SIZE --class nvim-wl-anywhere -e`.
Custom options must include the chosen terminal's command-execution flag.
Repeated `--term-opts` append arguments in order; the first occurrence removes
the defaults. An explicitly empty value represents an empty terminal argument.
Scalar options use the last supplied value. GNU `getopt` validates syntax;
the script consumes original arguments without `eval` and rejects abbreviated
options, short aliases, unknown options, missing values, and positional arguments.

Exit statuses: `0` for success/help, `2` for argument errors, `1` for operational
failures (signals use conventional `128 + signal` statuses). Diagnostics go to
stderr. All options are validated before runtime actions; `--help` combined with
invalid arguments reports an error rather than ignoring those arguments.

### Intentional corrections

- Help now exits instead of looping; process termination occurs only after
  parsing, validation, and dependency checks. Instance matching is limited to
  the first command token, not terminal names appearing in arbitrary arguments,
  and excludes the current script PID.
- Font-size overrides now reach default terminal arguments; custom argument
  boundaries are preserved instead of splitting strings.
- Primary selection is read directly into the buffer, including when it equals
  clipboard contents; selection read failures are reported rather than ignored.
- Buffer contents retain literal text and trailing newlines, including
  newline-only buffers; no extra newline is added when prefilling selection.
- Temporary files have unique private names in `/tmp/nvim-wl-anywhere`; the
  directory must be owned by the user and not a symlink, and is secured to mode
  `700`. `--rm-tmp` retains the buffer on failure to protect edits.

Only static verification is authorized under the current project policy:
Bash syntax checks, ShellCheck when available, `git diff --check`, and code/diff
review. Do not run behavioral tests, including smoke checks, temporary harnesses,
mocks, or ad hoc CLI cases. See `AGENTS.md`.

## Dependencies

The script depends on the following commands:

- `nvim` → Neovim editor  
- `alacritty` → terminal (or another terminal of your choice)  
- `wofi` → for selecting a file extension when `--ask-ext` is enabled  
- `wtype` → for simulating keystrokes (needed for `--keystroke-mode`)  
- `wl-clipboard` → provides `wl-copy` / `wl-paste` for clipboard support  
- GNU `getopt` → validates long options (usually provided by util-linux)
- `pgrep` and the standard `mkdir`, `chmod`, `mktemp` utilities; `rm` with `--rm-tmp`

Only the selected terminal is required. `wofi` is required only with
`--ask-ext`, `wl-paste` only with `--copy-selected`, and `wl-copy` only in
clipboard mode. `wtype` is required in both output modes. Standalone
`--help` does not require any external commands.

Install on Arch-based systems:

```bash
sudo pacman -S neovim alacritty wofi wtype wl-clipboard
```

---

## License

MIT
