{pkgs, ...}: {
  home.packages = with pkgs; [
    # LLM Gui / Server
    # lm-studio  # Available via Homebrew on Darwin (lm-studio cask)
    # LLM Agent
    opencode
    claude-code
  ];

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    settings = {
      provider = {
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (local)";
          options = {
            baseURL = "http://127.0.0.1:1234/v1";
          };
          models = {
            "zai-org/glm-4.6v-flash" = {
              name = "GLM-4.6V-Flash (local)";
            };
            "liquid/lfm2.5-1.2b" = {
              name = "LF-M 2.5-1.2B (local)";
            };
          };
        };
      };
    };
  };
}
