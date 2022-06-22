{ nixpkgs ? getFlake "nixpkgs"
, lib     ? ( builtins.getFlake ( toString ../../.. ) ).lib
}: let

  # flakeref:   path, git, or indirect
  # fetchTree:  path, git, or tarball

  uris = {

    path = "[path:]<path>(\?<params>)?";
    git  = "git(+http|+https|+ssh|+git|+file):(//<server>)?<path>(\?<params>)?";
    mercurial = "hg(+http|+https|+ssh|+file):(//<server>)?<path>(\?<params>)?";
    /**
     * If `path' ends in any of the following, "tarball+" can be dropped.
     *   ".zip" ".tar" ".tgz" ".tar.gz" ".tar.xz" ".tar.bz2" ".tar.zst"
     */
    tarball = "tarball(+http|+https|+file)(://<server>)?<path>";
    /**
     * If path does not end in one of the tarball extensions, "file+" can
     * be dropped.
     */
    file = "file(+http|+https|+file):(//<server>)?<path>";
    github = "github:<owner>/<repo>(/(<rev>|<ref>))?(\?<params>)?";
    # This can accepts "host" as a param which is used as `server'.
    sourcehut = "sourcehut:<owner>/<repo>(/(<rev>|<ref>))?(\?<params>)?";

    # Registry lookup.
    indirect = "[flake:]<flake-id>(/(<ref>(/<rev>)?|<rev>))?";

  };

in {

}
