# windows11 Powershell WSL2 Distro Generator

A PowerShell script to **build** and **export** a ready-to-import WSL2 distribution tarball using Docker Desktop on Windows.

## Motivation

While Docker is powerful for containerized development, it can add complexity and overhead. By building a complete WSL2 distro—with all your preferred tools and configurations—once and exporting it as a tarball, you:

- Eliminate container runtime overhead: The distribution runs natively under WSL2, with no additional daemon or networking layers.
- Customize optimally: Install exactly the PHP versions, Composer, Nginx, Node.js, and more, tailored to your workflow.
- Achieve faster startup: No need to manage Docker containers; the distro boots with your Windows session.
- Maintain consistency: Share the pre-built tarball with colleagues to ensure everyone uses the same environment.

> [!TIP]
> For features and more information [you can find out more here](https://github.com/jonasvanderhaegen-xve/windows-powershell-wsl-distro-importer)

## Overview

This repository contains a single script, **build.ps1**, which automates:

1. Building a customized Linux filesystem via Docker containers (with PHP, Composer, Nginx, etc.)
2. Exporting the container’s filesystem into `xve-distro.tar`
3. (Optional) Uploading the tarball to GitHub Releases as an asset

## Prerequisites

* **Docker Desktop** installed with WSL2 integration enabled
* **PowerShell** (run as Administrator)
* **Optional**: `GITHUB_TOKEN` environment variable (for private GitHub repos)

## Usage

### Generate Tarball Only

```powershell
# Run the build script to create the tarball
.\build.ps1
```

This will produce **`xve-distro.tar`** in the repository root.

### Generate and Upload to GitHub

```powershell
# Include -Upload to push the tarball to your GitHub repo
.\build.ps1 -Upload
```

* Requires `GITHUB_TOKEN` with **repo** scope set in your environment.
* Uploads `xve-distro.tar` to the configured GitHub repository’s Releases.

## Parameters

| Parameter | Type     | Description                                                   |
| --------- | -------- | ------------------------------------------------------------- |
| `-Upload` | `switch` | When specified, also uploads the generated tarball to GitHub. |

## Output

* **`xve-distro.tar`**: A portable WSL2 distro archive ready for import with `wsl --import`.

## Troubleshooting

* **Docker errors**: Ensure Docker Desktop is running and the WSL2 backend is enabled.
* **Permission issues**: Run PowerShell as Administrator.
* **Upload failures**: Verify `GITHUB_TOKEN` is correctly set and has the appropriate scopes.

---

# Background

This tool was conceived spontaneously while I was doing groceries. I was asked whether I wanted a Windows laptop before my first workday, and chose Windows because it was more commonly used in our team. After 8 years on macOS, I opted for Windows so I could better troubleshoot colleagues’ software and hardware issues. Knowing I’d inevitably encounter challenges myself, I saw an opportunity to learn, optimize, and build a more pragmatic development environment for the whole team.

After experimenting with multiple AI assistants and numerous iterations, it evolved into a stable, PHP full‑stack developer environment generator. 

In the future, support for additional programming languages and toolchains can be added as needed.
