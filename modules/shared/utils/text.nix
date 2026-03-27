{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bat # Better cat with syntax highlighting
    fd # Better find
    fzf # Better find
    jq # JSON processor
    ripgrep # Silver searcher plus grep
    ripgrep-all # Ripgrep for extended file types
    sd # Better sed
    yq # Command-line YAML, JSON, XML, and TOML processor
    exiftool # Read and write EXIF metadata
    poppler-utils # PDF manipulation
    qpdf # PDF manipulation
    pdftk # PDF manipulation
    # xpdf # PDF viewer disabled because of CVE-2023-26930
  ];
}
