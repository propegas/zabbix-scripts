#!/usr/bin/perl

#use warnings;
#use strict;

#use strict;
#use warnings;
use utf8;

use Data::Dumper;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use XML::Simple;
use JSON;
#use NET::SSL;
use IO::Socket::SSL;
use Mozilla::CA;

#my $host = "172.20.12.112";
#    my $client = IO::Socket::SSL->new(
#        PeerHost => "$host:443",
#        SSL_verify_mode => 0x00,
#        SSL_ca_file => Mozilla::CA::SSL_ca_file(),
#    )
#        || die "******** Can't connect: $@";
#
#    $client->verify_hostname($host, "http")
#        || die " ****** hostname verification failure";

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
#$ENV{HTTPS_VERSION} = 3;

#print "пк";

my $zabbixSender = "/usr/bin/zabbix_sender";
my $zabbixConfd = "/etc/zabbix/zabbix_agentd.conf";
my $sendFile = "/var/tmp/zabbixSenderHPP2000";
my $zabbixSendCommand = "$zabbixSender -c $zabbixConfd -i ";

#my $USERNAME = "zsm";
#my $PASSWORD = "Mzoning2";

my $debug = 1;

if ($debug == 1) {
    $zabbixSendCommand = "$zabbixSender -vv -c $zabbixConfd -i ";
}

sub getLastEventsId {
    my $ua = shift;
    my $sessionKey = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;
    my $idName = shift;
    my $controller = shift;
    my $zbxArray = shift;

    $url = $http_v."://".$url;
    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'sessionKey' => $sessionKey );
    $req->header( 'dataType' => 'api' );
    my $res = $ua->request( $req );
    my $ref = XMLin( $res->content, KeyAttr => "oid" );

    if ($debug == 1) {
        print Dumper( $ref );
    }

    eval {
        while(my ($k, $oid) = each %{$ref->{OBJECT}}) {


            if ($oid->{name} =~ /^($objectName)$/) {
                my $reference;
                my $id = "";
                my $contr = "";
                my $namefull = "";
                my $fullid = "";
                foreach my $entry (@{$oid->{PROPERTY}}) {

                    if ($entry->{name} =~ /^($idName)$/) {
                        $id = $entry->{content};
                        #$reference = {'{#HP_EVENT_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                        #last;
                    }

                    if ($entry->{name} =~ /^($controller)$/) {
                        #$name = $type . " " . $entry->{content};
                        $contr = $entry->{content};
                        #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                        #last;
                    }

                }
                if ($id ne "") {
                    $reference = { '{#HP_P2000_LASTEVENT_ID}' => $id, '{#HP_P2000_EVENT_CONTR}' => $contr };
                    push @{$zbxArray}, { %{$reference} };
                }

            }

        }
    };
    if ($@) {
        # handle failure...
    }
}

sub getLastEvents {
    my $ua = shift;
    my $sessionKey = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;

    my $colHash = shift;

    $url = $http_v."://".$url;
    if ($debug == 1) {
        print Dumper( $url );
    }
    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'sessionKey' => $sessionKey );
    $req->header( 'dataType' => 'api' );
    my $res = $ua->request( $req );
    my $ref = XMLin( $res->content, KeyAttr => "oid" );

    if ($debug == 1) {
        print Dumper( $ref );
    }

    my $i = 0;
    eval {
        while(my ($k, $oid) = each %{$ref->{OBJECT}}) {


            if ($oid->{name} =~ /^($objectName)$/) {

                $i++;
                my $reference;

                my $time;
                my $eventcode;
                my $eventid;
                my $severity;
                my $message;
                my $controller;

                my $hashKey;
                my $id;
                my $contr = "";
                my $namefull = "";
                my $fullid = "";
                foreach my $entry (@{$oid->{PROPERTY}}) {

                    if ($entry->{name} eq "time-stamp") {
                        $time = $entry->{content};
                    }

                    if ($entry->{name} eq "event-code") {
                        $eventcode = $entry->{content};
                    }

                    if ($entry->{name} eq "event-id") {
                        $eventid = $entry->{content};
                    }

                    if ($entry->{name} eq "severity") {
                        $severity = $entry->{content};
                    }

                    if ($entry->{name} eq "message") {
                        $message = $entry->{content};
                    }

                    if ($entry->{name} eq "controller") {
                        $controller = $entry->{content};
                    }

                }

                $hashKey = $eventid;
                $message = $time." ".$severity." ".$eventcode." ".$eventid." ".$message;

                if ($debug == 1) {
                    print $message."\n";
                }

                $reference->{event} = $message;
                $reference->{key} = $controller;

                $colHash->{$hashKey} = { %{$reference} };

                if ($debug == 1) {
                    print Dumper( $colHash );
                }

                #  $outputString .= "\"$hostname\" \"hp.p2000.stats[$type,$key,$itemKey]\" \"$colHash->{$key}->{$itemKey}\"\n";

            }

        }
    };
    if ($@) {
        # handle failure...
    }

}

