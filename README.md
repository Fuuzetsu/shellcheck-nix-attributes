# shellcheck-nix-attributes

When writing derivations with nix, the underlying language that gets
executed in Bash, which means we can end up with many Bash snippets in
our nix files. It may be desirable to check these snippets with the
excellent `shellcheck` script such that we know that nothing strange
is going to happen late into the build.

By applying the nix expression here to your derivation, an additional
set of phases will run an the very start of the build. These phases
will check each of the specified attributes and exit the build with
failure if necessary.

Let's consider a file `example-fail.nix` that defines a simple
derivation and runs shellcheck on `installPhase`:

```
{ pkgs ? import <nixpkgs> {} }:

let shellchecked = pkgs.callPackage ./default.nix {};
    someDerivation = pkgs.stdenvNoCC.mkDerivation {
      name = "someDerivation";
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir $out
        echo foo > $out/some-output
      '';
    };
in shellchecked someDerivation
```

If we try to build it, we may see something like:

```
$ nix-build example-fail.nix --no-out-link
these derivations will be built:
  /nix/store/pywslpazmnqaqjk03qia051qyxfcc2z4-someDerivation_shellcheck_installPhase.drv
  /nix/store/bgfxd8kwcq6k5c9prprppdc3ym78fzky-someDerivation.drv
building '/nix/store/pywslpazmnqaqjk03qia051qyxfcc2z4-someDerivation_shellcheck_installPhase.drv'...
building '/nix/store/bgfxd8kwcq6k5c9prprppdc3ym78fzky-someDerivation.drv'...
shellcheck_installPhase

In /nix/store/f4lzcsyqfmnf9x4hswql7mijxsysngsn-someDerivation_shellcheck_installPhase line 1:
mkdir $out
      ^--^ SC2086: Double quote to prevent globbing and word splitting.

Did you mean:
mkdir "$out"


In /nix/store/f4lzcsyqfmnf9x4hswql7mijxsysngsn-someDerivation_shellcheck_installPhase line 2:
echo foo > $out/some-output
           ^--^ SC2086: Double quote to prevent globbing and word splitting.

Did you mean:
echo foo > "$out"/some-output

For more information:
  https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...
builder for '/nix/store/bgfxd8kwcq6k5c9prprppdc3ym78fzky-someDerivation.drv' failed with exit code 1
error: build of '/nix/store/bgfxd8kwcq6k5c9prprppdc3ym78fzky-someDerivation.drv' failed
```

Great.

See `default.nix` for some things you can configure and few comments.

Your `nixpkgs` has to be recent-ish enough to support all the used
library functions, such as `getAttrs`. If you'd like to support older
versions or would like to pin a known-working nixpkgs, feel free to
open an issue.
