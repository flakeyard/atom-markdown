---
id: ADR-0001
title: Format and lint Markdown with prettier, markdownlint and lychee
status: accepted
date: 2026-11-16
supersedes: []
superseded_by: []
related: []
affects:
  ["flake.nix", "flake.lock", "nix/**", "config/**", "dev/**", "README.md"]
review_by:
---

## Context

atom-markdown is an atom of step 4 of [FY-0038][fy-0038]. It owns documentation:
prettier for Markdown only as the formatter, markdownlint as the linter, and
lychee offline as a hook for links inside the repository and as an app for all
links ([FY-0017][fy-0017]). Decisions of flakeyard require of it:

- [FY-0017][fy-0017]: inputs are exactly the upstream flakes whose modules the
  atom imports, `treefmt-nix` and `git-hooks`, each checked against the
  consumer's input of the same name before the import. Upstream options are set
  with `lib.mkOverride 900`, list options that upstream defines at plain
  priority at plain priority, and tool packages come from the consumer's `pkgs`.
  The domain has one check, built with `lib.<system>.run` of git-hooks.nix from
  only the domain's hooks and the project's global excludes; checks run without
  network access, and work that needs it is an app. Developer tools are
  `devShells.flakeyard-<atom>`.
- [FY-0015][fy-0015]: Markdown is formatted by prettier with `proseWrap: always`
  at 80 characters and passes markdownlint with its default rules, MD013 with
  tables included. Links inside the repository pass lychee offline in the check;
  all links are checked by the lychee app.
- [FY-0037][fy-0037]: prettier, markdownlint and lychee are tools of the kind "a
  file by flag". The default lives in `config/`, a project's file at a standard
  path at the root replaces it wholly, the chosen file reaches the tool by flag
  as a store path of its own, and a file in a form the atom cannot pass fails
  evaluation. Where a tool merges a discovered file into the one passed by flag,
  the default sets every value of the tool, and a fixture asserts that a
  discovered file changes nothing. Ignore files are configuration files.
- [FY-0024][fy-0024] and [FY-0038][fy-0038]: releases start at `v0.1.0` with the
  moving tag `v0`, a stricter default ships first as an opt-in under
  `config/next/`, and the warning of the next major version lives in
  `nix/next-major.nix`.

Reading treefmt-nix at `0d6d739a`, git-hooks.nix at `204b6977` and the tools of
`nixos-26.05` at `ac588ef1` (prettier 3.8.3, markdownlint-cli 0.48.0 with
markdownlint 0.40.0, lychee 0.24.1), and running them, showed:

- treefmt-nix's `programs.prettier` includes `*.md` and also `*.mdx`, `*.json`,
  `*.yaml`, `*.yml`, `*.js`, `*.ts`, `*.css`, `*.html` and other web files, as
  the default of its option `includes`. It adds `--config` with a generated file
  only when `programs.prettier.settings` sets a value.
- prettier with `--config` reads no other configuration file: a `.prettierrc.js`
  or a `.prettierrc.json` next to the files is ignored without a message. It
  still reads `.editorconfig`, whose `max_line_length`, `indent_style`,
  `indent_size` or `tab_width` and `end_of_line` become `printWidth`, `useTabs`,
  `tabWidth` and `endOfLine` unless the file of `--config` sets them. It skips
  the files that `.prettierignore` or `.gitignore` of the working directory
  list, also when they are named on the command line.
- prettier chooses the parser of its configuration by the extension of the file
  name. A store path such as `/nix/store/<hash>-.prettierrc` fails with
  `No loader specified for extension ".prettierrc"`; the same file named
  `<hash>-prettierrc` is read as YAML.
- git-hooks.nix defines the hook `markdownlint` with markdownlint-cli,
  `files = "\.md$"` and an `entry` that passes `-c` with a file written from
  `settings.configuration`. It defines the hook `lychee` with
  `types = [ "text" ]`, no `files`, and an `entry` of lychee with
  `--config <settings.configPath>` and `settings.flags`.
