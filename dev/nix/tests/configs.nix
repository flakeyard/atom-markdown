# The configuration files (FY-0037): the project's file at each standard path
# replaces the default of the atom, and the chosen file reaches the tool by
# flag as a store path of its own. More than one file at the standard paths
# of a tool, or a JavaScript configuration of prettier, fails evaluation with
# a message that names the files.
{
  facts,
  fixture,
  lib-atom,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      project = name: (fixture { inherit name; }).allSystems.${system};
      check = name: check: (fixture { inherit name; }).checks.${system}.${check};
      # The store path of a file as the atom names it, as text to look for.
      # Restated: the name is the interface that prettier reads (FY-0035).
      stored =
        path:
        builtins.unsafeDiscardStringContext "${builtins.path {
          inherit path;
          name = lib.removePrefix "." (baseNameOf path);
        }}";
      # The file each tool gets in a project.
      prettier = name: lib.last (project name).treefmt.settings.formatter.prettier.options;
      markdownlint =
        name: lib.last (lib.splitString " " (project name).pre-commit.settings.hooks.markdownlint.entry);
      lychee = name: (project name).pre-commit.settings.hooks.lychee.settings.configPath;
      # The project's file of a fixture in dev/fixtures/configs.
      own = name: file: stored (root + "/dev/fixtures/configs/${name}/${file}");
      default = file: stored (root + "/config/${file}");
      prettiers = {
        prettierrc = ".prettierrc";
        prettierrc-json = ".prettierrc.json";
        prettierrc-json5 = ".prettierrc.json5";
        prettierrc-yaml = ".prettierrc.yaml";
        prettierrc-yml = ".prettierrc.yml";
        prettierrc-toml = ".prettierrc.toml";
      };
      markdownlints = {
        markdownlint-json = ".markdownlint.json";
        markdownlint-jsonc = ".markdownlint.jsonc";
        markdownlint-yaml = ".markdownlint.yaml";
        markdownlint-yml = ".markdownlint.yml";
        markdownlintrc = ".markdownlintrc";
      };
      # The message that the atom's own module makes for the files of
      # prettier or markdownlint in a fixture in dev/fixtures/errors: the
      # atom gets a lib-atom whose config gives the errors as the file, since
      # builtins.tryEval loses the text of a throw.
      spied.lib = lib-atom // {
        config =
          arguments: tool:
          let
            chosen = lib-atom.config arguments tool;
          in
          chosen // { file = lib.concatStringsSep "\n" chosen.errors; };
      };
      spiedProject =
        name:
        (fixture {
          name = "errors/${name}";
          atomInputs.lib-atom = spied;
        }).allSystems.${system};
      message = name: lib.last (spiedProject name).treefmt.settings.formatter.prettier.options;
      markdownlintMessage =
        name:
        lib.last (lib.splitString " -c " (spiedProject name).pre-commit.settings.hooks.markdownlint.entry);
      evaluates = name: output: (builtins.tryEval (check "errors/${name}" output).drvPath).success;
    in
    {
      checks = {
        test-configs = facts pkgs "test-configs" (
          {
            "without a file, prettier gets the default" = prettier "good" == default "prettier.json";
            "without a file, markdownlint gets the default" =
              markdownlint "good" == default "markdownlint.json";
            "without a file, lychee gets the default" = lychee "good" == default "lychee.toml";
            "the check runs the chosen files" =
              lib.hasInfix (own "lychee" "lychee.toml") (
                builtins.toJSON (check "configs/lychee" "markdown").config.rawConfig
              )
              && lib.hasInfix (own "markdownlint-json" ".markdownlint.json") (
                builtins.toJSON (check "configs/markdownlint-json" "markdown").config.rawConfig
              );
            "prettier gets one --config" =
              lib.count (option: option == "--config")
                (project "good").treefmt.settings.formatter.prettier.options == 1;
            "lychee.toml replaces the default" = lychee "configs/lychee" == own "lychee" "lychee.toml";
            # Restated: the text is the interface (FY-0035).
            "two files of prettier fail" = !evaluates "two-configs" "treefmt";
            "two files of markdownlint fail" = !evaluates "two-configs" "markdown";
            "the error names the files of prettier" =
              message "two-configs"
              == "atom-markdown: the project has more than one configuration of prettier: .prettierrc.json, .prettierrc.yaml; keep one.";
            "a JavaScript configuration fails" = !evaluates "js-config" "treefmt";
            "the error names the JavaScript files" =
              message "js-config"
              == "atom-markdown: the atom cannot pass these configurations of prettier to it: .prettierrc.cjs, prettier.config.ts; write the configuration in one of .prettierrc, .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml, .prettierrc.toml instead.";
            # prettier resolves the patterns of overrides against the
            # directory of the file of --config.
            "overrides with a directory fail" = !evaluates "prettier-directories" "treefmt";
            "the error names the patterns with a directory" =
              message "prettier-directories"
              == "atom-markdown: the atom cannot pass these configurations of prettier to it: .prettierrc.json (overrides with a directory: docs/**/*.md, notes/*.md); write the configuration in one of .prettierrc, .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml, .prettierrc.toml instead.";
            "overrides with a directory in TOML fail" = !evaluates "prettier-directories-toml" "treefmt";
            "the error names the patterns of TOML" =
              message "prettier-directories-toml"
              == "atom-markdown: the atom cannot pass these configurations of prettier to it: .prettierrc.toml (overrides with a directory: docs/*.md); write the configuration in one of .prettierrc, .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml, .prettierrc.toml instead.";
            "overrides by file names evaluate" = evaluates "prettier-names" "treefmt";
            # prettier ignores the key prettier of package.json with --config.
            "the key prettier of package.json fails" = !evaluates "package-json" "treefmt";
            "the error names the key prettier of package.json" =
              message "package-json"
              == "atom-markdown: the atom cannot pass these configurations of prettier to it: the key prettier of package.json; write the configuration in one of .prettierrc, .prettierrc.json, .prettierrc.json5, .prettierrc.yaml, .prettierrc.yml, .prettierrc.toml instead.";
            "package.json without the key prettier evaluates" = evaluates "package-json-other" "treefmt";
            # markdownlint-cli resolves extends against the directory of the
            # file of -c.
            "extends fails" = !evaluates "markdownlint-extends" "markdown";
            "the error names the file that extends" =
              markdownlintMessage "markdownlint-extends"
              == "atom-markdown: the atom cannot pass these configurations of markdownlint to it: .markdownlint.json (extends); write the configuration in one of .markdownlint.json, .markdownlint.jsonc, .markdownlint.yaml, .markdownlint.yml, .markdownlintrc instead.";
            "extends in YAML fails" = !evaluates "markdownlint-extends-yaml" "markdown";
            "extends null evaluates" = evaluates "markdownlint-extends-null" "markdown";
          }
          // lib.mapAttrs' (
            name: file:
            lib.nameValuePair "${file} replaces the default of prettier" (
              prettier "configs/${name}" == own name file
            )
          ) prettiers
          // lib.mapAttrs' (
            name: file:
            lib.nameValuePair "${file} replaces the default of markdownlint" (
              markdownlint "configs/${name}" == own name file
            )
          ) markdownlints
        );
        # The files pass only with the project's configuration: prettier keeps
        # a paragraph on one line, markdownlint allows a long line, and lychee
        # excludes a missing file.
        test-configs-lychee = check "configs/lychee" "markdown";
      }
      // lib.mapAttrs' (
        name: _: lib.nameValuePair "test-configs-${name}" (check "configs/${name}" "treefmt")
      ) prettiers
      // lib.mapAttrs' (
        name: _: lib.nameValuePair "test-configs-${name}" (check "configs/${name}" "markdown")
      ) markdownlints;
    };
}
