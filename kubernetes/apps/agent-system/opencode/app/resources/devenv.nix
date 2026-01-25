{ pkgs, inputs, ... }:

{
  # Declarative toolchain
  languages.python.enable = true;
  languages.python.uv.enable = true;
  languages.javascript.enable = true;
  languages.javascript.bun.enable = true;
  languages.go.enable = true;

  packages = [
    inputs.opencode.packages.${pkgs.system}.default
    pkgs.git
    pkgs.curl
    pkgs.kubectl
    pkgs.fluxcd
    pkgs.talosctl
    pkgs.crane
    pkgs.gh
    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
  ];

  # OpenCode Server
  processes.opencode.exec = "opencode --host 0.0.0.0 --port 4096";

  # Setup for the AI agent
  enterShell = ''
    echo "--- AGENT SYSTEM LOADED ---"
    cat ./AGENTS.md
  '';
}
