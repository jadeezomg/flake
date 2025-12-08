#!/usr/bin/env nu
# Overview of flake build scripts

use common.nu *
use theme.nu *

# Dispatcher for flake helper scripts.
def main [
  cmd?: string,
  --fast (-f),
  --dry-run,
  --check,
  --all (-A),
  --all-except-nix (-e),
  --apps (-a),
  --launcher (-l),
  --wallpapers (-w),
  --bat (-b),
  --tldr (-t),
  --icons (-i),
  --nix (-n),
  ...args: string
] {
  let flake_path = (get-flake-path)
  let cmds = [
    { key: "build",          script: "build.nu",          usage: "build [host] [build|boot|dry|dev]", desc: "Build NixOS config (no switch)" }
    { key: "switch",         script: "switch.nu",         usage: "switch [host] [--fast] [--check]",        desc: "Build & switch NixOS config" }
    { key: "health",         script: "health.nu",         usage: "health",                                  desc: "System health check" }
    { key: "gc",             script: "gc.nu",             usage: "gc [keep|days|all] [value]",              desc: "Garbage collect generations (keep N, delete older than days, or deep clean)" }
    { key: "update",         script: "update.nu",         usage: "update [input]",                          desc: "Update flake inputs" }
    { key: "caches",         script: "update-caches.nu",  usage: "caches [flags]",                          desc: "Update caches (bat, tldr, icons, nix)" }
    { key: "check-backups",  script: "check-backups.nu",  usage: "check-backups",                           desc: "Scan ~/.config for *.backup / *.bkp files" }
    { key: "clean-backups",  script: "clean-backups.nu",  usage: "clean-backups [--dry-run]",               desc: "Remove *.backup / *.bkp files from ~/.config" }
    { key: "generation",     script: "generation.nu",     usage: "generation [list|switch|delete] <num>",   desc: "List/switch/delete NixOS generations" }
    { key: "init",           script: "init.nu",           usage: "init [host]",                             desc: "Set default host for build scripts" }
    { key: "info",           script: "flake-info.nu",     usage: "info",                                    desc: "Show flake metadata" }
    { key: "untracked",      script: "untracked.nu",      usage: "untracked",                               desc: "List untracked files in the repo" }
    { key: "fmt",            script: "fmt.nu",            usage: "fmt",                                     desc: "Format Nix files with nixfmt" }
    { key: "reload-services",script: "reload-services.nu",usage: "reload-services",                         desc: "Reload user services (Wayland, mako)" }
    { key: "git",            script: "git-update.nu",     usage: "git",                                     desc: "Show git status/diff, commit (prompt), and push" }
  ]

  if ($cmd | is-empty) {
    let cols = (try { term size | get columns } catch { 100 })
    let rows = ($cmds | select key usage desc | rename command usage description)

    if $cols < 90 {
      print-header "FLAKE CMDS (compact)"
      $rows | each { |r|
        let usage_raw = ($r.usage | default "")
        let usage_clean = (if $usage_raw == "" { "" } else { $usage_raw | str replace -r "^flake\\s+" "" })
        let usage_txt = (if $usage_clean == "" { "" } else { $" | usage: ($usage_clean)" })
        print $"  (ansi ($theme_colors.info_bold))($r.command)(ansi reset)($usage_txt)"
      }
    } else if $cols < 130 {
      print-header "FLAKE CMDS"
      let table_txt = ($rows | table --width $cols -i false | str join (char newline))
      print $table_txt
    } else {
      print-header "FLAKE COMMANDS"
      let table_txt = ($rows | table --expand --width $cols -i false | str join (char newline))
      print $table_txt
    }
    return
  }

  let entry = ($cmds | where key == $cmd | first | default null)

  if ($entry | is-empty) {
    print-error $"Unknown command: ($cmd)"
    print-info "Run 'flake' to see available commands."
    exit 1
  }

  let script_path = $"($flake_path)/build/($entry.script)"
  let forwarded_flags = (
    []
      | append (if $fast { "--fast" } else { null })
      | append (if $dry_run { "--dry-run" } else { null })
      | append (if $check { "--check" } else { null })
      | append (if $all { "--all" } else { null })
      | append (if $all_except_nix { "--all-except-nix" } else { null })
      | append (if $apps { "--apps" } else { null })
      | append (if $launcher { "--launcher" } else { null })
      | append (if $wallpapers { "--wallpapers" } else { null })
      | append (if $bat { "--bat" } else { null })
      | append (if $tldr { "--tldr" } else { null })
      | append (if $icons { "--icons" } else { null })
      | append (if $nix { "--nix" } else { null })
      | where { |x| $x != null }
  )

  let pass_args = ($args | append $forwarded_flags)
  ^nu $script_path ...$pass_args
}

