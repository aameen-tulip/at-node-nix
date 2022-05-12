# at-node-nix
Node.js Nix expressions

## Useful snippets

### Get list of `node2nix` readable local packages

```sh
nix shell nixpkgs#yarn;
cd ~src/tulip/environemnts;
yarn workspaces list --json                                           \
 |jq -s 'del( .[0] )|map( { (.name): ( "file:./" + .location ) } )';
```

Or prettier:

``` sh
yarn workspaces list --json                                            \
  |jq -sc 'del( .[0] )|map( { (.name): ( "file:./" + .location ) } )'  \
  |sed -e 's/,/,\n/g' -e 's/]/\n]/' -e 's/\[/[ /'                      \
  |sed 's/^{/  {/';
```

### Update `package.json` with local package paths.

``` sh
jq -s '
.[0] as $pkg|
.[1] as $local|
$pkg +
{ dependencies:    ( $pkg.dependencies|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
, devDependencies: ( $pkg.devDependencies|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
}
' cloud/Central/factory/package.json ./tulip-packages.json  \
  |sed 's/file:\./file:..\/..\/../g';
```

### Together

``` sh
nix shell nixpkgs#yarn nixpkgs#node2nix;
cd ~/src/tulip/environments;
jq -s '
.[0] as $pkg|
.[1] as $local|
$pkg +
{ dependencies:    ( $pkg.dependencies|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
, devDependencies: ( $pkg.devDependencies|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
}
' cloud/Central/factory/package.json <(
  yarn workspaces list --json|jq -sc 'del( .[0] )|map( { (.name): ( "file:./" + .location ) } )'; )  \
|sed 's/file:\./file:..\/..\/../g' > ./cloud/Central/factory/package.json~;
cd ./cloud/Central/factory;
mv package.json~ package.json;
node2nix -14 --include-peer-dependencies -d;
nix-build -A nodeDependencies;
```

``` sh
patch-pkg-json() { jq -s '.[0] as $pkg|.[1] as $local|$pkg +
{ dependencies:    ( $pkg.dependencies // {}|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
, devDependencies: ( $pkg.devDependencies // {}|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) )
, peerDependencies: ( $pkg.peerDependencies // {}|with_entries( { key: .key, value: ( $local[.key] // .value ) } ) ) }
' $1 ./tulip-packages.json  \
|sed "s/file:\./file:$( dirname $1|sed 's/\/[^/]\+/\/../g'|sed 's/\//\\\//g'; )/g"|tee $1~ && mv $1~ $1;
}
```

