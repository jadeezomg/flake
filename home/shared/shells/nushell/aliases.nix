{hostKey ? "framework", ...}: let
  sharedAliases = import ../shared/aliases.nix;
in {
  # Import common aliases
  programs.nushell.shellAliases = sharedAliases.commonAliases;

  # Nushell-specific function implementations
  programs.nushell.extraConfig = ''
    # Quick directory navigation shortcuts
    def --env zz [] { cd ''$env.HOME }
    def --env zc [] { cd $"(''$env.HOME)/.config" }
    def --env zd [] { cd $"(''$env.HOME)/Downloads" }
    def --env zp [] { cd $"(''$env.HOME)/.dotfiles" }
    def --env zf [] { cd $"(''$env.HOME)/.dotfiles/flake" }

    # Home Manager shortcuts
    alias hm = nix run home-manager/master -- --flake $"(''$env.FLAKE)#${hostKey}"
    alias hms = nix run home-manager/master -- switch --flake $"(''$env.FLAKE)#${hostKey}"
    alias hmn = nix run home-manager/master -- news --flake $"(''$env.FLAKE)#${hostKey}"

    # Flake build scripts shortcuts
    alias flake = nu $"(''$env.FLAKE)/build/flake.nu"
  '';
}
