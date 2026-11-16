# A project whose Markdown passes both checks: links to a file, to an anchor
# in it and in the same file, from the root, to a directory and to a file
# that is not Markdown, and an external link that only the app checks. Its
# YAML and JSON, which prettier would change, are left alone.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    let
      inherit (fixture { name = "good"; }) checks;
    in
    {
      checks.test-good = checks.${system}.markdown;
      checks.test-good-format = checks.${system}.treefmt;
    };
}
