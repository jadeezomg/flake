#!/usr/bin/env nu
# Reload user services (parity with rh-reload-services.sh)

use common.nu *

def main [] {
  notify "Flake Reload Services" "Reloading user services..." "pending"

  # Reload user daemon
  ^systemctl --user daemon-reload

  # Optional: trigger niri screen transition if available
  if (command-exists "niri") {
    ^niri msg action do-screen-transition --delay-ms 800 | ignore
  }

  # Restart key user services
  let services = ["rh-swaybg" "rh-waybar"]
  $services | each { |svc|
    ^systemctl --user restart $"($svc).service" | ignore
  }

  # Reload notifications
  if (command-exists "makoctl") {
    ^makoctl reload
  }

  notify "Flake Reload Services" "Reloaded user services" "success"
}


