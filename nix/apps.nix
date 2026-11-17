# apps.markdown-links: lychee with network access over the tracked Markdown
# files of the project, for the links that the check cannot reach
# (FY-0017). It runs the entry and the arguments of the hook lychee without
# the word --offline, so the configuration and the flags of the hook apply to
# both, from the root of the git checkout, and selects the files by the
# hook's `files`, its `excludes` and the project's global excludes.
{
  _file = ./apps.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit) settings;
      inherit (settings.hooks) lychee;
      # The global excludes and those of the hook as one pattern, as
      # pre-commit joins them.
      excludes = settings.excludes ++ lychee.excludes;
      exclude = lib.concatMapStringsSep "|" (pattern: "(?:${pattern})") excludes;
      # The entry without the word --offline; the shell splits it into
      # arguments as pre-commit does.
      online = lib.concatStringsSep " " (lib.remove "--offline" (lib.splitString " " lychee.entry));
      links = pkgs.writeShellApplication {
        name = "markdown-links";
        runtimeInputs = [
          settings.gitPackage
          pkgs.gnugrep
        ];
        text = ''
          # Links that start with / are relative to the root, as in the check.
          cd "$(git rev-parse --show-toplevel)"
          # lychee reads GITHUB_TOKEN for links to github.com; without a token
          # it is limited to fewer requests.
          if [[ -z ''${GITHUB_TOKEN:-} && -n ''${GH_TOKEN:-} ]]; then
            export GITHUB_TOKEN=$GH_TOKEN
          fi
          if [[ -z ''${GITHUB_TOKEN:-} ]]; then
            unset GITHUB_TOKEN
          fi
          # pre-commit matches `files` and `excludes` with Python's re.search,
          # which grep -P reads the same. grep fails with 1 when it selects
          # nothing, which is no error here.
          matching() { grep "$@" || [[ $? == 1 ]]; }
          list=$(mktemp)
          trap 'rm -f -- "$list"' EXIT
          git ls-files -z \
            | matching -zP ${lib.escapeShellArg lychee.files} \
            ${lib.optionalString (excludes != [ ]) "| matching -zvP ${lib.escapeShellArg exclude}"} >"$list"
          mapfile -d "" files <"$list"
          if [[ ''${#files[@]} == 0 ]]; then
            echo "markdown-links: no Markdown files to check."
            exit 0
          fi
          ${online} ${lib.escapeShellArgs lychee.args} --no-progress -- "''${files[@]}"
        '';
      };
    in
    {
      apps.markdown-links = {
        type = "app";
        program = lib.getExe links;
        meta.description = "Check every link in the Markdown files of the project with lychee.";
      };
    };
}
