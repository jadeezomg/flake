#!/usr/bin/env nu

# Script to check package availability across platforms
# Usage: ./check-packages.nu

use common.nu *
use theme.nu *

def main [] {
    print-header "PACKAGE CHECK"

    notify "Package Check" "Starting package availability check..." "pending"

    let package_categories = extract_packages_from_nix_files

    # Display package categories summary
    print-pending "Package Categories:"
    $package_categories.categories | each { |category|
        let pkg_count = ($category.packages | length)
        print $"  ($theme_icons.info) ($category.name): ($pkg_count) packages"
    }
    print ""

    # Check availability based on category requirements
    let results = check_package_availability $package_categories

    # Compile and display results
    compile_results $results $package_categories

    notify "Package Check" $"Package check complete! Found ($package_categories.total_unique) unique packages across ($package_categories.categories | length) categories" "success"

    print-header "END"
}

def extract_packages_from_nix_files [] {
    print "Scanning Nix files for packages..."


    # Get the flake root directory (parent of build directory)
    let flake_root = ($env.FILE_PWD? | default (pwd)) | path dirname

    # Define directories to search (relative to flake root)
    let home_dirs = [
        ($flake_root | path join "home/shared")
        ($flake_root | path join "home/nixos")
        ($flake_root | path join "home/darwin")
    ]

    let module_dirs = [
        ($flake_root | path join "modules/shared")
        ($flake_root | path join "modules/nixos")
        ($flake_root | path join "modules/darwin")
    ]

    # Extract packages from home configurations
    mut home_packages = []
    for dir in $home_dirs {
        let packages = (extract_packages_from_directory $dir "home")
        $home_packages = ($home_packages | append $packages)
    }
    let home_packages = ($home_packages | flatten)

    # Extract packages from system modules
    mut system_packages = []
    for dir in $module_dirs {
        let packages = (extract_packages_from_directory $dir "system")
        $system_packages = ($system_packages | append $packages)
    }
    let system_packages = ($system_packages | flatten)

    # Combine and categorize
    let all_categories = [
        {
            name: "Home Packages (Shared)"
            packages: ($home_packages | where {|p| $p.category == "shared"} | get packages | flatten | uniq)
            platforms: ["x86_64-linux" "aarch64-darwin"]
        }
        {
            name: "Home Packages (NixOS)"
            packages: ($home_packages | where {|p| $p.category == "nixos"} | get packages | flatten | uniq)
            platforms: ["x86_64-linux"]
        }
        {
            name: "Home Packages (Darwin)"
            packages: ($home_packages | where {|p| $p.category == "darwin"} | get packages | flatten | uniq)
            platforms: ["aarch64-darwin"]
        }
        {
            name: "System Packages (Shared)"
            packages: ($system_packages | where {|p| $p.category == "shared"} | get packages | flatten | uniq)
            platforms: ["x86_64-linux" "aarch64-darwin"]
        }
        {
            name: "System Packages (NixOS)"
            packages: ($system_packages | where {|p| $p.category == "nixos"} | get packages | flatten | uniq)
            platforms: ["x86_64-linux"]
        }
        {
            name: "System Packages (Darwin)"
            packages: ($system_packages | where {|p| $p.category == "darwin"} | get packages | flatten | uniq)
            platforms: ["aarch64-darwin"]
        }
    ]

    let total_unique = ($all_categories | get packages | flatten | uniq | length)

    {categories: $all_categories, total_unique: $total_unique}
}



