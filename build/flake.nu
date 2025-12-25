#!/usr/bin/env nu
# Overview of flake build scripts

use common.nu *
use theme.nu *

# Helper to add color highlighting to preview text
def highlight-preview-text [text: string] {
  # Highlight section headers
  let text = ($text | str replace "Description:" $"(ansi ($theme_colors.info_bold))Description:(ansi reset)")
  let text = ($text | str replace "Usage:" $"(ansi ($theme_colors.info_bold))Usage:(ansi reset)")
  let text = ($text | str replace "Subcommands:" $"(ansi ($theme_colors.info_bold))Subcommands:(ansi reset)")
  let text = ($text | str replace "Examples:" $"(ansi ($theme_colors.info_bold))Examples:(ansi reset)")
  let text = ($text | str replace "Arguments:" $"(ansi ($theme_colors.info_bold))Arguments:(ansi reset)")
  
  # Highlight command names (flake commands)
  let text = ($text | str replace -a "flake " $"(ansi ($theme_colors.success_bold))flake (ansi reset)")
  
  # Highlight long flags (--flag)
  let text = ($text | str replace -a " --" $"(ansi ($theme_colors.pending_bold)) --(ansi reset)")
  
  # Highlight short flags (-f, -A, etc.) - common flag patterns
  let text = ([a A b e f i l n t w] | reduce -f $text { |flag, acc|
    $acc | str replace -a $" -($flag) " $"(ansi ($theme_colors.pending)) -($flag) (ansi reset)"
  })
  
  # Highlight host names (common ones)
  let text = ($text | str replace -a " desktop " $"(ansi ($theme_colors.info)) desktop (ansi reset)")
  let text = ($text | str replace -a " framework " $"(ansi ($theme_colors.info)) framework (ansi reset)")
  let text = ($text | str replace -a " caya " $"(ansi ($theme_colors.info)) caya (ansi reset)")
  
  $text
}

# Helper to build forwarded flags list from boolean parameters
def build-forwarded-flags [
  fast: bool,
  dry_run: bool,
  dry: bool,
  check: bool,
  all: bool,
  all_except_nix: bool,
  apps: bool,
  launcher: bool,
  wallpapers: bool,
  bat: bool,
  tldr: bool,
  icons: bool,
  nix: bool
] {
  [
    (if $fast { "--fast" } else { null }),
    (if $dry_run { "--dry-run" } else { null }),
    (if $dry { "--dry" } else { null }),
    (if $check { "--check" } else { null }),
    (if $all { "--all" } else { null }),
    (if $all_except_nix { "--all-except-nix" } else { null }),
    (if $apps { "--apps" } else { null }),
    (if $launcher { "--launcher" } else { null }),
    (if $wallpapers { "--wallpapers" } else { null }),
    (if $bat { "--bat" } else { null }),
    (if $tldr { "--tldr" } else { null }),
    (if $icons { "--icons" } else { null }),
    (if $nix { "--nix" } else { null })
  ] | where { |x| $x != null }
}

# Helper to normalize subcommands by stripping -- prefix for scripts that don't expect it
def normalize-subcommands [subcommands: list, script_name: string] {
  let scripts_needing_strip = ["build.nu" "gc.nu" "generation.nu"]

  if $script_name in ["switch.nu", "fmt.nu", "backups.nu"] {
    let filtered = ($subcommands | where { |sub| $sub != "normal" })
    if ($scripts_needing_strip | any { |s| $s == $script_name }) {
      $filtered | each { |sub|
        if ($sub | str starts-with "--") {
          $sub | str substring 2..
        } else {
          $sub
        }
      }
    } else {
      $filtered
    }
  } else {
    if ($scripts_needing_strip | any { |s| $s == $script_name }) {
      $subcommands | each { |sub|
        if ($sub | str starts-with "--") {
          $sub | str substring 2..
        } else {
          $sub
        }
      }
    } else {
      $subcommands
    }
  }
}

