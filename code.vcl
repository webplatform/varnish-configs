#
# Heavily copied from static.webplatform.org
#
# Adjust variables accordingly
#
sub vcl_recv {

  if (req.url ~ "^/w/") {
    set req.http.X-Auth-User = "SWIFT:PUBKEY";
    set req.http.X-Auth-Key  = "SWIFT_PRIVATE_KEY";
  }

#FASTLY recv

  if (req.url ~ "^/w/") {
      # /wiki/ live wiki assets
      set req.url = regsub( req.url, "^/w/(thumb|temp|public)/(.+)$",
                            "/swift/v1/wpwiki-local-\1/\2");

      # As suggested in
      # http://www.clarksys.com/blog/2012/03/02/howto-cache-s3-objects-with-varnish/
      unset req.http.cookie;
      unset req.http.cache-control;
      unset req.http.pragma;
      unset req.http.expires;
      unset req.http.etag;
      unset req.http.X-Forwarded-For;
      # /As suggested...
  }

  ## Fastly BOILERPLATE ========
  if (req.request != "HEAD" && req.request != "GET" && req.request != "PURGE") {
    return(pass);
  }
  return(lookup);
  ## /Fastly BOILERPLATE =======
}
