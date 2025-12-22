# Shared configuration values used across all shells
{
  # Nix/Home Manager configuration
  nixConfig = {
    homeManagerFlake = "home-manager/master";
    flakeBuildScript = "build/flake.nu";
  };

  # Oh My Posh configuration
  ohMyPoshConfig = {
    themeName = "birds-of-paradise.json";
    configDir = ".config/oh-my-posh";
    themePath = "$HOME/.config/oh-my-posh/birds-of-paradise.json";
    schemaUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
  };
}
