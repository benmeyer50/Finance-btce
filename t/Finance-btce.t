# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Finance-btce.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 4;
BEGIN { use_ok('Finance::btce') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my %btupublic = %{Finance::btce::BTCtoUSD()};
ok( defined($btupublic{'avg'}), 'BTCtoUSD() works');

my %ltbpublic = %{Finance::btce::LTCtoBTC()};
ok( defined($ltbpublic{'avg'}), 'LTCtoBTC() works');

my %ltupublic = %{Finance::btce::LTCtoUSD()};
ok( defined($ltupublic{'avg'}), 'LTCtoUSD() works');
