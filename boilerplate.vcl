

#
# Fastly (Varnish) configuration for ...
#
# Service: ..., v #...
#
# Backend configs:
#   - Max connections: 700
#   - Error treshold: 5
#   - Connection (ms): 60000
#   - First byte (ms): 60000
#   - Between bytes (ms): 30000
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

  # Debug, Advise backend
  set resp.http.X-Backend-Key = req.backend;

  # Debug, what URL was requested
  set resp.http.X-Request-Url = req.url;

  # Debug, change version string
  set resp.http.X-Config-Serial = "2014012300";

  ## Fastly BOILERPLATE ========
  return(deliver);
  ## /Fastly BOILERPLATE =======
}



sub vcl_error {
#FASTLY error
}



sub vcl_pass {
#FASTLY pass
}