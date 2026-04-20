{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # --- Javascript/Typescript/React.js/Next.js ---
    nodejs_24 # Node.js JavaScript runtime
    bun
    mise
    # Kagi client library (pair with kagi-ken-cli in tooling/llm.nix)
    (pkgs.callPackage ../../../../packages/kagi-ken {})
  ];

  home.sessionVariables.NODE_PATH = lib.makeSearchPath "lib/node_modules" [
    (pkgs.callPackage ../../../../packages/kagi-ken {})
  ];
}
