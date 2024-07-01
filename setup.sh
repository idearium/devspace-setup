#!/bin/bash

set -u

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]
then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]
then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]
then
  abort 'Bash must not run in POSIX mode. Please unset POSIXLY_CORRECT and try again.'
fi

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]
then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# First check OS.
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]
then
  DEVSPACE_ON_LINUX=1
elif [[ "${OS}" == "Darwin" ]]
then
  DEVSPACE_ON_MACOS=1
else
  abort "DevSpace is only supported on macOS and Linux."
fi

printf "\nCreating ~/Developer.\n"

# Create ~/Developer if it doesn't exist.
if [ ! -e ${HOME}/Developer ]; then
    mkdir ${HOME}/Developer
fi

printf "\nSetting up .gitconfig.\n"

# Setup .gitconfig.
if [ ! -e ${HOME}/.gitconfig ]; then
    touch ${HOME}/.gitconfig
fi

# Setup user.name if we need to.
if [[ ! $(git config --file ${HOME}/.gitconfig user.name) ]]; then

    printf "\nWhat is your name on GitHub?\n"
    read GITHUB_NAME

    git config --file ${HOME}/.gitconfig --add user.name "$GITHUB_NAME"

fi

# Setup user.email if we need to.
if [[ ! $(git config --file ${HOME}/.gitconfig user.email) ]]; then

    printf "\nWhat is your email on GitHub?\n"
    read GITHUB_EMAIL

    git config --file ${HOME}/.gitconfig --add user.email "$GITHUB_EMAIL"

fi

printf "\nInstalling gh.\n"

if [[ -n "${DEVSPACE_ON_LINUX-}" ]]
then
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
fi

if [[ -n "${DEVSPACE_ON_MACOS-}" ]]
then
    brew install gh
fi

printf "\ngit config and gh are setup.\n\n"
