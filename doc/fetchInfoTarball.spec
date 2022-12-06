fetch_info_tarball :: struct {
  type         :: "tarball"
, url          :: string[uri_ref]
, lastModified :: ? int
, narHash      :: ? string[sha256:sri]
}
