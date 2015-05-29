sub vcl_recv {
    set req.http.X-Auth-User = "SWIFT:PUBKEY";
    set req.http.X-Auth-Key  = "SWIFT_PRIVATE_KEY";

#FASTLY recv

    # Buckets to map:
    #
    # MW site at docs.webplatform.org/test/:
    # - wptestwiki-local-deleted
    # - wptestwiki-local-public
    # - wptestwiki-local-thumb
    #
    # MW site at docs.webplatform.org/wiki/:
    # - wpwiki-local-deleted
    # - wpwiki-local-public
    # - wpwiki-local-temp
    # - wpwiki-local-thumb
    #
    # Blog assets storage:
    # - wpd-blog
    #
    # General purpose storage (fallback):
    # - wpd

    if (req.url ~ "^/t/(thumb|deleted|public)/") {
        # /test/ wiki assets
        set req.url = regsub( req.url, "^/t/(thumb|deleted|public)/(.+)$",
                               "/swift/v1/wptestwiki-local-\1/\2");

    } elseif (req.url ~ "^/w/(thumb|temp|public)/") {
        # /wiki/ live wiki assets
        set req.url = regsub( req.url, "^/w/(thumb|temp|public)/(.+)$",
                              "/swift/v1/wpwiki-local-\1/\2");

    } elseif (req.url ~ "^/wpd-blog/") {
        set req.url = regsub( req.url, "^(.+)$",
                              "/swift/v1\1");

    } else {
        # Bucket to store all the rest
        set req.url = regsub( req.url, "^(.+)$",
                              "/swift/v1\1");
    }

    # Varnish doesn't like url containing
    # double slashes
    if(req.url ~ "^(.*)//(.*)$")
    {
      set req.url = regsub(req.url,"^(.*)//(.*)$","\1/\2");
    }

    # normalize Accept-Encoding to reduce vary
    if (req.http.Accept-Encoding) {
      if (req.http.User-Agent ~ "MSIE 6") {
        unset req.http.Accept-Encoding;
      } elsif (req.http.Accept-Encoding ~ "gzip") {
        set req.http.Accept-Encoding = "gzip";
      } elsif (req.http.Accept-Encoding ~ "deflate") {
        set req.http.Accept-Encoding = "deflate";
      } else {
        unset req.http.Accept-Encoding;
      }
    }


    # As suggested in
    # http://www.clarksys.com/blog/2012/03/02/howto-cache-s3-objects-with-varnish/
    unset req.http.cookie;
    unset req.http.cache-control;
    unset req.http.pragma;
    unset req.http.expires;
    unset req.http.etag;
    unset req.http.X-Forwarded-For;
    # /As suggested...

  ## Fastly BOILERPLATE ========
  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }
  return(lookup);
  ## /Fastly BOILERPLATE =======
}

sub vcl_fetch {
#FASTLY fetch

  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.request == "GET" || req.request == "HEAD")) {
    restart;
  }

  if(req.restarts > 0 ) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return (pass);
  }

  if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return (pass);
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }

  # Gzip
  if (beresp.status == 200 && (beresp.http.content-type ~ "^(text/html|application/x-javascript|text/css|application/javascript|text/javascript)\s*($|;)" || req.url ~ "\.(js|css|html)($|\?)" ) ) {

    # always set vary to make sure uncompressed versions dont always win
    if (!beresp.http.Vary ~ "Accept-Encoding") {
      if (beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary ", Accept-Encoding";
      } else {
         set beresp.http.Vary = "Accept-Encoding";
      }
    }
    if (req.http.Accept-Encoding == "gzip") {
      set beresp.gzip = true;
    }
  }

  # As suggested in
  # http://www.clarksys.com/blog/2012/03/02/howto-cache-s3-objects-with-varnish/
  set beresp.ttl = 2w;
  set beresp.grace = 30s;
  # /As suggested in...

  return(deliver);
}

