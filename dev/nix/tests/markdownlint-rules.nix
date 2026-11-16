# config/markdownlint.json sets every value of the markdownlint that the atom
# runs (FY-0037): "default", "extends", every tag and alias as true, and every
# rule with every parameter at its default, which the schema of the package
# holds. A new rule or parameter of markdownlint, a typo or another value
# fails. Tags and aliases come before the rules, so that an edited rule in a
# copy of the file is not reset by an alias after it.
{ root, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings.hooks.markdownlint) package;
    in
    {
      checks.test-markdownlint-rules =
        pkgs.runCommand "test-markdownlint-rules"
          {
            nativeBuildInputs = [
              pkgs.check-jsonschema
              pkgs.jq
            ];
          }
          ''
            # Restated, since the schema's default of MD043's headings, [],
            # requires a file without headings, while the rule without the
            # parameter checks nothing; ["*"] allows any headings (FY-0035).
            jq '.properties |= with_entries(
                  if .key == "$schema" then .
                  elif .key == "extends" then .value = {const: null}
                  elif (.key | test("^MD[0-9]+$")) then
                    .value = (.value.oneOf[] | select(.type == "object")
                      | .required = (.properties | keys)
                      | .properties |= map_values({const: .default}))
                  else .value = {const: true}
                  end)
                | .properties.MD043.properties.headings = {const: ["*"]}
                | .required = (.properties | keys - ["$schema"])' \
              ${package}/lib/node_modules/markdownlint-cli/node_modules/markdownlint/schema/markdownlint-config-schema.json \
              >schema.json
            config=${root + "/config/markdownlint.json"}
            check-jsonschema --schemafile schema.json "$config"
            # The last tag or alias comes before the first rule.
            jq -e 'keys_unsorted
              | (map(test("^MD[0-9]+$") | not) | rindex(true))
                < (map(test("^MD[0-9]+$")) | index(true))' "$config"
            touch $out
          '';
    };
}
