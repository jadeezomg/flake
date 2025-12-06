{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # IDEs
    zed-editor
    code-cursor
  ];
}

