# -*- mode: Perl; tab-width: 4; -*-
#
# Fink::CLI module
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
# Copyright (c) 2001-2005 The Fink Package Manager Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA	 02111-1307, USA.
#

package Fink::CLI;

use Carp;

use strict;
use warnings;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION	 = 1.00;
	@ISA		 = qw(Exporter);
	@EXPORT		 = qw();
	%EXPORT_TAGS = ( );			# eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK	 = qw(&print_breaking &print_breaking_stderr
					  &prompt &prompt_boolean &prompt_selection
					  &print_optionlist
					  &get_term_width);
}
our @EXPORT_OK;

# non-exported package globals go here
our $linelength = 77;

END { }				# module clean-up code here (global destructor)

=head1 NAME

Fink::CLI - functions for user interaction

=head1 DESCRIPTION

These functions handle a variety of output formatting and user
interaction/response tasks.

=head2 Functions

No functions are exported by default. You can get whichever ones you
need with things like:

    use Fink::Services '&prompt_boolean';
    use Fink::Services qw(&print_breaking &prompt);

=over 4

=item print_breaking

    print_breaking $string;
    print_breaking $string, $linebreak;
    print_breaking $string, $linebreak, $prefix1;
    print_breaking $string, $linebreak, $prefix1, $prefix2;

Wraps $string, breaking at word-breaks, and prints it on STDOUT. The
screen width is determined by get_term_width, or if that fails, the
package global variable $linelength. Breaking is performed only at
space chars. A linefeed will be appended to the last line printed
unless $linebreak is defined and false.

Optionally, prefixes can be defined to prepend to each line printed:
$prefix1 is prepended to the first line, $prefix2 is prepended to all
other lines. If only $prefix1 is defined, that will be prepended to
all lines.

If $string is a multiline string (i.e., it contains embedded newlines
other than an optional one at the end of the whole string), the prefix
rules are applied to each contained line separately. That means
$prefix1 affects the first line printed for each line in $string and
$prefix2 affects all other lines printed for each line in $string.

=cut

sub print_breaking {
	my $s = shift;
	my $linebreak = shift;
	$linebreak = 1 unless defined $linebreak;
	my $prefix1 = shift;
	$prefix1 = "" unless defined $prefix1;
	my $prefix2 = shift;
	$prefix2 = $prefix1 unless defined $prefix2;
	my ($pos, $t, $reallength, $prefix, $first);

	my $width = &get_term_width - 1;    # some termcaps need a char for \n
	$width = $linelength if $width < 1;

	chomp($s);

	# if string has embedded newlines, handle each line separately
	while ($s =~ s/^(.*?)\n//) {
	    # Feed each line except for last back to ourselves (always
	    # want linebreak since $linebreak only controls last line)
	    # prefix behavior: prefix1 for first line of each line of
	    # multiline (cf. first line of the whole multiline only)
	    my $s_line = $1;
	    &print_breaking($s_line, 1, $prefix1, $prefix2);
	}

	# at this point we have either a single line or only the last
	# line of a multiline, so wrap and print

	$first = 1;
	$prefix = $prefix1;
	$reallength = $width - length($prefix);
	while (length($s) > $reallength) {
		$pos = rindex($s," ",$reallength);
		if ($pos < 0) {
			$t = substr($s,0,$reallength);
			$s = substr($s,$reallength);
		} else {
			$t = substr($s,0,$pos);
			$s = substr($s,$pos+1);
		}
		print "$prefix$t\n";
		if ($first) {
			$first = 0;
			$prefix = $prefix2;
			$reallength = $width - length($prefix);
		}
	}
	print "$prefix$s";
	print "\n" if $linebreak;
}

=item print_breaking_stderr

This is a wrapper around print_breaking that causes output to go to
STDERR. See print_breaking for a complete description of parameters
and usage.

=cut

sub print_breaking_stderr {
	my $old_fh = select STDERR;
	&print_breaking(@_);
	select $old_fh;
}

=item prompt

    my $answer = prompt $prompt;
    my $answer = prompt $prompt, %options;

Ask the user a question and return the answer. The user is prompted
via STDOUT/STDIN using $prompt (which is word-wrapped). The trailing
newline from the user's entry is removed.

The %options are given as option => value pairs. The following
options are known:

=over 4