- markdownlint-cli reads, through the package run-con, `/etc/markdownlintrc`,
  `/etc/markdownlint/config`, `~/.markdownlintrc`, `~/.markdownlint/config`,
  `~/.config/markdownlint`, `~/.config/markdownlint/config`, a `.markdownlintrc`
  in the working directory or above it, and the variables `markdownlint_*`; it
  then merges a `.markdownlint.jsonc`, `.json`, `.yaml` or `.yml` of the working
  directory over them, and the file of `-c` over both with a deep merge. A
  `~/.markdownlintrc` with `{"MD013": {"tables": false}}` silences a long table
  line under a file of `-c` that holds only `{"default": true}`.
- markdownlint applies the keys of its configuration in their order, and a rule
  name, an alias such as `line-length` or a tag such as `whitespace` each set
  the rules they name. A deep merge keeps the order of the keys that the
  discovered file had first. A default can therefore keep every value only by
  listing every rule, alias and tag; a rule given as `true` takes its
  parameters' defaults.
- The schema in the package, `markdownlint-config-schema.json`, lists every
  rule, alias and tag and every parameter of every rule with its default. The
  default `[]` of the parameter `headings` of MD043 is not what the rule does
  without it: with `[]` it reports every heading, without it nothing. `["*"]`
  allows any headings: over 161 Markdown files of flakeyard's repositories and a
  file that breaks most rules, the full default with `["*"]` and
  `{"default": true}` report the same findings.
- markdownlint-cli reads `.markdownlintignore` of the working directory and
  drops the files it lists, also when they are named on the command line.
- lychee 0.24.1 with `--offline` checks links to files and directories and, with
  `--include-fragments`, anchors of Markdown headings, and skips links to the
  network. A link that starts with `/` fails with
  `To resolve root-relative links in local files, provide a root dir`, unless
  `--root-dir` is given; `--root-dir .` is accepted and resolves against the
  working directory, although the help asks for an absolute path. pre-commit
  runs an `entry` without a shell, so `$PWD` would not be expanded.
- lychee with `--config` reads no `lychee.toml` of the working directory, fails
  on unknown keys of its configuration, and reads `.lycheeignore` of the working
  directory. It builds its HTTP client also with `--offline`, and fails in the
  Nix sandbox with `No CA certificates were loaded from the system` unless
  `SSL_CERT_FILE` names a bundle. It reads a GitHub token from `GITHUB_TOKEN`,
  and its output formats are `compact`, `detailed`, `json`, `junit` and
  `markdown`, none of them GitHub annotations.

## Decision

### Inputs

The public flake has two inputs, `treefmt-nix` (numtide/treefmt-nix) and
`git-hooks` (cachix/git-hooks.nix). Before importing the module of either, the
atom fails evaluation with the line `inputs.<name>.follows = "<name>";` when the
consumer's input of that name has another store path.

### Configuration files

One function, `nix/config.nix`, chooses the file of each tool: the project's
file at one of the tool's standard paths at the root, detected with
`builtins.pathExists` on the project's source, else the default in `config/`.
The chosen file becomes a store path of its own with `builtins.path`, named
without a leading dot so that prettier reads its extension. More than one file
at the standard paths of a tool fails evaluation with a message that names them,
as does a file in a form the atom cannot pass.

- prettier: `.prettierrc`, `.prettierrc.json`, `.prettierrc.json5`,
  `.prettierrc.yaml`, `.prettierrc.yml` or `.prettierrc.toml`, else
  `config/prettier.json`;
- markdownlint: `.markdownlint.json`, `.markdownlint.jsonc`,
  `.markdownlint.yaml`, `.markdownlint.yml` or `.markdownlintrc`, else
  `config/markdownlint.json`;
- lychee: `lychee.toml`, else `config/lychee.toml`.

prettier's JavaScript and TypeScript configurations, `.prettierrc` and
`prettier.config` with the extensions `js`, `cjs`, `mjs`, `ts`, `cts` and `mts`,
fail evaluation with a message that names them, since prettier would ignore them
under `--config` without a message. The key `prettier` of `package.json` and
`package.yaml` is not read.

