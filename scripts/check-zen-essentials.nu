#!/usr/bin/env nu

# Diagnostic script to check Zen browser essentials configuration
# Usage: nu check-zen-essentials.nu

def main [] {
  print "🔍 Checking Zen Browser Essentials Configuration..."
  print ""
  
  # Check if Zen is running
  let zen_running = (ps | where name =~ "zen" | length)
  if $zen_running > 0 {
    print "⚠️  Zen browser is running (this may lock the database)"
    print "   Consider closing Zen before running updates"
    print ""
  } else {
    print "✅ Zen browser is not running"
    print ""
  }
  
  # Check profiles.ini
  print "📋 Checking profiles.ini..."
  let profiles_ini = ($env.HOME | path join ".zen" "profiles.ini")
  if ($profiles_ini | path exists) {
    print $"✅ profiles.ini exists: ($profiles_ini)"
    let ini_content = (open $profiles_ini)
    let default_profile = ($ini_content | lines | where ($it | str contains "Default=1") | first)
    if ($default_profile | is-not-empty) {
      print "   Default profile configuration found"
    }
  } else {
    print $"⚠️  profiles.ini not found: ($profiles_ini)"
  }
  print ""
  
  # Check if profile directory exists
  let profile_dir = ($env.HOME | path join ".zen" "default")
  if not ($profile_dir | path exists) {
    print $"❌ Profile directory does not exist: ($profile_dir)"
    return
  }
  print $"✅ Profile directory exists: ($profile_dir)"
  
  # Check local directory (cache)
  let local_dir = ($env.HOME | path join ".cache" "zen" "default")
  if ($local_dir | path exists) {
    print $"✅ Local directory exists: ($local_dir)"
  } else {
    print $"⚠️  Local directory does not exist: ($local_dir)"
  }
  print ""
  
  # Check if database exists
  let db_path = ($profile_dir | path join "places.sqlite")
  if not ($db_path | path exists) {
    print $"❌ Database does not exist: ($db_path)"
    return
  }
  print $"✅ Database exists: ($db_path)"
  
  # Check database modification time
  let db_mtime = (try {
    ^stat -c %Y $db_path | str trim | into int
  } catch {
    0
  })
  let db_mtime_readable = (try {
    ^stat -c %y $db_path | str trim
  } catch {
    "unknown"
  })
  let now = (date now | into int)
  let age_seconds = $now - $db_mtime
  print $"   Last modified: ($db_mtime_readable)"
  print $"   Age: ($age_seconds) seconds"
  
  if $age_seconds < 60 {
    print "   ✅ Database was recently modified (within last minute)"
  } else if $age_seconds < 300 {
    print $"   ⚠️  Database was modified ($age_seconds) sec ago (may not reflect recent changes)"
  } else {
    print $"   ⚠️  Database was last modified ($age_seconds) sec ago - may be stale"
  }
  
  # Check for database backup files
  let db_backups = (try {
    ls ($profile_dir | path join "places.sqlite*") | get name
  } catch {
    []
  })
  if ($db_backups | length) > 1 {
    print $"   Found ($db_backups | length) database files (may include backups)"
  }
  print ""
  
  # Check if database is accessible
  let db_check = (try {
    ^sqlite3 $db_path "SELECT 1;" | complete
    $in.exit_code == 0
  } catch {
    false
  })
  
  if not $db_check {
    print "⚠️  Database may be locked (Zen may be running)"
    print "   Attempting read-only queries anyway..."
    print ""
  } else {
    print "✅ Database is accessible"
    print ""
  }
  
  # Try to query the database even if it might be locked (read-only should work)
  # SQLite allows read-only access even when locked for writes
  print "Attempting to query database (read-only access)..."
  print ""
  
  # Always try to query - SQLite supports concurrent reads
  try {
    # First, list all tables to see what's available
    print "📋 Database Tables:"
    let tables_result = (^sqlite3 $db_path ".tables" | complete)
    
    # Check if database is locked by checking both exit code and error messages
    let is_locked = ($tables_result.exit_code != 0) and (
      ($tables_result.stderr | str contains "database is locked") or
      ($tables_result.stderr | str contains "locked") or
      ($tables_result.stdout | str contains "database is locked") or
      ($tables_result.stdout | str contains "Error: database is locked")
    )
    
    if $is_locked {
      let error_msg = if ($tables_result.stderr | str trim | is-not-empty) {
        $tables_result.stderr | str trim
      } else {
        $tables_result.stdout | str trim
      }
      print $"   ⚠️  ($error_msg)"
      print ""
      print "❌ Database is locked and cannot be queried"
      print "   Please close Zen browser and try again"
      print ""
      return
    }
    
    if $tables_result.exit_code == 0 {
      print $"   ($tables_result.stdout | str trim)"
    } else {
      print $"   ⚠️  Error: ($tables_result.stderr | str trim)"
    }
    print ""
    
    # Check all pins (not just essentials)
    print "📌 Checking All Pins..."
    print "   Querying database for current pin values..."
    let all_pins_output = (try {
      let result = (^sqlite3 $db_path "SELECT COUNT(*) FROM zen_pins;" | complete)
      if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
        $result.stdout | str trim
      } else {
        if ($result.stderr | str contains "database is locked") {
          "LOCKED"
        } else {
          "0"
        }
      }
    } catch {|err|
      let err_str = ($err | to text)
      if ($err_str | str contains "locked") {
        "LOCKED"
      } else {
        "0"
      }
    })
    
    if $all_pins_output == "LOCKED" or ($all_pins_output | str trim | is-empty) {
      if $all_pins_output == "LOCKED" {
        print "   ⚠️  Database is locked - cannot query pins"
      } else {
        print "   ⚠️  No result from query (database may be locked)"
      }
      print ""
      return
    }
    
    let all_pins_count = (try {
      if ($all_pins_output | str trim | is-not-empty) {
        $all_pins_output | into int
      } else {
        0
      }
    } catch {
      0
    })
    
    if $all_pins_count == 0 {
      print "❌ No pins found in database!"
    } else {
      print $"✅ Found ($all_pins_count) total pins in database"
      print ""
      print "   All Pins (from database):"
      try {
        let pins_query_result = (^sqlite3 $db_path "SELECT title, url, position, is_essential FROM zen_pins ORDER BY position;" | complete)
        if $pins_query_result.exit_code == 0 {
          $pins_query_result.stdout | lines | each { |line|
            let parts = ($line | split column "|" title url position is_essential)
            let essential_marker = if ($parts.is_essential == "1") { "⭐" } else { "  " }
            print $"   ($essential_marker) ($parts.title) - ($parts.url) [pos: ($parts.position)]"
          }
        } else {
          print $"   Error: ($pins_query_result.stderr)"
        }
      } catch {|err|
        print $"   Error querying pins: ($err | to text)"
      }
    }
    print ""
    
    # Check essential pins separately
    print "⭐ Checking Essential Pins..."
    print "   Querying database for essential pins..."
    let pins_output = (try {
      let result = (^sqlite3 $db_path "SELECT COUNT(*) FROM zen_pins WHERE is_essential = 1;" | complete)
      if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
        $result.stdout | str trim
      } else {
        if ($result.stderr | str contains "database is locked") {
          "LOCKED"
        } else {
          "0"
        }
      }
    } catch {|err|
      let err_str = ($err | to text)
      if ($err_str | str contains "locked") {
        "LOCKED"
      } else {
        "0"
      }
    })
    
    if $pins_output == "LOCKED" or ($pins_output | str trim | is-empty) {
      if $pins_output == "LOCKED" {
        print "   ⚠️  Database is locked - cannot query essential pins"
      } else {
        print "   ⚠️  No result from query (database may be locked)"
      }
      print ""
      return
    }
    
    let pins_count = (try {
      if ($pins_output | str trim | is-not-empty) {
        $pins_output | into int
      } else {
        0
      }
    } catch {
      0
    })
    
    if $pins_count == 0 {
      print "❌ No essential pins found in database!"
    } else {
      print $"✅ Found ($pins_count) essential pins in database"
      print ""
      print "   Essential Pins list (from database):"
      try {
        let essential_query_result = (^sqlite3 $db_path "SELECT title, url, position FROM zen_pins WHERE is_essential = 1 ORDER BY position;" | complete)
        if $essential_query_result.exit_code == 0 {
          $essential_query_result.stdout | lines | each { |line|
            let parts = ($line | split column "|" title url position)
            print $"   • ($parts.title) - ($parts.url) [pos: ($parts.position)]"
          }
        } else {
          print $"   Error: ($essential_query_result.stderr)"
        }
      } catch {|err|
        print $"   Error querying essential pins: ($err | to text)"
      }
    }
    print ""
    
    # Check for active tabs
    print "🔖 Checking Active Tabs..."
    
    # First, let's see what tables actually exist that might contain tabs
    print "   Checking for tab-related tables..."
    let all_tables_result = (^sqlite3 $db_path "SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE '%tab%' OR name LIKE '%Tab%');" | complete)
    if $all_tables_result.exit_code == 0 and ($all_tables_result.stdout | str trim | is-not-empty) {
      print $"   Found tab-related tables: ($all_tables_result.stdout | str trim)"
    } else {
      print "   No tables with 'tab' in the name found"
    }
    print ""
    
    # Try different possible table names for tabs - prioritize zen_tabs
    let tab_tables = ["zen_tabs", "moz_tabs", "tabs", "session_tabs"]
    mut tabs_found = false
    
    for tab_table in $tab_tables {
      let table_check = (try {
        let result = (^sqlite3 $db_path $"SELECT name FROM sqlite_master WHERE type='table' AND name='($tab_table)';" | complete)
        if $result.exit_code == 0 {
          let table_name = ($result.stdout | str trim)
          $table_name == $tab_table
        } else {
          false
        }
      } catch {
        false
      })
      
      if $table_check {
        print $"   Found table: ($tab_table)"
        try {
          # Use string concatenation to avoid * being interpreted as glob
          let count_query = "SELECT COUNT(" + "*" + ") FROM " + $tab_table + ";"
          let count_result = (^sqlite3 $db_path $count_query | complete)
          if $count_result.exit_code == 0 and (not ($count_result.stderr | str contains "database is locked")) {
            let tabs_count = (try {
              $count_result.stdout | str trim | into int
            } catch {
              0
            })
            
            if $tabs_count > 0 {
              print $"   ✅ Found ($tabs_count) tabs in ($tab_table)"
              print ""
              print "   Active Tabs:"
              # Try to get tab information - adjust columns based on actual schema
              let tabs_query = (try {
                # Try common column names first for zen_tabs
                let select_cols_query = if $tab_table == "zen_tabs" {
                  "SELECT url, title, position FROM zen_tabs ORDER BY position LIMIT 20;"
                } else {
                  "SELECT url, title FROM " + $tab_table + " LIMIT 20;"
                }
                let result = (^sqlite3 $db_path $select_cols_query | complete)
                if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
                  $result.stdout | lines
                } else {
                  # If that fails, try SELECT *
                  let select_all_query = "SELECT " + "*" + $" FROM ($tab_table) LIMIT 20;"
                  let alt_result = (^sqlite3 $db_path $select_all_query | complete)
                  if $alt_result.exit_code == 0 and ($alt_result.stdout | str trim | is-not-empty) {
                    $alt_result.stdout | lines
                  } else {
                    []
                  }
                }
              } catch {|err|
                print $"   Debug: Error in query - ($err)"
                []
              })
              
              if ($tabs_query | length) > 0 {
                for tab in $tabs_query {
                  print $"   • ($tab)"
                }
              } else {
                print "   (Table exists but could not retrieve tab details - may be empty or schema differs)"
              }
              $tabs_found = true
              break
            } else {
              print $"   (Table ($tab_table) exists but is empty)"
            }
          } else {
            if ($count_result.stderr | str contains "database is locked") {
              print $"   ⚠️  Database is locked - cannot query ($tab_table)"
            } else {
              print $"   ⚠️  Query failed for ($tab_table): ($count_result.stderr)"
            }
          }
        } catch {|err|
          print $"   Error querying ($tab_table): ($err | to text)"
        }
      }
    }
    
    if not $tabs_found {
      print "   ⚠️  No tab tables found in SQL database"
      print "   (Tabs are typically stored in sessionstore files, not SQL database)"
    }
    print ""
    
    # Check for sessionstore files (where tabs are usually stored)
    print "📑 Checking Session Files (for tabs)..."
    let session_files = [
      ($profile_dir | path join "sessionstore.jsonlz4"),
      ($profile_dir | path join "sessionstore.json"),
      ($profile_dir | path join "sessionstore-backups" "recovery.jsonlz4"),
      ($profile_dir | path join "sessionstore-backups" "recovery.json")
    ]
    
    mut session_found = false
    for session_file in $session_files {
      if ($session_file | path exists) {
        print $"   ✅ Found: ($session_file)"
        $session_found = true
        # Note: sessionstore files are compressed (lz4) or JSON, would need special handling
        # Just report that they exist for now
      }
    }
    
    if not $session_found {
      print "   ⚠️  No sessionstore files found"
      print "   (Zen may not be saving session, or files are in a different location)"
    }
    print ""
    
    # Check spaces
    print "🌌 Checking Spaces..."
    let spaces_output = (try {
      let result = (^sqlite3 $db_path "SELECT COUNT(*) FROM zen_workspaces;" | complete)
      if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
        $result.stdout | str trim
      } else {
        if ($result.stderr | str contains "database is locked") {
          "LOCKED"
        } else {
          "0"
        }
      }
    } catch {|err|
      let err_str = ($err | to text)
      if ($err_str | str contains "locked") {
        "LOCKED"
      } else {
        "0"
      }
    })
    
    if $spaces_output == "LOCKED" or ($spaces_output | str trim | is-empty) {
      if $spaces_output == "LOCKED" {
        print "   ⚠️  Database is locked - cannot query spaces"
      } else {
        print "   ⚠️  No result from query (database may be locked)"
      }
      print ""
    } else {
      let spaces_count = (try {
        if ($spaces_output | str trim | is-not-empty) {
          $spaces_output | into int
        } else {
          0
        }
      } catch {
        0
      })
      
      if $spaces_count == 0 {
        print "❌ No spaces found in database!"
      } else {
        print $"✅ Found ($spaces_count) spaces in database"
        print ""
        print "   Spaces list:"
        try {
          let result = (^sqlite3 $db_path "SELECT name, icon, position FROM zen_workspaces ORDER BY position;" | complete)
          if $result.exit_code == 0 {
            $result.stdout | lines | each { |line|
              let parts = ($line | split column "|" name icon position)
              print $"   • ($parts.name) ($parts.icon) [pos: ($parts.position)]"
            }
          } else {
            print $"   Error: ($result.stderr)"
          }
        } catch {|err|
          print $"   Error querying spaces: ($err)"
        }
      }
      print ""
    }
    
    # Check containers
    print "📦 Checking Containers..."
    let containers_file = ($profile_dir | path join "containers.json")
    if ($containers_file | path exists) {
      let containers = (open $containers_file | get identities | where public == true)
      if ($containers | length) > 0 {
        print $"✅ Found ($containers | length) containers:"
        for $container in $containers {
          print $"   • ($container.name) [id: ($container.userContextId)]"
        }
      } else {
        print "⚠️  No public containers found"
      }
    } else {
      print "⚠️  containers.json not found"
    }
    print ""
  } catch {|err|
    print $"❌ Error accessing database: ($err)"
    print "   The database may be locked or corrupted"
    print ""
  }
  
  # Check update script
  print "📜 Checking Update Script..."
  let update_script = ($profile_dir | path join "places_update.sh")
  if ($update_script | path exists) {
    print $"✅ Update script exists: ($update_script)"
    let script_target = (^readlink -f $update_script | str trim)
    print $"   → Points to: ($script_target)"
  } else {
    print $"❌ Update script not found: ($update_script)"
  }
  print ""
  
  # Check settings
  print "⚙️  Checking Settings..."
  let prefs_file = ($profile_dir | path join "prefs.js")
  if ($prefs_file | path exists) {
    # Check for separate-essentials setting
    let separate_line = (open $prefs_file | lines | where ($it | str contains "separate-essentials") | first)
    if ($separate_line | is-not-empty) {
      let parts = ($separate_line | split row "=")
      if ($parts | length) > 1 {
        let separate_essentials = ($parts | get 1 | str trim | str replace ";" "")
        print $"   zen.workspaces.separate-essentials = ($separate_essentials)"
        if $separate_essentials == "false" {
          print "   ✅ Essentials should be visible in main workspace"
        } else {
          print "   ⚠️  Essentials are separated (may be in different view)"
          print "   💡 Try setting this to false in about:config"
        }
      }
    } else {
      print "   ⚠️  zen.workspaces.separate-essentials not found in prefs.js"
      print "   💡 Default behavior may hide essentials"
    }
    
    # Check for other relevant Zen settings
    let zen_settings = (open $prefs_file | lines | where ($it | str contains "zen.") | where ($it | str contains "essential") or ($it | str contains "pin") or ($it | str contains "workspace"))
    if ($zen_settings | length) > 0 {
      print ""
      print "   Other Zen-related settings:"
      for setting in $zen_settings {
        print $"   ($setting)"
      }
    }
  } else {
    print "   ⚠️  prefs.js not found"
  }
  print ""
  
  # Check user.js for overrides
  print "📝 Checking user.js for overrides..."
  let userjs_file = ($profile_dir | path join "user.js")
  if ($userjs_file | path exists) {
    let userjs_zen = (open $userjs_file | lines | where ($it | str contains "zen.") | where ($it | str contains "essential") or ($it | str contains "pin") or ($it | str contains "workspace"))
    if ($userjs_zen | length) > 0 {
      print "   Found Zen-related settings in user.js:"
      for setting in $userjs_zen {
        print $"   ($setting)"
      }
    } else {
      print "   No Zen essentials/pins settings in user.js"
    }
  } else {
    print "   user.js not found (this is normal)"
  }
  print ""
  
  # Check for userChrome.css that might hide essentials
  print "🎨 Checking for userChrome.css..."
  let chrome_dir = ($profile_dir | path join "chrome")
  if ($chrome_dir | path exists) {
    let userchrome = ($chrome_dir | path join "userChrome.css")
    if ($userchrome | path exists) {
      let chrome_content = (open $userchrome)
      let hides_essentials = ($chrome_content | str contains "essential" -i) or ($chrome_content | str contains "pin" -i)
      if $hides_essentials {
        print "   ⚠️  userChrome.css exists and may affect essentials display"
        print "   💡 Check if it contains rules hiding essentials"
      } else {
        print "   ✅ userChrome.css exists but doesn't seem to hide essentials"
      }
    } else {
      print "   userChrome.css not found"
    }
  } else {
    print "   chrome/ directory not found"
  }
  print ""
  
  # Recommendations
  print "💡 Troubleshooting Steps:"
  print ""
  print "   Since database values are correct but essentials don't appear:"
  print ""
  print "   1. Check about:config for these settings:"
  print "      • zen.workspaces.separate-essentials (should be false)"
  print "      • zen.workspaces.continue-where-left-off"
  print "      • Any zen.pinned-tab-manager.* settings"
  print ""
  print "   2. Open browser console (F12) and check for errors:"
  print "      • Look for JavaScript errors related to 'pins' or 'essentials'"
  print "      • Check if Zen extension is loaded correctly"
  print ""
  print "   3. Check UI state:"
  print "      • Right-click on workspace area - look for 'Show Essentials' option"
  print "      • Check if essentials bar is collapsed (look for expand icon)"
  print "      • Try switching workspaces - essentials might be workspace-specific"
  print ""
  print "   4. Try manual refresh:"
  print "      • Close Zen completely"
  print "      • Run: ~/.zen/default/places_update.sh"
  print "      • Restart Zen"
  print ""
  print "   5. Check if it's a workspace issue:"
  print "      • Essentials might only show in specific workspaces"
  print "      • Try creating a new workspace and see if essentials appear there"
  print ""
  print "   6. Check Zen extension status:"
  print "      • Go to about:addons"
  print "      • Verify 'Zen Internet' extension is enabled"
  print "      • Check extension console for errors"
}
