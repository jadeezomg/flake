#!/usr/bin/env nu
# Format Nix files in the flake using Alejandra (parity with rh-fmt.sh)

use common.nu *
use theme.nu *

def main [--no-tree] {
  print-header "FMT"
  let flake_path = (get-flake-path)

  if not (command-exists "alejandra") {
    print-error "alejandra not found. Install alejandra to format Nix files."
    exit 1
  }

  notify "Flake Fmt" "Formatting Nix files..." "pending"

  let files = (glob $"($flake_path)/**/*.nix")
  let count = ($files | length)

  if $count == 0 {
    notify "Flake Fmt" "No .nix files found." "info"
    return
  }

  # Run alejandra per file to avoid argument length issues
  # Track successes, failures, and which files were actually changed
  let results = ($files | each { |f|
    # Get modification time before formatting
    let mtime_before = (try {
      (($f | path expand) | get metadata).modified
    } catch {
      null
    })
    
    # Format the file
    let result = (^alejandra $f | complete)
    
    # Get modification time after formatting
    let mtime_after = (try {
      (($f | path expand) | get metadata).modified
    } catch {
      null
    })
    
    # Check if file was actually changed (mtime changed)
    let was_changed = (
      if ($mtime_before != null) and ($mtime_after != null) {
        ($mtime_before | into int) != ($mtime_after | into int)
      } else {
        false
      }
    )
    
    {
      file: $f
      success: ($result.exit_code == 0)
      changed: $was_changed
      error: (if ($result.stderr | is-not-empty) { $result.stderr | str trim } else { null })
    }
  })
  
  let success_count = ($results | where success == true | length)
  let changed_files = ($results | where { |r| $r.success == true and $r.changed == true })
  let unchanged_files = ($results | where { |r| $r.success == true and $r.changed == false })
  let failed = ($results | where success == false)
  let failed_count = ($failed | length)
  let changed_count = ($changed_files | length)
  let unchanged_count = ($unchanged_files | length)
  
  # Helper to get relative path from flake root
  def get-relative-path [full_path: string] {
    let rel = ($full_path | str replace $flake_path "")
    if ($rel | str starts-with "/") {
      $rel | str substring 1..
    } else {
      $rel
    }
  }
  
  # Helper to get directory from a file path
  def get-directory [file_path: string] {
    let dir = ($file_path | path dirname)
    if $dir == "." {
      ""
    } else {
      $dir
    }
  }
  
  # Helper to get filename from a file path
  def get-filename [file_path: string] {
    $file_path | path basename
  }
  
  # Helper to display files as a tree
  def display-grouped-files [files: table, status_icon: string] {
    # Filter out default.nix files
    let filtered_files = ($files | where { |r|
      let filename = (get-filename (get-relative-path $r.file))
      $filename != "default.nix"
    })
    
    if ($filtered_files | is-empty) {
      return
    }
    
    # Check if tree plugin is available
    let tree_plugin = (which tree)
    
    if ($tree_plugin | is-not-empty) {
      # Use tree plugin if available - convert to table format it expects
      let file_table = ($filtered_files | each { |r|
        {
          name: (get-filename (get-relative-path $r.file))
          path: (get-relative-path $r.file)
        }
      })
      $file_table | tree
    } else {
      # Fallback: simple tree display without mutation
      let rel_paths = ($filtered_files | each { |r| get-relative-path $r.file } | sort)
      
      # Build set of all directories
      let all_dirs = (
        $rel_paths
        | each { |path|
          let parts = ($path | split row "/")
          if ($parts | length) > 1 {
            ($parts | take (($parts | length) - 1) | enumerate | each { |p|
              ($parts | take ($p.index + 1) | str join "/")
            })
          } else {
            []
          }
        }
        | flatten
        | uniq
        | sort
      )
      
      # Print tree
      $rel_paths | enumerate | each { |item|
        let path = $item.item
        let parts = ($path | split row "/")
        let depth = (($parts | length) - 1)
        let prev_path = (if $item.index > 0 { ($rel_paths | get ($item.index - 1)) } else { "" })
        let prev_parts = (if ($prev_path | is-not-empty) { ($prev_path | split row "/") } else { [] })
        
        # Find common prefix
        let common_count = (
          $parts
          | enumerate
          | where { |p|
            ($p.index < ($prev_parts | length)) and ($p.item == ($prev_parts | get $p.index))
          }
          | length
        )
        
        # Print new directories
        if $depth > 0 {
          $parts | enumerate | each { |part|
            if ($part.index < $depth) and ($part.index >= $common_count) {
              let is_last = ($part.index == ($depth - 1))
              let prefix = (if $is_last { "└── " } else { "├── " })
              let indent = ("    " | fill --width ($part.index * 4) --character " ")
              print-info $"($indent)($prefix)($part.item)/"
            }
          }
        }
        
        # Print file
        let filename = ($parts | last)
        let indent = ("    " | fill --width ($depth * 4) --character " ")
        print-info $"($indent)└── ($filename)"
      }
    }
  }
  
  # Print errors for failed files
  if $failed_count > 0 {
    print ""
    print-error "Files that failed to format:"
    $failed | each { |r|
      print-error $"  ($theme_icons.error) (get-relative-path $r.file)"
      if ($r.error != null) {
        let error_lines = ($r.error | lines)
        $error_lines | each { |line| print-error $"    ($line)" }
      }
    }
    print ""
  }
  
  # Show summary grouped by directory (unless --no-tree flag is set)
  if not $no_tree {
    print ""
    if $changed_count > 0 {
      let file_word = (if $changed_count == 1 { "file" } else { "files" })
      print-success $"Formatted ($changed_count) ($file_word):"
      display-grouped-files $changed_files $theme_icons.success
      print ""
    }
    
    if $unchanged_count > 0 {
      let file_word = (if $unchanged_count == 1 { "file" } else { "files" })
      print-info $"($unchanged_count) ($file_word) already formatted - excluded default.nix files:"
      display-grouped-files $unchanged_files $theme_icons.info
      print ""
    }
  }
  
  # Final notification
  if $failed_count == 0 {
    if $changed_count > 0 {
      notify "Flake Fmt" $"Formatted ($changed_count) files, ($unchanged_count) already formatted" "success"
    } else {
      notify "Flake Fmt" $"All ($unchanged_count) files already formatted" "success"
    }
  } else {
    notify "Flake Fmt" $"Formatted ($changed_count) files, ($unchanged_count) unchanged, ($failed_count) failed" "error"
  }
  print-header "END"
}



