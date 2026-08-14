#!/usr/bin/env bats

if [ "${PATH#*/usr/local/lokahostcp/bin*}" = "$PATH" ]; then
    . /etc/profile.d/lokahostcp.sh
fi

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

function random() {
head /dev/urandom | tr -dc 0-9 | head -c$1
}

function setup() {
    # echo "# Setup_file" > &3
    if [ $BATS_TEST_NUMBER = 1 ]; then
        echo 'user=test-5285' > /tmp/lokahostcp-test-env.sh
        echo 'user2=test-5286' >> /tmp/lokahostcp-test-env.sh
        echo 'userbk=testbk-5285' >> /tmp/lokahostcp-test-env.sh
        echo 'userpass1=test-5285' >> /tmp/lokahostcp-test-env.sh
        echo 'userpass2=t3st-p4ssw0rd' >> /tmp/lokahostcp-test-env.sh
        echo 'LOKAHOSTCP=/usr/local/lokahostcp' >> /tmp/lokahostcp-test-env.sh
        echo 'domain=test-5285.lokahost.online' >> /tmp/lokahostcp-test-env.sh
        echo 'domainuk=test-5285.lokahost.online.uk' >> /tmp/lokahostcp-test-env.sh
        echo 'rootdomain=testlokahostcp.com' >> /tmp/lokahostcp-test-env.sh
        echo 'subdomain=cdn.testlokahostcp.com' >> /tmp/lokahostcp-test-env.sh
        echo 'database=test-5285_database' >> /tmp/lokahostcp-test-env.sh
        echo 'dbuser=test-5285_dbuser' >> /tmp/lokahostcp-test-env.sh
    fi

    source /tmp/lokahostcp-test-env.sh
    source $LOKAHOSTCP/func/main.sh
    source $LOKAHOSTCP/conf/lokahostcp.conf
    source $LOKAHOSTCP/func/ip.sh
}



function validate_web_domain() {
    local user=$1
    local domain=$2
    local webproof=$3
    local webpath=${4}
    local valwebpath=${5}

    refute [ -z "$user" ]
    refute [ -z "$domain" ]
    refute [ -z "$webproof" ]

    source $LOKAHOSTCP/func/ip.sh

    run v-list-web-domain $user $domain
    assert_success

    USER_DATA=$LOKAHOSTCP/data/users/$user
    local domain_ip=$(get_object_value 'web' 'DOMAIN' "$domain" '$IP')
    SSL=$(get_object_value 'web' 'DOMAIN' "$domain" '$SSL')
    domain_ip=$(get_real_ip "$domain_ip")

    if [ -z $valwebpath ]; then
        if [ ! -z $webpath ]; then
            domain_docroot=$(get_object_value 'web' 'DOMAIN' "$domain" '$CUSTOM_DOCROOT')
            if [ -n "$domain_docroot" ] && [ -d "$domain_docroot" ]; then
                assert_file_exist "${domain_docroot}/${webpath}"
            else
                assert_file_exist "${HOMEDIR}/${user}/web/${domain}/public_html/${webpath}"
            fi
        fi
    fi
    # Test HTTP
    run curl --location --silent --show-error --insecure --resolve "${domain}:80:${domain_ip}" "http://${domain}/${webpath}"
    assert_success
    assert_output --partial "$webproof"

    # Test HTTPS
    if [ "$SSL" = "yes" ]; then
        run v-list-web-domain-ssl $user $domain
        assert_success

        run curl --location --silent --show-error --insecure --resolve "${domain}:443:${domain_ip}" "https://${domain}/${webpath}"
        assert_success
        assert_output --partial "$webproof"
    fi
}

#----------------------------------------------------------#
#                     Backup / Restore                     #
#----------------------------------------------------------#

#Test backup
#  Lokahostcp v1.1.1 archive contains:
#    user: lokahostcp111
#    web:
#      - test.lokahost.online (+SSL self-signed)
#    dns:
#      - test.lokahost.online
#    mail:
#      - test.lokahost.online
#    mail acc:
#      - testaccount@test.lokahost.online
#    db:
#      - lokahostcp111_db
#    cron:
#      - 1: /bin/true
#  Lokahostcp 1.7.0 archive contains (As zstd format)
#    user: lokahostcp131
#    web:
#      - test.lokahost.online (+SSL self-signed)
#        FTP Account
#        Awstats enabled
#    dns:
#      - test.lokahost.online
#    mail:
#      - test.lokahost.online
#        Ratelimit: 10
#    mail acc:
#      - testaccount@test.lokahost.online
#           Alias: info@test.lokahost.online
#           Ratelimit: 20
#      - support@test.lokahost.online
#    db:
#      - lokahostcp170_db
#    cron:
#      - 1: /bin/true
#  Vesta 0.9.8-23 archive contains:
#    user: vesta09823
#    web:
#      - vesta09823.tld (+SSL self-signed)
#    dns:
#      - vesta09823.tld
#    mail:
#      - vesta09823.tld
#    mail acc:
#      - testaccount@vesta09823.tld
#    db:
#      - vesta09823_db
#    cron:
#      - 1: /bin/true
#

