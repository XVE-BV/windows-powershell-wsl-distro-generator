#!/bin/bash

# Patch Management System for XVE WSL Distro
# Similar to Laravel migrations but for system patches

set -euo pipefail

# Configuration
PATCH_DIR="/opt/xve-patches"
PATCH_STATE_FILE="/opt/xve-patches/applied_patches.json"
BACKUP_DIR="/opt/xve-patches/backups"
PATCHES_AVAILABLE_DIR="/opt/xve-patches/available"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Initialize patch system
init_patch_system() {
    log "Initializing patch management system..."
    
    # Create directories
    sudo mkdir -p "$PATCH_DIR" "$BACKUP_DIR" "$PATCHES_AVAILABLE_DIR"
    
    # Initialize state file if it doesn't exist
    if [[ ! -f "$PATCH_STATE_FILE" ]]; then
        echo '{"applied_patches": [], "last_update": null, "version": "1.0"}' | sudo tee "$PATCH_STATE_FILE" > /dev/null
        success "Patch state file initialized"
    fi
    
    # Set proper permissions
    sudo chown -R xve:xve "$PATCH_DIR"
    success "Patch system initialized"
}

# Get applied patches from state file
get_applied_patches() {
    if [[ -f "$PATCH_STATE_FILE" ]]; then
        jq -r '.applied_patches[]' "$PATCH_STATE_FILE" 2>/dev/null || echo ""
    fi
}

# Check if patch is already applied
is_patch_applied() {
    local patch_name="$1"
    local applied_patches
    applied_patches=$(get_applied_patches)
    echo "$applied_patches" | grep -q "^$patch_name$"
}

# Add patch to applied list
mark_patch_applied() {
    local patch_name="$1"
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg patch "$patch_name" --arg timestamp "$(date -Iseconds)" '
        .applied_patches += [$patch] |
        .last_update = $timestamp
    ' "$PATCH_STATE_FILE" > "$temp_file"
    
    sudo mv "$temp_file" "$PATCH_STATE_FILE"
    success "Marked patch '$patch_name' as applied"
}

# Remove patch from applied list (for rollback)
mark_patch_unapplied() {
    local patch_name="$1"
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg patch "$patch_name" --arg timestamp "$(date -Iseconds)" '
        .applied_patches = (.applied_patches | map(select(. != $patch))) |
        .last_update = $timestamp
    ' "$PATCH_STATE_FILE" > "$temp_file"
    
    sudo mv "$temp_file" "$PATCH_STATE_FILE"
    warning "Marked patch '$patch_name' as unapplied (rolled back)"
}

# Create backup of file before patching
create_backup() {
    local file_path="$1"
    local patch_name="$2"
    local backup_path="$BACKUP_DIR/${patch_name}_$(basename "$file_path").backup"
    
    if [[ -f "$file_path" ]]; then
        sudo cp "$file_path" "$backup_path"
        log "Created backup: $backup_path"
        echo "$backup_path"
    else
        # File doesn't exist, create empty backup marker
        echo "FILE_NOT_EXISTS" > "$backup_path"
        echo "$backup_path"
    fi
}

# Restore backup
restore_backup() {
    local backup_path="$1"
    local original_path="$2"
    
    if [[ -f "$backup_path" ]]; then
        if grep -q "FILE_NOT_EXISTS" "$backup_path" 2>/dev/null; then
            # Original file didn't exist, remove it
            if [[ -f "$original_path" ]]; then
                sudo rm "$original_path"
                log "Removed file that didn't exist before patch: $original_path"
            fi
        else
            # Restore original file
            sudo cp "$backup_path" "$original_path"
            log "Restored backup: $original_path"
        fi
        sudo rm "$backup_path"
    else
        error "Backup file not found: $backup_path"
        return 1
    fi
}