def check_package_availability [package_categories] {
    let category_results = $package_categories.categories | each { |category|
        print-info $"Checking category: ($category.name)"

        let platform_results = $category.platforms | each { |platform|
            let check_cmd = $"nix eval --system ($platform) --json github:NixOS/nixpkgs#legacyPackages.($platform).hello"
            let check_cmd_pretty = $"(ansi ($theme_colors.info_bold))nix eval --system ($platform)(ansi reset) (ansi white)--json github:NixOS/nixpkgs#legacyPackages.($platform).hello(ansi reset)"
            print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) Checking ($category.packages | length) packages on ($platform)"

            # Check if nixpkgs is available for this platform
            let nixpkgs_available = try {
                run-external "nix" "flake" "metadata" $"github:NixOS/nixpkgs" $"--system" $platform
                    | complete
            } catch { |err|
                print-error $"  nixpkgs not available for ($platform)"
                {platform: $platform, available: [], unavailable: $category.packages}
            }

            if $nixpkgs_available.exit_code != 0 {
                print-error $"  nixpkgs not available for ($platform)"
                notify "Package Check" $"Error: nixpkgs not available for ($platform)" "error"
                {platform: $platform, available: [], unavailable: $category.packages}
            } else {
                # For each package, try to evaluate it
                let results = $category.packages | par-each { |pkg|
                    let eval_result = try {
                        run-external "nix" "eval" $"--system" $platform "--json" $"github:NixOS/nixpkgs#($pkg)"
                            | complete
                    } catch { |err|
                        {package: $pkg, available: false, error: $err.msg}
                    }

                    if $eval_result.exit_code == 0 {
                        {package: $pkg, available: true}
                    } else {
                        {package: $pkg, available: false, error: $eval_result.stderr}
                    }
                }

                let available = $results | where {|r| $r.available} | get package
                let unavailable = $results | where {|r| not $r.available} | get package

                let avail_count = ($available | length)
                let unavail_count = ($unavailable | length)

                if $unavail_count == 0 {
                    print-success $"  Available: ($avail_count), Unavailable: ($unavail_count)"
                } else {
                    print-pending $"  Available: ($avail_count), Unavailable: ($unavail_count)"
                }

                {platform: $platform, available: $available, unavailable: $unavailable}
            }
        }

        {
            category: $category.name
            platforms: $platform_results
            packages: $category.packages
        }
    }

    $category_results
}

def compile_results [results: list, package_categories] {
    print-header "PACKAGE COMPATIBILITY RESULTS"

    # Create comprehensive table data combining all categories
    let comprehensive_data = ($results | each { |category_result|
        let category_name = $category_result.category

        # Create entries for each platform in this category
        $category_result.platforms | each { |platform_result|
            let platform = $platform_result.platform
            let available_count = ($platform_result.available | length)
            let unavailable_count = ($platform_result.unavailable | length)
            let total_count = $available_count + $unavailable_count

            {
                Category: $category_name
                Platform: $platform
                Status: $"($available_count)/($total_count) available"
                Issues: (if $unavailable_count == 0 {
                    $"($theme_icons.success) OK"
                } else {
                    $"($theme_icons.pending) ($unavailable_count) missing"
                })
            }
        }
    } | flatten)

    # Print the comprehensive table
    if ($comprehensive_data | length) > 0 {
        print-table $comprehensive_data --no-index
    }

    # Show detailed missing packages for categories with issues
    let categories_with_issues = ($results | where {|cat|
        ($cat.platforms | any {|p| ($p.unavailable | length) > 0})
    })

    if ($categories_with_issues | length) > 0 {
        print ""
        print-info "Missing packages by category:"
        $categories_with_issues | each { |category_result|
            let missing_by_platform = ($category_result.platforms | where {|p| ($p.unavailable | length) > 0})
            if ($missing_by_platform | length) > 0 {
                print $"  ($theme_icons.info) ($category_result.category):"
                $missing_by_platform | each { |platform_result|
                    if ($platform_result.unavailable | length) > 0 {
                        let missing_list = ($platform_result.unavailable | str join ', ')
                        print $"    ($platform_result.platform): ($missing_list)"
                    }
                }
            }
        }
    }

    # Overall platform analysis
    print ""
    print-header "PLATFORM COMPATIBILITY SUMMARY"

    # Collect all platform results
    let all_platform_results = $results | get platforms | flatten

    let linux_x86 = $all_platform_results | where {|r| $r.platform == "x86_64-linux"}
    let darwin_aarch = $all_platform_results | where {|r| $r.platform == "aarch64-darwin"}

    # Cross-platform availability summary
    if ($linux_x86 | length) > 0 and ($darwin_aarch | length) > 0 {
        let linux_available = $linux_x86 | get available | flatten | uniq
        let darwin_available = $darwin_aarch | get available | flatten | uniq

        let linux_only = $linux_available | where {|pkg| not ($pkg in $darwin_available)}
        let darwin_only = $darwin_available | where {|pkg| not ($pkg in $linux_available)}
        let common = $linux_available | where {|pkg| $pkg in $darwin_available}

        # Create concise compatibility summary
        let summary_data = [
            {
                Scope: "Cross-platform packages"
                Count: ($common | length)
                Status: $"($theme_icons.success) Available on both"
            }
            {
                Scope: "Linux-only packages"
                Count: ($linux_only | length)
                Status: (if ($linux_only | length) > 0 { $"($theme_icons.pending) Linux x86_64 only" } else { $"($theme_icons.success) None" })
            }
            {
                Scope: "Darwin-only packages"
                Count: ($darwin_only | length)
                Status: (if ($darwin_only | length) > 0 { $"($theme_icons.pending) Darwin aarch64 only" } else { $"($theme_icons.success) None" })
            }
        ]

        print-table $summary_data --no-index
    }

    print-success $"Analysis complete! Found ($package_categories.total_unique) unique packages across ($package_categories.categories | length) categories."
}

