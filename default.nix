{ shellcheck
, writeText
, lib
# Disable SC2154 by default: referenced but not assigned variables. We
# want to be able to run this on small snippets of strings rather than
# the whole script that we don't necessarily have control over.
, disabledChecks ? [ "SC2154" ]
, shellType ? "bash"
}:

let
  disabledArgs = builtins.map (checkName: "-e ${checkName}") disabledChecks;
  check = pathStr: lib.concatStringsSep " " (
    [ "${shellcheck}/bin/shellcheck" "-s ${shellType}" ]
    ++ disabledArgs
    ++ [ pathStr ]
  );
in
# Takes a derivation and checks its phases.
#
# If shellcheckAttributes is set, that's what gets checked. If
# shellcheckAttributes is not set, whatever is set in phases attribute
# is checked.
#
# If neither is set, doesn't check anything.
drv: drv.overrideAttrs (attrs:
  let
    # First check if shellcheckAttributes was set, then check phases.
    attrNames = attrs.shellcheckAttributes or attrs.phases or [];

    # Instead of having only one phase, have one phase per thing being
    # checked. This makes it more obvious what's running in the CLI
    # output.
    shellcheckPhases =
      let attrStrings = lib.getAttrs attrNames attrs;
      in lib.mapAttrs' (attrName: attrStr:
        let n = "shellcheck_${attrName}";
        in lib.nameValuePair n (check (writeText "${drv.name}_${n}" attrStr))
      ) attrStrings;

    # We have to figure out the least intrusive way to run our
    # phase. Notably, we don't want to set phases if they weren't
    # set to start with.
    #
    # If phases is set, that's where new phases are added, otherwise
    # we add to prePhases which runs by default.
    injectPhases = newPhases: if attrs ? phases
      then { phases = newPhases ++ attrs.phases; }
      else { prePhases = newPhases ++ attrs.prePhases or []; };

  in shellcheckPhases // injectPhases (builtins.attrNames shellcheckPhases)
)
