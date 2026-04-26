{...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        ratio = [3 3 4];
        show_hidden = true;
        show_symlink = true;
        linemode = "size_and_mtime";
      };
    };

    initLua = ./init.lua;

    # Plugins/flavors go here as `name = ./path/to/foo.yazi;` once added.
    # See https://yazi-rs.github.io/docs/plugins/overview
    plugins = {};
    flavors = {};
  };
}
