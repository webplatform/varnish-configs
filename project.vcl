

#
# Fastly (Varnish) configuration for project.webplatform.org
#
# Service: project, v #17
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
# Ref:
#  - https://www.varnish-cache.org/docs/2.1/tutorial/vcl.html
#  - https://www.varnish-software.com/static/book/VCL_functions.html
#  - http://docs.fastly.com/guides/22958207/27123847
#  - http://docs.fastly.com/guides/22958207/23206371
#  - https://www.varnish-cache.org/docs/2.1/tutorial/increasing_your_hitrate.html
#  - https://fastly.zendesk.com/entries/23206371
#


    # Doc: Called at the beginning of a request, after the complete request
    #      has been received and parsed. Its purpose is to
    #      decide whether or not to serve the request, how to
    #      do it, and, if applicable, which backend to use.
sub vcl_recv {
#FASTLY recv

  set client.identity = req.http.Fastly-Client-IP;

  if (req.http.Fastly-SSL) {
    error 802 "enforce-non-ssl";
  }

  #
  # Handle grace periods for where we will serve a stale response
  #     source: https://github.com/python/psf-fastly/blob/master/vcl/pypi.vcl
  if (!req.backend.healthy) {
      # The backend is unhealthy which means we want to serve the stale
      #   response long enough (hopefully) for us to fix the problem.
      set req.grace = 24h;

      # The backend is unhealthy which means we want to serve responses as
      #   if the user was not logged in. This means they will be eligible
      #   for the cached pages.
      remove req.http.Authenticate;
      remove req.http.Authorization;
      remove req.http.Cookie;
  }
  else {
      # Avoid a request pileup by serving stale content if required.
      set req.grace = 15s;
  }

  # Remove ALL cookies to the backend
  #   except the ones MediaWiki cares about
  if(req.url ~ "(UserLogin|UserLogout)") {
    # Do not tamper with MW cookies here
  } else {
    if (req.http.Cookie) {
      set req.http.Cookie = ";" req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(THEBUGGENIE|tbg4_username|tbg3_password)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

      if (req.http.Cookie == "") {
          remove req.http.Cookie;
      }
    }
  }

  ## Fastly BOILERPLATE ========
  if (req.request != "HEAD" && req.request != "GET" && req.request != "PURGE") {
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
  if(!beresp.http.X-Cache-Note) {
    set beresp.http.X-Cache-Note = "Debugging notes: ";
  }

  ## Fastly BOILERPLATE ========
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
  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.ttl = 3600s;
  }
  return(deliver);
  ## /Fastly BOILERPLATE =======
}



    # Doc: Called after a cache lookup if the requested document was found in the cache.
sub vcl_hit {
#FASTLY hit

  ## Fastly BOILERPLATE ========
  if (!obj.cacheable) {
    return(pass);
  }
  return(deliver);
  ## /Fastly BOILERPLATE =======
}



sub vcl_miss {
#FASTLY miss

  ## Fastly BOILERPLATE ========
  return(fetch);
  ## /Fastly BOILERPLATE =======
}



sub vcl_deliver {
#FASTLY deliver

  # Always send this instead of using meta tags in markup
  if (resp.http.Content-Type ~ "html") {
    set resp.http.X-UA-Compatible = "IE=edge,chrome=1";
  }

  # Debug, change version string
  set resp.http.X-Config-Serial = "2014102600";

  # The (!req.http.Fastly-FF) is to differentiate between
  #   edge to the sheild nodes. Shield nodes has a Fastly-FF
  #   header added internally.
  if ((!req.http.Fastly-FF) && (!req.http.Fastly-Debug)) {
      remove resp.http.X-Cache-Note;
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



sub vcl_error {
#FASTLY error

  if (obj.status == 802) {
     set obj.status = 301;
     set obj.response = "Moved Permanently";
     set obj.http.Location = "http://" req.http.host req.url;
     synthetic {""};
     return (deliver);
  }

}



sub vcl_pass {
#FASTLY pass
}