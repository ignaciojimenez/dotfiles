#!/bin/bash

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Color constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Default settings
DRY_RUN=0
VERBOSE=0
FORCE=0
KICKSTART=0
CONFLICTS=0  # links skipped because something else is in the way

# Import common functions early to ensure they're available
source "${SCRIPT_DIR}/thefiles/.common_functions"

# Output functions
info() { echo -e "${GREEN}=>${NC} $*"; }
warn() { echo -e "${YELLOW}=>${NC} $*" >&2; }
error() { echo -e "${RED}=>${NC} $*" >&2; }

# Usage function
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -k, --kickstart         Install environment packages
    -d, --dry-run          Show what would be done
    -f, --force            Force overwrite of existing files
    -v, --verbose          Verbose output
    -h, --help             Show this help message

Example:
    $(basename "$0") --kickstart
EOF
    exit 1
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--kickstart)
                KICKSTART=1
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Require zsh. We support zsh on macOS as primary and zsh on Linux as
# secondary; bash was dropped from the dotfiles in 2026-05.
# zsh is what the shell config targets, but it is not a prerequisite for
# linking. Only four tracked files need it — .zshrc, .zprofile, .zsh_options,
# .zsh_keys — and without zsh they are inert, not broken. The other ten work
# under any shell or none: .profile (POSIX, read by login bash), .exports,
# .common_functions, .gitconfig, .starship.toml, .scripts/, and the agent
# context. Hard-failing denied all of that over four dormant files, on exactly
# the hosts least able to fix it — a container or a shared box where installing
# a shell needs root you may not have. Link everything, say so once; the zsh
# files start working the moment zsh appears, with no re-run needed.
warn_missing_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not installed — .zshrc/.zprofile/.zsh_options/.zsh_keys will be"
        warn "inert until it is. Everything else links and works normally."
        warn "To enable them:  apt install zsh  |  dnf install zsh  |  brew install zsh"
    fi
}

# All dotfiles symlinked into $HOME. No shell branching — zsh-only.
get_dotfiles() {
    echo ".zshrc .zprofile .zsh_options .zsh_keys .profile .shell_options .shell_tools .aliases .exports .common_functions .security .scripts .gitconfig .ansible_preauth .starship.toml"
}

# Compare files or symlinks
files_differ() {
    local src="$1"
    local dst="$2"
    
    # If destination doesn't exist, they differ
    if [[ ! -e "$dst" ]]; then
        return 0
    fi
    
    # If destination exists but isn't a symlink, they differ
    if [[ ! -L "$dst" ]]; then
        return 0
    fi
    
    # If it's a symlink but points to wrong location, they differ
    local link_target
    link_target=$(readlink "$dst")
    if [[ "$link_target" != "$src" ]]; then
        return 0
    fi
    
    # If it's a symlink pointing to the right place, they're the same
    return 1
}

# Create backup directory
create_backup() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        info "Created backup directory: $BACKUP_DIR"
    fi
}

# Link one path with the same backup + FORCE gate as the main loop.
# Creates the parent directory, so it works for nested harness config paths.
# Reads/updates the create_symlinks counters via bash dynamic scoping.
link_with_backup() {
    local src="$1"
    local dst="$2"

    if ! files_differ "$src" "$dst"; then
        [[ "$VERBOSE" -eq 1 ]] && info "Skipping $dst (already correctly linked)"
        return 0
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ "$FORCE" -eq 0 ]]; then
            if [[ -L "$dst" ]]; then
                warn "Different symlink exists: $dst -> $(readlink "$dst")"
            else
                warn "File exists and differs: $dst"
            fi
            warn "Use --force to overwrite"
            CONFLICTS=$((CONFLICTS + 1))
            return 0
        elif [[ "$DRY_RUN" -eq 0 ]]; then
            [[ "$backups_made" -eq 0 ]] && create_backup
            # Flatten the path so nested configs can't collide in the backup dir.
            mv "$dst" "${BACKUP_DIR}/$(echo "${dst#"$HOME"/}" | tr '/' '_')"
            info "Backed up: $dst"
            backups_made=$((backups_made + 1))
        else
            info "[DRY-RUN] Would back up: $dst"
        fi
    fi

    if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$(dirname "$dst")"
        ln -sfn "$src" "$dst"
        info "Created symlink: $dst -> $src"
        changes_made=$((changes_made + 1))
    else
        info "[DRY-RUN] Would create symlink: $dst -> $src"
    fi
}

