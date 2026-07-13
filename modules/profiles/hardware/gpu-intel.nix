# Intel GPU trait (dotfiles.hardware.gpu = "intel") — iGPU and/or Arc dGPU.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.dotfiles.hardware.gpu == "intel") {
    hardware.graphics = {
      enable = true;
      # enableRedistributableFirmware = true;
      extraPackages = with pkgs; [
        # Required for modern Intel GPUs (Xe iGPU and ARC)
        intel-media-driver # VA-API (iHD) userspace
        vpl-gpu-rt # oneVPL (QSV) runtime

        # Optional (compute / tooling):
        intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
      ];
    };

    environment = {
      sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";
      };
      systemPackages = with pkgs; [
        intel-gpu-tools
        nvtopPackages.intel
      ];
    };

    boot.kernelParams = [ "i915.enable_guc=3" ];

    # CAP_PERFMON wrappers so the GPU monitors read the perf PMU without sudo
    # (perf_event_paranoid blocks unprivileged perf access). /run/wrappers/bin
    # precedes the user profile in PATH, so `btop`/`gputop` hit these wrappers.
    #   - btop: shows the i915 iGPU (utilisation/power/clock); it has no xe
    #     support, so the Arc dGPU never appears there.
    #   - gputop: the xe-aware igt monitor; the only tool here that reads the
    #     Arc Battlemage dGPU (per-client engine stats under load).
    security.wrappers = {
      btop = {
        owner = "root";
        group = "root";
        capabilities = "cap_perfmon+ep";
        source = "${pkgs.btop}/bin/btop";
      };
      gputop = {
        owner = "root";
        group = "root";
        capabilities = "cap_perfmon+ep";
        source = "${pkgs.intel-gpu-tools}/bin/gputop";
      };
    };
  };
}
