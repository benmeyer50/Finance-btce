package Finance::btce;

use 5.012004;
use strict;
use warnings;
use POSIX; # for INT_MAX
use JSON;
use LWP::UserAgent;
use Carp qw(croak);
use Digest::SHA qw(hmac_sha512_hex);
use WWW::Mechanize;
use MIME::Base64;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Finance::btce ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(BtceConversion BTCtoUSD LTCtoBTC LTCtoUSD BtceDepth BtceTrades) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(new);

our $VERSION = '0.1';

our $json = JSON->new->allow_nonref;

sub BTCtoUSD
{
	return BtceConversion('btc_usd');
}

sub LTCtoBTC
{
	return BtceConversion('ltc_btc');
}

sub LTCtoUSD
{
	return BtceConversion('ltc_usd');
}

sub BtceConversion
{
	my ($exchange) = @_;
	return _apiprice('Mozilla/4.76 [en] (Win98; U)', $exchange);
}

sub BtceFee
{
	my ($exchange) = @_;
	return _apifee('Mozilla/4.76 [en] (Win98; U)', $exchange);
}

sub BtceTrades
{
	my ($exchange) = @_;
	return _apitrades('Mozilla/4.76 [en] (Win98; U)', $exchange);
}

sub BtceDepth
{
	my ($exchange) = @_;
	return _apidepth('Mozilla/4.76 [en] (Win98; U)', $exchange);
}
	

### Authenticated API calls

sub new
{
	my ($class, $args) = @_;
	
	my $self = {
		mech => WWW::Mechanize->new(stack_depth => 0, quiet=>0),
		apikey => ${$args}{'apikey'},
		secret => ${$args}{'secret'},
	};
	
	unless ($self->{'apikey'} && $self->{'secret'})
	{
		croak "You must provide an apikey and secret";
		return undef;
	}

	$self->{mech}->agent_alias('Windows IE 6');

	return bless $self, $class;
}

sub getInfo
{
	my ($self) = @_;
	return $self->_post('getInfo');
}

sub TradeHistory
{
	my ($self, $args) = @_;
	return $self->_post('TradeHistory', $args);
}

sub ActiveOrders
{
	my ($self, $exchange) = @_;
	my $args;
	if (defined($exchange)) {
		${$args}{'pair'} = $exchange;
	}
	return $self->_post('ActiveOrders', $args);
}

sub CancelOrder
{
	my ($self, $oid) = @_;
	my $args;
	${$args}{'order_id'} = $oid;
	return $self->_post('CancelOrder', $args);
}

sub Trade
{
	my ($self, $args) = @_;
	if ($args->{'pair'} && $args->{'type'} && $args->{'rate'} &&
	    $args->{'amount'}) {
		foreach my $v (('rate','amount')) {
			# can't have more than 8 digits of precision
			$args->{$v} = sprintf "%0.8f", $args->{$v};
			$args->{$v} =~ s/0+$//g;
			$args->{$v} =~ s/\.$//g;
		}
		# further check validity of arguments somehow??
	} else {
		croak "Trade requires pair+type+rate+amount args";
	}
	return $self->_post('Trade', $args);
}

#private methods

sub _apikey
{
	my ($self) = @_;
	return $self->{'apikey'};
}

sub _apiget
{
	my ($version, $url) = @_;

	my $browser = _newagent($version);
	retryapiget:
	my $resp = $browser->get($url);
	my $response = $resp->content;
	my %info;
	my $ret;
	eval {
		$ret = $json->decode($response);
	};
	if (ref($ret) eq "HASH") {
		%info = %{$ret};
	} else {
		return $ret;
	}
	if ($@) {
		if ($response =~ /Please try again in a few minutes/ ||
			$response =~ /handshake problems/ ||
			$response =~ /connection issue between CloudFare/ ||
			$response =~ /Connection timed out/) {
			print STDERR "!";
			sleep(5);
			goto retryapiget;
		}
		printf STDERR "ApiGet(%s, %s): response = '%s'\n",
			$version, $url, $response;
		printf STDERR "ApiPrice(%s, %s): %s\n", $version, $url, $@;
		my %i;
		return \%i;
	}
	return \%info;
}

sub _apiprice
{
	my ($version, $exchange) = @_;

	my %ticker = %{_apiget($version, "https://btc-e.com/api/2/".$exchange."/ticker")};
	if (! keys %ticker || ! defined($ticker{'ticker'})) {
		return \%ticker;
	}
	my %prices = %{$ticker{'ticker'}};
	my %price = (
		'updated' => $prices{'updated'},
		'last' => $prices{'last'},
		'high' => $prices{'high'},
		'low' => $prices{'low'},
		'avg' => $prices{'avg'},
		'buy' => $prices{'buy'},
		'sell' => $prices{'sell'},
	);

	return \%price;
}