# Apply a single patch
apply_patch() {
    local patch_file="$1"
    local patch_name
    patch_name=$(basename "$patch_file" .sh)
    
    log "Applying patch: $patch_name"
    
    # Check if already applied
    if is_patch_applied "$patch_name"; then
        warning "Patch '$patch_name' already applied, skipping"
        return 0
    fi
    
    # Source the patch file to get patch functions
    if [[ ! -f "$patch_file" ]]; then
        error "Patch file not found: $patch_file"
        return 1
    fi
    
    # Execute patch in a subshell to contain any errors
    if (
        source "$patch_file"
        if declare -f patch_up >/dev/null; then
            patch_up
        else
            error "Patch file '$patch_file' missing patch_up function"
            exit 1
        fi
    ); then
        mark_patch_applied "$patch_name"
        success "Successfully applied patch: $patch_name"
        return 0
    else
        error "Failed to apply patch: $patch_name"
        
        # Attempt rollback if patch_down function exists
        if (source "$patch_file" && declare -f patch_down >/dev/null); then
            warning "Attempting to rollback patch: $patch_name"
            if (source "$patch_file" && patch_down); then
                warning "Rollback successful for patch: $patch_name"
            else
                error "Rollback failed for patch: $patch_name"
            fi
        fi
        return 1
    fi
}

# List available patches
list_patches() {
    log "Available patches:"
    if [[ -d "$PATCHES_AVAILABLE_DIR" ]]; then
        for patch in "$PATCHES_AVAILABLE_DIR"/*.sh; do
            if [[ -f "$patch" ]]; then
                local patch_name
                patch_name=$(basename "$patch" .sh)
                if is_patch_applied "$patch_name"; then
                    echo -e "  ${GREEN}✓${NC} $patch_name (applied)"
                else
                    echo -e "  ${YELLOW}○${NC} $patch_name (pending)"
                fi
            fi
        done
    else
        warning "No patches directory found"
    fi
}

# Apply all pending patches
apply_all_patches() {
    log "Applying all pending patches..."
    local failed_patches=0
    
    if [[ ! -d "$PATCHES_AVAILABLE_DIR" ]]; then
        warning "No patches directory found"
        return 0
    fi
    
    # Sort patches by name to ensure consistent order
    for patch_file in $(find "$PATCHES_AVAILABLE_DIR" -name "*.sh" | sort); do
        if ! apply_patch "$patch_file"; then
            ((failed_patches++))
        fi
    done
    
    if [[ $failed_patches -eq 0 ]]; then
        success "All patches applied successfully"
        return 0
    else
        error "$failed_patches patch(es) failed to apply"
        return 1
    fi
}

# Show patch status
show_status() {
    log "Patch Management Status:"
    echo
    
    if [[ -f "$PATCH_STATE_FILE" ]]; then
        local last_update
        last_update=$(jq -r '.last_update // "Never"' "$PATCH_STATE_FILE")
        echo "Last update: $last_update"
        echo
        
        local applied_count
        applied_count=$(jq -r '.applied_patches | length' "$PATCH_STATE_FILE")
        echo "Applied patches: $applied_count"
        
        if [[ $applied_count -gt 0 ]]; then
            echo "Applied patch list:"
            jq -r '.applied_patches[]' "$PATCH_STATE_FILE" | while read -r patch; do
                echo -e "  ${GREEN}✓${NC} $patch"
            done
        fi
    else
        warning "Patch state file not found"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "init")
            init_patch_system
            ;;
        "apply")
            if [[ -n "${2:-}" ]]; then
                apply_patch "$PATCHES_AVAILABLE_DIR/$2.sh"
            else
                apply_all_patches
            fi
            ;;
        "list")
            list_patches
            ;;
        "status")
            show_status
            ;;
        "selfupdate")
            log "Running self-update (applying all pending patches)..."
            apply_all_patches
            ;;
        *)
            echo "XVE Patch Manager"
            echo "Usage: $0 {init|apply [patch_name]|list|status|selfupdate}"
            echo
            echo "Commands:"
            echo "  init        - Initialize patch management system"
            echo "  apply       - Apply all pending patches"
            echo "  apply NAME  - Apply specific patch"
            echo "  list        - List all available patches"
            echo "  status      - Show patch system status"
            echo "  selfupdate  - Apply all pending patches (alias for apply)"
            exit 1
            ;;
    esac
}

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    error "jq is required but not installed. Please install jq first."
    exit 1
fi

main "$@"