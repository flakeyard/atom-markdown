# The ignore files that the tools read themselves, in the hooks and in the
# checks alike (FY-0037): prettier skips the files of .prettierignore and
# .gitignore, markdownlint those of .markdownlintignore, and lychee the links
# that match .lycheeignore. Each other file of the project fails one tool
# without its ignore file.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    let
      inherit (fixture { name = "ignores"; }) checks;
    in
    {
      checks.test-ignores = checks.${system}.markdown;
      checks.test-ignores-format = checks.${system}.treefmt;
    };
}
