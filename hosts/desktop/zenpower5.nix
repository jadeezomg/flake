{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  llvmPackages_latest,
}: let
  kernelUsesLLVM = builtins.any (
    flag:
      builtins.match ".*LLVM=1.*" (toString flag)
      != null
      || builtins.match ".*CC=clang.*" (toString flag) != null
  ) (kernel.makeFlags or []);

  buildStdenv =
    if kernelUsesLLVM
    then llvmPackages_latest.stdenv
    else stdenv;
in
  buildStdenv.mkDerivation {
    pname = "zenpower";
    version = "0.5.0-unstable-2026-03-13";

    src = fetchFromGitHub {
      owner = "mattkeenan";
      repo = "zenpower5";
      rev = "66871d8e59c3741e00de2eb1f61c3b64263ed10b";
      hash = "sha256-g0zVTDi5owa6XfQN8vlFwGX+gpRIg+5q1F4EuxAk9Sk=";
    };

    postPatch = lib.optionalString kernelUsesLLVM ''
      substituteInPlace Makefile --replace-fail "-Wimplicit-fallthrough=3" "-Wimplicit-fallthrough"
    '';

    hardeningDisable = ["pic"];

    nativeBuildInputs =
      kernel.moduleBuildDependencies
      ++ lib.optionals kernelUsesLLVM [llvmPackages_latest.lld];

    makeFlags =
      [
        "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ]
      ++ lib.optionals kernelUsesLLVM [
        "LLVM=1"
        "CC=clang"
        "LD=ld.lld"
        "KCFLAGS=-Wno-unused-command-line-argument -Wno-unknown-warning-option"
      ];

    installPhase = ''
      install -D zenpower.ko -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon/zenpower/"
    '';

    meta = {
      homepage = "https://github.com/mattkeenan/zenpower5";
      description = "AMD Zen family CPU sensors driver with Zen 5 support — temperature, SVI2 voltage/current (Zen 1-4), RAPL power";
      license = lib.licenses.gpl2Plus;
      platforms = ["x86_64-linux"];
      broken = lib.versionOlder kernel.version "4.14";
    };
  }
