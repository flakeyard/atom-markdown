# The app markdown-links in a git checkout of a project, without network
# access, which the links of these projects do not need: it reports the
# broken links of dev/fixtures/bad from a subdirectory, also those from the
# root, but not the CHANGELOG.md that atom-workspace excludes, and passes
# dev/fixtures/configs/lychee with the project's lychee.toml.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      app = name: (fixture { inherit name; }).apps.${system}.markdown-links.program;
      # A git checkout of a fixture with every file tracked.
      checkout = name: ''
        export HOME=$TMPDIR
        cp -r --no-preserve=mode ${root + "/dev/fixtures/${name}"} ${name}
        git -C ${name} init --quiet
        git -C ${name} add --all
      '';
    in
    {
      checks.test-app =
        pkgs.runCommand "test-app"
          {
            # lychee builds its HTTP client, which needs CA certificates.
            nativeBuildInputs = [
              pkgs.cacert
              pkgs.git
            ];
          }
          ''
            ${checkout "bad"}
            mkdir bad/sub
            if (cd bad/sub && ${app "bad"}) >log 2>&1; then
              cat log
              exit 1
            fi
            cat log
            grep -F 'links.md' log
            grep -F 'docs/missing.md' log
            grep -F 'links.md#missing-anchor' log
            if grep -F 'changelog-missing.md' log; then exit 1; fi
            mkdir configs
            ${checkout "configs/lychee"}
            (cd configs/lychee && ${app "configs/lychee"})
            touch $out
          '';
    };
}
