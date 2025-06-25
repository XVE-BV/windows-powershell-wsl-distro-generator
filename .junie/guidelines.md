# Project Guidelines - Windows 11 WSL2 Distro Generator

## Project Overview

This project is a **Windows 11 WSL2 Distro Generator** that uses PowerShell and Docker Desktop to automate the creation of fully-configured WSL2 Linux environments. The tool creates custom WSL2 distros based on Alpine Linux with pre-installed development tools, user configurations, and Docker integration.

### Key Purpose
- **Prebuild once**: Create a distro image with all tools and configs baked in
- **Redistribute easily**: Share a single tarball for consistent environments
- **Stay in Linux**: Enjoy native WSL2 performance vs layered containers
- **Onboard rapidly**: New teammates get identical environments immediately

## Project Structure

### Core Files
- **`build.ps1`**: Main PowerShell script that builds and exports the WSL2 distro tarball
- **`Dockerfile`**: Defines the Alpine Linux-based custom image with user setup and tools
- **`compose.yml`**: Simple Docker Compose configuration for building the image
- **`README.md`**: Comprehensive project documentation

### Configuration Files
- **`wsl.conf`**: WSL2 configuration for automount options and default user
- **`conf/`**: Additional WSL configuration files (default.wsl.conf, nginx.wsl.conf)

### Scripts Directory
- **`scripts/entrypoint.sh`**: Container entrypoint script
- **`scripts/auto-setup.sh`**: Automated setup script for the distro
- **`scripts/first-run.sh`**: First-run initialization script
- **`scripts/skel_zshrc`**: Zsh configuration template
- **`scripts/p10k.zsh`**: Powerlevel10k theme configuration
- **`scripts/docker-config.json`**: Docker CLI configuration

### Additional Components
- **`nginx-proxy-manager-compose.yml`**: Nginx Proxy Manager setup for the distro

## Development Guidelines for Junie

### Testing Requirements
- **No automated tests**: This project doesn't have a traditional test suite
- **Manual verification**: Changes should be verified by building the distro
- **Build testing**: Run `.\build.ps1` to ensure the build process works correctly

### Build Process
- **Always test builds**: Before submitting changes, run the build process to ensure it completes successfully
- **Build command**: `.\build.ps1` (requires PowerShell as Administrator and Docker Desktop)
- **Output verification**: Ensure `xve-distro.tar` is generated successfully

### Code Style Guidelines
- **PowerShell**: Follow standard PowerShell conventions with proper error handling
- **Shell Scripts**: Use proper shebang lines and ensure cross-platform compatibility where possible
- **Docker**: Follow Docker best practices for layer optimization and security
- **Configuration Files**: Maintain consistent formatting and proper comments

### Key Technical Details
- **Base Image**: Alpine Linux (latest)
- **Default User**: `xve` (UID: 1000, GID: 1000)
- **Shell**: Zsh with Powerlevel10k theme
- **Working Directory**: `/apps` (owned by xve user)
- **Included Tools**: Docker CLI, Docker Compose, Git, Zsh, sudo, and development utilities

### Prerequisites for Development
- Windows 11 with WSL2 enabled
- Docker Desktop with WSL2 integration
- PowerShell (Administrator privileges required)
- Optional: GITHUB_TOKEN for release uploads

### Important Notes
- This project creates WSL2 distros, not regular containers
- The build process exports filesystem as tarball for WSL2 import
- User permissions and WSL2 integration are critical components
- Docker integration allows running containers from within the WSL2 distro