# Testing Lokahostcp backups
@test "Restore[1]: Lokahostcp archive for a non-existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    mkdir -p /backup

    local archive_name="lokahostcp111.2020-03-26"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[1]: From Lokahostcp [WEB]" {
    local domain="test.lokahost.online"
    validate_web_domain $userbk $domain 'Hello Lokahostcp'
}

@test "Restore[1]: From Lokahostcp [DNS]" {
    local domain="test.lokahost.online"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[1]: From Lokahostcp [MAIL]" {
    local domain="test.lokahost.online"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[1]: From Lokahostcp [MAIL-Account]" {
    local domain="test.lokahost.online"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
}

@test "Restore[1]: From Lokahostcp [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[1]: From Lokahostcp [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}

@test "Restore[1]: From Lokahostcp Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}


@test "Restore[2]: Lokahostcp archive over a existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    if [ ! -d "$HOMEDIR/$userbk" ]; then
        run v-add-user $userbk $userbk test@lokahost.online
        assert_success
    fi

    mkdir -p /backup

    local archive_name="lokahostcp111.2020-03-26"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[2]: From Lokahostcp [WEB]" {
    local domain="test.lokahost.online"
    validate_web_domain $userbk "${domain}" 'Hello Lokahostcp'
}

@test "Restore[2]: From Lokahostcp [DNS]" {
    local domain="test.lokahost.online"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[2]: From Lokahostcp [MAIL]" {
    local domain="test.lokahost.online"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[2]: From Lokahostcp [MAIL-Account]" {
    local domain="test.lokahost.online"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
}

@test "Restore[2]: From Lokahostcp [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[2]: From Lokahostcp [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}

@test "Restore[2]: From Lokahostcp Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}

@test "Restore[3]: Lokahostcp (zstd) archive for a non-existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    mkdir -p /backup

    local archive_name="lokahostcp170.2022-08-23"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[3]: From Lokahostcp [WEB]" {
    local domain="test.lokahost.online"
    validate_web_domain $userbk $domain 'Hello Lokahostcp'
}

@test "Restore[3]: From Lokahostcp [WEB] FTP" {
    local domain="test.lokahost.online"
    assert_file_contains /etc/passwd "$userbk_test"
    assert_file_contains /etc/passwd "/home/$userbk/web/$domain"
}

@test "Restore[3]: From Lokahostcp [WEB] Awstats" {
    local domain="test.lokahost.online"
    assert_file_exist /home/$userbk/conf/web/$domain/awstats.conf
}

@test "Restore[3]: From Lokahostcp [WEB] Custom rule" {
    # check if custom rule is still working
    local domain="test.lokahost.online"
    validate_web_domain $userbk $domain 'lokahostcp-yes' '/lokahostcp/lokahostcp' 'no'
}


@test "Restore[3]: From Lokahostcp [DNS]" {
    local domain="test.lokahost.online"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[3]: From Lokahostcp [MAIL]" {
    local domain="test.lokahost.online"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[3]: From Lokahostcp [MAIL-Account]" {
    local domain="test.lokahost.online"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
    # Check if alias is created
    assert_file_contains /etc/exim4/domains/$domain/aliases "testaccount@$domain"
    # Check if expected rate limits are set
    assert_file_contains /etc/exim4/domains/$domain/limits "testaccount@$domain:20"
    assert_file_contains /etc/exim4/domains/$domain/limits "support@$domain:10"
}

@test "Restore[3]: From Lokahostcp [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[3]: From Lokahostcp [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}


@test "Restore[3]: From Lokahostcp Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}