### Formatter

The atom enables `programs.prettier` of treefmt-nix with `pkgs.prettier` of the
consumer and sets its `includes` to `[ "*.md" ]`, both with
`lib.mkOverride 900`, so that prettier formats Markdown and nothing that other
atoms own. The chosen file reaches prettier as `--config <file>` in
`settings.formatter.prettier.options`, a plain definition next to treefmt-nix's
`--write`. `config/prettier.json` sets every option of prettier that decides how
files are formatted, also those of the languages in code blocks:
`proseWrap: "always"` and `printWidth: 80`, which [FY-0015][fy-0015] requires,
and every other option at prettier's default. prettier keeps reading
`.editorconfig`; with the default, its values are overridden by the file, and a
project's file that leaves them out takes them from `.editorconfig`.

### Linters

The atom enables the upstream hook `markdownlint` with `pkgs.markdownlint-cli`
and replaces its `entry` with `lib.mkOverride 900` by markdownlint with
`-c <file>`. `config/markdownlint.json` holds `"default": true`,
`"extends": null`, every tag and every alias as `true`, and then every rule with
every parameter at the default of the schema, with `enabled: true` and
`severity: "error"`, except `headings: ["*"]` of MD043. Tags and aliases come
before the rules, so that a project that copies the file and edits a rule is not
reset by an alias after it. A discovered `.markdownlint*` file, a
`~/.markdownlintrc` or a variable `markdownlint_*` can then change no value of
the default.

The atom enables the upstream hook `lychee` with `pkgs.lychee` and sets, with
`lib.mkOverride 900`, `files = "\.md$"`, `settings.configPath` to the chosen
file and `settings.flags` to `--offline --include-fragments --root-dir .`.
`config/lychee.toml` leaves links in code and mail addresses unchecked, excludes
loopback, private and link-local addresses, and sets the accepted responses, the
redirects, the timeout and the retries explicitly.

### Check, app and shell

`checks.markdown` is built with `lib.<system>.run` of git-hooks.nix from only
the hooks `markdownlint` and `lychee`, with every option the project's
configuration holds for them, the project's global
`pre-commit.settings.excludes` and the project's `pre-commit` and `git`
packages. Its source is the whole project: links in Markdown lead to files of
every kind and to directories, which lychee must find. In the check only, the
hook `lychee` gets `pkgs.cacert` as an extra package, whose setup hook sets
`SSL_CERT_FILE`.

`apps.markdown-links` runs lychee with the hook's package and configuration
file, `--include-fragments` and `--root-dir .`, without `--offline`, from the
root of the git checkout, over the tracked files that match the hook's `files`
and none of the global excludes or the hook's `excludes`, matched with `grep -P`
as pre-commit matches them with Python. It passes `GH_TOKEN` as `GITHUB_TOKEN`
when only the former is set, and runs without a token otherwise. Its output is
lychee's own.

`devShells.flakeyard-markdown` holds prettier, markdownlint-cli and lychee.

### Next major version

While `nix/next-major.nix` exists, `checks.markdown` and
`devShells.flakeyard-markdown` warn with `lib.warn` of the consumer's nixpkgs:
the version, the end of support 6 months after it, and the link to the migration
guide the file names ([FY-0016][fy-0016], [FY-0038][fy-0038]).

### Tests

`dev/flake.nix` imports the atom from the flake's own outputs called with the
dev flake's `treefmt-nix` and `git-hooks`, which is what `follows` gives a
consumer, together with atom-nix, atom-shell, atom-workflows and atom-workspace,
and checks this repository with them. Fixture projects import the atom and
atom-workspace the same way. Its checks evaluate on x86*64-linux and
aarch64-linux: a project that passes both checks, whose YAML and JSON prettier
would change; a project with a finding of markdownlint, a missing file, a
missing anchor and a missing file from the root, and a file prettier would
change; a project for every standard path of every tool whose files pass only
with that file; more than one file and a JavaScript configuration; the ignore
files of the three tools and `.gitignore`; `.editorconfig` with a project's file
and with the default; the global excludes; the app in a git checkout; the glue
of atom-workspace; the follows error of both inputs; the next-major warning;
that `config/markdownlint.json` lists every rule, alias, tag and parameter of
the installed markdownlint at its default, and `config/prettier.json` every
option of the installed prettier; and that a discovered file, a
`~/.markdownlintrc` and `markdownlint*\*` variables do not change the findings
of the default.

