#!/usr/bin/env bash
# shellcheck disable=SC2034
# ANSI theme (simplified from theme.nu). Same codes are exported from root Justfile for `just` recipes.
export THEME_GREEN='\033[32m'
export THEME_GREEN_BOLD='\033[1;32m'
export THEME_YELLOW='\033[33m'
export THEME_YELLOW_BOLD='\033[1;33m'
export THEME_RED='\033[31m'
export THEME_RED_BOLD='\033[1;31m'
export THEME_CYAN='\033[36m'
export THEME_CYAN_BOLD='\033[1;36m'
export THEME_RESET='\033[0m'
export ICON_SUCCESS="${THEME_GREEN}▲${THEME_RESET}"
export ICON_PENDING="${THEME_YELLOW}❖${THEME_RESET}"
export ICON_ERROR="${THEME_RED}▼${THEME_RESET}"
export ICON_INFO="${THEME_CYAN}▪${THEME_RESET}"
