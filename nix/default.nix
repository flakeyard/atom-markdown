# The root module of atom-markdown (FY-0017). It fails when the consumer locks
# treefmt-nix or git-hooks.nix a second time, imports the modules of both and
# the atom's modules. The atom's inputs and the root of the repository reach
# the other files only as function arguments.
atomInputs:
{
  inputs,
  lib,
  self,
  ...
}:
let
  root = ./..;
  # The functions that atoms share, of the revision the atom pins (FY-0040).
  shared = atomInputs.lib-atom.lib;
  upstream = shared.upstream {
    atom = "atom-markdown";
    own = atomInputs;
    consumer = inputs;
  };
  # The warning of the next major version, with lib of the consumer's nixpkgs.
  warning =
    pkgsLib:
    shared.warning {
      lib = pkgsLib;
      atom = "atom-markdown";
      inherit root;
    };
  # The configuration file that the project chose for a tool (FY-0037), with
  # the arguments tool, default, names and unsupported of lib-atom's config.
  chosen = shared.config {
    inherit lib;
    atom = "atom-markdown";
    project = self.outPath;
  };
in
{
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    (upstream "treefmt-nix" atomInputs.treefmt-nix.flakeModule)
    (upstream "git-hooks" atomInputs.git-hooks.flakeModule)
    (import ./formatter.nix { inherit root chosen shared; })
    (import ./hooks.nix { inherit root chosen; })
    (import ./checks.nix {
      inherit (atomInputs) git-hooks;
      inherit warning;
    })
    ./apps.nix
    (import ./shell.nix { inherit warning; })
  ];
}
