{
  pkgs,
  pkgs-stable,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # IDEs
    pkgs-stable.zed-editor
    code-cursor
  ];
}
