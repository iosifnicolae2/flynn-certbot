# Flynn Certbot with Cloudflare support
This repo was forked from https://github.com/nrempel/flynn-certbot.

This tool can help you automatically issue and renew SSL certificates and secure Flynn routes for related domains. The tool uses [Let's Encrypt](https://letsencrypt.org) to generate certificates.

Pull requests with improvements are welcome. For significant changes, create an issue first to discuss the topic.

## Caveats

I'm using this tool right now and it works for me but it is not well tested. I would recommend reading the script before following these instructions.

Currently, this only works for clusters hosted on Digital Ocean.

Since Flynn does not support persistent volumes, every time the process starts it issues a certificate then begins watching to renew the certificate. Due to [Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/), this can only happen 20 times per week.

Scaling the process will trigger this. Changing environment variables will trigger this. Deployments will trigger this. I recommend double checking your configuration is correct before scaling up the process.

If you scale deployment past a single process, you may see problems.

You've been warned!

## Installing

Clone this repository.

Create a new Flynn app using this repository.

`flynn create certbot`

### Environment variables
Set the following environment variables:
CERTBOT_DNS_PLUGIN=cloudflare
CLOUDFLARE_API_KEY=<paste_cloudflare_token>
DOMAINS=example.your-domain.com
CLOUDFLARE_EMAIL=<paste_cloudflare_email>
FLYNN_CLUSTER_HOST=<cluster_domain_name>
FLYNN_CONTROLLER_KEY=<controller_key>
FLYNN_TLS_PIN=<check_above_script>


#### FLYNN_CONTROLLER_KEY
```
flynn -c <cluster_domain_name> -a controller env get AUTH_KEY
```

#### FLYNN_TLS_PIN
```
openssl s_client -connect controller.website.mailo.ml:443 \
  -servername controller.website.mailo.ml 2>/dev/null </dev/null \
  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
  | openssl x509 -inform PEM -outform DER \
  | openssl dgst -binary -sha256 \
  | openssl base64
```



Finally, when you're ready, push this repository to your flynn remote then scale it to 1 process (exactly).
```
git push flynn master
```
If everything goes well, all of the domains in `$DOMAINS` should now support https routes with a valid certificate!

🍻
