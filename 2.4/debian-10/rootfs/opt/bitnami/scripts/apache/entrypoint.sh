#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

# Load libraries
. /opt/bitnami/scripts/libapache.sh
. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh

# Load Apache environment
. /opt/bitnami/scripts/apache-env.sh

print_welcome_page

if [[ "$*" == *"/opt/bitnami/scripts/apache/run.sh"* ]]; then
    info "** Starting Apache setup **"
    /opt/bitnami/scripts/apache/setup.sh
    info "** Apache setup finished! **"
fi

TX_SMTP_RELAY_HOST=${TX_SMTP_RELAY_HOST?Missing env var TX_SMTP_RELAY_HOST}
TX_SMTP_RELAY_MYHOSTNAME=${TX_SMTP_RELAY_MYHOSTNAME?Missing env var TX_SMTP_RELAY_MYHOSTNAME}
TX_SMTP_RELAY_USERNAME=${TX_SMTP_RELAY_USERNAME?Missing env var TX_SMTP_RELAY_USERNAME}
TX_SMTP_RELAY_PASSWORD=${TX_SMTP_RELAY_PASSWORD?Missing env var TX_SMTP_RELAY_PASSWORD}
TX_SMTP_RELAY_NETWORKS=${TX_SMTP_RELAY_NETWORKS:-10.0.0.0/8,127.0.0.0/8,172.17.0.0/16,192.0.0.0/8}

echo "Setting configuration"
echo "TX_SMTP_RELAY_HOST        -  ${TX_SMTP_RELAY_HOST}"
echo "TX_SMTP_RELAY_MYHOSTNAME  -  ${TX_SMTP_RELAY_MYHOSTNAME}"
echo "TX_SMTP_RELAY_USERNAME    -  ${TX_SMTP_RELAY_USERNAME}"
echo "TX_SMTP_RELAY_PASSWORD    -  (hidden)"
echo "TX_SMTP_RELAY_NETWORKS    -  ${TX_SMTP_RELAY_NETWORKS}"
echo "TX_SMTP_FALLBACK_RELAY_HOST - ${TX_SMTP_FALLBACK_RELAY_HOST}"

# Write SMTP credentials
echo "${TX_SMTP_RELAY_HOST} ${TX_SMTP_RELAY_USERNAME}:${TX_SMTP_RELAY_PASSWORD}" > /etc/postfix/sasl_passwd || exit 1
postmap /etc/postfix/sasl_passwd || exit 1
rm /etc/postfix/sasl_passwd || exit 1

# Set configurations
postconf 'smtp_sasl_auth_enable = yes' || exit 1
postconf 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd' || exit 1
postconf 'smtp_sasl_security_options =' || exit 1

# These are required
postconf "relayhost = ${TX_SMTP_RELAY_HOST}" || exit 1
postconf "myhostname = ${TX_SMTP_RELAY_MYHOSTNAME}" || exit 1
# if we set a fallback
postconf "fallback_relay = ${TX_SMTP_FALLBACK_RELAY_HOST}"

# Set allowed networks
postconf "mynetworks = ${TX_SMTP_RELAY_NETWORKS}" || exit 1

# http://www.postfix.org/COMPATIBILITY_README.html#smtputf8_enable
postconf 'smtputf8_enable = no' || exit 1

# This makes sure the message id is set. If this is set to no dkim=fail will happen.
postconf 'always_add_missing_headers = yes' || exit 1
mkdir -p /data
service postfix stop
service rsyslog stop
touch /data/mail.log
ln -sf /data/mail.log /var/log/mail.log
service rsyslog start
service postfix start
exec "$@"
