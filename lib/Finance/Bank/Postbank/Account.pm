package Finance::Bank::Postbank::Account;

use strict;
use warnings;
use Carp;
use base 'Class::Accessor';

use vars qw[ $VERSION ];

$VERSION = '0.01';

BEGIN {
  Finance::Bank::Postbank::Account->mk_accessors(qw( number balance balance_prev transactions ));
};

sub new {
  my ($class,%args) = @_;

  my $self = {
    number => $args{number},
  };
  bless $self, $class;

  $self;
};

sub parse_date {
  my ($self,$date) = @_;
  $date =~ /^(\d{2})\.(\d{2})\.(\d{4})$/
    or die "Unknown date format '$date'. A date must be in the format 'DD.MM.YYYY'\n";
  $3.$2.$1;
};

sub parse_amount {
  my ($self,$amount) = @_;
  die "String '$amount' does not look like a number"
    unless $amount =~ /^-?[0-9]{1,3}(?:\.\d{3})*,\d{2}$/;
  $amount =~ tr/.//d;
  $amount =~ s/,/./;
  $amount;
};

sub slurp_file {
  my ($self,$filename) = @_;
  local $/ = undef;
  local *F;
  open F, "< $filename"
    or croak "Couldn't read from file '$filename' : $!";
  <F>;
};

sub parse_statement {
  my ($self,%args) = @_;

  # If $self is just a string, we want to make a new class out of us
  $self = $self->new
    unless ref $self;
  my $filename = $args{file};
  my $raw_statement = $args{content};
  if ($filename) {
    $raw_statement = $self->slurp_file($filename);
  } elsif (! defined $raw_statement) {
    croak "Need an account number if I have to retrieve the statement online"
      unless $args{number};
    croak "Need a password if I have to retrieve the statement online"
      unless exists $args{password};
    my $login = $args{login} || $args{number};

    return Finance::Bank::Postbank->new( login => $login, password => $args{password} )->get_account_statement;
  };

  my $start_date = $args{since} || "00000000";
  my $end_date = $args{upto} || "99999999";
  $start_date =~ /^\d{8}$/ or croak "Argument {since => '$start_date'} dosen't look like a date to me.";
  $end_date =~ /^\d{8}$/ or croak "Argument {upto => '$end_date'} dosen't look like a date to me.";

  croak "Don't know what to do with empty content"
    unless $raw_statement;

  my @lines = split /\n/, $raw_statement;
  croak "No valid account statement"
    unless $lines[0] eq 'Postbank Kontoauszug Girokonto';
  shift @lines;

  # PFIFFIG, PETRA  BLZ: 20010020  Kontonummer: 9999999999
  $lines[0] =~ /^(.*?)\s+BLZ:\s+(\d{8})\s+Kontonummer:\s+(\d+)$/
    or croak "No owner found in account statement ($lines[0])";
  $self->{name} = $1;
  $self->{blz} = $2;

  # Verify resp. set the account number from what we read
  my $num = $self->number;
  croak "Account statement for different account"
    unless (not defined $num) or ($num eq $3);
  $self->number($3)
    unless $num;
  shift @lines;

  shift @lines;
  $lines[0] =~ /^Kontostand\s+Datum\s+Betrag\s+EUR$/
    or croak "No summary found in account statement ($lines[0])";
  shift @lines;
  my ($balance_now,$balance_prev);
  for ($balance_now,$balance_prev) {
    if ($lines[0] =~ /^([0-9.]{10})\s+([0-9.,]+)$/) {
      $_ = [$self->parse_date($1),$self->parse_amount($2)];
    } else {
      die "Couldn't find a balance statement in ($lines[0])";
    };
    shift @lines;
  };
  shift @lines;

  $self->balance( $balance_now );
  $self->balance_prev( $balance_prev );

  # Now parse the lines for each cashflow :
  $lines[0] =~ /^Datum\s+Wertstellung\s+Art\s+Verwendungszweck\s+Auftraggeber\s+Empfänger\s+Betrag\s+EUR$/
    or croak "Couldn't find start of transactions ($lines[0])";
  shift @lines;
  my (@fields) = qw[tradedate valuedate type comment receiver sender amount];
  my (%convert) = (
    tradedate => \&parse_date,
    valuedate => \&parse_date,
    amount => \&parse_amount,
  );

  $self->transactions([]);
  my @transactions;
  my $line;
  for $line (@lines) {
    next if $line =~ /^\s*$/;
    my (@row) = split /\t/, $line;
    scalar @row == scalar @fields
      or die "Malformed cashflow ($line)";

    my (%rec);
    @rec{@fields} = @row;
    for (keys %convert) {
      $rec{$_} = $convert{$_}->($self,$rec{$_});
    };

    push @transactions, \%rec;
  };

  # Filter the transactions
  $self->transactions( grep { $_->{tradedate} gt $start_date and $_->{tradedate} le $end_date } @transactions );

  $self
};