sub getHPP200Objects {
    my $ua = shift;
    my $sessionKey = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;
    my $idName = shift;
    my $Name = shift;
    #my $typeName = shift;
    my $type = shift;
    my $parentid = shift;
    my $parenttype = shift;
    my $useparentarray = shift;
    my $zbxArray = shift;

    my $idNameFull = shift; # "controller|phy-index"
    my $NameFull = shift; # "type|enclosure-id|controller|wide-port-index|phy-index"

    $url = $http_v."://".$url;
    #print "**** " . $url;
    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'sessionKey' => $sessionKey );
    $req->header( 'dataType' => 'api' );
    my $res = $ua->request( $req );
    my $ref = XMLin( $res->content, KeyAttr => "oid" );

    if ($debug == 1) {
        print Dumper( $ref );
    }

    #foreach my $oid (values %{$ref->{OBJECT}}) {
    while(my ($k, $oid) = each %{$ref->{OBJECT}}) {
        #print $k . "\n";
        #print $oid->{name} . "\n";
        #if ($oid->{name} eq $objectName) {
        if ($oid->{name} =~ /^($objectName)$/) {

            my $parentname = "";
            if ($useparentarray == 1) {
                ## find parent
                if ($debug == 1) {
                    print "Use parent array\n";
                }

                my $refparent;
                foreach my $parent (@{$ref->{COMP}}) {
                    if ($parent->{P} eq $k) {

                        $refparent = $ref->{OBJECT}->{$parent->{G}}->{PROPERTY};
                        if ($debug == 1) {
                            print "Finded G: ".$parent->{G}."\n";
                            print Dumper ($refparent);
                            print "****\n";
                        }

                        last;
                    }
                }
                # for parent

                #my $parenttype = "";
                foreach my $parent (@{$refparent}) {
                    if ($parent->{name} =~ /^($parentid)$/) {
                        $parentname = $parent->{content};
                        #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                        #last;


                    }

                    if ($parent->{name} =~ /^($parenttype)$/) {
                        #$name = $type . " " . $entry->{content};
                        $parenttype = $entry->{content};
                        #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                        #last;
                    }

                }

            }
            else {

            }

            my $reference;
            my $id;
            my $name = "";
            my $namefull = "";
            my $fullid = "";
            my $sensorType = "";
            my $voltType = "";
            my $typeFull = $type;
            foreach my $entry (@{$oid->{PROPERTY}}) {
                if ($entry->{name} =~ /^($idName)$/) {
                    $id = $entry->{content};
                    #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                    #last;
                }

                if ($entry->{name} =~ /^($NameFull)$/) {
                    #$name = $type . " " . $entry->{content};
                    $namefull .= " ".$entry->{"display-name"}." ".$entry->{content}.",";
                    #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                    #last;
                }

                if ($entry->{name} =~ /^($Name)$/) {
                    #$name = $type . " " . $entry->{content};
                    $name = $entry->{content};
                    #$reference = {'{#HP_P2000_ID}' => $entry->{content}, '{#HP_P2000_TYPE}' => $type};
                    #last;
                }

                # create full id uniq object
                if ($debug == 1) {
                    print "idNameFull: ".$idNameFull."\n";
                }
                if ($entry->{name} =~ /^($idNameFull)$/) {
                    my $partname = $entry->{content};
                    $fullid .= "_".$partname;
                }

                # if not use  parentarray
                if ($useparentarray == 0) {
                    if ($entry->{name} =~ /^($parentid)$/) {
                        #$name = $type . " " . $entry->{content};
                        $parentname = $entry->{content};
                    }
                }

                if ($type eq "Сенсоры") {
                    if ($entry->{name} eq "sensor-type") {
                        $sensorType = $entry->{content};
                        #print " sensorType **** " . $sensorType;
                        my $sensorName = $name;
                        #print " sensorName **** " . $sensorName;
                        if ($sensorName =~ /^Voltage (.*) Loc.*$/) {
                            #print " voltage key **** " . $1;
                            $voltType = $1;
                            #$sensorType = $sensorType . " " . $voltType;
                        }
                        #$typeFull = $type . ": " . $sensorType;
                    }
                }

                # if ( $parentname ne "" ) {
                #     $parentname .= " (" . $parenttype . ")" . "::";
                #     # $SystemCreationClassName = " (" . $SystemCreationClassName . ")";
                # }

                # $reference = {'{#HP_P2000_NAME}' => $name, '{#HP_P2000_ID}' => $id, '{#HP_P2000_TYPE}' => $type,
                #             '{#HP_P2000_PARENT}' => $parentname, '{#HP_P2000_PARENTTYPE}' => $parenttype };
            }

            if ($parentname ne "") {
                $parentname .= " (".$parenttype.")"."::";
                # $SystemCreationClassName = " (" . $SystemCreationClassName . ")";
            }

            # trim spaces
            $namefull =~ s/^\s+|\s+$//g;

            # trim end comma
            $namefull =~ s/,$//g;

            if ($type ne "Сенсоры") {
                $reference = { '{#HP_P2000_NAME}'   => $name, '{#HP_P2000_FULLNAME}' => $namefull, '{#HP_P2000_ID}' =>
                    lc( $id ), '{#HP_P2000_FULLID}' => lc( $fullid ), '{#HP_P2000_TYPE}' => $typeFull,
                    '{#HP_P2000_PARENT}'            => $parentname, '{#HP_P2000_PARENTTYPE}' => $parenttype };
            }
            else {
                $typeFull = $type . ": " . $sensorType . " " . $voltType;
                $typeFull =~ s/^\s+|\s+$//g;
                $reference = { '{#HP_P2000_NAME}'   => $name, '{#HP_P2000_FULLNAME}' => $namefull, '{#HP_P2000_ID}' =>
                    lc( $id ), '{#HP_P2000_FULLID}' => lc( $fullid ), '{#HP_P2000_TYPE}' => $typeFull,
                    '{#HP_P2000_PARENT}'            => $parentname, '{#HP_P2000_PARENTTYPE}' => $parenttype,
                    '{#HP_P2000_SENSORTYPE}' => $sensorType, '{#HP_P2000_VOLTTYPE}' => $voltType
                };
            }

            push @{$zbxArray}, { %{$reference} };
        }
    }
}