def fzf-select [
  items: list,           # List of records with 'key' and 'desc' fields
  preview_data: list,    # List of records with 'key' and preview content
  header: string,        # Header text for fzf
  --subcommands,         # If set, use subcommand color scheme
  --multi                # If set, allow multiple selections
] {
  # Format items for fzf display with tab separator for column alignment
  # fzf will show this as two columns when using --with-nth
  # Add colors to make rows more visually appealing
  let fzf_input = ($items | each { |item|
    # Use different colors for subcommands vs main commands
    let key_color = (if $subcommands {
      # Subcommands: flags get pending color, actions get success color
      if ($item.key | str starts-with "--") {
        $theme_colors.pending_bold
      } else {
        $theme_colors.success_bold
      }
    } else {
      # Main commands: use info color
      $theme_colors.info_bold
    })
    $"(ansi ($key_color))($item.key)(ansi reset)\t(ansi ($theme_colors.info))($item.desc)(ansi reset)"
  } | str join "\n")
  
  # Create temporary files for preview
  let uuid_part = (random uuid | str substring 0..8)
  let preview_script = ($env.TMPDIR? | default "/tmp") + $"/flake-preview-($uuid_part).nu"
  
  # Create data file with preview information
  let data_file = ($env.TMPDIR? | default "/tmp") + $"/flake-preview-data-($uuid_part).json"
  let preview_data_for_file = ($preview_data | each { |data|
    let safe_key = if ($data.key | str starts-with "--") {
      "flag_" + ($data.key | str substring 2..)
    } else {
      $data.key
    }
    {
      key: $safe_key
      content: $data.content
    }
  })
  $preview_data_for_file | to json | save -f $data_file

  # Create simple nushell script that reads from data file and environment
  let script_lines = [
    "#!/usr/bin/env nu"
    ""
    "# Read preview data from file"
    $"let data_file = '($data_file)'"
    "let preview_data = open $data_file"
    ""
    "# Create lookup dictionary"
    "let previews = ($preview_data | reduce -f {} {|item, acc|"
    "  $acc | merge {$item.key: $item.content}"
    "})"
    ""
    "def preview [item: string] {"
    "  let raw_key = ($item | split row (char tab) | get 0? | default \"\")"
    "  # Strip ANSI codes from key"
    "  let plain_key = ($raw_key | str replace -r '\\u{001b}\\[[0-9;]*m' '' | str trim)"
    "  # Transform key to match dictionary format (avoid -- flag conflicts)"
    "  let lookup_key = if ($plain_key | str starts-with \"--\") {"
    "    \"flag_\" + ($plain_key | str substring 2..)"
    "  } else {"
    "    $plain_key"
    "  }"
    "  # Look up preview in dictionary"
    "  let preview_text = (try {"
    "    $previews | get $lookup_key"
    "  } catch {"
    "    \"Preview for: \" + $plain_key"
    "  })"
    "  print $preview_text"
    "}"
    ""
    "# Main function to read from environment variable"
    "def main [] {"
    "  let item = ($env.FZF_PREVIEW_ITEM? | default '')"
    "  preview $item"
    "}"
  ]
  let script_content = ($script_lines | str join "\n")
  
  $script_content | save -f $preview_script
  
  # Ensure preview script path is absolute
  let preview_script_abs = ($preview_script | path expand)
  
  # Run fzf - use nushell script for preview, pass data via environment variable
  let base_fzf_args = [
    "--height=40%"
    "--layout=reverse"
    "--border"
    "--ansi"
    $"--header=($header)"
    $"--preview=FZF_PREVIEW_ITEM={} nu '($preview_script_abs)'"
    "--preview-window=right:50%:wrap"
    "--delimiter=\t"
    "--with-nth=1,2"
    "--tabstop=20"
  ]
  
  # Add multi-select if requested
  let fzf_args = if $multi {
    ($base_fzf_args | append "--multi")
  } else {
    $base_fzf_args
  }
  
  let selected = (try {
    $fzf_input | ^fzf ...$fzf_args | str trim
  } catch {
    null
  })
  
  # Clean up
  try { rm $preview_script } catch { }
  try { rm $data_file } catch { }
  
  # Extract and return selected key(s) (first column before tab)
  # Strip ANSI codes since fzf output includes colors we added
  def strip-ansi [text: string] {
    $text | str replace -r '\u{001b}\[[0-9;]*m' '' | str trim
  }
  
  if ($selected | is-not-empty) {
    if $multi {
      # Return list of selected keys
      ($selected | lines | each { |line|
        let raw_key = ($line | split row "\t" | get 0)
        strip-ansi $raw_key
      })
    } else {
      # Return single key
      let raw_key = ($selected | split row "\t" | get 0)
      strip-ansi $raw_key
    }
  } else {
    if $multi {
      []
    } else {
      null
    }
  }
}

