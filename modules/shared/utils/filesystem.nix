{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    eza # Better ls
    dust # Better disk usage
    broot # Interactive tree view
    difftastic # Better diff
    dua # Interactive disk usage analyzer
    file # Determine file types
    gawk # GNU's awk
    libarchive # Compression library
    lsof # Tool to list open files
    ncdu # NCurses disk usage analyzer
    p7zip # 7-Zip archiver
    rar # RAR archives
    unzip # Extract ZIP archives
    zip # Create ZIP archives
    zstd # Compression algorithm (optional Emacs dep)
  ];
}
