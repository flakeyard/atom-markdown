# markdownlint-cli merges the .markdownlint* file of the working directory,
# the user's ~/.markdownlintrc and the variables markdownlint_* under the file
# of -c. With the default, which sets every value, they change nothing
# (FY-0037): the hook reports the same findings with files and variables that
# switch rules off, through rule names, aliases, tags and "default", as
# without them. A minimal file of -c, as the control, lets them through.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit ((fixture { name = "good"; }).allSystems.${system}.pre-commit.settings.hooks.markdownlint)
        entry
        ;
      markdownlint = builtins.head (pkgs.lib.splitString " " entry);
    in
    {
      checks.test-markdownlint-merge = pkgs.runCommand "test-markdownlint-merge" { } ''
        cp --no-preserve=mode ${root + "/dev/fixtures/bad/lint.md"} lint.md
        {
          echo
          echo "A line of prose that is longer than eighty characters, which the rule MD013 reports here."
          echo
          echo "| a table row that is longer than eighty characters | which the rule MD013 also reports |"
          echo "| --- | --- |"
        } >>lint.md
        mkdir home
        export HOME=$PWD/home
        ${entry} lint.md >clean.log 2>&1 && exit 1
        cat clean.log
        grep -F MD001 clean.log
        grep -F 'lint.md:5:81 error MD013' clean.log
        grep -F 'lint.md:7:81 error MD013' clean.log
        cat >home/.markdownlintrc <<'JSON'
        {
          "MD013": { "tables": false, "line_length": 200 },
          "line-length": false,
          "heading-increment": { "enabled": false },
          "headings": false,
          "default": false
        }
        JSON
        cat >.markdownlint.yaml <<'YAML'
        MD001: false
        whitespace: false
        line_length: false
        YAML
        export markdownlint_MD013__tables=false markdownlint_default=false
        ${entry} lint.md >merged.log 2>&1 && exit 1
        diff clean.log merged.log
        printf '{ "default": true }\n' >minimal.json
        if ${markdownlint} -c minimal.json lint.md; then
          touch $out
        else
          echo "the discovered files no longer switch rules off; a test of the merge is needed again"
          exit 1
        fi
      '';
    };
}
