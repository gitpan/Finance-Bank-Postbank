#!/usr/bin/perl -w
use strict;
use FindBin;

use Test::More tests => 3;

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
    skip "Didn't get a connection to ".&Finance::Bank::Postbank::LOGIN."(LWP: $status)",2;
  };
  skip "Banking is unavailable due to maintenance", 2
    if $account->maintenance;
  $account->agent(undef);

  $status = $account->select_function("accountstatement");
  unless ($status == 200) {
    diag $account->agent->res->as_string;
    skip "Couldn't get to account statement (LWP: $status)", 2;
  };

  ok($account->close_session(),"Closed session");
  is($account->agent(),undef,"agent was discarded");
};