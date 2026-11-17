# Binaries Noctalia shells out to (plugins + screenshot pipe_to_command).
{ pkgs }:
with pkgs;
[
  satty # shell.screenshot pipe_to_command in config.toml

  # alexander/screen-toolkit plugin. Missing tools only break the feature that
  # needs them. `stat`, `pkill`, and `xdg-open` come from the system profile.
  curl # share uploads, Google Lens
  ffmpeg # recording thumbnail, MP4 finalize, GIF conversion (ships ffprobe)
  gpu-screen-recorder # fullscreen recording backend (NVENC)
  hyprpicker # color picker
  imagemagick # `magick`: crops, palette, OCR preprocessing
  jq # share/Lens JSON parsing
  pulseaudio # `pactl`: default audio source for wl-screenrec/wf-recorder
  qrencode # QR image for shared links
  slurp # region recording geometry, annotate-window click waiter
  tesseract # OCR; the nixpkgs build already ships the language packs
  translate-shell # `trans`: OCR translation
  wf-recorder # recording fallback
  wl-screenrec # preferred region recording backend
  zbar # `zbarimg`: QR/barcode decoding
]
