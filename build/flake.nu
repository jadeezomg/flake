#!/usr/bin/env nu
# Overview of flake build scripts

use common.nu *
use theme.nu *

# Dispatcher for flake helper scripts.
def main [cmd?: string, ...args: string] {
  let flake_path = (get-flake-path)
  let cmds = [
    { key: "build",          script: "build.nu",          usage: "flake build [host] [mode]",                   modes: "build | boot | dry | dev",     desc: "Build NixOS config (no switch)" }
    { key: "switch",         script: "switch.nu",         usage: "flake switch [host] [--fast]",                modes: "",                             desc: "Build & switch NixOS config" }
    { key: "health",         script: "health.nu",         usage: "flake health",                                modes: "",                             desc: "System health check" }
    { key: "gc",             script: "gc.nu",             usage: "flake gc <keep|days|all> [value]",            modes: "keep | days | all",            desc: "Garbage collect generations" }
    { key: "update",         script: "update.nu",         usage: "flake update [input]",                        modes: "",                             desc: "Update flake inputs" }
    { key: "caches",         script: "update-caches.nu",  usage: "flake caches [flags]",                        modes: "",                             desc: "Update caches (bat, tldr, icons, nix)" }
    { key: "check-backups",  script: "check-backups.nu",  usage: "flake check-backups",                         modes: "",                             desc: "Scan ~/.config for *.backup / *.bkp files" }
    { key: "clean-backups",  script: "clean-backups.nu",  usage: "flake clean-backups [--dry-run]",             modes: "",                             desc: "Remove *.backup / *.bkp files from ~/.config" }
    { key: "generation",     script: "generation.nu",     usage: "flake generation [list|switch|delete] <num>", modes: "list | switch | delete",       desc: "List/switch/delete NixOS generations" }
    { key: "init",           script: "init.nu",           usage: "flake init [host]",                           modes: "",                             desc: "Set default host for build scripts" }
    { key: "info",           script: "flake-info.nu",     usage: "flake info",                                  modes: "",                             desc: "Show flake metadata" }
    { key: "untracked",      script: "untracked.nu",      usage: "flake untracked",                             modes: "",                             desc: "List untracked files in the repo" }
    { key: "fmt",            script: "fmt.nu",            usage: "flake fmt",                                   modes: "",                             desc: "Format Nix files with nixfmt" }
    { key: "reload-services",script: "reload-services.nu",usage: "flake reload-services",                       modes: "",                             desc: "Reload user services (Wayland, mako)" }
  ]

  if ($cmd | is-empty) {
    print-header "FLAKE COMMANDS"
    let rows = ($cmds | select key modes usage desc | rename command modes usage description)
    let table_txt = ($rows | table --expand | str join (char newline))
    print $table_txt
    return
  }

  let entry = ($cmds | where key == $cmd | first | default null)

  if ($entry | is-empty) {
    print-error $"Unknown command: ($cmd)"
    print-info "Run 'flake' to see available commands."
    exit 1
  }

  let script_path = $"($flake_path)/build/($entry.script)"
  ^nu $script_path ...$args
}