=item default (optional)

If the option 'default' is given, then its value will be
returned if no input is detected.

This can occur if the user enters a null string, or if Fink
is configured to automatically accept defaults (i.e., bin/fink
was invoked with the -y or --yes option).

Default value: null string

=item timeout (optional)

The 'timeout' option establishes a wait period (in seconds) for
the prompt, after which the default answer will be used.
If a timeout is given, any existing alarm() is destroyed.

Default value: no timeout

=back

=cut

sub prompt {
	my $prompt = shift;
	my %opts = (default => "", timeout => 0, @_);

	my $answer = &get_input("$prompt [$opts{default}]", $opts{timeout});
	chomp $answer;
	$answer = $opts{default} if $answer eq "";
	return $answer;
}

=item prompt_boolean

    my $answer = prompt_boolean $prompt;
    my $answer = prompt_boolean $prompt, %options;

Ask the user a yes/no question and return the B<truth>-value of the
answer. The user is prompted via STDOUT/STDIN using $prompt (which is
word-wrapped).

The %options are given as option => value pairs. The following
options are known:

=over 4

=item default (optional)

If the option 'default' is given, then its B<truth>-value will be
returned if no input is detected.

This can occur if the user enters a null string, or if Fink
is configured to automatically accept defaults (i.e., bin/fink
was invoked with the -y or --yes option).

Default value: true

=item timeout (optional)

The 'timeout' option establishes a wait period (in seconds) for
the prompt, after which the default answer will be used.
If a timeout is given, any existing alarm() is destroyed.

Default value: no timeout

=back

=cut

sub prompt_boolean {
	my $prompt = shift;
	my %opts = (default => 1, timeout => 0, @_);

	my $choice_prompt = $opts{default} ? "Y/n" : "y/N";

	my $meaning;
	my $answer = &get_input(
		"$prompt [$choice_prompt]",
		$opts{timeout}
	);
	while (1) {
		chomp $answer;
		if ($answer eq "") {
			$meaning = $opts{default};
			last;
		} elsif ($answer =~ /^y(es?)?$/i) {
			$meaning = 1;
			last;
		} elsif ($answer =~ /^no?$/i) {
			$meaning = 0;
			last;
		}
		$answer = &get_input(
			"Invalid choice. Please try again [$choice_prompt]",
			$opts{timeout}
		);
	}

	return $meaning;
}

=item prompt_selection

    my $answer = prompt_selection $prompt, %options;

Ask the user a multiple-choice question and return the value for the
choice. The user is prompted via STDOUT/STDIN using $prompt (which is
word-wrapped) and a list of choices. The choices are numbered
(beginning with 1) and the user selects by number.

The %options are given as option => value pairs. The following
options are known:

=over 4

=item choices (required)

The option 'choices' must be a reference to an ordered pairwise
array [ label1 => value1, label2 => value2, ... ]. The labels will
be displayed to the user; the values are the return values if that
option is chosen.

=item default (optional)

If the option 'default' is given, then it determines which choice
will be returned if no input is detected.

This can occur if the user enters a null string, or if Fink
is configured to automatically accept defaults (i.e., bin/fink
was invoked with the -y or --yes option).

The following formats are recognized for the 'default' option:

  @default = [];                   # choice 1
  @default = ["number", $number];  # choice $number
  @default = ["label", $label];    # first choice with label $label
  @default = ["value", $label];    # first choice with value $value

Default value: choice 1

=item timeout (optional)

The 'timeout' option establishes a wait period (in seconds) for
the prompt, after which the default answer will be used.
If a timeout is given, any existing alarm() is destroyed.

Default value: no timeout

=item intro (optional)

A text block that will be displayed before the list of options. This
contrasts with the $prompt, which is goes afterwards.

=back

=cut

