
#
# Fastly (Varnish) VCL configuration for project.webplatform.org
#
# Service: project, v28 (18)
#
# Backend configs:
#   - Max connections: 500
#   - Error treshold: 5
#   - Connection (ms): 3000
#   - First byte (ms): 15000
#   - Between bytes (ms): 10000
#
# Assuming it is using Varnish 2.1.5 syntax
#


    # Doc: Called at the beginning of a request, after the complete request
    #      has been received and parsed. Its purpose is to
    #      decide whether or not to serve the request, how to
    #      do it, and, if applicable, which backend to use.
sub vcl_recv {
#FASTLY recv

  set client.identity = req.http.Fastly-Client-IP;

  # Header overwrite XFF
  if (!req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = req.http.Fastly-Client-IP;
  }

  # Handle grace periods for where we will serve a stale response
  #     source: https://github.com/python/psf-fastly/blob/master/vcl/pypi.vcl
  if (!req.backend.healthy) {
      # The backend is unhealthy which means we want to serve the stale
      #   response long enough (hopefully) for us to fix the problem.
      set req.grace = 1d;

      # The backend is unhealthy which means we want to serve responses as
      #   if the user was not logged in. This means they will be eligible
      #   for the cached pages.
      remove req.http.Authenticate;
      remove req.http.Authorization;
      remove req.http.Cookie;
  } else {
      # Avoid a request pileup by serving stale content if required.
      set req.grace = 30s;
  }

  # Remove ALL cookies to the backend
  #   except the ones we care
  if(!(req.url ~ "login")) {
    if (req.http.Cookie) {
      set req.http.Cookie = ";" req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(THEBUGGENIE|tbg3_username|tbg4_username|tbg3_password|tbg4_password)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

      if (req.http.Cookie == "") {
          remove req.http.Cookie;
      }
    }
  }

  # normalize Accept-Encoding to reduce vary
  if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
      # No point in compressing these
      remove req.http.Accept-Encoding;
    }
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

  #  NOTE: To use vcl_miss in some desired cases, pass everything to
  #        lookup, not pass
  #  ref: http://stackoverflow.com/questions/5110841/is-there-a-way-to-set-req-connection-timeout-for-specific-requests-in-varnish
  ## Fastly BOILERPLATE ========
  if (req.request != "HEAD" && req.request != "GET" && req.request != "PURGE") {
    return(pass);
  }
  return(lookup);  # Default outcome, keep at the end
  ## /Fastly BOILERPLATE =======
}



    # Doc: Called after a document has been successfully retrieved
    #      from the backend
sub vcl_fetch {
#FASTLY fetch

  # Debug notes
  if(!beresp.http.X-Cache-Debug) {
    set beresp.http.X-Cache-Debug = "Debugging " req.request " " req.url ": ";
  }

  # Add gzip to assets that supports it, without
  #     the need to use Fastly internal UI to have it
  if ((beresp.status == 200 || beresp.status == 404) && (beresp.http.content-type ~ "^(text\/html|application\/x\-javascript|text\/css|application\/javascript|text\/javascript)\s*($|;)" || req.url ~ "\.(js|css|html)($|\?)" )) {
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
    beresp.http.content-type ~ "^(text/css|image|application/javascript|text/javascript)\s*($|;)"
  ) {
      set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Forced static asset cache. ";
      set beresp.ttl = 86400s;
      set beresp.grace = 864000s;
      return(deliver);
  }

  ## Fastly BOILERPLATE ========
  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.request == "GET" || req.request == "HEAD")) {
    restart;
  }
  if(req.restarts > 0 ) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }
  if (beresp.http.Set-Cookie) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Has Set-Cookie. ";
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return (pass);
  }
  if (beresp.http.Cache-Control ~ "private") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Cache-Control private. ";
    set req.http.Fastly-Cachetype = "PRIVATE";
    return (pass);
  }
  if (beresp.status == 500 || beresp.status == 503) {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Error document. ";
    set req.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }
  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Has either max-age,Expires,Cache-control. ";
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.http.X-Cache-Debug = beresp.http.X-Cache-Debug "Had no max-age,expires,cache-control; setting default TTL. ";
    set beresp.ttl = 3600s;
  }
  return(deliver); # Default outcome, keep at the end
  ## /Fastly BOILERPLATE =======
}


    # Doc: Called before a cached object is
    #      delivered to the client
sub vcl_deliver {
#FASTLY deliver

  # Warn if its SSL or not. Even though Fastly might already be over SSL
  if (req.http.Fastly-SSL) {
      set resp.http.X-Is-SSL = "yes";
  } else {
      set resp.http.X-Is-SSL = "no";
  }

  # Always send this instead of using meta tags in markup
  if (resp.http.Content-Type ~ "html") {
    set resp.http.X-UA-Compatible = "IE=edge,chrome=1";
  }

  if (resp.http.Content-Type ~ "html" && !req.http.Fastly-SSL && req.request != "PURGE") {
     set resp.status = 301;
     set resp.response = "Moved Permanently";
     set resp.http.Location = "https://" req.http.host req.url;
     synthetic {""};
  }

  # The (!req.http.Fastly-FF) is to differentiate between
  #   edge to the sheild nodes. Shield nodes has a Fastly-FF
  #   header added internally.
  if ((!req.http.Fastly-FF) && (!req.http.Fastly-Debug)) {
      remove resp.http.X-Cache-Debug;
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
