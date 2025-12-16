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
  ];
}
