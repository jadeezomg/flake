# herdr plugin: file explorer and git source control in one herdr pane.
#
# herdr runs the commands in herdr-plugin.toml from the plugin folder
# (`./target/release/herdr-sidebar`). So the useful output is that folder:
# share/herdr/plugins/herdr-sidebar holds the upstream manifest and scripts,
# with the binary at target/release/. modules/profiles/devenv/agents/
# herdr-plugins.nix links it with `herdr plugin link`, which does not run the
# manifest's [[build]] step (upstream's fetch-or-build.sh).
#
# A linked plugin does not update itself. The "Update sidebar" action and the
# release check act only on `herdr plugin install` copies (updates.rs:
# "Refusing to overwrite a local or third-party checkout"). update-packages
# updates it.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-sidebar";
  version = "0.15.1";

  src = fetchFromGitHub {
    owner = "alexarthurs";
    repo = "herdr-sidebar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6lHSzGKzh6ef6rQXy43BHZgIMhBC4YVs3tDTqW0pRzU=";
  };

  sourceRoot = "${finalAttrs.src.name}/plugins/herdr-sidebar";

  cargoHash = "sha256-5WgmUlLzuBAiQeIx8tgfCT3UDMuH18BQT/+nGL1uKpw=";

  # Some tests run git in a temporary repository.
  nativeCheckInputs = [ git ];
  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  # herdr-sidebar-ensure is the Windows hook sidecar. The manifest uses it on
  # Windows only.
  postInstall = ''
    plugin=$out/share/herdr/plugins/herdr-sidebar
    install -Dm644 herdr-plugin.toml $plugin/herdr-plugin.toml
    cp -r scripts $plugin/scripts
    install -Dm755 $out/bin/herdr-sidebar $plugin/target/release/herdr-sidebar
    rm -r $out/bin
  '';

  meta = {
    description = "herdr plugin: VS Code-style file explorer and git source control in one pane";
    homepage = "https://github.com/alexarthurs/herdr-sidebar";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
