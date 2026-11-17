# The formatter prettier of treefmt-nix, for Markdown only (FY-0017): the
# other files that prettier can format belong to other atoms. prettier gets
# the configuration that the project chose by --config (FY-0037) and still
# reads .editorconfig, whose values the chosen file overrides, .prettierignore
# and .gitignore.
{
  root,
  chosen,
  shared,
}:
{ lib, self, ... }:
let
  # The standard names and the forms that prettier ignores with --config,
  # from lib-atom, which atom-data-formats also takes (FY-0040).
  config' = chosen (
    {
      tool = "prettier";
      default = root + "/config/prettier.json";
    }
    // shared.prettier {
      inherit lib;
      project = self.outPath;
    }
  );
in
{
  _file = ./formatter.nix;

  config.perSystem =
    { pkgs, ... }:
    {
      treefmt.programs.prettier = {
        enable = lib.mkOverride 900 true;
        package = lib.mkOverride 900 pkgs.prettier;
        # treefmt-nix also includes JSON, YAML, MDX and web files.
        includes = lib.mkOverride 900 [ "*.md" ];
      };
      # A plain definition, since treefmt-nix defines the list at plain
      # priority (FY-0017). treefmt-nix adds a --config of its own only when
      # programs.prettier.settings is set.
      treefmt.settings.formatter.prettier.options = [
        "--config"
        "${config'.file}"
      ];
    };
}
