# devShells.flakeyard-markdown: the tools of the domain for people
# (FY-0017); atom-workspace joins it into devShells.default.
{
  _file = ./shell.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
      warning = import ./warning.nix {
        inherit (pkgs) lib;
        file = ./next-major.nix;
      };
    in
    {
      devShells.flakeyard-markdown = warning (
        pkgs.mkShellNoCC {
          packages = [
            config.treefmt.programs.prettier.package
            hooks.markdownlint.package
            hooks.lychee.package
          ];
        }
      );
    };
}
