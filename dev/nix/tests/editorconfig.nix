# prettier reads .editorconfig and the chosen configuration overrides it
# (FY-0037). With a project's configuration that sets no width, prettier
# wraps at the max_line_length of .editorconfig; with the default, which sets
# every value, the width, indentation and line endings of .editorconfig do
# not apply.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    let
      format = name: (fixture { inherit name; }).checks.${system}.treefmt;
    in
    {
      checks.test-editorconfig = format "editorconfig";
      checks.test-editorconfig-default = format "editorconfig-default";
    };
}
