{...}: {
  # Scroll Reverser - Reverse scroll direction independently for mouse and trackpad
  # https://pilotmoon.com/scrollreverser/

  # Configure Scroll Reverser preferences via defaults
  targets.darwin.defaults."com.pilotmoon.scroll-reverser" = {
    # Enable scroll reversal
    InvertScrollingOn = true;

    # Reverse mouse but not trackpad
    ReverseTrackpad = false;

    # Show discrete scroll options
    ShowDiscreteScrollOptions = true;

    # Permissions
    HasRequestedAccessibilityPermission = true;
    HasRequestedInputMonitoringPermission = true;
    HasRunBefore = true;
  };
}