# Create symlinks with smart backup
create_symlinks() {
    local os_type="$1"
    local changes_made=0
    local backups_made=0

    # Get list of files to process
    for file in $(get_dotfiles); do
        local src="${SCRIPT_DIR}/thefiles/${file}"
        local dst="${HOME}/${file}"

        # Check if source exists
        if [[ ! -e "$src" ]]; then
            warn "Source file not found: $src"
            continue
        fi
        
        if files_differ "$src" "$dst"; then
            # Backup needed only if destination exists and isn't already correct
            if [[ -e "$dst" ]]; then
                if [[ "$FORCE" -eq 0 ]]; then
                    if [[ -L "$dst" ]]; then
                        warn "Different symlink exists: $dst -> $(readlink "$dst")"
                    else
                        warn "File exists and differs: $dst"
                    fi
                    warn "Use --force to overwrite"
                    CONFLICTS=$((CONFLICTS + 1))
                    continue
                fi
                
                # Create backup directory only when first backup is needed
                if [[ "$backups_made" -eq 0 ]]; then
                    create_backup
                fi
                
                mv "$dst" "${BACKUP_DIR}/"
                info "Backed up: $dst"
                backups_made=$((backups_made + 1))
            fi
            
            # Create symlink
            if [[ "$DRY_RUN" -eq 0 ]]; then
                ln -sf "$src" "$dst"
                info "Created symlink: $dst -> $src"
                changes_made=$((changes_made + 1))
            else
                info "[DRY-RUN] Would create symlink: $dst -> $src"
            fi
        else
            if [[ "$VERBOSE" -eq 1 ]]; then
                info "Skipping $file (already correctly linked)"
            fi
        fi
    done
    
    # macOS-specific shortcut: ~/Workspaces -> ~/Documents/Workspaces.
    # Idempotent: skips if target absent or shortcut already exists.
    if [[ "$os_type" == "macos" ]] \
       && [[ -d "$HOME/Documents/Workspaces" ]] \
       && [[ ! -e "$HOME/Workspaces" ]]; then
        if [[ "$DRY_RUN" -eq 0 ]]; then
            ln -s "$HOME/Documents/Workspaces" "$HOME/Workspaces"
            info "Created symlink: $HOME/Workspaces -> $HOME/Documents/Workspaces"
            changes_made=$((changes_made + 1))
        else
            info "[DRY-RUN] Would create symlink: $HOME/Workspaces -> $HOME/Documents/Workspaces"
        fi
    fi

    # Portable AI agent context. The canonical file is agent-context/AGENTS.md
    # in this repo — git is the only transport that reaches macOS, Linux agent
    # hosts and anything else, so this runs on every platform.
    #
    #   a. ~/.agent-context -> the repo's agent-context/ directory: a stable
    #      path to the canonical file for anything that has to name one without
    #      knowing where this repo is cloned.
    #   b. One adapter per harness, at each vendor's own global-config path,
    #      every one a symlink to the canonical file itself — no per-harness
    #      file in between. Created unconditionally: a dangling adapter for a
    #      harness that isn't installed is inert, and pre-wiring means adopting
    #      a new harness costs nothing.
    local agent_link="$HOME/.agent-context"
    link_with_backup "${SCRIPT_DIR}/agent-context" "$agent_link"

    local canonical="${SCRIPT_DIR}/agent-context/AGENTS.md"

    # Claude Code is the only harness that still needs the CLAUDE.md filename.
    # It reads a project's AGENTS.md since 2.1.x, but a *user-level* AGENTS.md
    # is answered as if it were a project file, so it is dropped in any repo
    # that carries a CLAUDE.md of its own — the global rules would vanish
    # exactly where they are least controlled. Verified 2026-09-20; see
    # docs/decisions.md. The file is the canonical one, not an importer.
    link_with_backup "$canonical" "$HOME/.claude/CLAUDE.md"

    # Harnesses that read AGENTS.md natively at a global path.
    link_with_backup "$canonical" "$HOME/.config/opencode/AGENTS.md"
    link_with_backup "$canonical" "$HOME/.config/devin/AGENTS.md"
    link_with_backup "$canonical" "$HOME/.gemini/AGENTS.md"

    # Devin Desktop (Windsurf IDE) has its own filename and a 6,000-char cap
    # on this file — scripts/validate.sh enforces that budget on the canonical.
    link_with_backup "$canonical" "$HOME/.codeium/windsurf/memories/global_rules.md"

    # Deliberately NOT linked: ~/.gemini/GEMINI.md. Antigravity and Gemini CLI
    # both read *and write* it (google-gemini/gemini-cli#16058), so a symlink
    # would let Antigravity's "+ Global" button overwrite the tracked file.
    # Gemini CLI is pointed at the AGENTS.md adapter above instead, via
    # `context.fileName` in ~/.gemini/settings.json — see README.

    # Agent session tracking (docs/agent-sessions.md). Claude Code loads any
    # folder under ~/.claude/skills/ that carries a plugin manifest, hooks
    # included, with no install step — so its adapter is one more link.
    link_with_backup "${SCRIPT_DIR}/agent-sessions/claude" "$HOME/.claude/skills/agent-sessions"

    # Per-harness behaviour (docs/decisions.md, 2026-09-19). Settings have no
    # cross-harness standard, so each harness gets its own tracked file under
    # harness/<name>/. The link is writable on purpose: a /model or /config
    # change lands in the working tree and shows up in `git status`, instead of
    # drifting in an untracked copy.
    link_with_backup "${SCRIPT_DIR}/harness/claude/settings.json" "$HOME/.claude/settings.json"

    # Summary
    if [[ "$CONFLICTS" -gt 0 ]]; then
        error "$CONFLICTS link(s) skipped: something else is in the way (see warnings above)"
    elif [[ "$changes_made" -eq 0 ]]; then
        info "No changes needed, all files are up to date"
    else
        info "Created $changes_made new symlinks"
        if [[ "$backups_made" -gt 0 ]]; then
            info "Created $backups_made backups in $BACKUP_DIR"
        fi
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Show usage if -h was passed and if any arguments are provided
    if [[ $# -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
        usage
        exit 0
    fi

    # Detect OS type
    local os_type
    os_type=$(detect_os)
    if [[ "$os_type" != "unix" && "$os_type" != "macos" ]]; then
        error "Unsupported OS type: $os_type"
        exit 1
    fi
    info "Detected OS: $os_type"

    warn_missing_zsh

    create_symlinks "$os_type"
    
    if [[ "$KICKSTART" -eq 1 ]]; then
        info "Running environment bootstrap"
        # Source the env_bootstrap script with detected OS type
        if [[ -f "${SCRIPT_DIR}/env_bootstrap.sh" ]]; then
            source "${SCRIPT_DIR}/env_bootstrap.sh" "$os_type"
        else
            error "Environment bootstrap script not found"
            exit 1
        fi
    fi
    
    # A skipped link means this machine is not wired the way the repo says.
    # Reporting success here is how ~/.agent-context pointed at a stale iCloud
    # copy for six weeks with every run green (docs/decisions.md, 2026-09-18).
    if [[ "$CONFLICTS" -gt 0 ]]; then
        error "Bootstrap incomplete — rerun with --force to replace (originals are backed up)"
        exit 1
    fi

    info "Bootstrap completed successfully"
}

# Run main function with all arguments
main "$@"