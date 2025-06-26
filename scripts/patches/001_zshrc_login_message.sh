#!/bin/bash

# ZSH Login Message Patch
# Adds a welcome message to the user's .zshrc file

# Patch metadata
PATCH_NAME="002_zshrc_login_message"
PATCH_DESCRIPTION="Add XVE welcome message to .zshrc"

# Configuration
TARGET_FILE="/home/xve/.zshrc"
PATCH_MARKER="# XVE WSL Login Patch - DO NOT REMOVE THIS LINE"
LOGIN_MESSAGE='echo "Welcome to XVE WSL Environment! 🚀"
echo "Run '\''als'\'' or '\''aliases'\'' to view available aliases"
echo "Detailed Breakdown: https://github.com/jonasvanderhaegen-xve/developer-kit/blob/main/ALIASES.md"'

# Apply patch (up migration)
patch_up() {
    echo "Applying patch: $PATCH_DESCRIPTION"
    
    # Create backup using the patch manager's backup function
    local backup_path
    backup_path=$(create_backup "$TARGET_FILE" "$PATCH_NAME")
    
    # Store backup path for potential rollback
    echo "$backup_path" > "/tmp/${PATCH_NAME}_backup_path"
    
    # Create .zshrc if it doesn't exist
    if [[ ! -f "$TARGET_FILE" ]]; then
        touch "$TARGET_FILE"
        echo "Created new .zshrc file"
    fi
    
    # Check if our patch is already applied (idempotent check)
    if ! grep -q "$PATCH_MARKER" "$TARGET_FILE"; then
        # Add the login message with marker
        cat >> "$TARGET_FILE" << EOF

$PATCH_MARKER
$LOGIN_MESSAGE

EOF
        echo "Added welcome message to $TARGET_FILE"
    else
        echo "Welcome message already exists in $TARGET_FILE"
    fi
    
    # Clean up backup path file on success
    rm -f "/tmp/${PATCH_NAME}_backup_path"
    
    # Remove the backup since patch was successful
    if [[ -f "$backup_path" ]]; then
        rm -f "$backup_path"
        echo "Removed backup file (patch successful)"
    fi
    
    return 0
}

# Rollback patch (down migration)
patch_down() {
    echo "Rolling back patch: $PATCH_DESCRIPTION"
    
    # Try to get backup path
    local backup_path
    if [[ -f "/tmp/${PATCH_NAME}_backup_path" ]]; then
        backup_path=$(cat "/tmp/${PATCH_NAME}_backup_path")
        
        # Restore backup
        if restore_backup "$backup_path" "$TARGET_FILE"; then
            echo "Successfully restored backup"
            rm -f "/tmp/${PATCH_NAME}_backup_path"
            return 0
        else
            echo "Failed to restore backup"
            return 1
        fi
    else
        # Fallback: manually remove the added section
        if [[ -f "$TARGET_FILE" ]] && grep -q "$PATCH_MARKER" "$TARGET_FILE"; then
            # Create a temporary file without our login message section
            local temp_file
            temp_file=$(mktemp)
            
            # Remove everything from the patch marker to the next empty line
            awk -v marker="$PATCH_MARKER" '
                BEGIN { skip = 0 }
                $0 == marker { skip = 1; next }
                skip && /^$/ { skip = 0; next }
                !skip { print }
            ' "$TARGET_FILE" > "$temp_file"
            
            # Replace the original file
            sudo cp "$temp_file" "$TARGET_FILE"
            rm -f "$temp_file"
            
            echo "Manually removed welcome message from $TARGET_FILE"
            return 0
        else
            echo "Nothing to rollback - welcome message not found"
            return 0
        fi
    fi
}

# Patch validation (optional)
patch_validate() {
    # Check if target directory exists
    local target_dir
    target_dir=$(dirname "$TARGET_FILE")
    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Target directory $target_dir does not exist"
        return 1
    fi
    
    # Check if we have write permissions to the directory
    if [[ ! -w "$target_dir" ]]; then
        echo "Error: No write permission for directory $target_dir"
        return 1
    fi
    
    # If file exists, check write permissions
    if [[ -f "$TARGET_FILE" ]] && [[ ! -w "$TARGET_FILE" ]]; then
        echo "Error: No write permission for $TARGET_FILE"
        return 1
    fi
    
    return 0
}