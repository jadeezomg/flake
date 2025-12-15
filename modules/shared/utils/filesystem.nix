{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    eza # Better ls, not really needed because of nushell's ls
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
    unzip # Extract ZIP archives
    zip # Create ZIP archives
  ];
}
