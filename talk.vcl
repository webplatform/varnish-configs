# Create our own director
# ref: http://blog.exceliance.fr/2013/04/22/client-ip-persistence-or-source-ip-hash-load-balancing/
# And load balance based on hash and availability
director iphashed client {
  {
    .backend = F_app1;
    .weight = 1;
  }
  {
    .backend = F_app2;
    .weight = 1;
  }
  {
    .backend = F_app3;
    .weight = 1;
  }
}


sub vcl_recv {
#FASTLY recv
  if (req.url ~ "^/chat") {
    set req.backend = iphashed;
    set client.identity = client.ip;
    return(pass);
  }
}

sub vcl_deliver {
#FASTLY deliver

  # Debug, what URL was requested
  set resp.http.X-Request-Url = req.url;

  # Debug, change version string
  set resp.http.X-Config-Serial = "2014012200";

  return(deliver);
}
