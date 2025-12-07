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
export def print-table [data: table, --compact] {
  if $compact {
    $data | table
  } else {
    $data | table --expand
  }
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
  # Use stepwise access for compatibility across Nu versions
  sys
  | get host
  | get hostname
  | str downcase
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
  let hostname = (get-current-host)
  let detected = (
    if ($hostname | str contains "framework") { "framework" }
    else if ($hostname | str contains "desktop") { "desktop" }
    else if ($hostname | str contains "caya") { "caya" }
    else { null }
  )
  
  if ($detected | is-not-empty) {
    return $detected
  }
  
  # Fallback to framework
  return "framework"
}

# Set the default host for this flake
export def set-host [host: string] {
  let config_file = $"($env.FLAKE? | default $"($env.HOME)/.dotfiles/flake")/.flake-host"
  $host | save -f $config_file
  print-success $"Default host set to: ($host)"
  print-info $"Config saved to: ($config_file)"
}
