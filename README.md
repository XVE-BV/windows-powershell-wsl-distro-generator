<a href="https://github.com/users/jonasvanderhaegen-xve/projects/1">View Project Kanban Board</a>

---

# Windows 11 WSL2 Distro Generator (PowerShell + Docker)

Automate the creation of a fully-configured WSL2 Linux environment using PowerShell and Docker Desktop. Ideal for bootstrapping a consistent, ready-to-use distro across your development team.

## Why This Tool Exists

Managing complex dev stacks in containers adds overhead and variability. This generator lets you:

* **Prebuild once**: Craft a distro image with all your tools and configs baked in.
* **Redistribute easily**: Share a single tarball; no per-project container startup.
* **Stay in Linux**: Enjoy native WSL2 performance rather than layered container filesystems.
* **Onboard rapidly**: New teammates import and land in the exact same environment immediately.

---

## Key Capabilities

* **Custom Base Image**: Start from Alpine Linux, trimmed to essentials.
* **User & Permissions**: Creates a non-root user (`xve`) with passwordless sudo.
* **Working Directory**: `/apps` folder owned by `xve` for project mounts.
* **Shell Environment**: Zsh with preconfigured aliases and functions (e.g. Laravel Sail shortcuts).
* **Utilities Included**: Docker CLI, optional Docker Compose, Git, `tput` (ncurses), and more.
* **Seamless Mounts**: `wsl.conf` sets WSL automount options and default user.

---

## Getting Started

### Prerequisites

* **Docker Desktop** with WSL2 integration enabled.
* **PowerShell** (run as Administrator) on Windows 11.
* **Optional**: `GITHUB_TOKEN` environment variable for GitHub release uploads.

### Build & Export

```powershell
# Clone the repo and navigate into it:
cd path\to\repo

# Build and export the WSL2 distro tarball:
.\build.ps1
```

* Generates `xve-distro.tar` in the project root.

### Upload to GitHub (Optional)

```powershell
.\build.ps1 -Upload
```

* Uploads the tarball to your GitHub Releases as the latest published asset.
* Requires `GITHUB_TOKEN` with `repo` scope.

### Import & Launch

[Check other repository for this](https://github.com/jonasvanderhaegen-xve/windows-powershell-wsl-distro-importer)

You will log in as user `xve` into `/apps`, ready to mount projects and run Docker/Sail commands.

---

## How It Works (Under the Hood)

1. **Docker Buildx Bake**: Uses `compose.yml` to define build stages for your custom Alpine image.
2. **Temporary Container**: Spins up a container and then exports its filesystem.
4. **Persistent Configs**: `wsl.conf` and skeleton dotfiles ensure the user, mounts, and shell are set.

---

## Troubleshooting

* **Permission denied errors**: Run PowerShell as Admin and confirm drive mount `metadata` is active in `wsl.conf`.
* **Upload failures**: Verify your `GITHUB_TOKEN` and repo settings.

---

## Contributing

Feedback, bug reports, and pull requests are welcome. Future enhancements might include additional language runtimes, GUI tool integrations, or preinstalled frameworks.

---

*Generated and maintained by XVE DevOps Team*
