#!/usr/bin/perl -w
use strict;

use vars qw(@accessors);

BEGIN { @accessors = qw( number balance balance_prev transactions)};

use Test::More tests => 2 + scalar @accessors * 2;

use_ok("Finance::Bank::Postbank::Account");

my $account = Finance::Bank::Postbank::Account->new( number => '9999999999' );
can_ok($account, qw(
  new
  parse_date
  parse_amount
  slurp_file
  parse_statement
  transactions_today
  ), @accessors );

sub test_scalar_accessor {
  my ($name,$newval) = @_;

  # Check our accessor methods
  my $oldval = $account->$name();
  $account->$name($newval);
  is($account->$name(),$newval,"Setting new value via accessor $name");
  $account->$name($oldval);
  is($account->$name(),$oldval,"Resetting new value via accessor $name");
};

for (@accessors) {
  test_scalar_accessor($_,"0999999999")
};