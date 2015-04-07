# Varnish config files

All Varnish caching config files (VCL) used to serve WebPlatform.org site.

Each file represent an exposed service. Configuration are based on [Fastly's Custom VCL feature](http://docs.fastly.com/guides/21835572/23206371)

To know how we maintain configuration, see [our procedure document](http://docs.webplatform.org/wiki/WPD:Infrastructure/procedures/Maintaining_Varnish_or_Fastly_configuration), in the [WPD:Infrastructure space](http://docs.webplatform.org/wiki/WPD:Infrastructure), and
also the helper document [Things to consider when we expose service behind Varnish](https://docs.webplatform.org/wiki/WPD:Infrastructure/architecture/Things_to_consider_when_we_expose_service_via_Fastly_and_Varnish)


## References

### Core principles to remember

* [Best practices for using the vary header](http://www.fastly.com/blog/best-practices-for-using-the-vary-header/)
* [Caching with analytics/tracking cookies](http://www.fastly.com/blog/how-to-cache-with-tracking-cookies/)


### Misc.
**Reminder** Fastly, our Varnish provider, uses Varnish 2.1.5 syntax.

* http://docs.fastly.com/guides/21835572/23206372
* https://fastly.zendesk.com/entries/23206371
* https://www.varnish-cache.org/docs/2.1/tutorial/vcl.html
* https://www.varnish-software.com/static/book/VCL_functions.html
* http://docs.fastly.com/guides/22958207/27123847
* http://docs.fastly.com/guides/22958207/23206371
* https://www.varnish-cache.org/docs/2.1/tutorial/increasing_your_hitrate.html
* https://fastly.zendesk.com/entries/23206371
* https://community.fastly.com/t/is-there-a-way-to-track-ssl-traffic-vs-non-ssl-traffic/47
