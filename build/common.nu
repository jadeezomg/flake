# Common utilities for build scripts
# This module provides shared functions used across all build scripts

use theme.nu *

# Get the flake path (defaults to current directory)
export def get-flake-path [] {
  $env.FLAKE? | default $"($env.HOME)/.dotfiles/flake"
}

# Send desktop notification (or pretty console fallback)
export def notify [
  title: string,
  message: string,
  status?: string = "info"
] {
  let icon = (match $status {
    "success" => $theme_icons.success
    "error" => $theme_icons.error
    "pending" => $theme_icons.pending
    _ => $theme_icons.info
  })

  let color = (match $status {
    "success" => $theme_colors.success_bold
    "error" => $theme_colors.error_bold
    "pending" => $theme_colors.pending_bold
    _ => $theme_colors.info_bold
  })

  let pretty_title = $"(ansi $color)($icon) ($title)(ansi reset)"
  let notify_title = $title 

  let notify_cmd = (which notify-send)
  if ($notify_cmd | is-not-empty) {
    ^notify-send --app-name="flake-build" $notify_title $message
  } else {
    print $"($pretty_title): ($message)"
  }
}

# Print colored output
export def print-success [msg: string] {
  print $"($theme_icons.success) ($msg)"
}

export def print-pending [msg: string] {
  print $"($theme_icons.pending) ($msg)"
}

export def print-error [msg: string] {
  print $"($theme_icons.error) ($msg)"
}

export def print-info [msg: string] {
  print $"($theme_icons.info) ($msg)"
}

