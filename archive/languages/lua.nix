{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Lua Runtime & Tools ---
    lua
    luarocks

    # --- Lua Language Server & Formatter ---
    lua-language-server
    stylua
  ];
}
