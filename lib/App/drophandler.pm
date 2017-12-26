package App::drophandler;
use Dancer ':syntax';
use if $] < 5.20, 'Filter::signatures';
no warnings 'experimental::signatures';
use feature 'signatures';

use vars '$VERSION';
$VERSION = '0.01';

=head1 NAME

App::drophandler - drag-and-drop URL receiver

This app allows you to launch custom actions when you drag and drop
data from other browsers into its window. For example, you can download
Youtube videos via C<youtube-dl> by configuring the following action
in C<config.yml>:

  - title: Youtube
    handlers:
        - name: Youtube-download
          url_like: (https?://(?:youtu.be|youtube.com)/.*)
          handler: "youtube-dl \"$1\""

This app also makes it easy to configure bookmarklets for such actions
so that you can also trigger the actions from within your browser without
needing to leave the browser.

TODO: add a gif animation of the above here

=cut

#$configfile ||= './drophandler.ini';

#reload_config( $configfile );

#sub reload_config($filename) {
#    undef $ini;
#    Config::IniFiles->new( -file => $filename );
#}

sub admin_log( $message ) {
    print "[ADMIN] $message\n";
};

=head2 C<< restructure_arguments >>

Restore the datastructure (AoH) from a series of keys
of the form C<< data[n][foo] >>.

=cut

sub restructure_arguments($args, $max_size, @allowed_keys) {
    my %allowed;
    undef @allowed{ @allowed_keys };
    my $data= [];
    for my $payload ( keys %$args ) {
        if( $payload =~ /^data\[(\d+)]\[(\w+)\]/ ) {
            if( $1 < $max_size ) {
                if( exists $allowed{ $2 } ) {
                    $data->[$1]->{ $2 } = $args->{ $payload }
                } else {
                    admin_log "Unknown key '$2' not deserialized. Allowed are @allowed_keys";
                };
            } else {
                admin_log "Maliciously? large data item not serialized ($1, max is $max_size)";
            };
        };
    };
    $data
}

# XXX Document API and format of parameters for POST requests

post '/dropped' => sub {
    my $params= params;
    $params->{ zone } =~ /^drop_(\d+)$/
        or return;
    my $zone = $1;
    warn "Zone $zone";

    # Now, restructure our object
    my $data = restructure_arguments(
        $params,
        scalar @{config->{zones}},
        qw(content_type data)
    );
    dispatch( $zone, $data );

    return "OK"
};

# XXX Document API and format of parameters for GET requests

get '/dropped' => sub {
    my $params= params;
    $params->{ zone } =~ /^drop_(\d+)$/
        or return;
    my $zone = $1;
    warn "Zone $zone via GET request";

    # Now, restructure our object
    my $data = restructure_arguments(
        $params,
        scalar @{config->{zones}},
        qw(content_type data)
    );
    dispatch( $zone, $data );

    return "OK"
};

# XXX Document API and format of parameters for reloading the config

post '/reload_config' => sub {
    #reload_config( $configfile );
    return redirect '/';
};

get '/about' => sub {
    template 'about'
};

get '/' => sub {
    my $zone_id= 0;
    my @zones = map {
        add_default_values( $_, $zone_id++ );
    } @{ config->{zones} || [] };

    my $template_data = {
        zones => config->{zones},
    };
    template 'index', $template_data;
};

sub add_default_values( $zone, $id ) {
    $zone->{ zone_id }= $id;
    $zone
}

sub content_type_check( $request_ct, $rule ) {
    my $ct = $rule;
    $ct =~ s!\*!.*!; # Convert from glob to regex
    my $res = $request_ct =~ m!^$ct$!i ? 1 : 0;
    warn "Content-Type: '$request_ct' =~ '$rule' ? $res";
    $res
};

sub dispatch( $zone_number, $data ) {
    my $zone= config->{zones}->[ $zone_number ];
    print "Handling drop in zone $zone_number ('$zone->{title}')\n";
    $SIG{CHLD} = 'IGNORE';
    HANDLER: for my $handler ( @{ $zone->{ handlers }}) {
        print "Checking $handler->{name}\n";
        my $action;

        for my $datacombo (@$data) {
            my $reason;
            if( $handler->{ "url_like" } && $handler->{ content_type } ) {
                $reason = "url-like and content-type";
                if(     content_type_check( $handler->{content_type}, $datacombo->{content_type} )
                    and $datacombo->{data} =~ /$handler->{ "url_like" }/ ) {
                    $action = $handler->{ handler };
                    my @replace_vars = map { substr $datacombo->{data}, $-[$_], $+[$_] } 0..$#+;
                    #warn Dumper \@replace_vars;
                    $action =~ s/\$(\d+)/$replace_vars[$_]/ge;
                };
            } elsif( $handler->{ "url_like" } ) {
                $reason = "url_like";
                if( $datacombo->{data} =~ /$handler->{ "url_like" }/ ) {
                    $action = $handler->{ handler };
                    my @replace_vars = map { substr $datacombo->{data}, $-[$_], $+[$_] } 0..$#+;
                    #warn Dumper \@replace_vars;
                    $action =~ s/\$(\d+)/$replace_vars[$_]/ge;
                };
            };
            if( $action ) {
                print "Matched $handler->{name} ($reason)\n";
                print "Launching [$action]\n";
                system( 1, $action ); # launch in background
                last HANDLER;
            } else {
                print "No match on $handler->{name}\n";
            };
        };
    };
};

true;
