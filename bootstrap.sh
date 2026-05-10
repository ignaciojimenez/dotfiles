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
require_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        error "zsh is required but not installed."
        error "Install it first:  apt install zsh   |   dnf install zsh   |   brew install zsh"
        exit 1
    fi
}

# All dotfiles symlinked into $HOME. No shell branching — zsh-only.
get_dotfiles() {
    echo ".zshrc .zprofile .zsh_options .zsh_keys .profile .shell_options .aliases .exports .common_functions .security .scripts .gitconfig .ansible_preauth .starship.toml"
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
                    continue
                fi
                
                # Create backup directory only when first backup is needed
                if [[ "$backups_made" -eq 0 ]]; then
                    create_backup
                fi
                
                mv "$dst" "${BACKUP_DIR}/"
                info "Backed up: $dst"
                ((backups_made++))
            fi
            
            # Create symlink
            if [[ "$DRY_RUN" -eq 0 ]]; then
                ln -sf "$src" "$dst"
                info "Created symlink: $dst -> $src"
                ((changes_made++))
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
            ((changes_made++))
        else
            info "[DRY-RUN] Would create symlink: $HOME/Workspaces -> $HOME/Documents/Workspaces"
        fi
    fi
    
    # Summary
    if [[ "$changes_made" -eq 0 ]]; then
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

    require_zsh

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
    
    info "Bootstrap completed successfully"
}

# Run main function with all arguments
main "$@"