{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
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
      sudo python src/slave.py
    '';
    run-master.exec = ''
      python src/master.py "$@"
    '';
    test-cycle.exec = ''
      python src/master.py --test-cycle "$@"
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
    echo "  run-slave    - Run Modbus slave (server) on port 502"
    echo "  run-master   - Run test master client"
    echo "  test-cycle   - Test start/stop cycle (simulate CLICK PLC)"
    echo ""
    echo "======================================"
  '';

  # See full reference at https://devenv.sh/reference/options/
}
