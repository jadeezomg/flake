# sops-nix's installer package (pkgs/sops-install-secrets) still asks for
# `buildGo125Module`. nixpkgs removed that builder after Go 1.25 reached
# end-of-life; the attribute now throws, so every host that evaluates
# `sops.package` (NixOS and Home Manager) fails to build. This overlay points
# the old name at the default Go builder until sops-nix moves on.
#
# Verified 2026-09-17 against sops-nix 13616ff and nixpkgs b1b8759.
{
  expiry,
  inputs,
  lib,
}:
final: _prev: {
  buildGo125Module = expiry.expireWhen {
    fixed =
      !lib.hasInfix "buildGo125Module" (
        builtins.readFile "${inputs.sops-nix}/pkgs/sops-install-secrets/default.nix"
      );
    reason = "sops-nix no longer uses buildGo125Module; drop the alias.";
    fallback = throw "buildGo125Module alias retired: nothing in this flake uses it any more";
  } final.buildGoModule;
}
