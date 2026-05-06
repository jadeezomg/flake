# Registry of all machines: metadata for each lives next to its system module in
# `hosts/<hostname-key>/host.nix` (this file only aggregates).
{
  hosts = {
    framework = import ./framework/host.nix;
    desktop = import ./desktop/host.nix;
    caya = import ./caya/host.nix;
    mini = import ./mini/host.nix;
  };
}