# Dispatcher for flake helper scripts.
def main [
  cmd?: string,
  --fast (-f),
  --dry-run,
  --dry,
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
    # Build commands
    {
      key: "build"
      script: "build.nu"
      usage: "build [host] [--build|--boot|--dry|--dev]"
      desc: "Build NixOS config (no switch)"
      examples: [
        "flake build"
        "flake build desktop --boot"
        "flake build framework --dev"
      ]
      subcommands: [
        { key: "--build", desc: "Test build", args: "" }
        { key: "--boot", desc: "Build for next boot", args: "" }
        { key: "--dry", desc: "Dry run", args: "" }
        { key: "--dev", desc: "Development build with trace", args: "" }
      ]
    }
    {
      key: "switch"
      script: "switch.nu"
      usage: "switch [host] [--fast] [--check] [--skip-git]"
      desc: "Build & switch NixOS config"
      examples: [
        "flake switch"
        "flake switch --fast"
        "flake switch desktop --check"
      ]
      subcommands: [
        { key: "normal", desc: "Run normal switch (full rebuild with checks)", args: "" }
        { key: "--fast", desc: "Skip git update and pre/post checks", args: "" }
        { key: "--check", desc: "Run flake check only, skip rebuild", args: "" }
        { key: "--skip-git", desc: "Skip git update step", args: "" }
      ]
    }
    {
      key: "health"
      script: "health.nu"
      usage: "health"
      desc: "System health check"
      examples: ["flake health"]
      subcommands: null
    }
    {
      key: "gc"
      script: "gc.nu"
      usage: "gc [--keep|--days|--all] [value]"
      desc: "Garbage collect generations"
      examples: [
        "flake gc --keep 5"
        "flake gc --days 7"
        "flake gc --all"
      ]
      subcommands: [
        { key: "--keep", desc: "Keep N generations (default: 5)", args: "[N]" }
        { key: "--days", desc: "Remove older than N days (default: 7)", args: "[N]" }
        { key: "--all", desc: "Aggressive cleanup", args: "" }
      ]
    }
    {
      key: "generation"
      script: "generation.nu"
      usage: "generation [--list|--switch|--delete] <num>"
      desc: "List/switch/delete NixOS generations"
      examples: [
        "flake generation --list"
        "flake generation --switch 5"
        "flake generation --delete 3"
      ]
      subcommands: [
        { key: "--list", desc: "List all generations", args: "" }
        { key: "--switch", desc: "Switch to generation (will prompt for number)", args: "" }
        { key: "--delete", desc: "Delete generation (will prompt for number)", args: "" }
      ]
    }

    # Update commands
    {
      key: "update"
      script: "update.nu"
      usage: "update [input]"
      desc: "Update flake inputs"
      examples: [
        "flake update"
        "flake update nixpkgs"
      ]
      subcommands: null
    }
    {
      key: "git"
      script: "git-update.nu"
      usage: "git"
      desc: "Show git status/diff, commit (prompt), and push"
      examples: ["flake git"]
      subcommands: null
    }
    {
      key: "check-packages"
      script: "check-packages.nu"
      usage: "check-packages"
      desc: "Check package availability across platforms"
      examples: ["flake check-packages"]
      subcommands: null
    }
    {
      key: "caches"
      script: "update-caches.nu"
      usage: "caches [flags]"
      desc: "Update caches (bat, tldr, icons, nix)"
      examples: [
        "flake caches --all"
        "flake caches --bat"
        "flake caches --all-except-nix"
      ]
      subcommands: [
        { key: "--all", desc: "Update all caches", args: "" }
        { key: "--all-except-nix", desc: "Update all caches except nix index", args: "" }
        { key: "--bat", desc: "Update bat syntax cache", args: "" }
        { key: "--tldr", desc: "Update tldr pages cache", args: "" }
        { key: "--icons", desc: "Update icons cache", args: "" }
        { key: "--nix", desc: "Update nix index database", args: "" }
        { key: "--apps", desc: "Update apps cache", args: "" }
        { key: "--launcher", desc: "Update launcher cache", args: "" }
        { key: "--wallpapers", desc: "Update wallpapers cache", args: "" }
      ]
    }
    {
      key: "backups"
      script: "backups.nu"
      usage: "backups [--clean] [--dry]"
      desc: "Check and optionally clean *.backup / *.bkp files from ~/.config"
      examples: [
        "flake backups"
        "flake backups --clean"
        "flake backups --clean --dry"
      ]
      subcommands: [
        { key: "normal", desc: "Check for backup files (no cleaning)", args: "" }
        { key: "--clean", desc: "Remove backup files", args: "" }
        { key: "--dry", desc: "Preview what would be removed", args: "" }
      ]
    }


    {
      key: "info"
      script: "flake-info.nu"
      usage: "info"
      desc: "Show flake metadata"
      examples: ["flake info"]
      subcommands: null
    }
    {
      key: "fmt"
      script: "fmt.nu"
      usage: "fmt [--no-tree]"
      desc: "Format Nix files with nixfmt"
      examples: [
        "flake fmt"
        "flake fmt --no-tree"
      ]
      subcommands: [
        { key: "normal", desc: "Format files with tree output", args: "" }
        { key: "--no-tree", desc: "Hide tree output of formatted files", args: "" }
      ]
    }
    {
      key: "init"
      script: "init.nu"
      usage: "init [host]"
      desc: "Set default host for build scripts"
      examples: [
        "flake init"
        "flake init desktop"
      ]
      subcommands: null
    }
    {
      key: "reload-services"
      script: "reload-services.nu"
      usage: "reload-services"
      desc: "Reload user services (Wayland, mako)"
      examples: ["flake reload-services"]
      subcommands: null
    }

  ]

  if ($cmd | is-empty) {
    # Interactive menu mode with fzf for arrow key navigation
    loop {
      # Prepare preview data for each command
      let preview_data = ($cmds | each { |cmd|
        let examples_text = ($cmd.examples | each { |ex| $"  ($theme_icons.info) ($ex)" } | str join "\n")
        let subcommands_text = if ($cmd.subcommands | is-not-empty) {
          let subcmds = ($cmd.subcommands | each { |sub|
            # Color code subcommands: flags get pending color, actions get success color
            let sub_key_color = (if ($sub.key | str starts-with "--") {
              $theme_colors.pending_bold
            } else {
              $theme_colors.success_bold
            })
            $"  ($theme_icons.info) (ansi ($sub_key_color))($sub.key)(ansi reset)($sub.args) - ($sub.desc)"
          } | str join "\n")
          $"
Subcommands:
($subcmds)
"
        } else {
          ""
        }
        {
          key: $cmd.key
          content: (highlight-preview-text $"
Description: ($cmd.desc)

Usage: ($cmd.usage)
($subcommands_text)
Examples:
($examples_text)
")
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
          let arguments_section = (if ($sub.args | is-not-empty) {
            $"\nArguments: ($sub.args)"
          } else {
            ""
          })
          {
            key: $sub.key
            content: (highlight-preview-text $"
Description: ($sub.desc)($arguments_section)

Example: flake ($selected_cmd.key) ($sub.key)($sub.args)
")
          }
        })
        
        let subcmd_header = "Select subcommand(s) for " + $selected_cmd.key + " (Tab to select multiple, Enter to confirm, Esc to cancel)"
        let selected_subcmd_keys = (fzf-select 
          $selected_cmd.subcommands 
          $subcmd_preview_data 
          $subcmd_header
          --subcommands
          --multi
          )
        
        if ($selected_subcmd_keys | is-empty) {
          continue  # User cancelled, go back to main menu
        }
        
        # Return list of selected subcommands (can be single item or multiple)
        $selected_subcmd_keys
      } else {
        null
      }
      
      # Build command arguments
      let script_path = $"($flake_path)/build/($selected_cmd.script)"
      let forwarded_flags = (build-forwarded-flags $fast $dry_run $dry $check $all $all_except_nix $apps $launcher $wallpapers $bat $tldr $icons $nix)
      
      # Add subcommand(s) if selected
      let normalized_subcommands = if ($subcommand | is-not-empty) {
        # Handle both single subcommand (string) and multiple (list)
        let subcommands_list = (if ($subcommand | describe) == "string" {
          [$subcommand]
        } else {
          $subcommand
        })
        normalize-subcommands $subcommands_list $selected_cmd.script
      } else {
        []
      }
      
      let pass_args = if ($normalized_subcommands | is-not-empty) {
        ($normalized_subcommands | append $args | append $forwarded_flags)
      } else {
        ($args | append $forwarded_flags)
      }
      
      # Execute the command
      print ""
      let script_dir = ($script_path | path dirname)
      cd $script_dir
      ^nu ($script_path | path basename) ...$pass_args
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
  let forwarded_flags = (build-forwarded-flags $fast $dry_run $dry $check $all $all_except_nix $apps $launcher $wallpapers $bat $tldr $icons $nix)

  # Normalize subcommands: strip -- prefix for scripts that don't expect it
  # This allows both --keep and keep to work for backward compatibility
  let normalized_args = if ($args | length) > 0 {
    let first_arg = ($args | get 0)
    if ($first_arg | str starts-with "--") {
      let stripped_list = (normalize-subcommands [$first_arg] $entry.script)
      $args | update 0 ($stripped_list | get 0)
    } else {
      $args
    }
  } else {
    $args
  }

  let pass_args = ($normalized_args | append $forwarded_flags)
  ^nu $script_path ...$pass_args
}

