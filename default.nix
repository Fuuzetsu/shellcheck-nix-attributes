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
{ # Takes a collection of attributes and a derivation. Returns a
  # derivation that has one extra phase at the beginning: one that
  # checks scripts of every attribute that was asked for.
  #
  # This allows us to have a runtime check for late phases (such as
  # installPhase) but at the very start of the build.
  shellcheckAttributes = attrNames:
    if attrNames == []
    then lib.id
    else drv: drv.overrideAttrs (attrs:
      let
        # Instead of having only one phase, have one phase per thing
        # being checked. This makes it more obvious what's running in
        # the CLI output.
        shellcheckPhases =
          let attrStrings = lib.getAttrs attrNames attrs;
          in lib.mapAttrs' (attrName: attrStr:
            let n = "shellcheck_${attrName}";
            in lib.nameValuePair n (check (writeText "${drv.name}_${n}" attrStr))
          ) attrStrings;
        addPhasesTo = attrName:
          if lib.hasAttr attrName attrs
          then builtins.attrNames shellcheckPhases ++ attrs.${attrName}
          else builtins.attrNames shellcheckPhases;
        # We have to figure out the least intrusive way to run our
        # phase. Notably, we don't want to set phases if they weren't
        # set to start with.
        injectPhases =
          if attrs ? phases
          then { phases = addPhasesTo "phases"; }
          else { prePhases = addPhasesTo "prePhases"; };
      in shellcheckPhases // injectPhases
    );
}