sub _apifee
{
	my ($version, $exchange) = @_;

	my %fees = %{_apiget($version, "https://btc-e.com/api/2/".$exchange."/fee")};
	return \%fees;
}

sub _apitrades
{
	my ($version, $exchange) = @_;

	return _apiget($version, "https://btc-e.com/api/2/".$exchange."/trades");
}

sub _apidepth
{
	my ($version, $exchange) = @_;

	my %depth = %{_apiget($version, "https://btc-e.com/api/2/".$exchange."/depth")};
	return \%depth;
}

# A word about nonces.  Nowhere can I find this documented, but through
# experience I have figured out that the nonce is a unique integer per api key
# that must be incremented per reqest.  Whatever one starts out with, one must
# increment.  Thus unix time seems appropriate for most use cases.
# In the event multiple apps are using the same api key (debug daemon + reg
sub _createnonce
{
	my ($self) = @_;
	if (!defined($self->{nonce})) {
		$self->{nonce} = int(rand(INT_MAX));
	} else {
		$self->{nonce}++;
	}
	return $self->{nonce};
}

sub _decode
{
	my ($self) = @_;

	my %apireturn = %{$json->decode( $self->_mech->content )};

	return \%apireturn;
}

sub _mech
{
	my ($self) = @_;

	return $self->{mech};
}

sub _post
{
	my ($self, $method, $args) = @_;
	retrynonce:
	my $uri = URI->new("https://btc-e.com/tapi");
	my $req = HTTP::Request->new( 'POST', $uri );
	my $query = "method=${method}";
	if (defined($args)) {
		foreach my $var (keys %{$args}) {
			my $val = ${$args}{$var};
			if (!defined($val)) {
				next;
			}
			$query .= "&".$var."=".$val;
		}
	}
	$query .= "&nonce=".$self->_createnonce;
	$uri->query(undef);
	$req->header( 'Content-Type' => 'application/x-www-form-urlencoded');
	$req->content($query);
	$req->header('Key' => $self->_apikey);
	$req->header('Sign' => $self->_sign($query));
	retry:
	eval {
		$self->_mech->request($req);
	};
	if ($@) {
		if ($@ =~ /(Connection timed out|Please try again in a few minute|handshake problems|unknown connection issue between CloudFare)/) {
			print STDERR "!";
			sleep(5);
			goto retry;
		}
		printf STDERR "_post: self->_mech->_request: %s\n", $@;
		my %empty;
		return \%empty;
	}
	my %result = %{$self->_decode};
	if (defined($result{success}) && defined($result{error})) {
		if ($result{success} == 0 && $result{error} =~
		    /invalid nonce parameter; on key:([0-9]+),/) {
			my $newnonce = $1;
			$self->{nonce} = $newnonce;
			printf STDERR "using new nonce %d\n", $newnonce;
			goto retrynonce;
		}
	}

	return \%result;
}

sub _secretkey
{
	my ($self) = @_;
	return $self->{'secret'};
}

sub _sign
{
	my ($self, $params) = @_;
	return hmac_sha512_hex($params,$self->_secretkey);
}

sub _newagent
{
	my ($version) = @_;
	my $agent = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1}, env_proxy => 1);
	if (defined($version)) {
		$agent->agent($version);
	}
	return $agent;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Finance::btce - Perl extension for interfacing with the BTC-e bitcoin exchange

=head1 Version

Version 0.01

=head1 SYNOPSIS

  use Finance::btce;

  my $btce = Finance::btce->new({apikey => 'key',
	secret => 'secret',});

  #public API calls
  
  #Prices for Bitcoin to USD
  my %price = %{BtceConversion('btc_usd')};

  #Prices for Litecoin to Bitcoin
  my %price = %{BtceConversion('ltc_btc')};
  
  #Prices for Litecoin to USD
  my %price = %{BtceConversion('ltc_usd')};

  #Authenticated API Calls

  my %accountinfo = %{$btce->getInfo()};

  # all parameters are optional
  my %history = %{$btce->TradeHistory({
	'from' => 0,
	'count' => 1000,
	'from_id' => 0,
	'end_id' => infinity,
	'order' => ASC or DESC,
	'since' => UNIX time start,
	'end' => UNIX time stop,
	'pair' => 'btc_usd' or default is all pairs,
	});
  my %activeorders = %{$btce->ActiveOrders({
	'pair' => 'btc_usd'
	})};

  # all parameters are required
  my %trade = %{$btce->Trade({
	'pair' => 'btc_usd',
	'type' => 'buy' || 'sell',
	'rate' => '0.00000001',
	'amount' => '0.1234',
	})};
  my %cancel = %{$btce->CancelOrders({
	'order_id' => 1234,
	})};

=head2 EXPORT

None by default.

=head1 BUGS

Please report all bug and feature requests through github
at L<https://github.com/benmeyer50/Finance-btce/issues>

=head1 AUTHOR

Benjamin Meyer, E<lt>bmeyer@benjamindmeyer.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Benjamin Meyer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
