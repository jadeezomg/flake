{
  config,
  lib,
  ...
}:
let
  cfg = config.maintenance.garbageCollection;
in
{
  options.maintenance.garbageCollection = {
    enable = lib.mkEnableOption "Automatic Nix store garbage collection";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "How often to run garbage collection (systemd timer format)";
      example = "daily";
    };

    deleteOlderThan = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Delete generations older than this";
      example = "7d";
    };
  };

  config = {
    maintenance.garbageCollection.enable = lib.mkDefault true;

    nix.gc = lib.mkIf cfg.enable {
      automatic = true;
      dates = cfg.schedule;
      options = "--delete-older-than ${cfg.deleteOlderThan}";
    };
  };
}
