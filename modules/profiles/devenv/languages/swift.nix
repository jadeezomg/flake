{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.devenv.languages.swift;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in {
  # Swift toolchain + sourcekit-lsp. Darwin-only realistically — pkgs.swift
  # on Linux needs the big foundation/dispatch build and we don't need it.
  config = lib.mkIf (cfg.enable && isDarwin) {
    environment.systemPackages = with pkgs; [
      swift
      sourcekit-lsp
    ];
  };
}