sub prompt_selection {
	my $prompt = shift;
	my %opts = (default => [], timeout => 0, @_);
	my @choices = @{$opts{choices}};
	my $default = $opts{default};

	my ($count, $default_value);

	if (@choices/2 != int(@choices/2)) {
		confess 'Odd number of elements in @choices';
	}

	if (!defined $default->[0]) {
		$default_value = 1;
	} elsif ($default->[0] eq "number") {
		$default_value = $default->[1];
		$default_value = 1 if $default_value < 1 || $default_value > @choices/2;
	} elsif ($default->[0] =~ /^(label|value)$/) {
		# will be handled later
	} else {
		confess "Unknown default type ",$default->[0];
	}

	print "\n";

	if (defined $opts{intro}) {
		&print_breaking($opts{intro});
		print "\n";
	}

	$count = 0;
	for (my $index = 0; $index <= $#choices; $index+=2) {
		$count++;
		print "($count)\t$choices[$index]\n";
		if (!defined $default_value && (
						(
						 ($default->[0] eq "label" && $choices[$index]   eq $default->[1])
						 ||
						 ($default->[0] eq "value" && $choices[$index+1] eq $default->[1])
						 )
						)) {
			$default_value = $count;
		}

	}
	$default_value = 1 if !defined $default_value;
	print "\n";

	my $answer = &get_input(
		"$prompt [$default_value]",
		$opts{timeout}
	);
	while (1) {
		chomp $answer;
		if ($answer eq "") {
			$answer = $default_value;
			last;
		} elsif ($answer =~ /^[1-9]\d*$/ and $answer >= 1 && $answer <= $count) {
			last;
		}
		$answer = &get_input(
			"Invalid choice. Please try again [$default_value]",
			$opts{timeout}
		);
	}

	return $choices[2*$answer-1];
}

=item get_input

    my $answer = get_input $prompt;
    my $answer = get_input $prompt, $timeout;

Prints the string $prompt, then gets a single line of input from
STDIN. If $timeout is zero or not given, will block forever waiting
for input. If $timeout is given and is positive, will only wait that
many seconds for input before giving up. Returns the entered string
(including the trailing newline), or a null string if the timeout
expires or immediately (without waiting for input) if fink is run with
the -y option. If not -y, this function destroys any pre-existing
alarm().

=cut

sub get_input {
	my $prompt = shift;
	my $timeout = shift || 0;

	# print the prompt string (leaving cursor on the same line)
	$prompt = "" if !defined $prompt;
	&print_breaking("$prompt ", 0);

	# handle -y if given
	require Fink::Config;
	if (Fink::Config::get_option("dontask")) {
		print "(assuming default)\n";
		return "";
	}

	# get input, with optional timeout functionality
	my $answer = eval {
		local $SIG{ALRM} = sub { die "SIG$_[0]\n"; };  # alarm() expired
		alarm $timeout;  # alarm(0) means cancel the timer
		my $answer = <STDIN>;
		alarm 0;
		return $answer;
	} || "";

	# deal with error conditions raised by eval{}
	if (length $@) {
		print "\n";   # move off input-prompt line
		if ($@ eq "SIGALRM\n") {
			print "TIMEOUT: using default answer.\n";
		} else {
			die $@;   # something else happened, so just propagate it
		}
	}

	return $answer;
}

=item get_term_width

  my $width = get_term_width;

This function returns the width of the terminal window, or zero if STDOUT 
is not a terminal. Uses Term::ReadKey if it is available, greps the TERMCAP
env var if ReadKey is not installed, tries tput if neither are available,
and if nothing works just returns 80.

=cut

sub get_term_width {
	my ($width, $dummy);
	use POSIX qw(isatty);
	if (isatty(fileno STDOUT))
	{
		if (eval { require Term::ReadKey; 1; }) {
			import Term::ReadKey qw(&GetTerminalSize);
			($width, $dummy, $dummy, $dummy) = &GetTerminalSize();						 
		}
		else {
			$width =~ s/.*co#([0-9]+).*/$1/ if defined ($width = $ENV{TERMCAP});
			unless (defined $width and $width =~ /^\d+$/) {
				chomp($width = `tput cols`)		 # Only use tput if it won't spout an error.
								if -t 1 and defined ($width = $ENV{TERM}) and $width ne "unknown";
				unless ($? == 0 and defined $width and $width =~ /^\d+$/) {
					$width = $ENV{COLUMNS};
					unless (defined $width and $width =~ /^\d+$/) {
						$width = 80;
					}
				}
			}
		}
	}
	else {
		# Not a TTY
		$width = 0;
	}
	if ($width !~ /^[0-9]+$/) {
		# Shouldn't get here, but just in case...
		$width = 80;
	}
	return $width;
}

=back

=cut

### EOF
1;