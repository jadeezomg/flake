{...}: {
  # noTunes - Prevent Apple Music/iTunes from launching automatically
  # https://github.com/tombonez/noTunes

  # Configure noTunes preferences via defaults
  # noTunes is a simple utility that just prevents Music.app from launching
  # It has minimal configuration - just needs to run at startup
  targets.darwin.defaults."digital.twisted.noTunes" = {
    # Menubar icon position (optional)
    "NSStatusItem Preferred Position Item-0" = 526;
  };
}
