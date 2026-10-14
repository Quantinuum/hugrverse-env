{ pkgs, ... }: {
  packages = [
    pkgs.actionlint
    pkgs.shellcheck
    pkgs.jq
    (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
  ];
}
