#!/usr/bin/env bash

ASK_EXT=false
REMOVE_TMP=false
KEYSTROKE_MODE=false
COPY_SELECTED=false
SHOW_HELP=false
TERM_OPTS_SET=false
CLEANUP_TMP=false

FONT_SIZE=25
TERM_CLASS='nvim-wl-anywhere'
TERMINAL='alacritty'
TERM_OPTS=()
TMPFILE_DIR='/tmp/nvim-wl-anywhere'
TMPFILE=''
EXT=''

emit() {
    local level=${1:-} message=${2:-} exit_code=${3:-}

    case $level in
        i) printf 'INFO: %s\n' "$message" >&2 ;;
        w) printf 'WARNING: %s\n' "$message" >&2 ;;
        e) printf 'ERROR: %s\n' "$message" >&2 ;;
        f) printf 'FATAL: %s\n' "$message" >&2 ;;
        *)
            printf 'ERROR: Invalid log level: %s\n' "$level" >&2
            return 2
            ;;
    esac
    [[ -z $exit_code ]] || exit "$exit_code"
    return 0
}

show-help() {
    printf 'Usage: %s [OPTIONS]\n\n' "${0##*/}"
    printf '%s\n' \
        'Options (long form only):' \
        '  --help                 Show usage and exit successfully.' \
        '  --ask-ext              Prompt for a temporary buffer file extension.' \
        '  --rm-tmp               Delete the temporary file after successful use.' \
        '                         Keep it on failure or interruption to protect edits.' \
        '  --copy-selected        Start editing the Wayland primary selection.' \
        '  --keystroke-mode       Type text with wtype instead of clipboard paste.' \
        '                         Line breaks may submit input in some applications.' \
        '  --font-size SIZE       Positive terminal font size (default: 25).' \
        '  --term EXECUTABLE      Terminal executable (default: alacritty).' \
        '  --term-opts ARG        Override defaults; repeat once per terminal argument.' \
        '                         Use --term-opts=ARG for arguments starting with --.' \
        '                         Quoted strings remain one argument, not shell code.' \
        '  --                     End options; no positional arguments are accepted.' \
        '' \
        'Values also accept --option=VALUE. Default terminal options are:' \
        '  -o font.size=SIZE --class nvim-wl-anywhere -e' \
        'Custom terminal options must include the terminal command-execution flag.' \
        'The existing editor invocation is Neovim; no editor abstraction is added.' \
        '' \
        'Example: --term foot --term-opts=--app-id --term-opts=nvim-wl-anywhere --term-opts=-e' \
        'Exit status: 0 success/help, 2 argument error, 1 operational failure.'
}

parse-args() {
    local option value getopt_status

    if (($# == 1)) && [[ $1 == --help ]]; then
        SHOW_HELP=true
        return 0
    fi

    command -v getopt >/dev/null 2>&1 || emit f 'GNU getopt is required to parse options.' 1
    getopt --test >/dev/null 2>&1
    getopt_status=$?
    ((getopt_status == 4)) || emit f 'GNU getopt with long-option support is required.' 1

    # Validate with getopt, but consume original argv instead of evaluating its output.
    getopt --name "${0##*/}" --options '' \
        --longoptions 'ask-ext,rm-tmp,keystroke-mode,copy-selected,font-size:,term:,term-opts:,help' \
        -- "$@" >/dev/null || exit 2

    while (($# > 0)); do
        case $1 in
            --ask-ext) ASK_EXT=true ;;
            --rm-tmp) REMOVE_TMP=true ;;
            --keystroke-mode) KEYSTROKE_MODE=true ;;
            --copy-selected) COPY_SELECTED=true ;;
            --help) SHOW_HELP=true ;;
            --font-size|--font-size=*|--term|--term=*|--term-opts|--term-opts=*)
                option=${1%%=*}
                if [[ $1 == *=* ]]; then
                    value=${1#*=}
                else
                    (($# >= 2)) && [[ $2 != --* ]] || emit e "$option requires a value (use $option=VALUE for a value starting with --)." 2
                    value=$2
                    shift
                fi
                case $option in
                    --font-size)
                        [[ $value =~ ^[0-9]+(\.[0-9]+)?$ && $value =~ [1-9] ]] || emit e '--font-size requires a positive number.' 2
                        FONT_SIZE=$value
                        ;;
                    --term)
                        [[ -n $value && $value != -* ]] || emit e '--term requires a nonempty executable name or path, not a command string.' 2
                        TERMINAL=$value
                        ;;
                    --term-opts)
                        TERM_OPTS_SET=true
                        TERM_OPTS+=("$value")
                        ;;
                esac
                ;;
            --)
                shift
                (($# == 0)) || emit e "Unexpected argument: $1" 2
                break
                ;;
            -*) emit e "Unknown option: $1" 2 ;;
            *) emit e "Unexpected argument: $1" 2 ;;
        esac
        shift
    done

    if ! $TERM_OPTS_SET; then
        TERM_OPTS=(-o "font.size=$FONT_SIZE" --class "$TERM_CLASS" -e)
    fi
}

