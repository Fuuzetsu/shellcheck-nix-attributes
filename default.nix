# For this reason, we will by default run shellcheck during build time
# instead of evaluation time.
{ shellcheck, runCommandNoCCLocal
, writeShellScript
, writeText
, lib
}:

let
  # Disable SC2154: referenced but not assigned variables. We want to be
  # able to run this on small snippets of strings rather than the whole
  # script that we don't necessarily have control over.
  check = pathStr: "${shellcheck}/bin/shellcheck -s bash -e SC2154 ${pathStr}";
  # Given a string, yield it only if shellcheck is happy with it,
  # otherwise fail.
  #
  # You should be carefuly when using this command as it necessarily
  # affects laziness! If you have a string where you interpolate
  # something, this has to be realised in order for shellcheck to be
  # able to run. Consider the below example:
  #
  # trader-unwrapped = {…};
  # trader-wrapped = {
  #   …
  #   installPhase = ''
  #     …
  #     ${trader-unwrapped}/…
  #     …
  #   '';
  #   …
  # };
  #
  # You could now happily do @nix-build --dry-run trader-wrapped@ and
  # nix could say that it would build trader-unwrapped and
  # trader-wrapped but do no further work.
  #
  # Now you decide that you want to shellcheck the installPhase, and change it to:
  #
  #   installPhase = pkgs.callPackage ./shellchecked.nix {} ''
  #     …
  #     ${trader-unwrapped}/…
  #     …
  #   '';
  #
  # Now to yield the string, we have to run it through shellcheck first.
  # To run it through shellcheck, you have to realise all interpolations
  # to get an actual string to use. To realise the string, you have to
  # build `trader-unwrapped` first! This means that now `--dry-run` for
  # `trader-wrapped` would be forced to first build `trader-unwrapped`.
  evaluationTime = content:
    let file = writeText "content-to-shellcheck" content;
    in runCommandNoCCLocal "check-bash-string" {} ''
      ${check file}
      ln -s ${file} "$out"
    '';
  runTime = content: ''
    ${check (writeText "content-to-shellcheck" content)}
    ${content}
  '';
in
{ # Functions for individual strings. For large parts of derivations,
  # see shellcheckAttributes.
  inherit runTime evaluationTime;
  # Takes a collection of attributes and a derivation. Returns a
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
