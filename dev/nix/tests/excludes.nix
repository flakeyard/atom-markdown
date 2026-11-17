# The project's global excludes, pre-commit.settings.excludes, apply to the
# check as to the hooks: the failing files of dev/fixtures/bad pass once
# excluded, and still fail when the excludes name other files.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      excluding =
        excludes:
        (fixture {
          name = "bad";
          module.perSystem.pre-commit.settings = { inherit excludes; };
        }).checks.${system}.markdown;
      failure = pkgs.testers.testBuildFailure (excluding [ ''^other\.md$'' ]);
    in
    {
      checks.test-excluded = excluding [ ''^(lint|links)\.md$'' ];
      checks.test-not-excluded = pkgs.runCommand "test-not-excluded" { } ''
        log=${failure}/testBuildFailure.log
        cat "$log"
        grep -F 'MD001' "$log"
        grep -F 'missing.md' "$log"
        touch $out
      '';
    };
}
