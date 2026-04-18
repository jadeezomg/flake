# Shared function definitions (shell-specific implementations)
{...}: {
  # Function names and their logic (implementation is shell-specific)
  commonFunctions = {
    # Quick directory navigation shortcuts
    zz = {
      description = "cd to home";
      path = "$HOME";
    };
    zc = {
      description = "cd to config";
      path = "$HOME/.config";
    };
    zd = {
      description = "cd to downloads";
      path = "$HOME/Downloads";
    };
    zp = {
      description = "cd to dotfiles";
      path = "$HOME/.dotfiles";
    };
    zf = {
      description = "cd to flake";
      path = "$HOME/.dotfiles/flake";
    };

    # Flake build scripts shortcuts
    flake = {
      description = "run flake script";
      command = ''nu "$HOME/.dotfiles/flake/build/flake.nu"'';
    };
  };
}