check-deps() {
    local cmd
    local -a deps=(nvim "$TERMINAL" wtype pgrep mkdir chmod mktemp)

    $ASK_EXT && deps+=(wofi)
    $COPY_SELECTED && deps+=(wl-paste)
    $KEYSTROKE_MODE || deps+=(wl-copy)
    $REMOVE_TMP && deps+=(rm)

    for cmd in "${deps[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || emit f "'$cmd' is required but not installed." 1
    done
}

kill-existing-instance() {
    local processes status=0 pid cmd executable found=false

    processes=$(pgrep -af -- "$TERM_CLASS") || status=$?
    ((status <= 1)) || emit f 'Unable to inspect existing instances.' 1
    [[ -n $processes ]] || return 0

    while read -r pid cmd; do
        [[ $pid =~ ^[0-9]+$ ]] || continue
        ((pid != $$)) || continue
        executable=${cmd%% *}
        if [[ $executable == "$TERMINAL" || ($TERMINAL != */* && ${executable##*/} == "$TERMINAL") ]]; then
            kill -KILL -- "$pid" || emit f "Unable to terminate existing instance $pid." 1
            found=true
        fi
    done <<< "$processes"

    $found && emit i 'An existing instance was found and terminated.' 1
    return 0
}

create-tmpfile() {
    mkdir --parents -- "$TMPFILE_DIR" || emit f 'Unable to create temporary directory.' 1
    [[ -d $TMPFILE_DIR && -O $TMPFILE_DIR && ! -L $TMPFILE_DIR ]] || emit f 'Temporary directory must be owned by you and must not be a symlink.' 1
    chmod 700 -- "$TMPFILE_DIR" || emit f 'Unable to secure temporary directory.' 1
    TMPFILE=$(mktemp --tmpdir="$TMPFILE_DIR" --suffix="${EXT:+.$EXT}" 'doc-XXXXXXXXXX') || emit f 'Unable to create temporary file.' 1
}

cleanup() {
    local status=$?

    if [[ -n $TMPFILE ]]; then
        if $REMOVE_TMP && $CLEANUP_TMP; then
            rm --force -- "$TMPFILE" || {
                emit e "Unable to remove temporary file: $TMPFILE"
                status=1
            }
        elif ((status != 0)); then
            emit w "Temporary file retained: $TMPFILE"
        fi
    fi
    return "$status"
}

main() {
    local -a editor_cmd

    parse-args "$@"
    if $SHOW_HELP; then
        show-help
        return 0
    fi

    check-deps
    trap 'cleanup || exit $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    trap 'exit 131' QUIT
    kill-existing-instance

    if $ASK_EXT; then
        EXT=$(wofi --dmenu --lines 1 --prompt 'File extension:') || emit f 'File extension prompt failed or was cancelled.' 1
        [[ $EXT != */* ]] || emit e 'File extension must not contain a slash.' 1
    fi

    create-tmpfile
    if $COPY_SELECTED; then
        wl-paste --primary --no-newline > "$TMPFILE" || emit f 'Unable to read the primary selection.' 1
    fi

    editor_cmd=("$TERMINAL" "${TERM_OPTS[@]}" nvim +startinsert '+autocmd BufWritePost <buffer> quit' "$TMPFILE")
    "${editor_cmd[@]}" || emit f "Editor launch failed; edits remain in $TMPFILE." 1

    [[ -s $TMPFILE ]] || emit e 'The edited buffer is empty.' 1
    if $KEYSTROKE_MODE; then
        wtype - < "$TMPFILE" || emit f 'Unable to type edited text.' 1
    else
        wl-copy < "$TMPFILE" || emit f 'Unable to copy edited text.' 1
        wtype -M Ctrl -k v -m Ctrl || emit f 'Unable to inject the paste shortcut.' 1
    fi
    CLEANUP_TMP=true
}

main "$@"
