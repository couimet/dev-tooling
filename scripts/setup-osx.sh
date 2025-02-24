#!/bin/zsh

# This script is used to install the necessary tools on a Mac machine to get a development environment up and running.
# It focuses on tools that are useful for working with Node.js and APIs.

# Add color/format constants at the top of the script
BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
RESET='\033[0m'

# Function to print formatted tool check message
print_check_message() {
    local tool_name=$1
    echo "Checking if ${BOLD}${BLUE}${tool_name}${RESET} is installed..."
}

# Utility function to check if a command exists
# Uses `command -v` instead of `-x` test because:
# 1. It works for both binary executables and shell functions
# 2. Shell functions like 'nvm' are sourced into the shell environment and aren't files
# 3. It's POSIX compliant and more portable
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "Installing ${BOLD}${cmd}${RESET}..."
        return 1
    else
        local version=""
        # Try different version flag patterns
        if $cmd --version &> /dev/null; then
            version=$($cmd --version | head -n 1)
        elif $cmd -v &> /dev/null; then
            version=$($cmd -v | head -n 1)
        elif $cmd -V &> /dev/null; then
            version=$($cmd -V | head -n 1)
        fi
        
        if [ -n "$version" ]; then
            echo "Yep, ${BOLD}${BLUE}${cmd}${RESET} is installed"
            echo "  → version: ${GREEN}${version}${RESET}"
        else
            echo "Yep, ${BOLD}${BLUE}${cmd}${RESET} is installed"
            echo "  → version: unknown"
        fi
        echo
        return 0
    fi
}

# Utility function to check if a macOS application is installed
check_app() {
    local app_name=$1
    local app_path="/Applications/${app_name}.app"
    local display_name=${2:-$app_name}  # Use second parameter as display name, fallback to app_name

    if [ ! -d "$app_path" ]; then
        echo "Installing ${BOLD}${display_name}${RESET}..."
        return 1
    else
        echo "Yep, ${BOLD}${BLUE}${display_name}${RESET} is installed"
        # Try to get version from Info.plist if it exists
        if [ -f "${app_path}/Contents/Info.plist" ]; then
            version=$(defaults read "${app_path}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
            echo "  → version: ${GREEN}${version:-unknown}${RESET}"
        else
            echo "  → version: unknown"
        fi
        echo
        return 0
    fi
}

# Function to determine if running on Apple Silicon
is_arm64() {
    [[ $(uname -m) == 'arm64' ]]
}

# Function to show manual download instructions
show_manual_download_instructions() {
    local app_name=$1
    local download_url=$2
    echo "${BOLD}${BLUE}Note:${RESET} Please download and install ${app_name} manually from:"
    echo "${GREEN}${download_url}${RESET}"
    echo "This is required to get the native ARM64 version for your Apple Silicon Mac."
    echo "Press Enter once you have completed the installation to continue..."
    read
}

# Function to prompt user for IDE selection
select_ides() {
    echo "${BOLD}${BLUE}IDE Selection${RESET}"
    echo "Which IDE(s) would you like to install?"
    echo "1) VS Code"
    echo "2) Cursor"
    echo "3) Both"
    echo "4) Skip IDE installation"
    echo -n "Enter your choice (1-4): "
    
    read ide_choice
    
    case $ide_choice in
        1) install_vscode=true; install_cursor=false ;;
        2) install_vscode=false; install_cursor=true ;;
        3) install_vscode=true; install_cursor=true ;;
        4) install_vscode=false; install_cursor=false ;;
        *) echo "Invalid choice. Installing VS Code by default."; install_vscode=true; install_cursor=false ;;
    esac
}

# Function to prompt user for password manager selection
select_password_managers() {
    echo "${BOLD}${BLUE}Password Manager Selection${RESET}"
    echo "Which password manager(s) would you like to install?"
    echo "1) MacPass"
    echo "2) 1Password"
    echo "3) Both"
    echo "4) Skip password manager installation"
    echo -n "Enter your choice (1-4): "
    
    read pm_choice
    
    case $pm_choice in
        1) install_macpass=true; install_1password=false ;;
        2) install_macpass=false; install_1password=true ;;
        3) install_macpass=true; install_1password=true ;;
        4) install_macpass=false; install_1password=false ;;
        *) echo "Invalid choice. Installing MacPass by default."; install_macpass=true; install_1password=false ;;
    esac
}

# Homebrew
print_check_message "Homebrew"
if ! check_command brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Git
print_check_message "Git"
if ! check_command git; then
    brew install git
else
    # Check if it's the system git
    if [[ $(which git) == "/usr/bin/git" ]]; then
        echo "System Git detected, installing latest version..."
        brew install git
    fi
fi

# Check Git Configuration
print_check_message "Git Configuration"
if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
    echo "${BOLD}${BLUE}Error:${RESET} Git configuration is incomplete."
    echo "Please configure git with:"
    echo "${GREEN}git config --global user.name \"Your Name\""
    echo "git config --global user.email \"your.email@example.com\"${RESET}"
    exit 1
fi

