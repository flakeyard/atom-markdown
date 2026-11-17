# atom-markdown

A flake-parts module that formats Markdown with prettier, through treefmt, lints
it with markdownlint and checks its links inside the repository with lychee
offline, as git hooks and as the check `checks.markdown`, and checks all its
links with lychee in the app `markdown-links` ([FY-0017][fy-0017],
[ADR-0001][adr-0001]).

## Inputs

The atom has two inputs, `treefmt-nix` and `git-hooks`, which the project makes
it share with `follows` ([FY-0017][fy-0017]). It also pins [lib-atom][lib-atom],
the functions that atoms share, in its own `flake.lock`; the project neither
declares nor follows it ([FY-0040][fy-0040]). While the atom is `0.y.z`, only
flakeyard's own repositories use it, in the form of [FY-0016][fy-0016]:

```nix
{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=<commit>&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "git+https://github.com/numtide/treefmt-nix?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atom-markdown = {
      url = "git+https://github.com/flakeyard/atom-markdown?ref=v0&rev=<commit>&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-workspace.url = "git+https://github.com/flakeyard/atom-workspace?ref=v0&rev=<commit>&shallow=1";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.atom-markdown.flakeModules.default
        inputs.atom-workspace.flakeModules.default
      ];
    };
}
```

Without a `follows` line, evaluation fails with, for example:

```text
atom-markdown: input 'git-hooks' is locked twice; add to input atom-markdown:
  inputs.git-hooks.follows = "git-hooks";
```

[atom-workspace][atom-workspace] joins the shell of the atom into
`devShells.default`, installs its hooks, enables the hook `treefmt`, makes
`checks.treefmt` substitutable and switches off the aggregated
`checks.pre-commit` of git-hooks.nix.

## Files it reads

From the project's source, which for a git flake holds only tracked files:

- the Markdown files, `*.md`, for all three tools;
- the files and directories that links in Markdown lead to, for lychee;
- the configuration files at the standard paths of the table below;
- `.editorconfig`, which prettier reads: its `max_line_length`, `indent_style`,
  `indent_size` or `tab_width` and `end_of_line` apply where the chosen
  configuration of prettier sets no `printWidth`, `useTabs`, `tabWidth` or
  `endOfLine`. The default sets all four, so `.editorconfig` applies only with a
  project's file that leaves them out;
- `.prettierignore` and `.gitignore` at the root, whose files prettier skips;
- `.markdownlintignore` at the root, whose files markdownlint skips;
- `.lycheeignore` at the root, whose patterns exclude links from lychee.

The tools read the ignore files themselves, in the hooks and in the check alike,
also for files that the hooks name on the command line.

Locally, markdownlint also reads, under the chosen file, the user's
`~/.markdownlintrc`, `~/.markdownlint/config`, `~/.config/markdownlint` and
`~/.config/markdownlint/config`, `/etc/markdownlintrc` and
`/etc/markdownlint/config`, a `.markdownlintrc` above the project and the
environment variables `markdownlint_*`, and merges them. The default sets every
value, so they change nothing under it; a project's file that leaves values out
gets them from these files locally, while the check in the sandbox has none.

## Tools and configuration

Each tool gets the configuration file the project chose: the project's file at
one of the tool's standard paths at the root, else the default of the atom in
[`config/`](config). The project's file replaces the default wholly; nothing is
merged. The atom passes the chosen file by flag and never lets a tool discover
one ([FY-0037][fy-0037]).

| Tool         | Standard path        | Default      | Project's file |
| ------------ | -------------------- | ------------ | -------------- |
| prettier     | `.prettierrc`        | [config][pr] | replaces it    |
| markdownlint | `.markdownlint.json` | [config][ml] | replaces it    |
| lychee       | `lychee.toml`        | [config][ly] | replaces it    |

- prettier also takes `.prettierrc.json`, `.prettierrc.json5`,
  `.prettierrc.yaml`, `.prettierrc.yml` and `.prettierrc.toml`, and gets the
  chosen file with `--config`. The key `prettier` of `package.json` or
  `package.yaml` is not read. A JavaScript or TypeScript configuration,
  `.prettierrc` or `prettier.config` with the extension `js`, `cjs`, `mjs`,
  `ts`, `cts` or `mts`, fails evaluation with a message that names it, since
  prettier would ignore it.
- markdownlint also takes `.markdownlint.jsonc`, `.markdownlint.yaml`,
  `.markdownlint.yml` and `.markdownlintrc`, in JSON or YAML, and gets the
  chosen file with `-c`.
- lychee gets the chosen file with `--config`; the hook adds `--offline`,
  `--include-fragments` and `--root-dir .`, the app `--include-fragments` and
  `--root-dir .`.
