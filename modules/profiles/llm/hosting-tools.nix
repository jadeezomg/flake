# Shared CLI tools for LLM hosting hosts (desktop `profiles.llm` + mini `./services/llm`).
{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.python314Packages.huggingface-hub ];
}
