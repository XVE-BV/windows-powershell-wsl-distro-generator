# XVE Patch Management System

A Laravel-style migration system for managing patches in the XVE WSL distro. This system allows you to apply patches safely with automatic backup and rollback capabilities.

## Overview

The patch management system provides:
- **State tracking**: JSON file tracks which patches have been applied
- **Backup/Rollback**: Automatic backup before applying patches, with rollback on failure
- **Idempotent operations**: Patches won't be re-applied if already successful
- **Ordered execution**: Patches are applied in alphabetical order by filename

## Quick Start

### Running Self-Update

```bash
# Apply all pending patches
selfupdate

# Or use the patch manager directly
patch-manager selfupdate
```

### Checking Patch Status

```bash
# Show current patch status
patch-manager status

# List all available patches
patch-manager list
```

### Applying Specific Patches

```bash
# Apply a specific patch
patch-manager apply 001_example_zsh_config

# Apply all pending patches
patch-manager apply
```

## Creating Patches

Patches are bash scripts that follow a specific structure. They should be placed in `/opt/xve-patches/available/` and follow the naming convention: `NNN_descriptive_name.sh`

### Patch Structure

```bash
#!/bin/bash

# Patch metadata
PATCH_NAME="001_example_patch"
PATCH_DESCRIPTION="Description of what this patch does"

# Apply patch (required)
patch_up() {
    echo "Applying patch: $PATCH_DESCRIPTION"
    
    # Create backup if modifying files
    local backup_path
    backup_path=$(create_backup "/path/to/file" "$PATCH_NAME")
    
    # Apply your changes here
    # ... patch logic ...
    
    # Clean up backup on success (optional)
    if [[ -f "$backup_path" ]]; then
        rm -f "$backup_path"
    fi
    
    return 0
}

# Rollback patch (optional but recommended)
patch_down() {
    echo "Rolling back patch: $PATCH_DESCRIPTION"
    
    # Rollback logic here
    # ... rollback logic ...
    
    return 0
}

# Validation (optional)
patch_validate() {
    # Pre-flight checks
    # Return 0 if patch can be applied, 1 if not
    return 0
}
```

### Patch Naming Convention

- Use 3-digit numbers for ordering: `001_`, `002_`, etc.
- Use descriptive names: `001_update_zsh_config.sh`
- Patches are applied in alphabetical order

### Best Practices

1. **Always create backups** for files you're modifying
2. **Implement rollback logic** in `patch_down()` function
3. **Make patches idempotent** - they should be safe to run multiple times
4. **Use validation** to check prerequisites before applying
5. **Test patches thoroughly** before deployment

## Backup and Rollback System

### Automatic Backups

The system automatically creates backups when you use the `create_backup()` function:

```bash
# In your patch_up() function
local backup_path
backup_path=$(create_backup "/path/to/file" "$PATCH_NAME")
```

### Manual Rollback

If a patch fails, the system will automatically attempt to call the `patch_down()` function if it exists.

### Backup Storage

- Backups are stored in `/opt/xve-patches/backups/`
- Backup files are named: `{patch_name}_{filename}.backup`
- Successful patches automatically clean up their backups

## System Files

### State File
- **Location**: `/opt/xve-patches/applied_patches.json`
- **Format**: JSON with applied patches list and timestamps
- **Example**:
```json
{
  "applied_patches": ["001_example_zsh_config", "002_docker_config"],
  "last_update": "2024-01-15T10:30:00Z",
  "version": "1.0"
}
```

### Directory Structure
```
/opt/xve-patches/
├── applied_patches.json    # State tracking
├── available/              # Available patches
│   ├── 001_example.sh
│   └── 002_another.sh
└── backups/               # Backup files
    ├── 001_example_file.backup
    └── 002_another_config.backup
```

## Commands Reference

### patch-manager

Main patch management script with the following commands:

- `init` - Initialize patch management system
- `apply [patch_name]` - Apply specific patch or all pending patches
- `list` - List all available patches with status
- `status` - Show current patch system status
- `selfupdate` - Apply all pending patches (alias for apply)

### selfupdate

Simple wrapper that calls `patch-manager selfupdate`.

## Example Patches

### Simple Configuration Patch

```bash
#!/bin/bash

PATCH_NAME="001_add_git_aliases"
PATCH_DESCRIPTION="Add useful git aliases to .zshrc"

patch_up() {
    local target_file="/home/xve/.zshrc"
    local backup_path
    backup_path=$(create_backup "$target_file" "$PATCH_NAME")
    
    if ! grep -q "# Git aliases" "$target_file"; then
        cat >> "$target_file" << 'EOF'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
EOF
        echo "Added git aliases to $target_file"
    fi
    
    return 0
}

patch_down() {
    local target_file="/home/xve/.zshrc"
    
    # Remove the git aliases section
    sed -i '/# Git aliases/,+4d' "$target_file"
    echo "Removed git aliases from $target_file"
    
    return 0
}
```

### Package Installation Patch

```bash
#!/bin/bash

PATCH_NAME="002_install_htop"
PATCH_DESCRIPTION="Install htop system monitor"

patch_up() {
    echo "Installing htop..."
    
    if ! command -v htop >/dev/null 2>&1; then
        sudo apk add --no-cache htop
        echo "htop installed successfully"
    else
        echo "htop already installed"
    fi
    
    return 0
}

patch_down() {
    echo "Removing htop..."
    sudo apk del htop
    echo "htop removed"
    return 0
}

patch_validate() {
    # Check if we can install packages
    if ! command -v apk >/dev/null 2>&1; then
        echo "Error: apk package manager not found"
        return 1
    fi
    
    return 0
}
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Make sure scripts are executable and you have proper permissions
2. **jq not found**: Ensure jq is installed (`apk add jq`)
3. **Patch fails**: Check the patch logic and ensure all dependencies are met
4. **Backup restore fails**: Verify backup files exist and have correct permissions

### Debugging

Enable verbose output by adding `set -x` to your patch scripts:

```bash
patch_up() {
    set -x  # Enable debug output
    # ... your patch logic ...
    set +x  # Disable debug output
}
```

### Recovery

If the patch system becomes corrupted:

1. Manually restore files from `/opt/xve-patches/backups/`
2. Reset the state file: `echo '{"applied_patches": [], "last_update": null, "version": "1.0"}' > /opt/xve-patches/applied_patches.json`
3. Re-run `patch-manager init`

## Integration with Build System

The patch system is automatically included in the Docker build process:

1. Patch manager scripts are copied to `/usr/local/bin/`
2. Available patches are copied to `/opt/xve-patches/available/`
3. System is initialized with empty state file
4. Proper permissions are set for the `xve` user

Users can then run `selfupdate` after importing the WSL distro to apply any available patches.