sub getHPP200Stats {
    my $ua = shift;
    my $sessionKey = shift;
    my $http_v = shift;
    my $url = shift;
    my $objectName = shift;
    my $idName = shift;
    my $params = shift;

    my $colHash = shift;

    my $idNameFull = shift; # "controller|phy-index"

    $url = $http_v."://".$url;
    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'sessionKey' => $sessionKey );
    $req->header( 'dataType' => 'api' );
    my $res = $ua->request( $req );
    my $ref = XMLin( $res->content, KeyAttr => "oid" );
    foreach my $oid (values %{$ref->{OBJECT}}) {

        if ($oid->{name} =~ /^($objectName)$/) {

            my $reference;
            my $hashKey;
            my $fullid = "";
            foreach my $entry (@{$oid->{PROPERTY}}) {
                my $value = "";
                if ($entry->{name} =~ /^($idName|$params|$idNameFull)$/) {
                    my $key = $1;
                    if ($debug == 1) {
                        print "key: ".$key."\n";
                    }
                    if ($key eq $idName) {
                        $hashKey = lc( $entry->{content} );
                    }

                    if ($key =~ /^($idNameFull)$/) {
                        my $partname = $entry->{content};
                        if ($debug == 1) {
                            print "*** idkey: " . $key;
                            print "*** idNameFull: " . $idNameFull;
                            print "partname: ".$partname."\n";
                        }
                        $fullid .= "_".$partname;
                        if ($debug == 1) {
                            print "fullid: ".$partname."\n";
                        }
                        $hashKey = lc( $fullid );

                    }

                    if ($entry->{name} =~ /^($params)$/) {
                        $value = "";
                        $value = $entry->{content};
                        if ($value eq undef) {
                            $value = "";
                        }

                        if ($entry->{name} =~ /^value$/) {
                            if ($value eq "OK") {
                                $value = "1";
                            }
                            if ($value =~ /^(.*)\sC$/) {
                                $value = $1;
                            }
                            if ($value =~ /^(.*)%$/) {
                                $value = $1;
                            }
                        }

                        $reference->{$key} = $value;

                    }

                }
            }
            $colHash->{$hashKey} = { %{$reference} };
        }
    }

    if ($debug == 1) {
        print Dumper( $colHash );
    }
}

