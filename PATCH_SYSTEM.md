# XVE Patch Management System

A Laravel-style migration system for managing patches in the XVE WSL distro. This system allows you to apply patches safely with automatic backup and rollback capabilities, with patches sourced from external GitHub repositories.

## Overview

The patch management system provides:
- **External patch source**: Downloads patches from GitHub repository releases
- **State tracking**: JSON file tracks which patches have been applied
- **Backup/Rollback**: Automatic backup before applying patches, with rollback on failure
- **Idempotent operations**: Patches won't be re-applied if already successful
- **Ordered execution**: Patches are applied in alphabetical order by filename
- **Configurable repositories**: Support for different patch repositories and release tags

## External Patch Repository Setup

The patch system now downloads patches from external GitHub repositories, allowing for centralized patch management and distribution.

### Default Configuration

By default, the system is configured to download patches from:
- **Repository**: `jonasvanderhaegen-xve/xve-wsl-patches`
- **Release**: `latest`

### Setting Up Your Patch Repository

1. **Create a GitHub repository** for your patches (e.g., `your-org/xve-wsl-patches`)

2. **Create a `patches` directory** in the repository root

3. **Add your patch files** to the `patches` directory following the naming convention: `NNN_descriptive_name.sh`

4. **Create a release** in your GitHub repository:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   Then create a release from the tag in the GitHub web interface.

### Repository Structure

Your external patch repository should have this structure:
```
your-patch-repo/
├── README.md
├── patches/
│   ├── 001_example_patch.sh
│   ├── 002_another_patch.sh
│   └── 003_final_patch.sh
└── (other files are ignored)
```

### Configuration Options

You can customize the patch source using environment variables:

```bash
# Use a different repository
export XVE_PATCH_REPO_OWNER="your-organization"
export XVE_PATCH_REPO_NAME="your-patch-repo"

# Use a specific release tag
export XVE_PATCH_RELEASE_TAG="v1.2.0"

# Then run selfupdate
selfupdate
```

### Private Repositories

For private repositories, you'll need to set up authentication. The system uses `curl` to download from GitHub, so you can:

1. **Use a GitHub token** (recommended):
   ```bash
   # Set up GitHub token for private repos
   export GITHUB_TOKEN="your_github_token"

   # Modify the curl command in selfupdate to use authentication
   # This requires manual modification of the selfupdate script
   ```

2. **Use SSH access** by cloning the repository manually and pointing to a local path

## Quick Start

### Running Self-Update

```bash
# Apply all pending patches (downloads from external source)
selfupdate

# Use specific repository and release
XVE_PATCH_REPO_OWNER="myorg" XVE_PATCH_RELEASE_TAG="v2.0.0" selfupdate

# Or use the patch manager directly (works with locally available patches)
patch-manager selfupdate
```

### Configuration Examples

```bash
# Download from latest release of default repository
selfupdate

# Download from specific release
XVE_PATCH_RELEASE_TAG="v1.5.0" selfupdate

# Download from different repository
XVE_PATCH_REPO_OWNER="mycompany" XVE_PATCH_REPO_NAME="custom-patches" selfupdate

# Show help and configuration options
selfupdate --help
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

Patches are bash scripts that follow a specific structure. They should be created in your external GitHub repository's `patches/` directory and follow the naming convention: `NNN_descriptive_name.sh`

### Patch Development Workflow

1. **Create patch in your external repository**:
   - Add the patch file to the `patches/` directory in your GitHub repository
   - Follow the naming convention and structure described below
   - Test the patch locally if possible

2. **Create a new release**:
   - Commit and push your changes to the repository
   - Create a new release tag (e.g., `v1.1.0`)
   - Push the tag and create a GitHub release

3. **Deploy to WSL environments**:
   - Users run `selfupdate` to download and apply the new patches
   - Or specify the specific release: `XVE_PATCH_RELEASE_TAG="v1.1.0" selfupdate`

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
2. System directories are created (`/opt/xve-patches/available/`, `/opt/xve-patches/backups/`)
3. System is initialized with empty state file
4. Proper permissions are set for the `xve` user
5. Required dependencies (`curl`, `jq`, `tar`) are installed

Users can then run `selfupdate` after importing the WSL distro to:
1. Download patches from the configured external GitHub repository
2. Install them to `/opt/xve-patches/available/`
3. Apply any new patches automatically

### Build System Changes

With the external patch system, the Docker build no longer needs to include patch files directly. Instead:

- The `selfupdate` script handles downloading patches at runtime
- Patches are fetched from GitHub releases on-demand
- This allows for patch updates without rebuilding the WSL distro
- Users can configure different patch repositories per environment