- More than one file at the standard paths of one tool fails evaluation with a
  message that names them. The messages are those of lib-atom
  ([FY-0040][fy-0040]):

  ```text
  atom-markdown: the atom cannot pass these configurations of prettier to it:
  .prettierrc.cjs; write the configuration in one of .prettierrc,
  .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml,
  .prettierrc.toml instead.
  atom-markdown: the project has more than one configuration of markdownlint:
  .markdownlint.json, .markdownlintrc; keep one.
  ```

  (one line each, wrapped here).

The defaults:

- [`config/prettier.json`][pr] wraps prose at 80 characters
  (`proseWrap: "always"`, `printWidth: 80`) and sets every other option of
  prettier at its default, also those that format the languages of code blocks.
- [`config/markdownlint.json`][ml] enables every rule with its default
  parameters, MD013 with tables included ([FY-0015][fy-0015]). It lists every
  tag and alias as `true` and every rule with every parameter, so that a file
  that markdownlint-cli merges under it changes nothing. MD043 gets
  `headings: ["*"]`, which allows any headings, as the rule does without the
  parameter. To change a rule in a copy, edit its `MD` entry: the aliases and
  tags come first, so they do not reset it.
- [`config/lychee.toml`][ly] leaves links in code and mail addresses unchecked,
  excludes loopback, private and link-local addresses, and sets the accepted
  responses, redirects, timeout and retries.

To replace a default, copy it from [`config/`](config) to a standard path,
commit it and edit it. Since the atom reads only tracked files, an untracked
file is seen by the tool in the working tree but not by the atom.

## Options

The atom sets `programs.prettier` of treefmt-nix and the hooks `markdownlint`
and `lychee` of git-hooks.nix with `lib.mkOverride 900`, so a plain definition
of the project, such as
`perSystem.pre-commit.settings.hooks.lychee.settings.flags = "...";`, replaces a
value of the atom without `mkForce`. The check and the app run the hooks'
packages, `entry` and settings, so such a definition changes them too. The check
also honours the hooks' other options and the project's global
`perSystem.pre-commit.settings.excludes`: pre-commit selects the files in the
check as the installed hooks do.

`--config <file>` of prettier is a plain definition of
`perSystem.treefmt.settings.formatter.prettier.options`, which treefmt-nix
defines at plain priority. Setting
`perSystem.treefmt.programs.prettier.settings` makes treefmt-nix pass a second
`--config`; use a configuration file instead.

## Outputs

- `flakeModules.default`: the module. It adds to every system:
  - the formatter `prettier` of treefmt, enabled for `*.md` only, with the
    package of the project's nixpkgs;
  - the hooks `markdownlint` and `lychee`, enabled for `*.md`, with the packages
    of the project's nixpkgs;
  - `checks.markdown`: both hooks, run by pre-commit through `lib.<system>.run`
    of git-hooks.nix with the project's global excludes, over the whole source
    of the project, without network access. Formatting is checked by
    `checks.treefmt`;
  - `apps.markdown-links`: the app below;
  - `devShells.flakeyard-markdown`: prettier, markdownlint-cli and lychee, which
    atom-workspace joins into `devShells.default`.

Supported systems are `x86_64-linux` and `aarch64-linux`.

## App

`nix run .#markdown-links` checks every link of the project's tracked Markdown
files, also those on the network, with lychee and the chosen configuration. It
runs from the root of the git checkout, from any directory in it, and skips the
files of the project's global excludes and of the hook's `excludes`. It takes no
arguments and reads these environment variables:

- `GITHUB_TOKEN`, or `GH_TOKEN` when `GITHUB_TOKEN` is not set: a token for
  links to github.com. Without one, the app runs with the lower rate limit of
  anonymous requests.

The output is lychee's own; lychee has no format of GitHub annotations. The app
exits with 0 when every link works and with lychee's status otherwise.

## Supported upstream revisions

