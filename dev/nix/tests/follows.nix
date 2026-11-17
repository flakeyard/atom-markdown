# A consumer that locks treefmt-nix or git-hooks.nix a second time fails at
# evaluation with the follows line to add (FY-0017).
{ testing, ... }:
{
  perSystem = testing.follows {
    output = [
      "checks"
      "markdown"
    ];
    # Restated: the text is the interface (FY-0035).
    messages = {
      treefmt-nix = ''
        atom-markdown: input 'treefmt-nix' is locked twice; add to input atom-markdown:
          inputs.treefmt-nix.follows = "treefmt-nix";'';
      git-hooks = ''
        atom-markdown: input 'git-hooks' is locked twice; add to input atom-markdown:
          inputs.git-hooks.follows = "git-hooks";'';
    };
  };
}
