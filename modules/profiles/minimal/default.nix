# minimal — system core + the user baseline HM halves (shells, ssh, sops
# plumbing, nix client settings). Always on, including the server.
{
  dotfilesLib,
  isDarwin,
  lib,
  ...
}@args:
dotfilesLib.mkProfile {
  path = [ "minimal" ];
  hm = [
    ./shells
    ./network
    ./git.nix
    ./nix-client.nix
    ./security.nix
  ]
  ++ lib.optionals (!isDarwin) [ ./linux ]
  ++ lib.optionals isDarwin [ ./darwin ];

  packages = dotfilesLib.minimalPackages;
} args
