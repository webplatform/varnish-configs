
#
# Fastly (Varnish) VCL configuration for docs.webplatform.org
#
# Service: docs, v105 (fork from 77,81,82,96,97,103,104)
#
# Backend Hosts:
#   - Max connections:       700
#   - Error treshold:        3
#   - Connect Timeout:       34000 ms
#   - First Byte Timeout:    34000 ms
#   - Between Bytes Timeout: 12000 ms
#
# Settings:
#   - Default TTL: 3600
#
# Notes:
#   - First origin host must have "first" as name
#   - If you configure your browser with header Fastly-Debug, it will use the "fist" origin
#   - Ensure Shielding is NOT on the "first" origin
#
# Assuming it is using Varnish 2.1.5 syntax
#


    # Doc: Called at the beginning of a request, after the complete request
    #      has been received and parsed. Its purpose is to
    #      decide whether or not to serve the request, how to
    #      do it, and, if applicable, which backend to use.
sub vcl_recv {
#FASTLY recv

  # If debugging header, please send to only one backend
  if(req.http.Fastly-Debug) {
    set req.backend = F_first;
  }

  # Handle grace periods for where we will serve a stale response
  # ref: https://github.com/python/psf-fastly/blob/master/vcl/pypi.vcl
  if (!req.backend.healthy) {
      # The backend is unhealthy which means we want to serve the stale
      #   response long enough (hopefully) for us to fix the problem.
      set req.grace = 24h;
      remove req.http.Authenticate;
      remove req.http.Authorization;
      remove req.http.Cookie;
  }

  # Remove ALL cookies to the backend except the ones MediaWiki uses
  if(req.url ~ "(UserLogin|UserLogout)") {
    # Do not tamper with MW cookies here
  } else {
    if (req.http.Cookie) {
      set req.http.Cookie = ";" req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(wpwikiUserID|wpwiki_session|wpwikiUserName|wpwikiToken|wpwikiLoggedOut|wptestwikiforceHTTPS|wptestwikiUserID|wptestwiki_session|wptestwikiUserName|wptestwikiToken|wptestwikiLoggedOut)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

      if (req.http.Cookie == "") {
          remove req.http.Cookie;
      }
    }
  }

  ## Fastly BOILERPLATE ========
  if (req.request != "HEAD" && req.request != "GET" && req.request != "FASTLYPURGE") {
    return(pass);
  }
  return(lookup);
  ## /Fastly BOILERPLATE =======
}



    # Doc: Called after a document has been successfully retrieved from the backend
sub vcl_fetch {
#FASTLY fetch

  # Set the maximum grace period on an object
  set beresp.grace = 24h;


  # Debug notes
  if (!beresp.http.X-Cache-Debug) {
    set beresp.http.X-Cache-Debug = "Debugging " req.request " " req.url ": ";
  }

  # If MediaWiki sends Vary: Cookie,Accept-Encoding, remove Cookie
  if (beresp.http.Vary ~ "Cookie" && beresp.http.Vary ~ "Accept-Encoding") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had Vary with cookie, overwrote to Accept-Encoding alone.  ";
    set beresp.http.Vary = "Accept-Encoding";
  }

  # If the request doesn’t contain a session cookie, drop MediaWiki Expires headers
  # as it breaks valid opportunities to serve cached content
  if (req.http.Cookie !~ "_session=") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had session cookie, remove Expires.  ";
    unset beresp.http.Expires;
  }

  if (beresp.http.Vary) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Vary is " beresp.http.Vary ".  ";
  }

  # ESI support
  set req.esi = true;
  esi;

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

  # Enforce static asset Cache
  if (
    req.url ~ "^/[t|w]/load\.php.*?\bonly=\b[styles|scripts].*" ||
    beresp.http.content-type ~ "^(text/css|image|application/javascript|text/javascript)\s*($|;)"
  ) {
      set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Forced static asset cache, Deliver.  ";
      set beresp.ttl = 86400s;
      set beresp.grace = 864000s;
      return(deliver);
  }

  ## Fastly BOILERPLATE ========
  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.request == "GET" || req.request == "HEAD")) {
    restart;
  }
  if(req.restarts > 0 ) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Restart " req.restarts " caught.  ";
    set beresp.http.Fastly-Restarts = req.restarts;
  }
  if (beresp.http.Set-Cookie) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had Set-Cookie, Pass.  ";
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return (pass);
  }
  if (beresp.http.Cache-Control ~ "private") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had Cache-Control private, Pass.  ";
    set req.http.Fastly-Cachetype = "PRIVATE";
    return (pass);
  }
  if (beresp.status == 500 || beresp.status == 503) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had 5xx error from origin, give short ttl and grace, Deliver.  ";
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }
  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had one or more of Expires,Surrogate-Control and Cache-Control, keep ttl.  ";
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had none of Expires,Surrogate-Control nor Cache-Control, set ttl to 3600s.  ";
    set beresp.ttl = 3600s;
  }
  set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Deliver.  ";

  return(deliver); # Default outcome, keep at the end
  ## /Fastly BOILERPLATE =======
}


    # Doc: Called before a cached object is
    #      delivered to the client
sub vcl_deliver {
#FASTLY deliver

  if (req.http.Fastly-SSL) {
    set resp.http.X-Is-SSL = "yes";
  } else {
    set resp.http.X-Is-SSL = "no";
  }

  # Redirect root to /wiki/Main_Page regardless of over SSL or not.
  if (req.url == "/" && req.request == "GET") {
    set resp.status = 301;
    set resp.response = "Moved Permanently";
    set resp.http.Location = "https://" req.http.host "/wiki/Main_Page";
    synthetic {""};
  }

  # Always send this instead of using meta tags in markup
  if (resp.http.Content-Type ~ "html") {
    set resp.http.X-UA-Compatible = "IE=edge,chrome=1";
  }

  if (resp.http.Content-Type ~ "(html|image)" && !req.http.Fastly-SSL && req.request != "FASTLYPURGE") {
     set resp.status = 301;
     set resp.response = "Moved Permanently";
     set resp.http.Location = "https://" req.http.host req.url;
     synthetic {""};
  }

  # Debug, Advise backend
  set resp.http.X-Backend-Key = req.backend;

  # The (!req.http.Fastly-FF) is to differentiate between
  #   edge to the sheild nodes. Shield nodes has a Fastly-FF
  #   header added internally.
  if ((!req.http.Fastly-FF) && (!req.http.Fastly-Debug)) {
      remove resp.http.X-Cache-Debug;
      remove resp.http.X-Backend-Key;
      remove resp.http.Server;
      remove resp.http.Via;
      remove resp.http.X-Served-By;
      remove resp.http.X-Cache;
      remove resp.http.X-Cache-Hits;
      remove resp.http.X-Timer;
  }

  ## Fastly BOILERPLATE ========
  return(deliver);
  ## /Fastly BOILERPLATE =======
}
