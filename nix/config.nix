# The configuration file of a tool that the project chose (FY-0037): the
# project's file at a standard path at the root, else the default of the atom
# in config/, either one as a store path of its own. message is null, or the
# error for files the atom cannot use: more than one file at the standard
# paths, or a file in a form that the tool cannot take by flag. file fails
# with that message.
{
  lib,
  root,
  self,
}:
{
  # The tool, for the message.
  tool,
  # The name of the default in config/.
  default,
  # The standard paths whose file replaces the default.
  names,
  # The standard paths of forms that the atom cannot pass to the tool.
  unsupported ? [ ],
}:
let
  # Tracked files only, for a git flake.
  present = lib.filter (name: builtins.pathExists (self.outPath + "/${name}"));
  found = present names;
  refused = present unsupported;
  message =
    if refused != [ ] then
      "atom-markdown: the atom cannot pass these configurations of ${tool} at the root of the project to it:"
      + " ${lib.concatStringsSep ", " refused}; write the configuration in one of"
      + " ${lib.concatStringsSep ", " names} instead."
    else if lib.length found > 1 then
      "atom-markdown: the project has more than one configuration of ${tool} at its root:"
      + " ${lib.concatStringsSep ", " found}; keep one."
    else
      null;
in
{
  inherit message;
  file =
    if message != null then
      throw message
    else if found == [ ] then
      builtins.path {
        path = root + "/config/${default}";
        name = default;
      }
    else
      builtins.path {
        path = self.outPath + "/${lib.head found}";
        # Without the leading dot: prettier chooses the parser by the
        # extension of the file name, which for .prettierrc in a store path
        # such as /nix/store/<hash>-.prettierrc would be ".prettierrc".
        name = lib.removePrefix "." (baseNameOf (lib.head found));
      };
}
