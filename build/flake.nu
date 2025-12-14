#!/usr/bin/env nu
# Overview of flake build scripts

use common.nu *
use theme.nu *

# Reusable fzf selection function
def fzf-select [
  items: list,           # List of records with 'key' and 'desc' fields
  preview_data: list,    # List of records with 'key' and preview content
  header: string,        # Header text for fzf
] {
  # Format items for fzf display with tab separator for column alignment
  # fzf will show this as two columns when using --with-nth
  let fzf_input = ($items | each { |item|
    $"($item.key)\t($item.desc)"
  } | str join "\n")
  
  # Create a simple nushell preview script (like the user's example)
  let uuid_part = (random uuid | str substring 0..8)
  let preview_script = ($env.TMPDIR? | default "/tmp") + $"/flake-preview-($uuid_part).nu"
  
  # Build preview lookup entries
  let preview_entries = ($preview_data | each { |data|
    let escaped = ($data.content | str replace "'" "''")
    $"    \"($data.key)\": \"($escaped)\","
  } | str join "\n")
  
  # Create nushell script that takes input as argument (fzf passes {} as argument)
  # Build script line by line to avoid interpolation issues
  let script_lines = [
    "#!/usr/bin/env nu"
    "def preview [item: string] {"
    "  let key = ($item | split row (char tab) | get 0? | default \"\")"
    "  let previews = {"
    $preview_entries
    "  }"
    "  let preview = (if ($previews | columns | any {|c| $c == $key}) { $previews | get $key } else { \"Preview for: \" + $key })"
    "  print $preview"
    "}"
    ""
    "# Main function to accept command-line argument (fzf passes {} as argument)"
    "def main [item: string = \"\"] {"
    "  preview $item"
    "}"
  ]
  let script_content = ($script_lines | str join "\n")
  
  $script_content | save -f $preview_script
  ^chmod +x $preview_script
  
  # Ensure preview script path is absolute
  let preview_script_abs = ($preview_script | path expand)
  
  # Run fzf - use nushell script for preview, {} is replaced by fzf with the selected line
  let fzf_args = [
    "--height=40%"
    "--layout=reverse"
    "--border"
    $"--header=($header)"
    $"--preview=nu '($preview_script_abs)' {}"
    "--preview-window=right:50%:wrap"
    "--delimiter=\t"
    "--with-nth=1,2"
    "--tabstop=20"
  ]
  let selected = (try {
    $fzf_input | ^fzf ...$fzf_args | str trim
  } catch {
    null
  })
  
  # Clean up
  try { rm $preview_script } catch { }
  
  # Extract and return selected key (first column before tab)
  if ($selected | is-not-empty) {
    ($selected | split row "\t" | get 0 | str trim)
  } else {
    null
  }
}

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
    { key: "build",          script: "build.nu",          usage: "build [host] [build|boot|dry|dev]", desc: "Build NixOS config (no switch)", examples: ["flake build", "flake build desktop boot", "flake build framework dev"], subcommands: [{ key: "build", desc: "Test build", args: "" }, { key: "boot", desc: "Build for next boot", args: "" }, { key: "dry", desc: "Dry run", args: "" }, { key: "dev", desc: "Development build with trace", args: "" }] }
    { key: "switch",         script: "switch.nu",         usage: "switch [host] [--fast] [--check]",        desc: "Build & switch NixOS config", examples: ["flake switch", "flake switch --fast", "flake switch desktop --check"], subcommands: null }
    { key: "health",         script: "health.nu",         usage: "health",                                  desc: "System health check", examples: ["flake health"], subcommands: null }
    { key: "gc",             script: "gc.nu",             usage: "gc [keep|days|all] [value]",              desc: "Garbage collect generations (keep N, delete older than days, or deep clean)", examples: ["flake gc keep 5", "flake gc days 7", "flake gc all"], subcommands: [{ key: "keep", desc: "Keep N generations (default: 5)", args: "[N]" }, { key: "days", desc: "Remove older than N days (default: 7)", args: "[N]" }, { key: "all", desc: "Aggressive cleanup", args: "" }] }
    { key: "update",         script: "update.nu",         usage: "update [input]",                          desc: "Update flake inputs", examples: ["flake update", "flake update nixpkgs"], subcommands: null }
    { key: "caches",         script: "update-caches.nu",  usage: "caches [flags]",                          desc: "Update caches (bat, tldr, icons, nix)", examples: ["flake caches --all", "flake caches --bat", "flake caches --all-except-nix"], subcommands: [{ key: "--all", desc: "Update all caches", args: "" }, { key: "--all-except-nix", desc: "Update all caches except nix index", args: "" }, { key: "--bat", desc: "Update bat syntax cache", args: "" }, { key: "--tldr", desc: "Update tldr pages cache", args: "" }, { key: "--icons", desc: "Update icons cache", args: "" }, { key: "--nix", desc: "Update nix index database", args: "" }, { key: "--apps", desc: "Update apps cache", args: "" }, { key: "--launcher", desc: "Update launcher cache", args: "" }, { key: "--wallpapers", desc: "Update wallpapers cache", args: "" }] }
    { key: "check-backups",  script: "check-backups.nu",  usage: "check-backups",                           desc: "Scan ~/.config for *.backup / *.bkp files", examples: ["flake check-backups"], subcommands: null }
    { key: "clean-backups",  script: "clean-backups.nu",  usage: "clean-backups [--dry-run]",               desc: "Remove *.backup / *.bkp files from ~/.config", examples: ["flake clean-backups", "flake clean-backups --dry-run"], subcommands: null }
    { key: "generation",     script: "generation.nu",     usage: "generation [list|switch|delete] <num>",   desc: "List/switch/delete NixOS generations", examples: ["flake generation list", "flake generation switch 5", "flake generation delete 3"], subcommands: [{ key: "list", desc: "List all generations", args: "" }, { key: "switch", desc: "Switch to generation (will prompt for number)", args: "" }, { key: "delete", desc: "Delete generation (will prompt for number)", args: "" }] }
    { key: "init",           script: "init.nu",           usage: "init [host]",                             desc: "Set default host for build scripts", examples: ["flake init", "flake init desktop"], subcommands: null }
    { key: "info",           script: "flake-info.nu",     usage: "info",                                    desc: "Show flake metadata", examples: ["flake info"], subcommands: null }
    { key: "fmt",            script: "fmt.nu",            usage: "fmt",                                     desc: "Format Nix files with nixfmt", examples: ["flake fmt"], subcommands: null }
    { key: "reload-services",script: "reload-services.nu",usage: "reload-services",                         desc: "Reload user services (Wayland, mako)", examples: ["flake reload-services"], subcommands: null }
    { key: "git",            script: "git-update.nu",     usage: "git",                                     desc: "Show git status/diff, commit (prompt), and push", examples: ["flake git"], subcommands: null }
  ]

  if ($cmd | is-empty) {
    # Interactive menu mode with fzf for arrow key navigation
    loop {
      # Prepare preview data for each command
      let preview_data = ($cmds | each { |cmd|
        let examples_text = ($cmd.examples | each { |ex| $"  • ($ex)" } | str join "\n")
        let subcommands_text = if ($cmd.subcommands | is-not-empty) {
          let subcmds = ($cmd.subcommands | each { |sub| $"  • ($sub.key)($sub.args) - ($sub.desc)" } | str join "\n")
          $"
Subcommands:
($subcmds)
"
        } else {
          ""
        }
        {
          key: $cmd.key
          content: $"
Description: ($cmd.desc)

Usage: ($cmd.usage)
($subcommands_text)
Examples:
($examples_text)
"
        }
      })
      
      # Use fzf to select command
      let selected_key = (fzf-select 
        $cmds 
        $preview_data 
        "Flake Commands (arrow keys to navigate, Enter to select, Esc to quit)"
        )
      
      if ($selected_key | is-empty) {
        print-info "Exiting..."
        return
      }
      let selected_cmd = ($cmds | where key == $selected_key | first | default null)
      
      if ($selected_cmd | is-empty) {
        print-error $"Invalid selection: ($selected_key)"
        continue
      }
      
      # If command has subcommands, show subcommand selector
      let subcommand = if ($selected_cmd.subcommands | is-not-empty) {
        # Prepare subcommand preview data
        let subcmd_preview_data = ($selected_cmd.subcommands | each { |sub|
          {
            key: $sub.key
            content: $"
Description: ($sub.desc)
Arguments: ($sub.args)

Example: flake ($selected_cmd.key) ($sub.key)($sub.args)
"
          }
        })
        
        let subcmd_header = "Select subcommand for " + $selected_cmd.key + " (arrow keys to navigate, Enter to select, Esc to cancel)"
        let selected_subcmd_key = (fzf-select 
          $selected_cmd.subcommands 
          $subcmd_preview_data 
          $subcmd_header
          )
        
        if ($selected_subcmd_key | is-empty) {
          continue  # User cancelled, go back to main menu
        }
        
        $selected_subcmd_key
      } else {
        null
      }
      
      # Build command arguments
      let script_path = $"($flake_path)/build/($selected_cmd.script)"
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
      
      # Add subcommand if selected
      let pass_args = if ($subcommand | is-not-empty) {
        ($args | append $forwarded_flags | prepend $subcommand)
      } else {
        ($args | append $forwarded_flags)
      }
      
      # Execute the command
      print ""
      ^nu $script_path ...$pass_args
      print ""
      let continue_loop = (input "Press Enter to continue or 'q' to quit: " | str trim | str downcase)
      if $continue_loop == "q" {
        return
      }
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