The oldest supported revisions are those the tests run with: treefmt-nix
`0d6d739a833ba9a9c93034862e4a7b061a062a1c`, git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`, with prettier 3.8.3,
markdownlint-cli 0.48.0 and lychee 0.24.1.

## Public API

Releases follow [semantic versioning][versioning] ([FY-0024][fy-0024]). The
public API is the inputs `treefmt-nix` and `git-hooks`, `flakeModules.default`,
the formatter `prettier` and the hooks `markdownlint` and `lychee`, the values
the atom sets whose change rewrites files or fails a project that passed before
(the defaults in `config/`, the files prettier formats and the flags of the
hooks), the files it reads, the app `markdown-links` and its environment
variables, the outputs `checks.markdown`, `apps.markdown-links` and
`devShells.flakeyard-markdown`, the supported systems and the oldest supported
upstream revisions. Versions of prettier, markdownlint-cli and lychee come from
the project's nixpkgs and are not part of it.

The last minor release before a major one contains `nix/next-major.nix`; while
it exists, the check and the shell warn at evaluation that the next major
version is coming and where its migration guide is ([FY-0038][fy-0038]).

## Develop in the container

Open the repository in the flakeyard dev container: the editor reads
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json), and
`direnv` loads the shell of [`dev/flake.nix`](dev/flake.nix) through
[`.envrc`](.envrc) ([FY-0012][fy-0012]). [atom-workspace][atom-workspace] builds
the shell and installs the git hooks each time it starts. The container runs
`direnv allow` when it is created; run it once in every other worktree, and run
`direnv block` before you check out a branch you do not trust, since entering
the directory runs that branch's shell hook. Commit inside the container, whose
Nix store has the tools of the hooks. With Nix on the host, `direnv allow` or
`nix develop ./dev` gives the same shell.

The public [`flake.nix`](flake.nix) holds only the inputs and the module
([FY-0017][fy-0017]). [`dev/flake.nix`](dev/flake.nix), with its own lock,
imports the atom as consumers do, with [atom-nix][atom-nix],
[atom-shell][atom-shell], [atom-workflows][atom-workflows] and atom-workspace,
and holds the tests:

- `markdown`, `treefmt`: the atom's checks of this repository;
- `nix`, `shell`, `workflows`: the checks of the other atoms of this repository;
- `test-good`, `test-good-format`: a fixture project in
  [`dev/fixtures`](dev/fixtures) whose Markdown passes both checks, with links
  to files, anchors, directories and from the root, and whose YAML and JSON
  prettier leaves alone;
- `test-bad`, `test-bad-format`: a fixture project with a finding of
  markdownlint, a missing file, a missing anchor, a missing file from the root
  and a file prettier would change;
- `test-configs` and `test-configs-*`: the defaults, every standard path of
  every tool, more than one file and a JavaScript configuration;
- `test-ignores`, `test-ignores-format`: `.prettierignore`, `.gitignore`,
  `.markdownlintignore` and `.lycheeignore`;
- `test-editorconfig`, `test-editorconfig-default`: `.editorconfig` with a
  project's configuration of prettier and with the default;
- `test-excluded`, `test-not-excluded`: the project's global excludes skip the
  failing files in the check, and other excludes do not;
- `test-app`: the app in a git checkout, without network access;
- `test-markdownlint-rules`, `test-prettier-options`: the defaults list every
  rule, parameter and option of the installed tools;
- `test-markdownlint-merge`: a discovered `.markdownlint.yaml`, a
  `~/.markdownlintrc` and `markdownlint_*` variables do not change the findings
  of the default;
- `test-workspace`: the formatter, the check, the shell and the app with
  atom-workspace;
- `test-follows`: the error for a missing `follows` of either input;
- `test-next-major`: the warning of the next major version.

The dev flake has no input for lib-atom: it fetches the revision that the root
[`flake.lock`](flake.lock) pins, gives it to the atom and takes the fixture
projects and the tests `test-follows`, `test-next-major` and `test-workspace`
from `internal/testing` of that revision ([FY-0040][fy-0040]).

Run the same commands as CI:

```sh
nix flake check --no-update-lock-file ./dev
nix flake check --no-update-lock-file --no-build --all-systems ./dev
```

CI runs [`test.yaml`](.github/workflows/test.yaml), which calls
[workflow-check][workflow-check] with `./dev`: it checks `dev/flake.lock`,
builds every check on x86_64 and arm64 runners, checks the pull request title
and `renovate.json`, fails on configuration files of atom tools at their
standard root paths ([FY-0037][fy-0037]), and reports `check / required`
([FY-0034][fy-0034]). Its weekly run builds the checks against the current
branches of nixpkgs, treefmt-nix, git-hooks.nix and flake-parts instead of the
locked revisions ([FY-0038][fy-0038]).
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard, and
[`release.yaml`](.github/workflows/release.yaml) releases the repository with
[workflow-release][workflow-release].

Before a pull request, also run typos and `reuse lint`; the atoms that will
provide them in this repository are not released yet ([FY-0038][fy-0038]).

## License

[MIT](LICENSE).

[adr-0001]:
  docs/adr/records/0001-format-and-lint-markdown-with-prettier-markdownlint-and-lychee.md
[atom-nix]: https://github.com/flakeyard/atom-nix
[atom-shell]: https://github.com/flakeyard/atom-shell
[atom-workflows]: https://github.com/flakeyard/atom-workflows
[atom-workspace]: https://github.com/flakeyard/atom-workspace
[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0040]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0040-share-code-through-lib-repositories.md
[lib-atom]: https://github.com/flakeyard/lib-atom
[ly]: config/lychee.toml
[ml]: config/markdownlint.json
[pr]: config/prettier.json
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
