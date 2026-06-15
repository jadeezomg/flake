# Intel GPU trait (dotfiles.hardware.gpu = "intel") — iGPU and/or Arc dGPU.
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.dotfiles.hardware.gpu == "intel") {
    hardware.graphics.enable = true;

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
      nvtopPackages.intel
    ];

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
