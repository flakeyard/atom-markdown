# devShells.flakeyard-markdown: the tools of the domain for people
# (FY-0017); atom-workspace joins it into devShells.default.
{ warning }:
{
  _file = ./shell.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
    in
    {
      devShells.flakeyard-markdown = warning pkgs.lib (
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
