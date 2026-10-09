# EasyEffects — PipeWire audio effects with a GUI. Used for loudness
# normalization (Autogain + Limiter on the output chain). The daemon starts
# with the session; open `easyeffects` to build and tweak presets. Presets
# stay mutable under ~/.config/easyeffects, so this module only starts it.
{ ... }:
{
  services.easyeffects.enable = true;
}
