{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    awscli2 # Main AWS Cli
    awslogs # Better AWS CloudWatch Logs
    postman # API client
    inputs.google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default # Google Workspace CLI
  ];
}
