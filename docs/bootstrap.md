# Bootstrap Initialization Script Documentation

## Overview
The `bootstrap-init.sh` script is designed to initialize a development environment with several key components, including Homebrew, yq, Python, Terraform, ZSH with Oh My Zsh and Powerlevel10k, and Docker with docker-compose services.

## Execution Order
The script follows a critical execution order to ensure all dependencies are correctly set up:
1. **Initial Setup**: Installs basic system packages and sets up the user context.
2. **Homebrew Installation**: Installs Homebrew, which is required for subsequent installations.
3. **yq Installation**: Installs yq for YAML processing.
4. **GitHub SSH User Setup**: Configures the GitHub SSH user for further operations.
5. **Function Definitions**: Defines functions for reading YAML and secrets.
6. **Configuration Reading**: Reads all necessary configurations and secrets.
7. **System Setup**: Installs development tools, configures the shell, and sets up Docker.

## User Context Transitions
- The script starts as root and transitions to using `SUDO_USER` for initial setup phases.
- It then transitions to `GITHUB_SSH_USER` for the remaining phases.

## Dependencies
- **Homebrew** must be installed before yq.
- **yq** must be installed before any YAML reading.
- **GITHUB_SSH_USER** must be set before function definitions.
- All configurations must be read before system setup.

## Checkpoint System
The script implements a checkpoint system to track progress and enable recovery from failures. Checkpoints are stored in `~/.bootstrap/checkpoints/` and contain:
- Timestamp of completion
- Status (SUCCESS/FAILED)
- Environment state
- Last successful operation

To resume from a checkpoint, run with `RESUME=1 sudo ./bootstrap-init.sh`. To force a clean run, use `CLEAN=1 sudo ./bootstrap-init.sh`.

## Logging
The script uses enhanced logging with multiple severity levels (INFO, WARN, ERROR, DEBUG) and structured output. Logs are written to a file in a writable directory, with rotation to prevent excessive file size.

## Error Handling
The script includes robust error handling with retry capabilities and detailed logging of command failures. It tracks successful and failed steps for a final execution summary.

## Version Management
- **Python Version**: Read from `.python-version` file, defaults to `3.12` if not found.
- **Terraform Version**: Read from `terraform/.terraform-version` file, defaults to `latest` if not found.

## Phases
### Phase 1: Initial Setup
- Installs essential system packages and Python build dependencies.
- Verifies installation of critical packages.

### Phase 2: Homebrew Installation
- Sets up Homebrew directories and installs Homebrew for the `SUDO_USER`.
- Verifies Homebrew installation and environment setup.

### Phase 3: yq Installation
- Installs yq using Homebrew and verifies its functionality.

### Phase 4: GitHub User Setup
- Reads GitHub configuration and verifies the existence of the `GITHUB_SSH_USER`.

### Phase 5: Function Definitions
- Defines functions for reading YAML and secrets using the `GITHUB_SSH_USER` context.

### Phase 6: Configuration Reading
- Reads all configuration values using the `GITHUB_SSH_USER` context.

### Phase 7: System Setup
- Installs pyenv and sets up Python.
- Installs tfenv and sets up Terraform.
- Configures ZSH and installs Oh My Zsh with Powerlevel10k.
- Installs Docker and Docker Compose, configures Docker, and sets up services.

## Conclusion
The `bootstrap-init.sh` script is a comprehensive tool for setting up a development environment with all necessary components and configurations. It ensures a smooth setup process with robust error handling, logging, and checkpointing to facilitate recovery and debugging. 