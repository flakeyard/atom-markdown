# config/prettier.json sets every option of the prettier that the atom runs
# that decides how files are formatted: all but those that name the input or
# a part of it, cursorOffset, filepath, parser, plugins, rangeStart and
# rangeEnd. A new option of prettier, or a typo, fails.
{ root, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.treefmt.programs.prettier) package;
    in
    {
      checks.test-prettier-options =
        pkgs.runCommand "test-prettier-options" { nativeBuildInputs = [ pkgs.jq ]; }
          ''
            ${pkgs.lib.getExe package} --support-info \
              | jq '[.options[].name] - ["cursorOffset", "filepath", "parser", "plugins", "rangeStart", "rangeEnd"] | sort' \
              >options.json
            jq 'keys' ${root + "/config/prettier.json"} >config.json
            diff options.json config.json
            touch $out
          '';
    };
}
