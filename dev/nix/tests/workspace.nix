# The atom in a project with atom-workspace: prettier formats only Markdown
# through the hook treefmt and the substitutable checks.treefmt,
# checks.pre-commit is off, devShells.default holds the three tools, and the
# app markdown-links exists.
{ testing, ... }:
{
  perSystem = testing.workspace (
    {
      pkgs,
      flake,
      system,
    }:
    {
      formatters.prettier = pkgs.prettier;
      packages = {
        inherit (pkgs) prettier lychee;
        markdownlint = pkgs.markdownlint-cli;
      };
      facts = {
        "prettier formats only Markdown" =
          flake.allSystems.${system}.treefmt.settings.formatter.prettier.includes == [ "*.md" ];
        "the app markdown-links exists" = flake.apps.${system} ? markdown-links;
      };
    }
  );
}