@test "Restore[4]: Lokahostcp (zstd) archive for a existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    if [ ! -d "$HOMEDIR/$userbk" ]; then
        run v-add-user $userbk $userbk test@lokahost.online
        assert_success
    fi

    mkdir -p /backup

    local archive_name="lokahostcp170.2022-08-23"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[4]: From Lokahostcp [WEB]" {
    local domain="test.lokahost.online"
    validate_web_domain $userbk $domain 'Hello Lokahostcp'
}

@test "Restore[4]: From Lokahostcp [WEB] FTP" {
    local domain="test.lokahost.online"
    assert_file_contains /etc/passwd "$userbk_test"
    assert_file_contains /etc/passwd "/home/$userbk/web/$domain"
}

@test "Restore[4]: From Lokahostcp [WEB] Awstats" {
    local domain="test.lokahost.online"
    assert_file_exist /home/$userbk/conf/web/$domain/awstats.conf
}

@test "Restore[4]: From Lokahostcp [WEB] Custom rule" {
    # check if custom rule is still working
    local domain="test.lokahost.online"
    validate_web_domain $userbk $domain 'lokahostcp-yes' '/lokahostcp/lokahostcp' 'no'
}


@test "Restore[4]: From Lokahostcp [DNS]" {
    local domain="test.lokahost.online"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[4]: From Lokahostcp [MAIL]" {
    local domain="test.lokahost.online"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[4]: From Lokahostcp [MAIL-Account]" {
    local domain="test.lokahost.online"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
    # Check if alias is created
    assert_file_contains /etc/exim4/domains/$domain/aliases "testaccount@$domain"
    # Check if expected rate limits are set
    assert_file_contains /etc/exim4/domains/$domain/limits "testaccount@$domain:20"
    assert_file_contains /etc/exim4/domains/$domain/limits "support@$domain:10"
}

@test "Restore[4]: From Lokahostcp [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[4]: From Lokahostcp [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}

@test "Restore[4]: From Lokahostcp Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}


# Testing Vesta Backups
@test "Restore[1]: Vesta archive for a non-existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    mkdir -p /backup

    local archive_name="vesta09823.2018-10-18"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[1]: From Vesta [WEB]" {
    local domain="vesta09823.tld"
    validate_web_domain $userbk $domain 'Hello Vesta'
}

@test "Restore[1]: From Vesta [DNS]" {
    local domain="vesta09823.tld"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[1]: From Vesta [MAIL]" {
    local domain="vesta09823.tld"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[1]: From Vesta [MAIL-Account]" {
    local domain="vesta09823.tld"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
}

@test "Restore[1]: From Vesta [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[1]: From Vesta [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}

@test "Restore[1]: From Vesta Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}


@test "Restore[2]: Vesta archive over a existing user" {
    if [ -d "$HOMEDIR/$userbk" ]; then
        run v-delete-user $userbk
        assert_success
        refute_output
    fi

    if [ ! -d "$HOMEDIR/$userbk" ]; then
        run v-add-user $userbk $userbk test@lokahost.online
        assert_success
    fi

    mkdir -p /backup

    local archive_name="vesta09823.2018-10-18"
    run wget --quiet --tries=3 --timeout=15 --read-timeout=15 --waitretry=3 --no-dns-cache "https://storage.lokahost.online/testing/data/${archive_name}.tar" -O "/backup/${archive_name}.tar"
    assert_success

    run v-restore-user $userbk "${archive_name}.tar"
    assert_success

    rm "/backup/${archive_name}.tar"
}

@test "Restore[2]: From Vesta [WEB]" {
    local domain="vesta09823.tld"
    validate_web_domain $userbk "${domain}" 'Hello Vesta'
}

@test "Restore[2]: From Vesta [DNS]" {
    local domain="vesta09823.tld"

    run v-list-dns-domain $userbk $domain
    assert_success

    run nslookup $domain 127.0.0.1
    assert_success
}

@test "Restore[2]: From Vesta [MAIL]" {
    local domain="vesta09823.tld"

    run v-list-mail-domain $userbk $domain
    assert_success
}

@test "Restore[2]: From Vesta [MAIL-Account]" {
    local domain="vesta09823.tld"

    run v-list-mail-account $userbk $domain testaccount
    assert_success
}

@test "Restore[2]: From Vesta [DB]" {
    run v-list-database $userbk "${userbk}_db"
    assert_success
}

@test "Restore[2]: From Vesta [CRON]" {
    run v-list-cron-job $userbk 1
    assert_success
}

@test "Restore[2]: From Vesta Cleanup" {
    run v-delete-user $userbk
    assert_success
    refute_output
}
