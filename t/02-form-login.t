#!/usr/bin/perl -w
use strict;
use Test::More tests => 7;

use_ok("Finance::Bank::Postbank");

my $account = Finance::Bank::Postbank->new(
                login => '9999999999',
                password => '11111',
                status => sub {
                            shift;
                            diag join " ",@_
                              if ($_[0] eq "HTTP Code") and ($_[1] != 200);
                          },
              );

# Get the login page:
my $status = $account->get_login_page(&Finance::Bank::Postbank::LOGIN);

# Check that we got a wellformed page back
SKIP: {
  unless ($status == 200) {
    diag $account->agent->res->as_string;
    skip "Didn't get a connection to ".&Finance::Bank::Postbank::LOGIN."(LWP: $status)",5;
  };
  is($status,200,"We got a HTML page back");
  skip "Banking is unavailable due to maintenance", 4
    if $account->maintenance;

  # Check that the expected form fields are available :
  my @fields = qw(Kontonummer PIN FUNCTION LOGIN);
  my $field;
  for $field (@fields) {
    diag $account->agent->current_form->inputs
      unless ok(defined $account->agent->current_form->find_input($field),"Login form has field '$field'");
  };
};

# Now fake the maintenance message :
{
  no warnings;
  $account->agent(undef);
  local *Finance::Bank::Postbank::maintenance = sub { 1 };
  local *Finance::Bank::Postbank::get_login_page = sub { 200 };
  eval { $account->new_session(); };
  like($@,"/Banking unavailable due to maintenance/","Maintenance handling");
};