#!/usr/bin/env nu

# Script to check package availability across platforms
# Usage: ./check-packages.nu

def main [] {
    print "🔍 Checking package availability across platforms..."

    # Extract all packages from configurations
    let package_categories = extract_packages_from_nix_files

    print $"Found ($package_categories | get total_unique) unique packages across ($package_categories.categories | length) categories"

    # Display package categories
    print "\n📦 Package Categories:"
    $package_categories.categories | each { |category|
        print $"  ($category.name): ($category.packages | length) packages"
    }

    # Check availability based on category requirements
    let results = check_package_availability $package_categories

    # Compile and display results
    compile_results $results $package_categories
}

# For now, let's use a simplified hardcoded list to get the script working
def extract_packages_from_nix_files [] {
    print "🔍 Using predefined package list..."

    # Predefined packages based on our analysis
    let all_categories = [
        {
            name: "Home Packages (Shared)"
            packages: ["age" "sops" "nushell" "pay-respects" "zoxide" "direnv" "yazi" "fzf" "home-manager"]
            platforms: ["x86_64-linux" "aarch64-darwin"]
        }
        {
            name: "Home Packages (NixOS)"
            packages: ["dconf"]
            platforms: ["x86_64-linux"]
        }
        {
            name: "Home Packages (Darwin)"
            packages: []
            platforms: ["aarch64-darwin"]
        }
        {
            name: "System Packages (Shared)"
            packages: ["git" "curl" "wget" "fd" "ripgrep" "eza" "btop" "gitui" "just" "tokei" "uv" "gh" "nixfmt-rfc-style" "nil" "nixd"]
            platforms: ["x86_64-linux" "aarch64-darwin"]
        }
        {
            name: "System Packages (NixOS)"
            packages: ["libnotify"]
            platforms: ["x86_64-linux"]
        }
        {
            name: "System Packages (Darwin)"
            packages: []
            platforms: ["aarch64-darwin"]
        }
    ]

    let total_unique = ($all_categories | get packages | flatten | uniq | length)

    {categories: $all_categories, total_unique: $total_unique}
}



def check_package_availability [package_categories] {
    print "\n🔍 Checking package availability by category..."

    let category_results = $package_categories.categories | each { |category|
        print $"📦 Checking category: ($category.name)"

        let platform_results = $category.platforms | each { |platform|
            print $"  🔍 Checking ($category.packages | length) packages on ($platform)..."

            # Check if nixpkgs is available for this platform
            let nixpkgs_available = try {
                run-external "nix" "flake" "metadata" $"github:NixOS/nixpkgs" $"--system" $platform
                    | complete
            } catch { |err|
                print $"    ❌ Error: nixpkgs not available for ($platform)"
                {platform: $platform, available: [], unavailable: $category.packages}
            }

            if $nixpkgs_available.exit_code != 0 {
                print $"    ❌ nixpkgs not available for ($platform)"
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

                print $"    ✅ Available: ($available | length), ❌ Unavailable: ($unavailable | length)"
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
    print "\n📊 Package Availability Results:"
    print "═" * 80

    # Display results by category using tables
    $results | each { |category_result|
        print $"\n📦 ($category_result.category)"
        print "─" * 60

        # Create table data for this category
        let table_data = ($category_result.platforms | each { |platform_result|
            let platform = $platform_result.platform
            let available_count = ($platform_result.available | length)
            let unavailable_count = ($platform_result.unavailable | length)
            let total_count = $available_count + $unavailable_count

            {
                Platform: $platform
                Available: $"($available_count)/($total_count)"
                Unavailable: $"($unavailable_count)/($total_count)"
                Status: (if $unavailable_count == 0 { "✅ All Available" } else { "⚠️  Some Missing" })
                Missing: (if $unavailable_count > 0 { ($platform_result.unavailable | str join ', ') } else { "-" })
            }
        })

        # Print the table
        $table_data | table -e
    }

    # Overall platform analysis
    print "\n🔍 Platform Compatibility Analysis:"
    print "═" * 80

    # Collect all platform results
    let all_platform_results = $results | get platforms | flatten

    let linux_x86 = $all_platform_results | where {|r| $r.platform == "x86_64-linux"}
    let darwin_aarch = $all_platform_results | where {|r| $r.platform == "aarch64-darwin"}

    # Cross-platform availability
    if ($linux_x86 | length) > 0 and ($darwin_aarch | length) > 0 {
        let linux_available = $linux_x86 | get available | flatten | uniq
        let darwin_available = $darwin_aarch | get available | flatten | uniq

        let linux_only = $linux_available | where {|pkg| not ($pkg in $darwin_available)}
        let darwin_only = $darwin_available | where {|pkg| not ($pkg in $linux_available)}
        let common = $linux_available | where {|pkg| $pkg in $darwin_available}

        # Create compatibility table
        let compatibility_data = [
            {
                Category: "🐧 Linux-only packages"
                Count: ($linux_only | length)
                Packages: (if ($linux_only | length) > 0 { ($linux_only | str join ', ') } else { "None" })
            }
            {
                Category: "🍎 Darwin-only packages"
                Count: ($darwin_only | length)
                Packages: (if ($darwin_only | length) > 0 { ($darwin_only | str join ', ') } else { "None" })
            }
            {
                Category: "✅ Cross-platform packages"
                Count: ($common | length)
                Packages: $"($common | length) packages available on both platforms"
            }
        ]

        print ""
        $compatibility_data | table -e
    }

    print $"\n✨ Analysis complete! Found ($package_categories.total_unique) unique packages across ($package_categories.categories | length) categories."
}
