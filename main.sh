#!/usr/bin/env bash
FLYNN_CMD="/app/flynn"
CERTBOT_WORK_DIR="/app"
CERTBOT_CONFIG_DIR="/app/config"

# Validation
if [ -z "$CERTBOT_DNS_PLUGIN" ]; then
    echo "CERTBOT_DNS_PLUGIN must be set"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_KEY" ]; then
    echo "$CLOUDFLARE_API_KEY must be set"
    exit 1
fi

if [ -z "$DOMAINS" ]; then
    echo "DOMAINS must be set"
    exit 1
fi

if [ -z "$CLOUDFLARE_EMAIL" ]; then
    echo "CLOUDFLARE_EMAIL must be set"
    exit 1
fi

if [ -z "$LETS_ENCRYPT_EMAIL" ]; then
    echo "LETS_ENCRYPT_EMAIL must be set"
    exit 1
fi

if [ -z "$FLYNN_CLUSTER_HOST" ]; then
    echo "FLYNN_CLUSTER_HOST must be set"
    exit 1
fi

if [ -z "$FLYNN_CONTROLLER_KEY" ]; then
    echo "FLYNN_CONTROLLER_KEY must be set"
    exit 1
fi

if [ -z "$FLYNN_TLS_PIN" ]; then
    echo "FLYNN_TLS_PIN must be set"
    exit 1
fi

# Install flynn-cli
echo "Installing Flynn CLI..."
L="$FLYNN_CMD" && curl -sSL -A "`uname -sp`" https://dl.flynn.io/cli | zcat >$L && chmod +x $L

# Add cluster
echo "Adding cluster $FLYNN_CLUSTER_HOST..."
"$FLYNN_CMD" cluster add -p "$FLYNN_TLS_PIN" default "$FLYNN_CLUSTER_HOST" "$FLYNN_CONTROLLER_KEY"

if [ "$CERTBOT_DNS_PLUGIN" != "cloudflare" ]; then
   echo "CERTBOT_DNS_PLUGIN only supports 'cloudflare'";
   exit 1;
fi

# Create file needed for certbot
echo "Writing Cloudflare key to disk..."
CLOUDFLARE_SECRET_PATH="/app/cloudflare.ini"
echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" >> "$CLOUDFLARE_SECRET_PATH"
echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" >> "$CLOUDFLARE_SECRET_PATH"
chmod 600 "$CLOUDFLARE_SECRET_PATH"

# Get domains array
echo "Collecting domains..."
DOMAINS_PAIRS_ARRAY=(${DOMAINS//,/ })
COMMA_DOMAINS=""
for ROUTE_DOMAIN_PAIR in "${DOMAINS_PAIRS_ARRAY[@]}"
do
    # Get domain from route:domain pair
    DOMAINS_ARRAY=(${ROUTE_DOMAIN_PAIR//:/ })
    DOMAIN="${DOMAINS_ARRAY[1]}"
    echo "$DOMAIN..."
    COMMA_DOMAINS="$COMMA_DOMAINS,$DOMAIN"
done
# Trim trailing comma
COMMA_DOMAINS="${COMMA_DOMAINS:1}"
echo "done"

echo "Generating certificate for domains..."
echo "certbot certonly \
        --work-dir $CERTBOT_WORK_DIR \
        --config-dir $CERTBOT_CONFIG_DIR \
        --logs-dir $CERTBOT_WORK_DIR/logs \
        --agree-tos \
        --no-eff-email \
        --email $LETS_ENCRYPT_EMAIL \
        --dns-cloudflare \
        --dns-cloudflare-credentials $CLOUDFLARE_SECRET_PATH \
        --dns-cloudflare-propagation-seconds 60 \
        -d $COMMA_DOMAINS"

certbot certonly \
  --work-dir "$CERTBOT_WORK_DIR" \
  --config-dir "$CERTBOT_CONFIG_DIR" \
  --logs-dir "$CERTBOT_WORK_DIR/logs" \
  --agree-tos \
  --no-eff-email \
  --email $LETS_ENCRYPT_EMAIL \
  --dns-cloudflare \
  --dns-cloudflare-credentials $CLOUDFLARE_SECRET_PATH \
  --dns-cloudflare-propagation-seconds 60 \
  -d "$COMMA_DOMAINS"

echo "Updating Flynn routes..."
# First domain is used as directory path
FIRST_DOMAIN_PAIR="${DOMAINS_PAIRS_ARRAY[0]}"
PAIR_ARRAY=(${FIRST_DOMAIN_PAIR//:/ })
FIRST_DOMAIN="${PAIR_ARRAY[1]}"
for ROUTE_DOMAIN_PAIR in "${DOMAINS_PAIRS_ARRAY[@]}"
do
    # Get app name and domain from app:domain pair
    DOMAINS_ARRAY=(${ROUTE_DOMAIN_PAIR//:/ })

    APP_NAME="${DOMAINS_ARRAY[0]}"
    DOMAIN="${DOMAINS_ARRAY[1]}"

    ROUTE_ID=$("$FLYNN_CMD" -a "$APP_NAME" route | grep "$DOMAIN" | awk '{print $3}')

    if [ -z "$ROUTE_ID" ]; then
        echo "Cannot determine route id from '$ROUTE_DOMAIN_PAIR'"
        exit 1
    fi

    echo "Updating route '$DOMAIN' for app '$APP_NAME'..."
    "$FLYNN_CMD" -a "$APP_NAME" route update "$ROUTE_ID" \
        --tls-cert "$CERTBOT_CONFIG_DIR/live/$FIRST_DOMAIN/fullchain.pem" \
        --tls-key "$CERTBOT_CONFIG_DIR/live/$FIRST_DOMAIN/privkey.pem"
done
echo "done"

while true
do
    echo "Renewing certificate..."
    certbot renew \
        --work-dir "$CERTBOT_WORK_DIR" \
        --config-dir "$CERTBOT_CONFIG_DIR" \
        --logs-dir "$CERTBOT_WORK_DIR/logs"

    sleep 60
done
