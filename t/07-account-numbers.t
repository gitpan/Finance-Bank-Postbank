#!/usr/bin/perl -w
use strict;
use FindBin;

use vars qw(@related_accounts);
BEGIN {
  @related_accounts = qw( 0999999999
                          9999999999 );
};

use Test::More tests => 4 + scalar @related_accounts *2;

use_ok("Finance::Bank::Postbank");

my $account = Finance::Bank::Postbank->new(
                login => '9999999999',
                password => '11111',
                status => sub {
                            shift;
                            diag join " ",@_
                              if ($_[0] eq "HTTP Code") and ($_[1] != 200)
                              #or $_[0] ne "HTTP Code";
                          },
              );

# Get the login page:
my $status = $account->get_login_page(&Finance::Bank::Postbank::LOGIN);

# Check that we got a wellformed page back
SKIP: {
  unless ($status == 200) {
    diag $account->agent->res->as_string;
    skip "Didn't get a connection to ".&Finance::Bank::Postbank::LOGIN."(LWP: $status)",3;
  };
  skip "Banking is unavailable due to maintenance", 3
    if $account->maintenance;
  $account->agent(undef);

  my @fetched_accounts = sort $account->account_numbers;
  is_deeply(\@fetched_accounts,\@related_accounts,"Retrieve account numbers");

  for (reverse @fetched_accounts) {
    isa_ok($account->get_account_statement(account_number => $_),'Finance::Bank::Postbank::Account', "Account $_");
  };
  for (sort @fetched_accounts) {
    isa_ok($account->get_account_statement(account_number => $_),'Finance::Bank::Postbank::Account', "Account $_");
  };

  ok($account->close_session(),"Close session");
  is($account->agent(),undef,"Agent was discarded");
};