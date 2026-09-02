# Minimal; disko (./disko.nix) owns `fileSystems.*`. Only kernel modules and
# platform facts live here.
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    # Arc Pro B50 (Battlemage, PCI id e223): the xe driver needs the explicit probe.
    kernelParams = [ "xe.force_probe=e223" ];
  };

  # Static IP managed via NetworkManager profile in default.nix.
  networking.useDHCP = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
