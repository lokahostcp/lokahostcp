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
    source /tmp/lokahostcp-api-env.sh
    source $LOKAHOSTCP/func/main.sh
    source $LOKAHOSTCP/conf/lokahostcp.conf
    source $LOKAHOSTCP/func/ip.sh
}

@test "[Success][ Admin/password ] List users" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "user=admin&password=$password&returncode=no&cmd=v-list-users&arg1=plain" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "admin"
}

@test "[Success][ Hash ] List users" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$apikey&returncode=no&cmd=v-list-users&arg1=plain" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "admin"
}

@test "[Fail][ APIV2 ] Create new user" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$accesskey&returncode=yes&cmd=v-add-user&arg1=lokahostcptest&arg2=strongpassword&arg3=info@lokahost.online" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "don't have permission to run the command v-add-user"
}

@test "[Success][ Hash ] Create tmp file" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$apikey&cmd=v-make-tmp-file&arg1=strongpassword&arg2=clusterpassword" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "OK"
}

@test "[Success][ Hash ] Create new user" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$apikey&cmd=v-add-user&arg1=lokahostcptest&arg2=/tmp/clusterpassword&arg3=info@lokahost.online&arg4=default" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "OK"
}

@test "[Success][ Hash ] Check password" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$apikey&cmd=v-check-user-password&arg1=lokahostcptest&arg2=strongpassword" "https://$server:$port/api/index.php"
    assert_success
    assert_output --partial "OK"
}


@test "[Success][ Local ] Add user" {
    run v-add-user lokahostcptest 1234BCD info@lokahost.online
    assert_success
}

@test "[Success][ Local ] Add DNS domain" {
    run v-add-dns-domain lokahostcptest ilovelokahostcp.com 127.0.0.1
    assert_success
}

@test "[Success][ APIV2 ] Add remote DNS host" {
    run v-add-remote-dns-host $server $port "$accesskey" '' api 'lokahostcptest'
    assert_success
}

@test "[Success][ APIV2 ] Sync DNS cluster 1" {
    run v-sync-dns-cluster
    assert_success
}

@test "[Success][ Local ] nslookup ilovelokahostcp.com" {
    run nslookup ilovelokahostcp.com $server
    assert_success
    assert_output --partial "127.0.0.1"
}

@test "[Success][ Local ] Add DNS domain 2" {
    run v-add-dns-domain lokahostcptest ilovelokahostcp.org 127.0.0.1
    assert_success
}

@test "[Success][ Local ] Add DNS record" {
    run v-add-dns-record lokahostcptest ilovelokahostcp.org test A 127.0.0.1 yes 20
    assert_success
}

@test "[Success][ Local ] nslookup test.ilovelokahostcp.org" {
    run nslookup test.ilovelokahostcp.org $server
    assert_failure 1
    assert_output --partial "REFUSED"

    run nslookup test.ilovelokahostcp.org localhost
    assert_success
    assert_output --partial "127.0.0.1"
}

@test "[Success][ APIV2 ] Sync DNS cluster 2" {
    run v-sync-dns-cluster
    assert_success

    run nslookup test.ilovelokahostcp.org $server
    assert_success
    assert_output --partial "127.0.0.1"
}

@test "[Success][ Local ] Delete DNS record" {
    run v-delete-dns-record lokahostcptest ilovelokahostcp.org 20
    assert_success
}

@test "[Success][ Local ] nslookup test.ilovelokahostcp.org 2" {
    run nslookup test.ilovelokahostcp.org $server
    assert_success
    assert_output --partial "127.0.0.1"

    run nslookup test.ilovelokahostcp.org localhost
    assert_failure
}

@test "[Success][ APIV2 ] Sync DNS cluster 3" {
    run v-sync-dns-cluster
    assert_success

    run nslookup test.ilovelokahostcp.org $server
    assert_failure
}


@test "[Success][ APIV2 ] Delete remote DNS host" {
    run v-delete-remote-dns-host $server
    assert_success
}


@test "[Success][ Local ] Delete user" {
    run v-delete-user lokahostcptest
    assert_success
}

@test "[Success][ Hash ] Delete user" {
    run curl -k -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "hash=$apikey&cmd=v-delete-user&arg1=lokahostcptest" "https://$server:$port/api/index.php"
}