{ ... }:

{
  programs = {
    fzf = {
      enable = true;
      defaultCommand = "fd --type f --strip-cwd-prefix";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
        "--preview='bat --color=always --style=plain {}'"
      ];
      fileWidgetCommand = "fd --type f";
      fileWidgetOptions = [
        "--preview='bat --color=always --style=plain {}'"
      ];
      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = [
        "--preview='tree -C {} | head -40'"
      ];
    };
  };
}
