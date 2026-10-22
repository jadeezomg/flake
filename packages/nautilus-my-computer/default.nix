{
  lib,
  stdenv,
  fetchFromGitHub,
  gettext,
  glib,
  python3,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nautilus-my-computer";
  version = "0.13.3";

  src = fetchFromGitHub {
    owner = "yannmasoch";
    repo = "nautilus-my-computer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-UW1BqLQItzjpcALXzu+Zgr3He0XFYTcDmbFvW5lCVKo=";
  };

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
