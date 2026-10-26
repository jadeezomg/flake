{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  gettext,
  glib,
  python3,
}:
let
  # callPackage cannot pass dotfilesLib, so import the guard directly.
  expiry = import ../../lib/expiry.nix { inherit lib; } "packages/nautilus-my-computer/default.nix";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nautilus-my-computer";
  version = "0.13.3";

  src = fetchFromGitHub {
    owner = "yannmasoch";
    repo = "nautilus-my-computer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-UW1BqLQItzjpcALXzu+Zgr3He0XFYTcDmbFvW5lCVKo=";
  };

  # 0.13.3 crashes Nautilus when you open Network from List view:
  # https://github.com/yannmasoch/nautilus-my-computer/issues/198
  # These two commits from upstream `dev` fix it (tested on dev at ba19800).
  # The guard drops them at 0.13.4, the first release that can contain them.
  patches =
    expiry.expireWhen
      {
        fixed = lib.versionAtLeast finalAttrs.version "0.13.4";
        reason = "upstream is at ${finalAttrs.version}. Make sure that this release contains the #198 fix (ba19800), then remove the patches. https://github.com/yannmasoch/nautilus-my-computer/issues/198";
        fallback = [ ];
      }
      [
        # fix: release native view refs on navigation to stop SIGSEGV (#198)
        (fetchpatch {
          url = "https://github.com/yannmasoch/nautilus-my-computer/commit/d3a635a92f0219d6abd7bc5f40bfa2ccc4816b02.patch";
          hash = "sha256-APZLq2kgmMolPvdD2Oavm3VzDpj2jpPyEdPAFv1Ng38=";
        })
        # fix: hold native model weakly in NativeBridge instead of view refs (#198)
        (fetchpatch {
          url = "https://github.com/yannmasoch/nautilus-my-computer/commit/ba19800524a81748efec209b087419d32a8d37bc.patch";
          hash = "sha256-CFlQ0BAONbAek21jSMyHz8jyfC52JrN4hWngECSXM+w=";
        })
      ];

  # The extension imports `cairo`. The nautilus-python host only puts
  # pygobject on sys.path, so add pycairo in the entry file.
  postPatch = ''
    substituteInPlace nautilus-my-computer.py \
      --replace-fail \
        'sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))' \
        'sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.path.append("${python3.pkgs.pycairo}/${python3.sitePackages}")'

    # GLib aborts Nautilus when a schema is not on XDG_DATA_DIRS, and Nautilus
    # often starts without it (D-Bus activation, nushell). Load the schema
    # from this package. The glib setup hook moves it to gsettings-schemas.
    substituteInPlace nautilus_my_computer/main.py \
      --replace-fail \
        'return Gio.Settings.new(SCHEMA_ID)' \
        'return Gio.Settings.new_full(Gio.SettingsSchemaSource.new_from_directory("${placeholder "out"}/share/gsettings-schemas/${finalAttrs.finalPackage.name}/glib-2.0/schemas", Gio.SettingsSchemaSource.get_default(), False).lookup(SCHEMA_ID, False), None, None)'
  '';

  nativeBuildInputs = [
    gettext # msgfmt for the .po catalogs
    glib # glib-compile-schemas
    python3 # py_compile check in `make build`
  ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  # Nautilus loads it from share/nautilus-python/extensions. The GNOME module
  # links that path and sets NAUTILUS_4_EXTENSION_DIR.
  meta = {
    description = "My Computer view for Nautilus: drives, volumes, and network mounts with usage";
    homepage = "https://github.com/yannmasoch/nautilus-my-computer";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
