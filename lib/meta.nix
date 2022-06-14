{ lib }: let

  # Combines parts of `nixpkgs.lib.getName' and
  # `nixpkgs.getName' ( pkgs/stdenv/generic/check-meta.nix )
  # These should honestly be a single function, because each misses parts that
  # the other would catch - so I frankenstein them here.
  #
  # Here's the rationale for having separate ones in Nixpkgs:
  #   - `nixpkgs.lib.getName' tries to return the "package name".
  #     This is referred to as `<pkg>.pname', and it does not indicate a version.
  #   - `nixpkgs.getName' returns "derivation name".
  #     This is referred to as `<pkg>.name' and is almost always constructed
  #     as "${pname}-${version}".
  # These functions should carry distinct names in Nixpkgs, but whatever.
  #
  # In our case we'll add the NPM and `package.json' notions of "names".
  # We'll call the "unsanitized" `package.json' name by the Yarn term: "ident"
  # to avoid confusion with Nix/Nixpkgs `name' and `pname' patterns.
  #
  # `ident' will be written to `<pkg>.meta.ident', and can also be found
  # from the actual `package.json' fields under `<pkg>.meta.pjs.name'.`
  #
  # FIXME: This needs to work out a priority, and strip versions.
  #
  #getName' = x: let
  #    # FIXME: this is literally from `lib.getName'.
  #    # Add junk from `./parse.nix' to this.
  #  fromString = drv: ( builtins.parseDrvName drv ).name;
  #  fromPkgAttrs = pkg: pkg.pname or ( fromString pkg.name ) or null;
  #  fromMeta = pkg: let meta = pkg.meta or {}; in
  #    meta.name or meta.ident or meta.pjs.name or null;
  #in if isString x then fromString else
  #    if fromMeta     != null then fromMeta else
  #    if fromPkgAttrs != null then fromPkgAttrs else
  #    "<name-missing>"


/* -------------------------------------------------------------------------- */

  # Metadata must be "flat" plain old data.
  # No derivations, no store paths, no string contexts.
  # If you want any of those things, scroll down and use `passthru'.
  #
  # Metadata fields should not need to be "recomputed" once retrieved, and
  # need to be able to write to/from JSON to be saved on disk.
  # Derivations cannot be serialized, except in the Nix store;
  # similarly Store Paths cannot be read from a regular file or from JSON,
  # because Nix has no way of determining which derivation produced the path.
  # This is why the separation between `passthru' and `meta' exists.
  #
  # NOTE: It is find to "fill metadata" fields from things like a REGISTERED
  # `package.json' or `packument' file ( NOT a local tree/git checkout! ), but
  # you need to be absolutely positive that this metadata will never change for
  # this package version, and in theory you should be able to carve this in
  # stone on disk as `read-only' forever and always.
  # If you do so, be sure to run `builtins.unsafeRemoveStringContext' so Nix
  # knows "no seriously this data is not ever going to change" so that it can
  # be dynamically repacked into a regular string.
  #
  # XXX: For a local tree, you shouldn't record that metadata to disk, because
  # presumably whatever version number is in your `package.json' isn't "real".
  # You could add some ridiculous hash to ensure you don't write "bad"
  # metadata, OR you can let Nix do that for you - all you do it
  # "don't call `builtins.unsafeRemoveStringContext'".
  # Yep, that's it, pretty easy.
  # No need to generate a unique hash for your source tree, because y'know,
  # that's that thing that Nix does all the time for every file using
  # string contexts.
  # This giant block about "meta" is really aiming to tell you "meta" is the
  # exception to Nix's tracking, so we treat it with exceptional caution.
  #
  # These functions never call `builtins.unsafeDiscardStringConext' - and this
  # is intentional ( and I know it seems inconvenient ).
  # This is because we NEED the user to take responsibility for explicitly
  # deciding when contexts should be stripped, so that we can use `meta' tags
  # in "impure" builds without poisoning the cache.


  # The name used by `nixpkgs' is misleading, because it's actually an update.
  # XXX: This will wipe out existing values.
  # XXX: This is a non-recursive merge.
  # FIXME: Add assert that `meta' does not contain derivations.
  updateMeta = newAttrs: drv: let
    # We extend `lib.addMetaAttrs' with automatic fixup for nested fields.
    newMeta =
      if lib.matchAttrs { meta = {}; } newAttrs then newAttrs.meta else
      if ( ! ( newAttrs ? meta ) ) then newAttrs else
      throw "Additional attrs were passed with meta - assuming PEBKAC";
    # This final portion is identical to `lib.addMetaAttrs'.
  in drv // { meta = (drv.meta or {}) // newAttrs; };

  # Only add fields, don't update existing ones them.
  addMissingMeta = newAttrs: drv: let
    newMeta =
      if lib.matchAttrs { meta = {}; } newAttrs then newAttrs.meta else
      if ( ! ( newAttrs ? meta ) ) then newAttrs else
      throw "Additional attrs were passed with meta - assuming PEBKAC";
  in drv // { meta = newMeta // ( drv.meta or {} ); };


