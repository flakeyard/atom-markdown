# The hooks markdownlint and lychee of git-hooks.nix, with the configuration
# that the project chose (FY-0037). Their package, entry and arguments are the
# single definition that the check and the app also run.
{ root }:
{ lib, self, ... }:
let
  chosen = import ./config.nix { inherit lib root self; };
  markdownlint = chosen {
    tool = "markdownlint";
    default = "markdownlint.json";
    # The files that markdownlint-cli finds in the working directory.
    names = [
      ".markdownlint.json"
      ".markdownlint.jsonc"
      ".markdownlint.yaml"
      ".markdownlint.yml"
      ".markdownlintrc"
    ];
  };
  lychee = chosen {
    tool = "lychee";
    default = "lychee.toml";
    names = [ "lychee.toml" ];
  };
in
{
  _file = ./hooks.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
    in
    {
      pre-commit.settings.hooks = {
        markdownlint = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.markdownlint-cli;
          # git-hooks.nix passes -c with a file written from
          # settings.configuration; the atom passes the chosen file instead.
          # markdownlint-cli merges the .markdownlint* file of the working
          # directory and the user's ~/.markdownlintrc under it, so the
          # default sets every value (FY-0037).
          entry = lib.mkOverride 900 "${lib.getExe' hooks.markdownlint.package "markdownlint"} -c ${markdownlint.file}";
        };
        lychee = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.lychee;
          # Markdown only; git-hooks.nix selects every text file.
          files = lib.mkOverride 900 ''\.md$'';
          settings = {
            configPath = lib.mkOverride 900 "${lychee.file}";
            # Links inside the repository, to files, directories and
            # anchors, without network access (FY-0017); all links are
            # checked by the app markdown-links. pre-commit runs the hook
            # from the root of the project, which links that start with /
            # are relative to.
            flags = lib.mkOverride 900 "--offline --include-fragments --root-dir .";
          };
        };
      };
    };
}