# Print a single-line header with short tapered bars around the title
export def print-header [
  title: string,
  icon?: string = "▲",
  bar_len?: any = null
] {
  let cols = (try { term size | get columns } catch { 100 })

  # Compute bar lengths with a left-aligned layout
  let core_len = (($icon | str length) + ($title | str length) + 4)  # spaces + icon
  let left_target = 12
  let min_left = 4

  let space = (if ($cols - $core_len) < 0 { 0 } else { $cols - $core_len })
  let desired_left = (if ($bar_len | is-empty) { $left_target } else { $bar_len })
  let left_len = (
    if $space == 0 { 0 }
    else {
      let want = (if $desired_left < $min_left { $min_left } else { $desired_left })
      if $want > $space { $space } else { $want }
    }
  )
  let right_len = (if $space < $left_len { 0 } else { $space - $left_len })

  # Build tapered bars (progressive: spaced middle dots -> dots -> light -> solid)
  let make_bar = {|bar_len is_left|
    0..<$bar_len
    | each { |i|
        let dist = if $is_left { $bar_len - 1 - $i } else { $i }
        if $dist >= 10 {
          if ($dist mod 2) == 0 { "·" } else { " " }                  # spaced middle dots
        } else if $dist >= 6 {
          "·"                                                         # tight middle dots
        } else if $dist >= 3 {
          "╼"                                                         # light taper
        } else {
          "━"                                                         # solid near the title
        }
      }
    | str join ""
  }

  let left_bar = (do $make_bar $left_len true)
  let right_bar = (do $make_bar $right_len false)

  let line = $"($left_bar) ($icon) ($title) ($right_bar)"
  let line_len = ($line | str length)
  let pad_total = (if $cols > $line_len { $cols - $line_len } else { 0 })
  let pad_left = ($pad_total // 2)
  let pad_right = ($pad_total - $pad_left)
  let left_pad = (" " | fill --width $pad_left --character " ")
  let right_pad = (" " | fill --width $pad_right --character " ")

  print $"(ansi ($theme_colors.header))($left_pad)($line)($right_pad)(ansi reset)"
}

# Print a table with structured data using nushell's table command
export def print-table [data: table, --compact, --no-index (-i)] {
  let formatted = (if $compact {
    if $no_index {
      $data | table -i false | to text
    } else {
      $data | table | to text
    }
  } else {
    if $no_index {
      $data | table --expand -i false | to text
    } else {
      $data | table --expand | to text
    }
  })
  print $formatted
}

# Print a grid layout for key-value pairs
export def print-grid [data: table] {
  $data | grid
}

# Spinner frames for animation (10 frames)
export def get-spinner-frames [] {
  ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"]
}

# Show a progress indicator with animated spinner
# frame: optional frame number (0-9) to show specific spinner character
export def show-progress [message: string, --frame: int = 0] {
  let frames = (get-spinner-frames)
  let frame_count = ($frames | length)
  let frame_index = (($frame mod $frame_count) | into int)
  let spinner_char = ($frames | get $frame_index)
  
  # Show progress message (use print -n to avoid newline, \r to overwrite)
  print -n $"\r(ansi yellow)($spinner_char) (ansi reset)($message)...     "
}

# Show progress as done and clear the line
export def show-progress-done [message: string] {
  # Clear the entire line with spaces, then show done message
  print -n $"\r(ansi green)✓ (ansi reset)($message)                                                      "
  print ""  # Move to next line
}

# Clear progress line completely (fills with spaces then returns to start)
export def clear-progress [] {
  # Fill line with spaces to clear any remaining text, then return to start
  print -n "\r                                                      \r"
}

# Run an external command with a status line and duration
export def run-external-with-status [message: string, command: string] {
  let start = (date now)
  # print in-place (no newline) so we can overwrite
  print -n $"(ansi ($theme_colors.pending_bold))… ($message)(ansi reset)"

  let result = (^bash -c $command | complete)

  # Clear the working line (overwrite with spaces, then return)
  clear-progress

  let duration_ms = ((date now) - $start) | into duration | into int | ($in / 1_000_000)
  let duration_display = (if $duration_ms < 1000 {
    $"($duration_ms)ms"
  } else {
    let secs = ($duration_ms / 1000.0)
    let secs_rounded = ($secs | math round --precision 2)
    $"($secs_rounded)s"
  })

  let success = ($result.exit_code == 0) or (($result.stdout | default "" | str length) > 0)

  let status_text = (if $success {
    $"(ansi ($theme_colors.success_bold))✓(ansi reset) ($message) took ($duration_display)"
  } else {
    $"(ansi ($theme_colors.error_bold))✗(ansi reset) ($message) failed after ($duration_display)"
  })

  print $status_text

  $result.stdout | default ""
}


# Print a key-value pair as a formatted row with proper ansi codes
export def print-kv [key: string, value: string, status?: string] {
  let status_icon = (match $status {
    "success" => $theme_icons.success
    "error" => $theme_icons.error
    "pending" => $theme_icons.pending
    _ => $theme_icons.info
  })
  
  let key_color = (match $status {
    "success" => $theme_colors.success_bold
    "error" => $theme_colors.error_bold
    "pending" => $theme_colors.pending_bold
    _ => $theme_colors.info_bold
  })
  
  print $"  ($status_icon) (ansi $key_color)($key):(ansi reset) ($value)"
}

# Check if command exists
export def command-exists [cmd: string] {
  let result = (which $cmd)
  ($result | is-not-empty)
}

# Get current hostname (for determining which host we're on)
export def get-current-host [] {
  # Use external hostname command (most reliable across systems and nushell versions)
  try {
    (^hostname | str trim | str downcase)
  } catch {
    # Fallback to environment variable
    if ($env.HOSTNAME? | is-not-empty) {
      ($env.HOSTNAME | str downcase)
    } else {
      "unknown"
    }
  }
}

# Detect host from hostname (returns null if not detected)
export def detect-host-from-hostname [] {
  let hostname = (get-current-host)
  if ($hostname | str contains "framework") {
    "framework"
  } else if ($hostname | str contains "desktop") {
    "desktop"
  } else if ($hostname | str contains "caya") {
    "caya"
  } else {
    null
  }
}

# Get list of available hosts
export def get-available-hosts [] {
  [
    { host: "framework" }
    { host: "desktop" }
    { host: "caya" }
  ]
}

# Prompt user for confirmation (returns true if confirmed)
export def confirm [message: string] {
  let response = (input $"($message) (y/N): " | str trim | str downcase)
  ($response == "y" or $response == "yes")
}

# Prompt user for a number with optional abort (returns int or null if aborted)
export def prompt-number [message: string] {
  let input = (input $"($message) (or 'abort' to cancel): " | str trim)
  if ($input | is-empty) or (($input | str downcase) == "abort") {
    print-info "Aborted."
    null
  } else {
    try {
      ($input | into int)
    } catch {
      print-info "Aborted."
      null
    }
  }
}

# Get the configured host or detect it automatically
export def get-host [host?: string] {
  let config_file = $"($env.FLAKE? | default $"($env.HOME)/.dotfiles/flake")/.flake-host"
  
  # If host is provided, use it
  if ($host | is-not-empty) {
    return $host
  }
  
  # Try to read from config file
  if ($config_file | path exists) {
    let saved_host = (open $config_file | str trim)
    if ($saved_host | is-not-empty) {
      return $saved_host
    }
  }
  
  # Auto-detect based on hostname
  let detected = (detect-host-from-hostname)
  
  if ($detected | is-not-empty) {
    return $detected
  }

  # If we cannot detect, prompt the user for a host
  let prompted = (input "Host not detected. Enter host (e.g. framework/desktop/...): " | str trim)
  if ($prompted | is-empty) {
    print-error "Host is required; please provide one or run 'flake init <host>'."
    exit 1
  }
  return $prompted
}

# Set the default host for this flake
export def set-host [host: string] {
  let config_file = $"($env.FLAKE? | default $"($env.HOME)/.dotfiles/flake")/.flake-host"
  $host | save -f $config_file
  print-success $"Default host set to: ($host)"
  print-info $"Config saved to: ($config_file)"
}

# Get the host config file path
export def get-host-config-file [] {
  $"($env.FLAKE? | default $"($env.HOME)/.dotfiles/flake")/.flake-host"
}

# Get file size in human-readable format
export def get-file-size [file_path: string] {
  let size_result = (^du -h $file_path | complete)
  if $size_result.exit_code == 0 {
    ($size_result.stdout | str trim | split row " " | get 0)
  } else {
    "unknown"
  }
}

# Get file age in days
export def get-file-age-days [file_path: string] {
  let file_info = (($file_path | path expand) | get metadata)
  let mtime = ($file_info.modified | into int)
  let now = (date now | into int)
  (($now - $mtime) / 86400000000000)
}

# Find backup files in a directory
export def find-backup-files [dir: string] {
  (glob $"($dir)/**/*.backup" | append (glob $"($dir)/**/*.bkp"))
}

# Parse generation number from nix-env output line
export def parse-generation-number [line: string] {
  let trimmed = ($line | str trim)
  if ($trimmed | is-empty) {
    null
  } else {
    try {
      ($trimmed | parse "{gen} *" | get gen | into int)
    } catch {
      null
    }
  }
}

# Build nixos-rebuild command
export def build-nixos-rebuild-cmd [
  flake_path: string,
  host: string,
  action: string = "switch"
] {
  match $action {
    "switch" => $"sudo nixos-rebuild switch --flake '($flake_path)#($host)'"
    "build" => $"cd /tmp && sudo nixos-rebuild build --flake '($flake_path)#($host)'"
    "boot" => $"cd /tmp && sudo nixos-rebuild boot --flake '($flake_path)#($host)'"
    "dry-build" => $"cd /tmp && sudo nixos-rebuild dry-build --flake '($flake_path)#($host)'"
    "dev" => $"cd /tmp && sudo nixos-rebuild switch --flake '($flake_path)#($host)' --show-trace -L"
    _ => $"sudo nixos-rebuild ($action) --flake '($flake_path)#($host)'"
  }
}
