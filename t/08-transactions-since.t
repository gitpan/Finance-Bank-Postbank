#!/usr/bin/perl -w
use strict;
use FindBin;

use vars qw($statement @test_dates);
BEGIN {
  @test_dates = qw{ 1.1.1999 01/01/1999 1/01/1999 1999011 foo foo1 19990101foo };
};
use Test::More tests => 12 + scalar @test_dates * 2;

use_ok("Finance::Bank::Postbank::Account");

my $account = Finance::Bank::Postbank::Account->new(
                number => '9999999999',
              );

my $acctname = "$FindBin::Bin/accountstatement.txt";
my $canned_statement = do {local $/ = undef;
                           local *F;
                           open F, "< $acctname"
                             or die "Couldn't read $acctname : $!";
                           <F>};

my $expected_statement_0 = { name => "PFIFFIG, PETRA",
                       blz => "20010020",
                       number => "9999999999",
                       balance => ["20030111","2500.00"],
                       balance_prev => ["20030102","347.36"],
                       transactions => [],
                     };

my $expected_statement_1 = { name => "PFIFFIG, PETRA",
                       blz => "20010020",
                       number => "9999999999",
                       balance => ["20030111","2500.00"],
                       balance_prev => ["20030102","347.36"],
                       transactions => [
                         { tradedate => "20030111", valuedate => "20030111", type => "GUTSCHRIFT",
                           comment => "KINDERGELD                 KINDERGELD-NR 234568/133",
                           receiver => "ARBEITSAMT BONN", sender => '', amount => "154.00", },
                         { tradedate => "20030111", valuedate => "20030111", type => "ÜBERWEISUNG",
                           comment => "FINANZKASSE 3991234        STEUERNUMMER 007 03434     EST-VERANLAGUNG 99",
                           receiver => "FINANZAMT KÖLN-SÜD", sender => '', amount => -328.75, },
                       ],
                     };

my $expected_statement_2 = { name => "PFIFFIG, PETRA",
                       blz => "20010020",
                       number => "9999999999",
                       balance => ["20030111","2500.00"],
                       balance_prev => ["20030102","347.36"],
                       transactions => [
                         { tradedate => "20030111", valuedate => "20030111", type => "GUTSCHRIFT",
                           comment => "KINDERGELD                 KINDERGELD-NR 234568/133",
                           receiver => "ARBEITSAMT BONN", sender => '', amount => "154.00", },
                         { tradedate => "20030111", valuedate => "20030111", type => "ÜBERWEISUNG",
                           comment => "FINANZKASSE 3991234        STEUERNUMMER 007 03434     EST-VERANLAGUNG 99",
                           receiver => "FINANZAMT KÖLN-SÜD", sender => '', amount => -328.75, },
                         { tradedate => "20030104", valuedate => "20030104", type => "LASTSCHRIFT",
                           comment => "RECHNUNG 03121999          BUCHUNGSKONTO 9876543210",
                           receiver => "TELEFON AG KÖLN", sender => '', amount => "-125.80", },
                         { tradedate => "20030104", valuedate => "20030104", type => "SCHECK",
                           comment => "",
                           receiver => "EC1037406000003", sender => '', amount => "-511.20", },
                         { tradedate => "20030104", valuedate => "20030104", type => "LASTSCHRIFT",
                           comment => "TEILNEHMERNUMMER 123456789 RUNDFUNK VON 1099 BIS 1299",
                           receiver => "GEZ KÖLN", sender => '', amount => -84.75, },
                         { tradedate => "20030104", valuedate => "20030104", type => "LASTSCHRIFT",
                           comment => "STROMKOSTEN                KD-NR 1462347              JAHRESABRECHNUNG",
                           receiver => "STADTWERKE MUSTERSTADT", sender => '', amount => -580.06, },
                         { tradedate => "20030104", valuedate => "20030104", type => "INH.SCHECK",
                           comment => "",
                           receiver => "2000123456789", sender => '', amount => "-100.00", },
                         { tradedate => "20030104", valuedate => "20030104", type => "SCHECKEINR",
                           comment => "EINGANG VORBEHALTEN",
                           receiver => "GUTBUCHUNG 12345", sender => '', amount => "1830.00", },
                         { tradedate => "20030104", valuedate => "20030104", type => "DAUER ÜBERW",
                           comment => "DA 100001",
                           receiver => "", sender => 'MUSTERMANN, HANS', amount => "-31.50", },
                         { tradedate => "20030104", valuedate => "20030104", type => "GUTSCHRIFT",
                           comment => "BEZÜGE                     PERSONALNUMMER 700600170/01",
                           receiver => "ARBEITGEBER U. CO", sender => '', amount => "2780.70", },
                         { tradedate => "20030104", valuedate => "20030104", type => "LASTSCHRIFT",
                           comment => "MIETE 600,00 EUR           NEBENKOSTEN 250,00 EUR     OBJEKT 22/328              MUSTERPFAD 567, MUSTERSTADT",
                           receiver => "EIGENHEIM KG", sender => '', amount => "-850.00", },
                       ],
                     };

$statement = $account->parse_statement(content => $canned_statement, since => "20030112");
is_deeply($statement,$expected_statement_0, "Capping transactions at 20030112");
$statement = $account->parse_statement(content => $canned_statement, since => "20030111");
is_deeply($statement,$expected_statement_0, "Capping transactions at 20030111");
$statement = $account->parse_statement(content => $canned_statement, since => "20030105");
is_deeply($statement,$expected_statement_1, "Capping transactions at 20030105");
$statement = $account->parse_statement(content => $canned_statement, since => "20030104");
is_deeply($statement,$expected_statement_1, "Capping transactions at 20030104");
$statement = $account->parse_statement(content => $canned_statement, since => "20030103");
is_deeply($statement,$expected_statement_2, "Capping transactions at 20030103");
$statement = $account->parse_statement(content => $canned_statement, since => "");
is_deeply($statement,$expected_statement_2, "Capping transactions at empty string");
$statement = $account->parse_statement(content => $canned_statement, since => undef);
is_deeply($statement,$expected_statement_2, "Capping transactions at undef");
$statement = $account->parse_statement(content => $canned_statement, upto => "");
is_deeply($statement,$expected_statement_2, "Capping transactions at empty string");
$statement = $account->parse_statement(content => $canned_statement, upto => undef);
is_deeply($statement,$expected_statement_2, "Capping transactions at undef");

$statement = $account->transactions_today(content => $canned_statement, yesterday => "20030104");
is_deeply($statement,$expected_statement_1, "Transactions today for 20030104");
$statement = $account->transactions_today(content => $canned_statement, yesterday => "20030111");
is_deeply($statement,$expected_statement_0, "Transactions today for 20030111");

# Now check our error handling
my $date;
for $date (@test_dates) {
  eval { $account->parse_statement( content => $canned_statement, since => $date )};
  like $@,"/^Argument \\{since => '$date'\\} dosen't look like a date to me\\./","Bogus start date ($date)";
  eval { $account->parse_statement( content => $canned_statement, upto => $date )};
  like $@,"/^Argument \\{upto => '$date'\\} dosen't look like a date to me\\./","Bogus end date ($date)";
};