{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pamixer # PulseAudio cli Mixer
    pavucontrol # PulseAudio Control Center
    playerctl # Media player controller
    wireplumber # PipeWire Session Manager
  ];

  # Enable sound with pipewire.
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  security.rtkit = {
    enable = true;
  };
}
