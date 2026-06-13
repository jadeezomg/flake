# Base Caya profile: settings, search, extensions, containers.
# Not overwritten by the session sync script.
{
  extensions,
  sharedSearch,
  sharedSettings,
  ...
}: {
  settings =
    sharedSettings
    // {
      "zen.workspaces.natural-scroll" = false;
    };

  search = sharedSearch;

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
    "Errors" = {
      color = "red";
      icon = "fence";
      id = 3;
    };
    "Dev" = {
      color = "green";
      icon = "tree";
      id = 4;
    };
  };
}
