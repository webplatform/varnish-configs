sub vcl_recv {
#FASTLY recv

  if (!req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = req.http.Fastly-Client-IP;
  }

  set req.grace = 7200s;
  set req.hash_ignore_busy = false;
  set req.hash_always_miss = false;

  if (!req.http.X-Geo-Area-Code) {
    set req.http.X-Geo-Area-Code = geoip.area_code;
  }
  if (!req.http.X-Geo-City) {
    set req.http.X-Geo-City = geoip.city;
  }
  if (!req.http.X-Geo-Country-Code) {
    set req.http.X-Geo-Country-Code = geoip.country_code;
  }
  if (!req.http.X-Geo-Country-Name) {
    set req.http.X-Geo-Country-Name = geoip.country_name;
  }
  if (!req.http.X-Geo-Latitude) {
    set req.http.X-Geo-Latitude = geoip.latitude;
  }
  if (!req.http.X-Geo-Longitude) {
    set req.http.X-Geo-Longitude = geoip.longitude;
  }
  if (!req.http.X-Geo-Postal-Code) {
    set req.http.X-Geo-Postal-Code = geoip.postal_code;
  }
  if (!req.http.X-Geo-Region) {
    set req.http.X-Geo-Region = geoip.region;
  }
  if (!req.http.X-Geo-Continent) {
    set req.http.X-Geo-Continent = geoip.continent_code;
  }

  if (req.url ~ "module=Proxy") {
    return (pass);
  }
  if (req.url ~ "^/piwik(.*)") {
    return (pass);
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

  if (obj.status == 900 ) {
     set obj.http.Content-Type = "";
     synthetic {"<!DOCTYPE html><html lang="en" dir="ltr" class="client-nojs"><head><meta charset="UTF-8"><title>500 Internal Server error &mdash; WebPlatform.org</title><!-- Placeholders --><base href="//www.webplatform.org/" /><link rel="shortcut icon" href="//www.webplatform.org/favicon.ico"/><link rel="stylesheet" href="//www.webplatform.org/assets/css/squished.css"/><link href="//www.webplatform.org/assets/css/error.css" rel="stylesheet"><style>html{background-color:transparent !important;}</style><meta name="viewport" content="width=device-width"></head><body class="ltr sitedir-ltr"><header id="mw-head" class="noprint"><div class="container"><div id="p-logo"><a href="/" title="Visit the main page"></a></div></div></header><nav id="sitenav"><div class="container"><ul class="links"><li><a href="http://status.webplatform.org/">System status</a></li></ul></div></nav><div id="content" class="mw-body"><div class="container"><a id="top"></a><div id="page"><div id="page-content"><div id="main-content"><hgroup><h1 class="code"><img src="//www.webplatform.org/assets/numbers/5.svg" alt="5">&nbsp;<img src="//www.webplatform.org/assets/numbers/0.svg" alt="0">&nbsp;<img src="//www.webplatform.org/assets/numbers/0.svg" alt="0"></h1><h2>Internal Server Error</h2><!-- Placeholders --></hgroup><p>We are sorry, but we encountered a server problem.</p><p>Our system is <strong>configured to notify us of these outages</strong>. You can <strong>see the known system status at <a href="http://status.webplatform.org/">status.webplatform.org</a></strong> or in our <a href="http://lists.w3.org/Archives/Public/public-webplatform/">public mailing-list archive</a>. But if you are having problems with the site that are not reflected in the <a href="http://status.webplatform.org/">status page</a>, please send us an email at <a href="mailto:team-webplatform-systems@w3.org">team-webplatform-systems@w3.org</a>.</p><p>We are sorry for the inconvenience, and thanks for using WebPlatform.org!</p><h2>By the way, do you know what a 500 error is?</h2><!-- Placeholders --><p> Every HTTP request returns a three digit code in the beginning which communicates how everything went in a compact way. These numbers are known as HTTP status codes. </p><p> Want to know more? Read through the <a href="//docs.webplatform.org/wiki/http/response_status_codes">list of HTTP status codes</a> or <a href="//www.webplatform.org">go to the homepage</a> and start from there! </p></div><div class="clear"></div></div></div></div></div></body></html>"};
     return(deliver);
  }

  if (obj.status == 901 ) {
     set obj.http.Content-Type = "";
     synthetic {"<!DOCTYPE html><html lang="en" dir="ltr" class="client-nojs"><head><meta charset="UTF-8"><title>503 Service unavailable &mdash; WebPlatform.org</title><!-- Placeholders --><base href="//www.webplatform.org/" /><link rel="shortcut icon" href="//www.webplatform.org/favicon.ico"/><link rel="stylesheet" href="//www.webplatform.org/assets/css/squished.css"/><link href="//www.webplatform.org/assets/css/error.css" rel="stylesheet"><style>html{background-color:transparent !important;}</style><meta name="viewport" content="width=device-width"></head><body class="ltr sitedir-ltr"><header id="mw-head" class="noprint"><div class="container"><div id="p-logo"><a href="/" title="Visit the main page"></a></div></div></header><nav id="sitenav"><div class="container"><ul class="links"><li><a href="http://status.webplatform.org/">System status</a></li></ul></div></nav><div id="content" class="mw-body"><div class="container"><a id="top"></a><div id="page"><div id="page-content"><div id="main-content"><hgroup><h1 class="code"><img src="//www.webplatform.org/assets/numbers/5.svg" alt="5">&nbsp;<img src="//www.webplatform.org/assets/numbers/0.svg" alt="0">&nbsp;<img src="//www.webplatform.org/assets/numbers/3.svg" alt="3"></h1><h2>Service unavailable</h2><!-- Placeholders --></hgroup><p>We are sorry, but we encountered a server problem.</p><p>Our system is <strong>configured to notify us of these outages</strong>. You can <strong>see the known system status at <a href="http://status.webplatform.org/">status.webplatform.org</a></strong> or in our <a href="http://lists.w3.org/Archives/Public/public-webplatform/">public mailing-list archive</a>. But if you are having problems with the site that are not reflected in the <a href="http://status.webplatform.org/">status page</a>, please send us an email at <a href="mailto:team-webplatform-systems@w3.org">team-webplatform-systems@w3.org</a>.</p><p>We are sorry for the inconvenience, and thanks for using WebPlatform.org!</p><h2>By the way, do you know what a 503 error is?</h2><!-- Placeholders --><p> Every HTTP request returns a three digit code in the beginning which communicates how everything went in a compact way. These numbers are known as HTTP status codes. </p><p> Want to know more? Read through the <a href="//docs.webplatform.org/wiki/http/response_status_codes">list of HTTP status codes</a> or <a href="//www.webplatform.org">go to the homepage</a> and start from there! </p></div><div class="clear"></div></div></div></div></div></body></html>"};
     return(deliver);
  }

  if (obj.status == 902 ) {
     set obj.http.Content-Type = "";
     synthetic {"<!DOCTYPE html><html lang="en" dir="ltr" class="client-nojs"><head><meta charset="UTF-8"><title>Backend server network connectivity error &mdash; WebPlatform.org</title><!-- Placeholders --><base href="//www.webplatform.org/" /><link rel="shortcut icon" href="//www.webplatform.org/favicon.ico"/><link rel="stylesheet" href="//www.webplatform.org/assets/css/squished.css"/><link href="//www.webplatform.org/assets/css/error.css" rel="stylesheet"><style>html{background-color:transparent !important;}</style><meta name="viewport" content="width=device-width"></head><body class="ltr sitedir-ltr"><header id="mw-head" class="noprint"><div class="container"><div id="p-logo"><a href="/" title="Visit the main page"></a></div></div></header><nav id="sitenav"><div class="container"><ul class="links"><li><a href="http://status.webplatform.org/">System status</a></li></ul></div></nav><div id="content" class="mw-body"><div class="container"><a id="top"></a><div id="page"><div id="page-content"><div id="main-content"><hgroup><h1 class="code"><img src="//www.webplatform.org/assets/numbers/5.svg" alt="5">&nbsp;<img src="//www.webplatform.org/assets/numbers/0.svg" alt="0">&nbsp;<img src="//www.webplatform.org/assets/numbers/4.svg" alt="4"></h1><h2>Gateway timeout error</h2><!-- Placeholders --></hgroup><p>We are sorry, but we encountered a backend connectivity timeout problem. In other words our caching layer could not wait any longer to server your request. It might be caused by a request you made that is too heavy at this time for our backend server and it could not respond in a reasonable time. You can try again with different parameters.</p><p>Our system is <strong>configured to notify us of outages</strong>. You can <strong>see the known system status at <a href="http://status.webplatform.org/">status.webplatform.org</a></strong> or in our <a href="http://lists.w3.org/Archives/Public/public-webplatform/">public mailing-list archive</a>. But if you are having problems with the site that are not reflected in the <a href="http://status.webplatform.org/">status page</a>, please send us an email at <a href="mailto:team-webplatform-systems@w3.org">team-webplatform-systems@w3.org</a>.</p><p>We are sorry for the inconvenience, and thanks for using WebPlatform.org!</p><h2>By the way, do you know what a 503 error is?</h2><!-- Placeholders --><p> Every HTTP request returns a three digit code in the beginning which communicates how everything went in a compact way. These numbers are known as HTTP status codes. </p><p> Want to know more? Read through the <a href="//docs.webplatform.org/wiki/http/response_status_codes">list of HTTP status codes</a> or <a href="//www.webplatform.org">go to the homepage</a> and start from there! </p></div><div class="clear"></div></div></div></div></div></body></html>"};
     return(deliver);
  }

  if (obj.status == 903 ) {
     set obj.http.Content-Type = "";
     synthetic {"<!DOCTYPE html><html lang="en" dir="ltr" class="client-nojs"><head><meta charset="UTF-8"><title>Network read timeout error &mdash; WebPlatform.org</title><!-- Placeholders --><base href="//www.webplatform.org/" /><link rel="shortcut icon" href="//www.webplatform.org/favicon.ico"/><link rel="stylesheet" href="//www.webplatform.org/assets/css/squished.css"/><link href="//www.webplatform.org/assets/css/error.css" rel="stylesheet"><style>html{background-color:transparent !important;}</style><meta name="viewport" content="width=device-width"></head><body class="ltr sitedir-ltr"><header id="mw-head" class="noprint"><div class="container"><div id="p-logo"><a href="/" title="Visit the main page"></a></div></div></header><nav id="sitenav"><div class="container"><ul class="links"><li><a href="http://status.webplatform.org/">System status</a></li></ul></div></nav><div id="content" class="mw-body"><div class="container"><a id="top"></a><div id="page"><div id="page-content"><div id="main-content"><hgroup><h1 class="code"><img src="//www.webplatform.org/assets/numbers/5.svg" alt="5">&nbsp;<img src="//www.webplatform.org/assets/numbers/9.svg" alt="9">&nbsp;<img src="//www.webplatform.org/assets/numbers/8.svg" alt="8"></h1><h2>Network read timeout error</h2><!-- Placeholders --></hgroup><p>We are sorry, but we encountered a backend connectivity timeout problem. In other words our caching layer could not wait any longer to server your request. It might be caused by a request you made that is too heavy at this time for our backend server and it could not respond in a reasonable time. You can try again with different parameters.</p><p>Our system is <strong>configured to notify us of outages</strong>. You can <strong>see the known system status at <a href="http://status.webplatform.org/">status.webplatform.org</a></strong> or in our <a href="http://lists.w3.org/Archives/Public/public-webplatform/">public mailing-list archive</a>. But if you are having problems with the site that are not reflected in the <a href="http://status.webplatform.org/">status page</a>, please send us an email at <a href="mailto:team-webplatform-systems@w3.org">team-webplatform-systems@w3.org</a>.</p><p>We are sorry for the inconvenience, and thanks for using WebPlatform.org!</p><h2>By the way, do you know what a 503 error is?</h2><!-- Placeholders --><p> Every HTTP request returns a three digit code in the beginning which communicates how everything went in a compact way. These numbers are known as HTTP status codes. </p><p> Want to know more? Read through the <a href="//docs.webplatform.org/wiki/http/response_status_codes">list of HTTP status codes</a> or <a href="//www.webplatform.org">go to the homepage</a> and start from there! </p></div><div class="clear"></div></div></div></div></div></body></html>"};
     return(deliver);
  }

  if (obj.status == 904 ) {
     set obj.http.Content-Type = "";
     synthetic {"<!DOCTYPE html><html lang="en" dir="ltr" class="client-nojs"><head><meta charset="UTF-8"><title>Network connect timeout error &mdash; WebPlatform.org</title><!-- Placeholders --><base href="//www.webplatform.org/" /><link rel="shortcut icon" href="//www.webplatform.org/favicon.ico"/><link rel="stylesheet" href="//www.webplatform.org/assets/css/squished.css"/><link href="//www.webplatform.org/assets/css/error.css" rel="stylesheet"><style>html{background-color:transparent !important;}</style><meta name="viewport" content="width=device-width"></head><body class="ltr sitedir-ltr"><header id="mw-head" class="noprint"><div class="container"><div id="p-logo"><a href="/" title="Visit the main page"></a></div></div></header><nav id="sitenav"><div class="container"><ul class="links"><li><a href="http://status.webplatform.org/">System status</a></li></ul></div></nav><div id="content" class="mw-body"><div class="container"><a id="top"></a><div id="page"><div id="page-content"><div id="main-content"><hgroup><h1 class="code"><img src="//www.webplatform.org/assets/numbers/5.svg" alt="5">&nbsp;<img src="//www.webplatform.org/assets/numbers/9.svg" alt="9">&nbsp;<img src="//www.webplatform.org/assets/numbers/9.svg" alt="9"></h1><h2>Network connect timeout error</h2><!-- Placeholders --></hgroup><p>We are sorry, but we encountered a backend connectivity timeout problem. In other words our caching layer could not wait any longer to server your request. It might be caused by a request you made that is too heavy at this time for our backend server and it could not respond in a reasonable time. You can try again with different parameters.</p><p>Our system is <strong>configured to notify us of outages</strong>. You can <strong>see the known system status at <a href="http://status.webplatform.org/">status.webplatform.org</a></strong> or in our <a href="http://lists.w3.org/Archives/Public/public-webplatform/">public mailing-list archive</a>. But if you are having problems with the site that are not reflected in the <a href="http://status.webplatform.org/">status page</a>, please send us an email at <a href="mailto:team-webplatform-systems@w3.org">team-webplatform-systems@w3.org</a>.</p><p>We are sorry for the inconvenience, and thanks for using WebPlatform.org!</p><h2>By the way, do you know what a 503 error is?</h2><!-- Placeholders --><p> Every HTTP request returns a three digit code in the beginning which communicates how everything went in a compact way. These numbers are known as HTTP status codes. </p><p> Want to know more? Read through the <a href="//docs.webplatform.org/wiki/http/response_status_codes">list of HTTP status codes</a> or <a href="//www.webplatform.org">go to the homepage</a> and start from there! </p></div><div class="clear"></div></div></div></div></div></body></html>"};
     return(deliver);
  }
  if (req.http.Fastly-Restart-On-Error) {
    if (obj.status == 503 && req.restarts == 0) {
      restart;
    }
  }

  {
    if (obj.status == 550) {
      return(deliver);
    }
  }

###
}

