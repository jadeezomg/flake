# Base Caya profile: settings, search, extensions, containers.
# Not overwritten by the session sync script.
{
  pkgs,
  extensions,
  ...
}: {
  settings = (import ../../settings.nix)
    // {
      "zen.workspaces.natural-scroll" = false;
    };

  search = import ../../search.nix {inherit pkgs;};

  profileExtensions = {
    "{d634138d-c276-4fc8-924b-40a0ea21d284}" = extensions.mkExtensionEntry {
      id = "1password-x-password-manager";
      pinned = true;
    };
  };

  containersForce = true;
  containers = {
    "Automations" = {
      color = "blue";
      icon = "briefcase";
      id = 1;
    };
    "Forwarding" = {
      color = "yellow";
      icon = "cart";
      id = 2;
    };
  };
}