def extract_packages_from_directory [dir: string, context: string] {
    # Use find command to locate .nix files recursively
    let find_output = try {
        (^find $dir -name "*.nix" -type f | lines)
    } catch { |err|
        print $"  Warning: Could not scan directory ($dir): ($err.msg)"
        []
    }

    $find_output | each { |file|
        let content = try {
            (open $file)
        } catch { |err|
            print $"  Warning: Could not read file ($file): ($err.msg)"
            ""
        }

        # Extract package names from the file content
        let packages = extract_packages_from_content $content

        # Determine category based on file path
        let category = if ($file | str contains "shared") {
            "shared"
        } else if ($file | str contains "nixos") {
            "nixos"
        } else if ($file | str contains "darwin") {
            "darwin"
        } else {
            "shared"  # default
        }

        {
            file: $file
            category: $category
            packages: $packages
            context: $context
        }
    }
}

def extract_packages_from_content [content: string] {
    mut all_packages = []

    # Look for package list patterns by finding the start markers
    let home_pkg_start = ($content | str index-of "home.packages = with pkgs; [")
    let env_pkg_start = ($content | str index-of "environment.systemPackages = with pkgs; [")
    let fonts_pkg_start = ($content | str index-of "fonts.packages = with pkgs; [")

    # Process home.packages
    if $home_pkg_start != -1 {
        let start_pos = $home_pkg_start + ("home.packages = with pkgs; [" | str length)
        let remaining = ($content | str substring $start_pos..)
        let end_pos = ($remaining | str index-of "]")
        if $end_pos != -1 {
            let list_content = ($remaining | str substring 0..$end_pos)
            let packages = (extract_package_names_from_list $"home.packages = with pkgs; [($list_content)]")
            $all_packages = ($all_packages | append $packages)
        }
    }

    # Process environment.systemPackages
    if $env_pkg_start != -1 {
        let start_pos = $env_pkg_start + ("environment.systemPackages = with pkgs; [" | str length)
        let remaining = ($content | str substring $start_pos..)
        let end_pos = ($remaining | str index-of "]")
        if $end_pos != -1 {
            let list_content = ($remaining | str substring 0..$end_pos)
            let packages = (extract_package_names_from_list $"environment.systemPackages = with pkgs; [($list_content)]")
            $all_packages = ($all_packages | append $packages)
        }
    }

    # Process fonts.packages
    if $fonts_pkg_start != -1 {
        let start_pos = $fonts_pkg_start + ("fonts.packages = with pkgs; [" | str length)
        let remaining = ($content | str substring $start_pos..)
        let end_pos = ($remaining | str index-of "]")
        if $end_pos != -1 {
            let list_content = ($remaining | str substring 0..$end_pos)
            let packages = (extract_package_names_from_list $"fonts.packages = with pkgs; [($list_content)]")
            $all_packages = ($all_packages | append $packages)
        }
    }

    $all_packages | flatten | uniq
}