## Constraints

- The public flake MUST declare only the inputs `treefmt-nix` and `git-hooks`,
  and MUST fail evaluation with the exact follows line when the consumer's input
  of either name has another store path.
- prettier MUST format only `*.md` and MUST get exactly one `--config`, with the
  chosen file.
- markdownlint MUST get the chosen file by `-c`, and lychee by `--config`; the
  atom MUST NOT rely on their discovery of configuration files.
- The chosen file MUST be a store path of its own, named after the file without
  a leading dot.
- More than one file at the standard paths of a tool, and a JavaScript or
  TypeScript configuration of prettier at the root, MUST fail evaluation with a
  message that names the files.
- `config/markdownlint.json` MUST list `default`, `extends`, every tag and alias
  before every rule, and every rule with every parameter of the markdownlint the
  dev flake runs at its default, `headings: ["*"]` of MD043 excepted.
- `config/prettier.json` MUST set every option of the prettier the dev flake
  runs, except `cursorOffset`, `filepath`, `parser`, `plugins`, `rangeStart` and
  `rangeEnd`.
- The hook `lychee` MUST run with `--offline`; only the app may reach the
  network.
- `checks.markdown` MUST be built with `lib.<system>.run` of git-hooks.nix from
  only the hooks `markdownlint` and `lychee` and the project's global excludes,
  and the atom MUST NOT select its files.
- Everything listed in the "Public API" of the README is the public API
  ([FY-0017][fy-0017], [FY-0024][fy-0024]).

## Consequences

- (+) A project gets the same findings in the git hooks, in `nix flake check`
  and in CI, with flakeyard's files or its own.
- (+) Broken links inside the repository, also anchors and links from the root,
  fail the pull request that breaks them, without network access.
- (+) A user's `~/.markdownlintrc` cannot weaken the default locally.
- (−) `checks.markdown` depends on the whole source, so any change rebuilds it.
- (−) `config/markdownlint.json` is long, and a new version of markdownlint in
  the dev flake's nixpkgs fails its test until the file lists the new rules and
  parameters.
- (−) With a project's own file, discovered files of markdownlint-cli, the
  user's `~/.markdownlintrc` and `markdownlint_*` variables still apply locally;
  the check in the sandbox has none of them.
- (−) `--root-dir .` relies on lychee accepting a relative root, which its help
  does not promise; a test of the atom fails if that changes.
- (−) A project that wants one option changed copies the whole default.
- (±) `.editorconfig` changes nothing under the default and decides the width,
  indentation and line endings of Markdown under a project's file that leaves
  them out.

## Alternatives considered

- **prettier with `--no-editorconfig`.** Explicit, but the owner chose to keep
  `.editorconfig`, the file people and editors share, for projects with their
  own configuration.
- **`programs.prettier.settings` of treefmt-nix and `settings.configuration` of
  the hook.** Module options instead of files, which [FY-0037][fy-0037] rejects.
- **Rules only in `config/markdownlint.json`.** A discovered file with an alias
  or a tag after a rule, or `"default": false`, would still change the default.
- **`--root-dir "$PWD"` through a wrapper script.** Works in the hook and the
  check alike, but replaces the upstream entry of lychee for what a relative
  root already does.
- **A source of the check filtered to Markdown.** Links to other files and to
  directories would fail.
- **lychee as an app only.** Broken links inside the repository would be found
  on schedule, not in the pull request ([FY-0015][fy-0015]).

[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