# GitHub SSH Setup
print_check_message "GitHub SSH Key"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "No SSH key found, creating one..."
    
    # Get git email
    GIT_EMAIL=$(git config --get user.email)
    if [ -z "$GIT_EMAIL" ]; then
        echo "${BOLD}${BLUE}Error:${RESET} Git email is not configured."
        echo "Please run: ${GREEN}git config --global user.email \"your.email@example.com\"${RESET}"
        exit 1
    fi
    
    # Generate SSH key using ed25519 algorithm
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
    
    # Start ssh-agent and add the key
    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519"
    
    # Copy the public key to clipboard
    pbcopy < "$HOME/.ssh/id_ed25519.pub"
    
    echo "${BOLD}${BLUE}Note:${RESET} Your new SSH public key has been copied to clipboard."
    echo "Please add it to GitHub at: ${GREEN}https://github.com/settings/keys${RESET}"
    
    # Test the connection (this will fail initially until the key is added to GitHub)
    echo "After adding the key to GitHub, test your connection with:"
    echo "${GREEN}ssh -T git@github.com${RESET}"
else
    echo "Yep, ${BOLD}${BLUE}SSH key${RESET} exists at ~/.ssh/id_ed25519"
    # Test if the key is added to ssh-agent
    if ! ssh-add -l | grep -q "ED25519"; then
        eval "$(ssh-agent -s)"
        ssh-add "$HOME/.ssh/id_ed25519"
    fi
    echo
fi

# SSH Configuration for GitHub
# There are two approaches to SSH configuration:
# 1. Using Host * (Generic configuration):
#    Pros:
#    - Simpler configuration with fewer lines
#    - Settings apply uniformly across all hosts
#    Cons:
#    - Less explicit about host-specific intentions
#    - Harder to maintain different settings per host
#    - May cause conflicts with future host-specific needs
#
# 2. Using Host github.com (Specific configuration):
#    Pros:
#    - Explicit and self-documenting
#    - Easier to modify GitHub-specific settings
#    - Better isolation from other host configurations
#    - More maintainable for future changes
#    Cons:
#    - Potential duplication if same settings exist in Host *
#    - More verbose configuration
#
# This script uses the specific approach (Host github.com) as it:
# - Makes the GitHub configuration more visible and maintainable
# - Allows for future GitHub-specific customizations
# - Follows the principle of explicit over implicit configuration
if [ ! -f "$HOME/.ssh/config" ] || ! grep -q "github.com" "$HOME/.ssh/config"; then
    echo "Configuring SSH for GitHub..."
    mkdir -p "$HOME/.ssh"
    cat >> "$HOME/.ssh/config" << EOL

Host github.com
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOL
    chmod 600 "$HOME/.ssh/config"
fi

# nvm
print_check_message "nvm"
if [ -d "$HOME/.nvm" ]; then
    # Source nvm if it exists
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    version=$(nvm --version 2>/dev/null)
    echo "Yep, ${BOLD}${BLUE}nvm${RESET} is installed"
    echo "  → version: ${GREEN}${version:-unknown}${RESET}"
    echo
else
    echo "nvm not found, installing..."
    # Get the latest version tag from GitHub API
    LATEST_NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "Installing nvm version ${LATEST_NVM_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    echo "nvm ${LATEST_NVM_VERSION} has been installed"
fi

# The next variable simply focuses on the latest `Major` version of Node.js.
export NODE_VERSION=22

print_check_message "Node.js"
if ! check_command node || [[ $(node --version | grep ${NODE_VERSION}) != *${NODE_VERSION}* ]]; then
    nvm install ${NODE_VERSION}
    nvm use ${NODE_VERSION}
    nvm alias default node
fi

# IDE Selection
select_ides

# VSCode
if [ "$install_vscode" = true ]; then
    print_check_message "VS Code"
    if ! check_app "Visual Studio Code" "VS Code"; then
        brew install --cask visual-studio-code
    fi
fi

# Cursor
if [ "$install_cursor" = true ]; then
    print_check_message "Cursor"
    if ! check_app "Cursor"; then
        if is_arm64; then
            show_manual_download_instructions "Cursor" "https://www.cursor.com/"
        else
            brew install --cask cursor
        fi
    fi
fi

# Docker
print_check_message "Docker"
if ! check_command docker; then
    brew install --cask docker
fi

# docker-compose
print_check_message "docker-compose"
if ! check_command docker-compose; then
    brew install docker-compose
fi

# AWS
print_check_message "AWS CLI"
if ! check_command aws; then
    brew install awscli
fi

# Postman
print_check_message "Postman"
if ! check_app "Postman"; then
    brew install --cask postman
fi

# Rectangle
print_check_message "Rectangle"
if ! check_app "Rectangle"; then
    brew install --cask rectangle
fi

# jq (JSON processor)
print_check_message "jq"
if ! check_command jq; then
    brew install jq
fi

# GitHub CLI
print_check_message "GitHub CLI"
if ! check_command gh; then
    brew install gh
    echo "${BOLD}${BLUE}Note:${RESET} After installation, run '${GREEN}gh auth login${RESET}' to authenticate with GitHub"
    echo "The CLI will request permissions including 'Full control of public keys' which is needed for SSH key management"
    echo "These permissions are safe and only affect your GitHub.com account, not your local system"
fi

# Password Manager Selection
select_password_managers

# MacPass
if [ "$install_macpass" = true ]; then
    print_check_message "MacPass"
    if ! check_app "MacPass"; then
        brew install --cask macpass
    fi
fi

# 1Password
if [ "$install_1password" = true ]; then
    print_check_message "1Password"
    if ! check_app "1Password"; then
        brew install --cask 1password
    fi
fi

echo "Done!"
