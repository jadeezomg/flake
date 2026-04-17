{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    # LLM Agent
    opencode
    claude-code

    # Forge (tailcallhq/forgecode) — AI pair programmer CLI
    inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.default

    # docs CLI
    (pkgs.callPackage ../../../../packages/context7 {})

    # Kagi search/summarizer via session token (unofficial)
    (pkgs.callPackage ../../../../packages/kagi-ken-cli {})
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
  };
}