sub getZabbixValues {
    my $hostname = shift;
    my $colHash = shift;
    my $type = shift;
    my $outputString = "";

    foreach my $key (keys %{$colHash}) {
        foreach my $itemKey (keys %{$colHash->{$key}}) {
            $outputString .= "\"$hostname\" \"hp.p2000.stats[$type,$key,$itemKey]\" \"$colHash->{$key}->{$itemKey}\"\n";
        }
    }
    if ($debug == 1) {
        print $outputString;
    }

    #print $outputString;

    $outputString;
}

sub getHPEventsZabbixValues {
    my $hostname = shift;
    my $colHash = shift;
    my $type = shift;
    my $outputString = "";

    foreach my $key (keys %{$colHash}) {
        #foreach my $itemKey (keys %{$colHash->{$key}}) {
        $outputString .= "\"$hostname\" \"hp.p2000.stats[$type,controller_".lc( $colHash->{$key}->{key} ).",event]\" \"$colHash->{$key}->{event}\"\n";
        #}
    }
    if ($debug == 1) {
        print $outputString;
    }

    #print $outputString;

    $outputString;
}

sub logOut {
    my $ua = shift;
    my $sessionKey = shift;
    my $hostname = shift;

    my $url = "https://$hostname/api/exit";
    my $req = HTTP::Request->new( GET => $url );
    $req->header( 'sessionKey' => $sessionKey );
    $req->header( 'dataType' => 'api' );
    $ua->request( $req );
}


# $ipAddr = $ARGV[0];
# $ipPort = $ARGV[1];
# $username = $ARGV[2];
# $password = $ARGV[3];
# $command = $ARGV[4];
# $object = $ARGV[5];
# $zabbixhost = $ARGV[6];

my $hostname = $ARGV[0] or die( "Usage: hp-msa-lld.pl <HOSTNAME> [lld|stats|event]" );
my $ipPort = $ARGV[1];
my $USERNAME = $ARGV[2];
my $PASSWORD = $ARGV[3];
my $function = $ARGV[4] || 'lld';
my $object = $ARGV[5];
my $object = $ARGV[5];
my $zabbixhost = $ARGV[6];
my $eventid = $ARGV[7];

die( "Usage: hp-msa-lld.pl <HOSTNAME> [lld|stats|event]" ) unless ($function =~ /^(lld|stats|event)$/);