def extract_package_names_from_list [text: string] {
    # Extract just the content between [ and ] for package lists
    # This handles cases like: home.packages = with pkgs; [ pkg1 pkg2 pkg3 ]
    let list_content = if ($text | str contains "[") and ($text | str contains "]") {
        let start = ($text | str index-of "[")
        let end = ($text | str index-of "]")
        if $start != -1 and $end != -1 and $end > $start {
            $text | str substring ($start + 1)..($end - 1) | str trim
        } else {
            ""
        }
    } else {
        ""
    }

    if ($list_content | str length) == 0 {
        return []
    }

    # Split by newlines first to handle multi-line lists
    let lines = ($list_content | split row "\n")

    let nix_keywords = [
        "with" "pkgs" "lib" "config" "true" "false" "null" "let" "in" "rec"
        "inherit" "import" "if" "then" "else" "assert" "or" "and" "not"
        "home" "environment" "systemPackages" "packages" "fonts"
        "enable" "settings" "programs" "services"
    ]

    mut valid_packages = []
    for line in $lines {
        # Remove comments (everything after #)
        let clean_line = ($line | str trim | split row "#" | get 0 | str trim)

        # Skip empty lines
        if ($clean_line | str length) == 0 {
            continue
        }

        # Split by whitespace to get individual packages
        let potential_packages = ($clean_line | split row " " | where { |s| ($s | str length) > 0 })

        for pkg in $potential_packages {
            let clean_pkg = ($pkg | str trim | str replace -r '[;,\]\[]' '')
            let len = ($clean_pkg | str length)
            let is_keyword = ($clean_pkg in $nix_keywords)
            let starts_with_dot = ($clean_pkg | str starts-with ".")
            let contains_special = ($clean_pkg | str contains "=") or ($clean_pkg | str contains "{") or ($clean_pkg | str contains "}")

            if (($len > 2) and (not $is_keyword) and (not $starts_with_dot) and (not $contains_special)) {
                $valid_packages = ($valid_packages | append $clean_pkg)
            }
        }
    }

    $valid_packages | uniq
}

def extract_package_names [text: string] {
    # Extract package names from Nix syntax
    # Look for word characters, dots, and hyphens that look like package names
    let pkg_matches = ($text | find -r '[\w\.-]+')

    # Filter out Nix keywords and common non-package words
    let nix_keywords = [
        "with" "pkgs" "lib" "config" "true" "false" "null" "let" "in" "rec"
        "inherit" "import" "if" "then" "else" "assert" "or" "and" "not"
        "home" "environment" "systemPackages" "packages" "fonts"
        "enable" "settings" "programs" "services" "mkForce"
        "mkDefault" "mkOverride" "mkOption" "types" "mkEnableOption"
        "mkIf" "optionalAttrs" "listToAttrs" "nameValuePair"
    ]

    mut filtered_packages = []
    for pkg in $pkg_matches {
        let len = ($pkg | str length)
        let is_keyword = ($pkg in $nix_keywords)
        let starts_with_dot = ($pkg | str starts-with ".")
        let ends_with_dot = ($pkg | str ends-with ".")
        let contains_double_dot = ($pkg | str contains "..")

        if (($len > 2) and (not $is_keyword) and (not $starts_with_dot) and (not $ends_with_dot) and (not $contains_double_dot)) {
            $filtered_packages = ($filtered_packages | append $pkg)
        }
    }
    $filtered_packages | uniq
}
