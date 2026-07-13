{ ... }: {
  programs.zed-editor = {
    userTasks = [
      {
        label = "worktree: copy untracked dotfiles";
        command = "sh";
        args = [
          "-c"
          ''for f in .flake-host .env .envrc .direnv; do [ -e "$ZED_MAIN_GIT_WORKTREE/$f" ] && cp -R "$ZED_MAIN_GIT_WORKTREE/$f" "$ZED_WORKTREE_ROOT/" || true; done''
        ];
        hooks = [ "create_worktree" ];
        reveal = "no_focus";
        hide = "on_success";
      }

      {
        label = "worktree: warm claude-sandbox devshell";
        command = "nix";
        args = [
          "develop"
          "$ZED_MAIN_GIT_WORKTREE#claude-sandbox"
          "--command"
          "true"
        ];
        cwd = "$ZED_WORKTREE_ROOT";
        hooks = [ "create_worktree" ];
        reveal = "no_focus";
        hide = "on_success";
      }

      {
        label = "worktree: launch claude-sandbox";
        command = "nix";
        args = [
          "develop"
          "$ZED_MAIN_GIT_WORKTREE#claude-sandbox"
          "--command"
          "claude-sandboxed"
          "--dangerously-skip-permissions"
        ];
        cwd = "$ZED_WORKTREE_ROOT";
        env = {
          GIT_AUTHOR_NAME = "claude";
          GIT_COMMITTER_NAME = "claude";
        };
        hooks = [ "create_worktree" ];
        use_new_terminal = true;
        allow_concurrent_runs = true;
        reveal = "no_focus";
        hide = "never";
      }

      {
        label = "agent: attach claude-sandbox to current worktree";
        command = "nix";
        args = [
          "develop"
          ".#claude-sandbox"
          "--command"
          "claude-sandboxed"
          "--dangerously-skip-permissions"
        ];
        cwd = "$ZED_WORKTREE_ROOT";
        use_new_terminal = true;
        allow_concurrent_runs = true;
        reveal = "no_focus";
        hide = "never";
      }
    ];
  };
}