my $md5_data = "${USERNAME}_${PASSWORD}";
my $md5_hash = md5_hex( $md5_data );

my $ua = LWP::UserAgent->new;
my $url;
my $http_v = "";
#$ua->ssl_opts( verify_hostnames => 0 );
if ($ipPort eq "80") {
    $http_v = "http";
    $url = "http://$hostname/api/login/".$md5_hash;
}
else {
    #print "*1*1*1";
    $ua->ssl_opts( verify_hostname => 0 );
    #$ua->ssl_opts(timeout => 10);
    #$ua->ssl_opts(verify_hostname => 'false');
    #$ua->ssl_opts(SSL_verify_mode => 0x00);
    $ua->ssl_opts( SSL_ca_file => Mozilla::CA::SSL_ca_file() );
    #$ua->protocols_allowed( ['http', 'https'] );
    $http_v = "https";
    $url = "https://$hostname/api/login/".$md5_hash;
}
my $req = HTTP::Request->new( GET => $url );
my $res = $ua->request( $req );

my $ref = XMLin( $res->content );
my $sessionKey;

if (exists $ref->{OBJECT}->{PROPERTY}->{"return-code"} && $ref->{OBJECT}->{PROPERTY}->{"return-code"}->{content} == 1) {
    $sessionKey = $ref->{OBJECT}->{PROPERTY}->{"response"}->{content};
} else {
    die( $ref->{OBJECT}->{PROPERTY}->{"response"}->{content} );
}

