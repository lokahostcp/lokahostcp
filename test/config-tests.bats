#!/usr/bin/env bats

if [ "${PATH#*/usr/local/lokahost/bin*}" = "$PATH" ]; then
    . /etc/profile.d/lokahost.sh
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
        echo 'user=test-5285' > /tmp/lokahost-test-env.sh
        echo 'user2=test-5286' >> /tmp/lokahost-test-env.sh
        echo 'userbk=testbk-5285' >> /tmp/lokahost-test-env.sh
        echo 'userpass1=test-5285' >> /tmp/lokahost-test-env.sh
        echo 'userpass2=t3st-p4ssw0rd' >> /tmp/lokahost-test-env.sh
        echo 'LOKAHOST=/usr/local/lokahost' >> /tmp/lokahost-test-env.sh
        echo 'domain=test-5285.lokahost.com' >> /tmp/lokahost-test-env.sh
        echo 'domainuk=test-5285.lokahost.com.uk' >> /tmp/lokahost-test-env.sh
        echo 'rootdomain=testlokahostcp.com' >> /tmp/lokahost-test-env.sh
        echo 'subdomain=cdn.testlokahostcp.com' >> /tmp/lokahost-test-env.sh
        echo 'database=test-5285_database' >> /tmp/lokahost-test-env.sh
        echo 'dbuser=test-5285_dbuser' >> /tmp/lokahost-test-env.sh
    fi

    source /tmp/lokahost-test-env.sh
    source $LOKAHOST/func/main.sh
    source $LOKAHOST/conf/lokahost.conf
    source $LOKAHOST/func/ip.sh
}

@test "Setup Test domain" {
    run v-add-user $user $user $user@lokahost.com default "Super Test"
    assert_success
    refute_output

    run v-add-web-domain $user 'testlokahostcp.com'
    assert_success
    refute_output

    ssl=$(v-generate-ssl-cert "testlokahostcp.com" "info@testlokahostcp.com" US CA "Orange County" LokahostCP IT "mail.$domain" | tail -n1 | awk '{print $2}')
    mv $ssl/testlokahostcp.com.crt /tmp/testlokahostcp.com.crt
    mv $ssl/testlokahostcp.com.key /tmp/testlokahostcp.com.key

    # Use self signed certificates during last test
    run v-add-web-domain-ssl $user testlokahostcp.com /tmp
    assert_success
    refute_output
}

@test "Web Config test" {
    for template in $(v-list-web-templates plain); do
        run v-change-web-domain-tpl $user testlokahostcp.com $template
        assert_success
        refute_output
    done
}

@test "Proxy Config test" {
    if [ "$PROXY_SYSTEM" = "nginx" ]; then
        for template in $(v-list-proxy-templates plain); do
            run v-change-web-domain-proxy-tpl $user testlokahostcp.com $template
            assert_success
            refute_output
        done
    else
        skip "Proxy not installed"
    fi
}

@test "Clean up" {
    run v-delete-user $user
    assert_success
    refute_output
}