/* -------------------------------------------------------------------------- */

  # XXX: This will wipe out existing values.
  # XXX: This is a non-recursive merge.
  # FIXME: Add assert that `pjs' does not contain derivations.
  updatePjs = newAttrs: drv: let
    newPjs =
      # FIXME: you're missing a layer of nesting.
      if lib.matchAttrs { meta.pjs = {}; } newAttrs then newAttrs.meta.pjs else
      if lib.matchAttrs { pjs = {}; } newAttrs then newAttrs.pjs else
      if ( ! ( ( newAttrs ? meta ) || ( newAttrs ? pjs ) ) ) then newAttrs else
      throw "Additional attrs were passed with pjs - assuming PEBKAC";
  in drv // {
    meta = ( drv.meta or {} ) // {
      pjs = ( drv.meta.pjs or {} ) // newPjs;
    };
  };

  # Only add fields, don't update existing ones them.
  addMissingPjs = newAttrs: drv: let
    newPjs =
      # FIXME: you're missing a layer of nesting.
      if lib.matchAttrs { meta.pjs = {}; } newAttrs then newAttrs.meta.pjs else
      if lib.matchAttrs { pjs = {}; } newAttrs then newAttrs.pjs else
      if ( ! ( ( newAttrs ? meta ) || ( newAttrs ? pjs ) ) ) then newAttrs else
      throw "Additional attrs were passed with pjs - assuming PEBKAC";
  in drv // {
    meta = ( drv.meta or {} ) // {
      pjs = newPjs // ( drv.meta.pjs or {} );
    };
  };


/* -------------------------------------------------------------------------- */

  # Unlike `meta' attributes, `passthru' attributes are allowed to carry
  # derivations and store paths.

  # FIXME: Probably use `recursiveUpdate' for inner attributes.
  # You want to keep this stricter checking for the outer attributes though
  # to make sure you don't add garbage fields to a derivation.

  # XXX: This will wipe out existing values.
  # XXX: This is a non-recursive merge.
  updatePassthru = newAttrs: drv: let
    newPassthru =
      if lib.matchAttrs { passthru = {}; } newAttrs then newAttrs.passthru else
      if ( ! ( newAttrs ? passthru ) ) then newAttrs else
      throw "Additional attrs were passed with passthru - assuming PEBKAC";
  in lib.addPassthruAttrs newPassthru drv;

  # Only add fields, don't update existing ones them.
  addMissingPassthru = newAttrs: drv: let
    newPassthru =
      if lib.matchAttrs { passthru = {}; } newAttrs then newAttrs.passthru else
      if ( ! ( newAttrs ? passthru ) ) then newAttrs else
      throw "Additional attrs were passed with passthru - assuming PEBKAC";
  in drv // { passthru = newPassthru // ( drv.passthru or {} ); };


/* -------------------------------------------------------------------------- */

in {
  inherit (lib) setName updateName appendToName;
  #inherit getName';
  inherit updateMeta addMissingMeta;
  inherit updatePjs addMissingPjs;
  inherit updatePassthru addMissingPassthru;
}
