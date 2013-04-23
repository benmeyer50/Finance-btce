package Finance::btce;

use 5.012004;
use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use Carp qw(croak);
use Digest::SHA qw( hmac_sha512_hex);
use WWW::Mechanize;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Finance::btce ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(BTCtoUSD LTCtoBTC LTCtoUSD) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.01';

our $json = JSON->new->allow_nonref;

sub BTCtoUSD
{
	my $browser = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	$browser->agent('Mozilla/4.76 [en] (Win98; U)');
	my $resp = $browser->get("https://btc-e.com/api/2/btc_usd/ticker");
	my $apiresponse = $resp->content;
	my %ticker = %{$json->decode($apiresponse)};
	my %prices = %{$ticker{'ticker'}};
	my $high = $prices{'high'}; 
	my $low = $prices{'low'};
	my $avg = $prices{'avg'};
	my %price = (
		'high' => $high,
		'low' => $low,
		'avg' => $avg,
	);

	return \%price;
}

sub LTCtoBTC
{
	my $browser = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	$browser->agent('Mozilla/4.76 [en] (Win98; U)');
	my $resp = $browser->get("https://btc-e.com/api/2/ltc_btc/ticker");
	my $apiresponse = $resp->content;
	my %ticker = %{$json->decode($apiresponse)};
	my %prices = %{$ticker{'ticker'}};
	my $high = $prices{'high'}; 
	my $low = $prices{'low'};
	my $avg = $prices{'avg'};
	my %price = (
		'high' => $high,
		'low' => $low,
		'avg' => $avg,
	);

	return \%price;
}

sub LTCtoUSD
{
	my $browser = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	$browser->agent('Mozilla/4.76 [en] (Win98; U)');
	my $resp = $browser->get("https://btc-e.com/api/2/ltc_usd/ticker");
	my $apiresponse = $resp->content;
	my %ticker = %{$json->decode($apiresponse)};
	my %prices = %{$ticker{'ticker'}};
	my $high = $prices{'high'}; 
	my $low = $prices{'low'};
	my $avg = $prices{'avg'};
	my %price = (
		'high' => $high,
		'low' => $low,
		'avg' => $avg,
	);

	return \%price;
}

### Authenticated API calls

sub new
{
	my ($class, $args) = @_;
	if($args->{'apikey'} && $args->{'secret'})
	{
		#check for existence of keys
	}
	else
	{
		croak "You must provide an apikey and secret";
	}
	return bless $args, $class;
}

sub getInfo
{
	my ($self) = @_;
	my $mech = WWW::Mechanize->new();
	$mech->stack_depth(0);
	$mech->agent_alias('Windows IE 6');
	my $nonce = time;
	my $url = "https://btc-e.com/tapi";
	my $data = "method=getInfo&nonce=".$nonce;
	my $hash = hmac_sha512_hex($data,$self->_secretkey);
	$mech->add_header('Key' => $self->_apikey);
	$mech->add_header('Sign' => $hash);
	$mech->post($url, ['method' => 'getInfo', 'nonce' => $nonce]);
	my %apireturn = %{$json->decode($mech->content())};

	return \%apireturn;
}

#private methods

sub _apikey
{
	my ($self) = @_;
	return $self->{'apikey'};
}

sub _secretkey
{
	my ($self) = @_;
	return $self->{'secret'};
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

  my $btce = Finance::btce->new({key => 'key', secret => 'secret',});

#public API calls
  
  #Prices for Bitcoin to USD
  my %price = %{BTCtoUSD()};

  #Prices for Litecoin to Bitcoin
  my %price = %{LTCtoBTC()};
  
  #Prices for Litecoin to USD
  my %price = %{LTCtoUSD()};

=head2 EXPORT

None by default.

=head1 BUGS

Please report all bug and feature requests through github
at L<https://github.com/benmeyer50/Finance-btce/issues>

=head1 AUTHOR

Benjamin Meyer, E<lt>bmeyer@apple.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Benjamin Meyer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
