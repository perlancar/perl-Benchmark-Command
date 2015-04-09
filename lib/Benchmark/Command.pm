package Benchmark::Command;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Carp;

use Benchmark::Dumb qw(cmpthese);
use Capture::Tiny qw(tee_stdout);
use File::Which;

sub run {
    my ($count, $cmds, $opts) = @_;

    $opts //= {};

    ref($cmds) eq 'HASH' or croak "cmds must be a hashref";

    my $subs = {};
    my $longest = 0;
  COMMAND:
    for (keys %$cmds) {
        $longest = length if length > $longest;
        my $cmd = $cmds->{$_};
        ref($cmd) eq 'ARRAY' or croak "cmds->{$_} must be an arrayref";
        @$cmd or croak "cmds->{$_} must not be empty";
        unless (which $cmd->[0]) {
            if ($opts->{skip_not_found}) {
                warn "cmds->{$_}: $cmd->[0] not found, skipped\n";
                next COMMAND;
            } else {
                croak "cmds->{$_}: $cmd->[0] not found";
            }
        }
        $subs->{$_} = sub { system {$cmd->[0]} @$cmd };
    }

    my $stdout = tee_stdout {
        cmpthese($count, $subs);
    };

    my $times = {};
    for (keys %$subs) {
        $stdout =~ m/^\Q$_\E\s+(\d+(?:\.\d+)?)/m
            or die "Can't find rate for '$_'";
        $times->{$_} = 1/$1;
    }
    #use DD; dd $times;

    print "\nAverage times:\n";
    for (sort {$times->{$a} <=> $times->{$b}} keys %$times) {
        printf "  %-${longest}s: %10.4fms\n",
            $_, 1000*$times->{$_};
    }
};

1;
#ABSTRACT: Benchmark commands

=head1 SYNOPSIS

 use Benchmark::Command;

 Benchmark::Command::run(100, {
     perl        => [qw/perl -e1/],
     "bash+true" => [qw/bash -c true/],
     ruby        => [qw/ruby -e1/],
     python      => [qw/python -c1/],
     nodejs      => [qw/nodejs -e 1/],
 });

Sample output:

                      Rate      nodejs      python        ruby bash+true   perl
 nodejs    40.761+-0.063/s          --      -55.3%      -57.1%    -84.8% -91.7%
 python        91.1+-1.3/s 123.6+-3.3%          --       -4.0%    -66.0% -81.5%
 ruby         94.92+-0.7/s 132.9+-1.8%   4.2+-1.7%          --    -64.6% -80.8%
 bash+true   267.94+-0.7/s   557.3+-2%   194+-4.4% 182.3+-2.2%        -- -45.7%
 perl         493.8+-5.1/s   1112+-13% 441.9+-9.7% 420.3+-6.6%  84.3+-2%     --

 Average times:
   perl     :     2.0251ms
   bash+true:     3.7322ms
   ruby     :    10.5352ms
   python   :    10.9769ms
   nodejs   :    24.5333ms


=head1 DESCRIPTION

This module provides C<run()>, a convenience routine to benchmark commands. This
module is similar to L<Benchmark::Apps> except: 1) commands will be executed
without shell (using the C<< system {$_[0]} @_ >> syntax); 2) the existence of
each program will be checked first; 3) L<Benchmark::Dumb> is used as the
backend.

This module is suitable for benchmarking commands that completes in a short
time, like the above example.


=head1 FUNCTIONS

=head2 run($count, \%cmds[, \%opts])

Do some checks and convert C<%cmds> (which is a hash of names and command
arrayrefs (e.g. C<< {perl=>["perl", "-e1"], nodejs=>["nodejs", "-e", 1]} >>)
into C<%subs> (which is a hash of names and coderefs (e.g.: C<< {perl=>sub
{system {"perl"} "perl", "-e1"}, nodejs=>sub {system {"nodejs"} "nodejs", "-e",
1}} >>).

The checks done are: each command must be an arrayref (to be executed without
invoking shell) and the program (first element of each arrayref) must exist.

Then run L<Benchmark::Dumb>'s C<< cmpthese($count, \%subs) >>. Usually,
C<$count> can be set to 0 but for the above example where the commands end in a
short time (in the order milliseconds), I set to to around 100.

Then also show the average run times for each command.

Known options:

=over

=item * skip_not_found => bool

If set to true, will skip benchmarking commands where the program is not found.
The default bahavior is to croak.

=back


=head2 SEE ALSO

L<Benchmark::Apps>

1;
