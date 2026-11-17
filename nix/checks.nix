# checks.markdown: the hooks markdownlint and lychee, as the project's
# configuration holds them, without network access (FY-0017). Built with
# lib.<system>.run of git-hooks.nix from only these hooks and the project's
# global excludes, so pre-commit selects the files by `files`, `types` and
# `excludes` as the installed hook does. Its source is the whole project:
# links in Markdown lead to files of every kind and to directories, which
# lychee checks.
{ git-hooks }:
{ self, ... }:
{
  _file = ./checks.nix;

  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit) settings;
      warning = import ./warning.nix {
        inherit lib;
        file = ./next-major.nix;
      };
      # Every option of the project's hook; raw is computed from the others.
      hook = name: removeAttrs settings.hooks.${name} [ "raw" ];
    in
    {
      checks.markdown = warning (
        git-hooks.lib.${system}.run {
          src = self.outPath;
          hooks = {
            markdownlint = hook "markdownlint";
            # lychee builds its HTTP client, which needs CA certificates, also
            # with --offline; the sandbox has none.
            lychee = hook "lychee" // {
              extraPackages = settings.hooks.lychee.extraPackages ++ [ pkgs.cacert ];
            };
          };
          inherit (settings) excludes package gitPackage;
        }
      );
    };
}
