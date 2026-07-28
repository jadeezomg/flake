# Binaries Noctalia shells out to (plugins + screenshot pipe_to_command).
{ pkgs }:
with pkgs;
[
  gpu-screen-recorder # noctalia/screen_recorder plugin
  satty # shell.screenshot pipe_to_command in config.toml
]