if ($function eq 'lld') {
    my $zbxArray = [ ];

    if ($object eq 'events') {
        if ($debug == 1) {
            print 'events\n';
        }
        getLastEventsId( $ua, $sessionKey, $http_v, "$hostname/api/show/events/A/last/1",
            "event", "event-id", "controller", $zbxArray );

        getLastEventsId( $ua, $sessionKey, $http_v, "$hostname/api/show/events/B/last/1",
            "event", "event-id", "controller", $zbxArray );
    }

    if ($object eq 'controllers') {
        if ($debug == 1) {
            print 'controllers\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "controllers", "durable-id", "controller-id", "Контроллеры", "enclosure-id", "Полки", 1, $zbxArray );
    }

    if ($object eq 'enclosures') {
        if ($debug == 1) {
            print 'enclosures\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "enclosures", "durable-id", "enclosure-id", "Полки", "", "", 0, $zbxArray );
    }

    if ($object eq 'ports') {
        if ($debug == 1) {
            print 'ports\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/ports",
            "ports", "durable-id", "port", "Порты", "controller", "Контроллеры", 0, $zbxArray );
    }

    if ($object eq 'ethports') {
        if ($debug == 1) {
            print 'ethports\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/controllers",
            "controller-[a-z]", "durable-id", "durable-id", "Порты ETH", "controller-id", "Контроллеры", 1, $zbxArray );
    }

    if ($object eq 'sasports') {
        if ($debug == 1) {
            print 'sasports\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/sas-link-health",
            "expander-port", "durable-id", "name", "Порты SAS", "controller", "Контроллеры", 0, $zbxArray );
    }

    if ($object eq 'psu') {
        if ($debug == 1) {
            print 'psu\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "power-supplies", "durable-id", "name", "Блоки питания", "enclosure-id", "Полки", 1, $zbxArray );
    }

    if ($object eq 'fans') {
        if ($debug == 1) {
            print 'fans\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "fan-details", "durable-id", "name", "Вентиляторы", "enclosure-id", "Полки", 1, $zbxArray );
    }

    if ($object eq 'ioports') {
        if ($debug == 1) {
            print 'ioports\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/expander-status",
            "enclosure-id", "phy-index|phy", "phy-index|phy", "IO порты", "controller", "Контроллеры", 0, $zbxArray,
            "enclosure-id|controller|wide-port-index|phy-index|phy|type",
            "type|enclosure-id|controller|wide-port-index|phy-index|phy" );
    }

    if ($object eq 'iomodules') {
        if ($debug == 1) {
            print 'iomodules\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "io-module", "durable-id", "name", "IO модули", "enclosure-id", "Полки", 1, $zbxArray );
    }

    if ($object eq 'sensors') {
        if ($debug == 1) {
            print 'sensors\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/sensor-status",
            "sensor", "durable-id", "sensor-name", "Сенсоры", "enclosure-id", "Полки", 0, $zbxArray,
            "enclosure-id|durable-id|sensor-name" );
    }

    if ($object eq 'vdisks') {
        if ($debug == 1) {
            print 'vdisks\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/vdisks",
            "virtual-disk", "name", "Виртуальные диски", $zbxArray );
    }

    if ($object eq 'disks') {
        if ($debug == 1) {
            print 'disks\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/disks",
            "drive", "durable-id", "durable-id", "Диски", "enclosure-id", "Полки", 0, $zbxArray );
    }

    if ($object eq 'volumes') {
        if ($debug == 1) {
            print 'volumes\n';
        }
        getHPP200Objects ( $ua, $sessionKey, $http_v, "$hostname/api/show/volumes",
            "volume", "volume-name", "Тома", $zbxArray );
    }

    print to_json( { data => $zbxArray }, { utf8 => 1, pretty => 1 } )."\n";

    logOut( $ua, $sessionKey, $hostname );
}
elsif ($function eq 'event') {
    my $ctrls = { };
    my $vdisks = { };
    my $volumes = { };
    my $outputString = "";

    #if ($object eq 'event'){
    if ($debug == 1) {
        print 'event\n';
    }

    if ($eventid =~ /^([aA-zZ]+)(\d+)$/) {
        my $id = $2;
        $id++;
        $eventid = $1.$id;
    }

    getLastEvents ( $ua, $sessionKey, $http_v, "$hostname/api/show/events/".$object."/from-event/".$eventid,
        "event", $ctrls );

    $outputString .= getHPEventsZabbixValues( $zabbixhost, $ctrls, "events" );

    logOut( $ua, $sessionKey, $hostname );

    #$outputString .= getZabbixValues($zabbixhost, $ctrls, "Controller");
    #$outputString .= getZabbixValues($zabbixhost, $vdisks, "Vdisk");
    #$outputString .= getZabbixValues($zabbixhost, $volumes, "Volume");

    $sendFile .= "_${hostname}_$$";
    die "Could not open file $sendFile!" unless (open( FH, ">", $sendFile ));
    print FH $outputString;
    die "Could not close file $sendFile!" unless (close( FH ));

    $zabbixSendCommand .= $sendFile;

    my $result = qx($zabbixSendCommand);
    if ($debug == 1) {
        print $result;
    }

    if ($result =~ /Failed 0/) {
        $res = 1;
    } else {
        $res = 0;
    }

    die "Can not remove file $sendFile!" unless (unlink ( $sendFile ));
    print "$res\n";
    exit ( $res - 1 );
    #}

}
else {
    my $ctrls = { };
    my $vdisks = { };
    my $volumes = { };
    my $outputString = "";

    if ($object eq 'enclosures') {
        if ($debug == 1) {
            print 'enclosures\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "enclosures", "durable-id", "type|model|description|number-of-disks|health-numeric|health-reason", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "enclosures" );
    }

    if ($object eq 'controllers') {
        if ($debug == 1) {
            print 'controllers\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/controllers",
            "controllers", "durable-id", "health-numeric|health-reason|ip-address", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "controllers" );
    }

    if ($object eq 'controllers2') {
        if ($debug == 1) {
            print 'controllers2\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/controller-statistics",
            "controller-statistics", "durable-id",
            "cpu-load|bytes-per-second-numeric|iops|number-of-reads|number-of-writes|data-read-numeric|data-written-numeric"
            , $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "controllers" );
    }

    if ($object eq 'ports') {
        if ($debug == 1) {
            print 'ports\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/ports",
            "ports", "durable-id", "status-numeric|health-reason|health-numeric", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "ports" );
    }

    if ($object eq 'ethports') {
        if ($debug == 1) {
            print 'ethports\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/controllers",
            "controller-[a-z]", "durable-id", "health-numeric|health-reason", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "ethports" );
    }

    if ($object eq 'sasports') {
        if ($debug == 1) {
            print 'sasports\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/sas-link-health",
            "expander-port", "durable-id", "status-numeric|health-reason|health-numeric", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "sasports" );
    }

    if ($object eq 'psu') {
        if ($debug == 1) {
            print 'psu\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "power-supplies", "durable-id", "status-numeric|health-reason|health-numeric", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "psu" );
    }

    if ($object eq 'fans') {
        if ($debug == 1) {
            print 'fans\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "fan-details", "durable-id", "status-numeric|health-reason|health-numeric", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "fans" );
    }

    if ($object eq 'ioports') {
        if ($debug == 1) {
            print 'ioports\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/expander-status",
            "enclosure-id", "", "status-numeric|elem-status-numeric|elem-disabled-numeric|elem-reason", $ctrls,
            "enclosure-id|controller|wide-port-index|phy-index|phy|type" );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "ioports" );
    }

    if ($object eq 'iomodules') {
        if ($debug == 1) {
            print 'iomodules\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/enclosures",
            "io-module", "durable-id", "health-numeric|health-reason", $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "iomodules" );
    }

    if ($object eq 'sensors') {
        if ($debug == 1) {
            print 'sensors\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/sensor-status",
            "sensor", "durable-id", "status-numeric|health-reason|status|value", $ctrls,
            "enclosure-id|durable-id|sensor-name" );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "sensors" );
    }

    if ($object eq 'disks') {
        if ($debug == 1) {
            print 'disks\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/disks",
            "drive", "durable-id", "health-numeric|health-reason|number-of-ios|total-data-transferred-numeric",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "disks" );
    }

    if ($object eq 'disks2') {
        if ($debug == 1) {
            print 'disks2\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/disks",
            "drive", "durable-id", "serial-number|vendor|model|description|architecture|revision|size|rpm|ssd-life-left"
            , $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "disks" );
    }

    if ($object eq 'disks3') {
        if ($debug == 1) {
            print 'disks3\n';
        }
        getHPP200Stats ( $ua, $sessionKey, $http_v, "$hostname/api/show/disk-statistics",
            "disk-statistics", "durable-id",
            "bytes-per-second-numeric|number-of-reads|number-of-writes|iops|data-read-numeric|data-written-numeric",
            $ctrls );

        $outputString .= getZabbixValues( $zabbixhost, $ctrls, "disks" );
    }

    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/controller-statistics",
    #              "controller-statistics", "durable-id", $ctrls);
    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/vdisk-statistics",
    #              "vdisk-statistics", "name", $vdisks);
    # getHPP200Stats ( $ua, $sessionKey, "https://$hostname/api/show/volume-statistics",
    #              "volume-statistics", "volume-name", $volumes);
    logOut( $ua, $sessionKey, $hostname );

    #$outputString .= getZabbixValues($zabbixhost, $ctrls, "Controller");
    #$outputString .= getZabbixValues($zabbixhost, $vdisks, "Vdisk");
    #$outputString .= getZabbixValues($zabbixhost, $volumes, "Volume");

    $sendFile .= "_${hostname}_$$";
    die "Could not open file $sendFile!" unless (open( FH, ">", $sendFile ));
    print FH $outputString;
    die "Could not close file $sendFile!" unless (close( FH ));

    $zabbixSendCommand .= $sendFile;

    my $result = qx($zabbixSendCommand);
    if ($debug == 1) {
        print $result;
    }

    if ($result =~ /Failed 0/) {
        $res = 1;
    } else {
        $res = 0;
    }

    die "Can not remove file $sendFile!" unless (unlink ( $sendFile ));
    print "$res\n";
    exit ( $res - 1 );
}


