# A project whose Markdown fails: checks.markdown reports the finding of
# markdownlint, a missing file, a missing anchor and a missing file from the
# root, but not the CHANGELOG.md that atom-workspace excludes; checks.treefmt
# reports the file that prettier would change.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (fixture { name = "bad"; }) checks;
      failure = check: pkgs.testers.testBuildFailure checks.${system}.${check};
    in
    {
      checks.test-bad = pkgs.runCommand "test-bad" { } ''
        log=${failure "markdown"}/testBuildFailure.log
        cat "$log"
        grep -F 'lint.md:3 error MD001/heading-increment' "$log"
        grep -F 'missing.md' "$log"
        grep -F 'links.md#missing-anchor' "$log"
        grep -F 'docs/missing.md' "$log"
        if grep -F 'changelog-missing.md' "$log"; then exit 1; fi
        if grep -F 'unformatted.md' "$log"; then exit 1; fi
        touch $out
      '';
      checks.test-bad-format = pkgs.runCommand "test-bad-format" { } ''
        log=${failure "treefmt"}/testBuildFailure.log
        cat "$log"
        grep -F 'unformatted.md' "$log"
        if grep -F 'CHANGELOG.md' "$log"; then exit 1; fi
        touch $out
      '';
    };
}
