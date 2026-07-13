{
  dotfilesLib,
  pkgs,
  ...
}:
let
  themeColors = dotfilesLib.palette;
in
{
  programs.nushell.extraEnv = ''
    $env.ENV_CONVERSIONS = {
      "PATH": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
      }
      "Path": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
      }
    }

    $env.NU_LIB_DIRS = [
      ($nu.default-config-dir | path join 'scripts')
      ($nu.data-dir | path join 'completions')
    ]

    $env.NU_PLUGIN_DIRS = [
      ($nu.default-config-dir | path join 'plugins')
    ]

    if ($nu.is-interactive and $env.config.color_config? != null) {
      $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')
    }
  '';

  programs.nushell.extraConfig = ''
    if $nu.is-interactive {
      ^sh -c 'test -t 1'
      if $env.LAST_EXIT_CODE == 0 {
        source ${pkgs.nu_scripts}/share/nu_scripts/themes/nu-themes/birds-of-paradise.nu
        $env.config.color_config = ($env.config.color_config | upsert background '${themeColors.bg-primary}')
      }
    }
  '';
}
