pkgs:
with pkgs; [
  # --- Search, find, path memory ---
  ripgrep
  fd
  fzf
  television
  zoxide
  broot

  # --- List, preview, file browser ---
  bat
  eza
  yazi

  # --- Structured data & text transforms ---
  jq
  yq
  sd

  # --- Disk, processes, quick benchmarks ---
  dust
  dua
  btop
  lsof
  hyperfine

  # --- HTTP, DNS, reachability ---
  curl
  wget
  dig
  xh
  gping

  # --- Diffs & readable patches ---
  difftastic
  delta

  # --- PDF helpers (pdftotext, etc.) ---
  poppler-utils

  # --- Archives & core file utilities ---
  file
  gawk
  libarchive
  p7zip
  unzip
  zip

  # --- Nix store / flake workflow ---
  git
  nh
  nix-index
]
