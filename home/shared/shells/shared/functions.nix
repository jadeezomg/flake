# Shared function definitions (shell-specific implementations)
{hostKey ? "framework", ...}: {
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

    # Home Manager shortcuts
    hm = {
      description = "home-manager command";
      command = ''nix run home-manager/master -- --flake "$HOME/.dotfiles/flake#${hostKey}"'';
    };
    hms = {
      description = "home-manager switch";
      command = ''nix run home-manager/master -- switch --flake "$HOME/.dotfiles/flake#${hostKey}"'';
    };
    hmn = {
      description = "home-manager news";
      command = ''nix run home-manager/master -- news --flake "$HOME/.dotfiles/flake#${hostKey}"'';
    };

    # Flake build scripts shortcuts
    flake = {
      description = "run flake script";
      command = ''nu "$HOME/.dotfiles/flake/build/flake.nu"'';
    };
  };
}
