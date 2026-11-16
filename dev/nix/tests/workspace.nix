# The atom in a project with atom-workspace: prettier formats only Markdown
# through the hook treefmt and the substitutable checks.treefmt,
# checks.pre-commit is off, devShells.default holds the three tools, and the
# app markdown-links exists.
{ facts, fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      flake = fixture { name = "good"; };
      values = flake.allSystems.${system};
      inherit (values.treefmt.settings.formatter) prettier;
      checks = flake.checks.${system};
      shell = flake.devShells.${system}.default;
      # The shell holds the output out of a package, not its first output.
      holds = package: lib.elem package.out shell.nativeBuildInputs;
    in
    {
      checks.test-workspace = facts pkgs "test-workspace" {
        "treefmt runs prettier of the project's nixpkgs" = prettier.command == lib.getExe pkgs.prettier;
        "prettier formats only Markdown" = prettier.includes == [ "*.md" ];
        "the hook treefmt is enabled" = values.pre-commit.settings.hooks.treefmt.enable;
        "checks.treefmt is substitutable" = checks.treefmt.allowSubstitutes;
        "checks.pre-commit is off" = !(checks ? pre-commit);
        "the shell holds prettier" = holds pkgs.prettier;
        "the shell holds markdownlint" = holds pkgs.markdownlint-cli;
        "the shell holds lychee" = holds pkgs.lychee;
        "the app markdown-links exists" = flake.apps.${system} ? markdown-links;
      };
    };
}
