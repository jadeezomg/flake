_: {
  programs.helix.languages = {
    language-server = {
      rust-analyzer = {
        command = "rust-analyzer";
      };
      # metals = {
      #   command = "metals";
      # };
      # gopls = {
      #   command = "gopls";
      # };
      # "pyright-extended" = {
      #   command = "pyright-langserver";
      #   args = [ "--stdio" ];
      # };
      texlab = {
        command = "texlab";
      };
      nil = {
        command = "nil";
      };
      "lua-ls" = {
        command = "lua-language-server";
      };
      # taplo = {
      #   command = "taplo";
      #   args = [
      #     "lsp"
      #     "stdio"
      #   ];
      # };
      "yaml-language-server" = {
        command = "yaml-language-server";
        args = [ "--stdio" ];
      };
      "typescript-language-server" = {
        command = "typescript-language-server";
        args = [ "--stdio" ];
      };
      "tailwindcss-language-server" = {
        command = "tailwindcss-language-server";
        args = [ "--stdio" ];
      };
      "vscode-html-language-server" = {
        command = "vscode-html-language-server";
        args = [ "--stdio" ];
      };
      "vscode-css-language-server" = {
        command = "vscode-css-language-server";
        args = [ "--stdio" ];
      };
      bash-language-server = {
        command = "bash-language-server";
        args = [ "start" ];
      };
      clangd = {
        command = "clangd";
      };
      # clojure-lsp = {
      #   command = "clojure-lsp";
      # };
      # elixir-ls = {
      #   command = "elixir-ls";
      # };
      # elm-language-server = {
      #   command = "elm-language-server";
      # };
      # haskell-language-server = {
      #   command = "haskell-language-server-wrapper";
      #   args = [ "--lsp" ];
      # };
      # intelephense = {
      #   command = "intelephense";
      #   args = [ "--stdio" ];
      # };
      # jdt-language-server = {
      #   command = "jdt-language-server";
      # };
      # kotlin-language-server = {
      #   command = "kotlin-language-server";
      # };
      # marksman = {
      #   command = "marksman";
      #   args = [ "server" ];
      # };
      nixd = {
        command = "nixd";
      };
      # ocaml-lsp = {
      #   command = "ocamllsp";
      # };
      # omnisharp = {
      #   command = "omnisharp";
      #   args = [ "-lsp" ];
      # };
      # perlnavigator = {
      #   command = "perlnavigator";
      #   args = [ "--stdio" ];
      # };
      # sourcekit-lsp = {
      #   command = "sourcekit-lsp";
      # };
      sqls = {
        command = "sqls";
      };
      # zls = {
      #   command = "zls";
      # };
    };
  };
}
