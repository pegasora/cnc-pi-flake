{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
  ];

  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  scripts = {
    run-slave.exec = ''
      python src/slave.py
    '';
  };

  # https://devenv.sh/basics/
  enterShell = ''
    echo "======================================"
    echo "CNC Simulator Development Environment"
    echo "======================================"
    echo "Python: $(python --version)"
    echo ""
    echo "Available commands:"
    echo "  run-slave  - Run Modbus slave (server) on port 502"
    echo ""
    echo "======================================"
  '';

  # See full reference at https://devenv.sh/reference/options/
}
