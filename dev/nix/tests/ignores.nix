# The ignore files that the tools read themselves, in the hooks and in the
# checks alike (FY-0037): prettier skips the files of .prettierignore and
# .gitignore, markdownlint those of .markdownlintignore, and lychee the links
# that match .lycheeignore. Each other file of the project fails one tool
# without its ignore file.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      project = fixture { name = "ignores"; };
      inherit (project.checks.${system}) markdown treefmt;
      inherit (project.allSystems.${system}.treefmt.settings.formatter) prettier;
      # prettier as treefmt runs it, which rewrites the files named on the
      # command line.
      format = "${prettier.command} ${lib.escapeShellArgs prettier.options}";
      original = root + "/dev/fixtures/ignores/gitignored.md";
    in
    {
      checks.test-ignores = markdown;
      # checks.treefmt formats the tracked files only, so it never names
      # gitignored.md; the hook names a file that is tracked although
      # .gitignore lists it. prettier leaves it as it is, and formats it
      # without .gitignore.
      checks.test-ignores-format = pkgs.runCommand "test-ignores-format" { } ''
        echo ${treefmt}
        cp -r --no-preserve=mode ${root + "/dev/fixtures/ignores"} ignores
        cd ignores
        ${format} gitignored.md
        cmp gitignored.md ${original}
        rm .gitignore
        ${format} gitignored.md
        if cmp gitignored.md ${original}; then exit 1; fi
        touch $out
      '';
    };
}