# Convenience method :
sub transactions_today {
  require POSIX;
  my ($self, %args) = @_;
  # Note that this method of calculating yesterdays date will be wrong whenever
  # a DST change is in effect,
  $args{since} = $args{yesterday} || POSIX::strftime("%Y%m%d",localtime(time()-24*60*60));
  $self->parse_statement(%args);
};

1;
__END__
=head1 NAME

Finance::Bank::Postbank::Account - Postbank bank account class

=head1 SYNOPSIS

  use strict;
  use Finance::Bank::Postbank;
  my $account = Finance::Bank::Postbank::Account->parse_statement(
                number => '9999999999',
                password => '11111',
              );
  # Retrieve account data :
  my $retrieved_statement = $account->parse_statement();
  print "Statement date : ",$retrieved_statement->balance->[0],"\n";
  print "Balance : ",$retrieved_statement->balance->[1]," EUR\n";

  # Output CSV for the transactions
  for my $row ($retrieved_statement->transactions}) {
    print join( ";", map { $row->{$_} } (qw( date valuedate type comment receiver sender amount ))),"\n";
  };

  $account->close_session;

=head1 DESCRIPTION

This module provides a rudimentary interface to the Postbank online banking system at
https://banking.postbank.de/. You will need either Crypt::SSLeay or IO::Socket::SSL
installed for HTTPS support to work with LWP.

The interface was cooked up by me without taking a look at the other Finance::Bank
modules. If you have any proposals for a change, they are welcome !

=head1 WARNING

This is code for online banking, and that means your money, and that means BE CAREFUL. You are encouraged, nay, expected, to audit the source of this module yourself to reassure yourself that I am not doing anything untoward with your banking data. This software is useful to me, but is provided under NO GUARANTEE, explicit or implied.

=head1 WARNUNG

Dieser Code beschaeftigt sich mit Online Banking, das heisst, hier geht es um Dein Geld und das bedeutet SEI VORSICHTIG ! Ich gehe
davon aus, dass Du den Quellcode persoenlich anschaust, um Dich zu vergewissern, dass ich nichts unrechtes mit Deinen Bankdaten
anfange. Diese Software finde ich persoenlich nuetzlich, aber ich stelle sie OHNE JEDE GARANTIE zur Verfuegung, weder eine
ausdrueckliche noch eine implizierte Garantie.

=head1 METHODS

=head2 new

Creates a new object. It takes three named parameters :

=over 4

=item number => '9999999999'

This is the number of the account. If you don't know it (for example, you
are reading in an account statement from disk), leave it undef.

=head2 $account->parse_statement %ARGS

Parses an account statement and returns it as a hash reference. The account statement
can be passed in via two named parameters. If no parameter is given, the current statement
is fetched via the website through a call to C<get_account_statement> (is this so?).

Parameters :

=over 4

=item file => $filename

Parses the file C<$filename> instead of downloading data from the web.

=item content => $string

Parses the content of C<$string>  instead of downloading data from the web.

=item since => $date

Removes all transactions that happened on or before $date. $date must
be in the format YYYYMMDD. If the line is missing, C<since =E<gt> '00000000'>
is assumed.

=item upto => $date

Removes all transactions that happened after $date. $date must
be in the format YYYYMMDD. If the line is missing, C<upto =E<gt> '99999999'>
is assumed.

=back

=head1 AUTHOR

Max Maischein, E<lt>corion@cpan.orgE<gt>

=head1 SEE ALSO

L<perl>, L<Finance::Bank::Postbank>.