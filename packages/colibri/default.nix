{
  pkgs,
  lib,
  cudaSupport ? false,
}:
let
  inherit (pkgs)
    stdenv
    gnumake
    python3
    fetchFromGitHub
    cudaPackages
    ;

  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "JustVugg";
    repo = "colibri";
    rev = "v${version}";
    hash = "sha256-GnUyW6XasJ7nTedRjvHa3zkMHC8no1LDd65foQa973s=";
  };

  engine = stdenv.mkDerivation {
    pname = "colibri";
    inherit version src;

    sourceRoot = "${src.name}/c";

    nativeBuildInputs = [
      gnumake
      pkgs.autoPatchelfHook
    ]
    ++ lib.optionals cudaSupport [
      cudaPackages.cudatoolkit
    ];

    buildInputs = [
      stdenv.cc.cc.lib
    ]
    ++ lib.optionals cudaSupport [
      cudaPackages.cudatoolkit
    ];

    enableParallelBuilding = true;

    env = lib.optionalAttrs cudaSupport {
      CUDA_HOME = cudaPackages.cudatoolkit;
    };

    makeFlags = lib.optionals cudaSupport [ "CUDA=1" ];

    buildPhase = ''
      runHook preBuild
      make colibri olmoe $makeFlags
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      make install PREFIX=$out BINDIR=$out/bin LIBEXECDIR=$out/libexec/colibri $makeFlags
      runHook postInstall
    '';

    meta = with lib; {
      description = "Colibrì — MoE inference runtime for GLM-5.2 (stream experts from disk)";
      homepage = "https://github.com/JustVugg/colibri";
      license = licenses.asl20;
      mainProgram = "coli";
      platforms = platforms.linux;
      sourceProvenance = with sourceTypes; [ fromSource ];
    };
  };
in
pkgs.symlinkJoin {
  name = "colibri-${version}";
  paths = [ engine ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/coli --prefix PATH : ${lib.makeBinPath [ python3 ]}
  '';
  meta = engine.meta;
}
