package Class::ParmList;

# $RCSfile: ParmList.pm,v $ $Revision: 1.1 $ $Date: 1999/06/15 18:41:41 $ $Author: snowhare $

use strict;
use Carp;
use vars qw ($VERSION);

BEGIN {
	$VERSION = '1.02';
}

=head1 NAME

Class::ParmList - A collection of routines for processing named parameter lists for method calls.

=head1 SYNOPSIS

 $thingy->some_method({
      -bgcolor   => '#ff0000',
      -textcolor => '#000000'
	  });

 sub some_method {
     my ($self) = shift;

	 my ($parm_ref) = @_;

     my $parms = Class::ParmList->new ({
            -parms    => $parm_ref,
            -legal    => [qw (-textcolor -border -cellpadding)], 
            -required => [qw (-bgcolor)],
            -defaults => {
                           -bgcolor   => "#ffffff",
                           -textcolor => "#000000"
                         }
         });

     if (not defined $parms) {
	    my $error_message = Class::ParmList->error;
		die ($error_message);
     }

     # Stuff...

 }

=head1 DESCRIPTION

This is a simple package for validating calling parameters to a subroutine or
method. It allows you to use "named parameters" while providing checking for
number and naming of parameters for verifying inputs are as expected and
meet any minimum requirements. It also allows the setting of default
values for the named parameters if omitted.

=cut

=head1 CHANGES

 1.00 1999.06.16 - Initial release

 1.01 1999.06.18 - Performance tweaks

 1.02 1999.06.21 - Fixing of failure to catch undeclared parm,
                   removal of 'use attrs qw(method)', and
				   extension of 'make test' support.

=cut

my $error = '';

#######################################################################
# Public methods                                                      #
#######################################################################

=over 4

=item C<new($parm_list_ref);>

Returns a reference to an object that can be used to return
values. If an improper specification is passed, returns 'undef'.
Otherwise returns the reference.

Example:

     my $parms = Class::ParmList->new ({
            -parms    => $parm_ref,
            -legal    => [qw (-textcolor -border -cellpadding)], 
            -required => [qw (-bgcolor)],
            -defaults => {
                           -bgcolor   => "#ffffff",
                           -textcolor => "#000000"
                         }
         });
All four parameters (-parms, -legal, -required, and -defaults) are
optional. It is liberal in that anything defined for a -default
or -required is automatically added to the '-legal' list.

If the '-legal' parameter is not _explicitly_ called out, no
checking against the legal list is done. If it _is_ explicitly
called out, then all -parms are checked against it and it will
fail with an error if a -parms parameter is present but not
defined in the -legal explict or implict definitions.

=back

=cut

sub new {
	my ($something) = shift;
	my ($class) = ref ($something) || $something;
	my $self = bless {},$class;

	# Clear any outstanding errors
	$error = '';

	if (-1 == $#_) { # It's legal to pass no parms.
		$self->{-name_list} = [];
		$self->{-parms}     = {};
		return $self;
	}

	my $raw_parm_list = {};
	my $reftype = ref $_[0];
	if ($reftype eq 'HASH') { # A basic HASH setup
		($raw_parm_list) = @_;
	} else {  # An unwrapped list
		%$raw_parm_list = @_;
	}

	# Transform to lowercase keys on our own parameters
	my $parms = {};
	%$parms = map { (lc($_),$raw_parm_list->{$_}) } keys %$raw_parm_list;
	
	# Check for bad parms
	my @parm_keys = keys %$parms;
	my @bad_parm_keys = grep(!/^-(parms|legal|defaults|required)$/,@parm_keys);
	if ($#bad_parm_keys > -1) {
		$error = "Invalid parameters ("."@bad_parm_keys".") passed to Class::ParmList->new\n";
		return;
	}

	my $check_legal    = 0;
	my $check_required = 0;

	# Legal Parameter names
	my $legal_names = {};
	if (defined $parms->{-legal}) {
		%$legal_names = map { (lc($_),1) } @{$parms->{-legal}}; 
		$check_legal = 1;
	}

	# Required Parameter names
	my $required_names = {};
	if (defined $parms->{-required}) {
		my $lk;
		%$required_names = map { $lk = lc $_; $legal_names->{$lk} = 1; ($lk,1) } @{$parms->{-required}};
		$check_required = 1;
	}

	# Set defaults if needed
	my $parm_list = {};
	my $defaults = $parms->{-defaults};
	if (defined $defaults) {
		my $lk;
		%$parm_list = map { $lk = lc $_; $legal_names->{$lk} = 1; ($lk,$defaults->{$_}) } keys %$defaults;
	}

	# The actual list of parms
	my $base_parm_list = $parms->{-parms};
	if (defined ($base_parm_list)) {
		my $lk;
		map { $parm_list->{lc($_)} = $base_parm_list->{$_} } keys %$base_parm_list;
	}

	# Check for Required parameters
	if ($check_required) {
		foreach my $name (keys %$required_names) {
			next if (exists $parm_list->{$name});
			$error .= "Required parameter '$name' missing\n";
		}
	}

	# Check for illegal parameters
	my $final_parm_names = [keys %$parm_list];
	if ($check_legal) {
		foreach my $name (@$final_parm_names) {
			next if (exists $legal_names->{$name});
			$error .= "Parameter '$name' not legal here.\n";
		}
		$self->{-legal} = $legal_names;
	}

	return if ($error ne '');

	# Save the parms for accessing
	$self->{-name_list} = $final_parm_names;
	$self->{-parms}     = $parm_list;

	$self;	
}

################################################################

=over 4

=item C<get($parm_name1,$parm_name2,...);>

Returns the parameter value(s) specified in the call line. If 
a parameter is not defined, it returns undef. If a set of
'-legal' parameters were declared, it croaks if a parameter
not in the '-legal' set is asked for.

Example: 
  my ($help,$who) = $parms->get(-help,-who);

=back

=cut

sub get {
	my ($self) = shift;

	my (@parmnames) = @_;
	if ($#parmnames == -1) {
		croak(__PACKAGE__ . '::get() called without any parameters');
	}
	my (@results) = ();
	my $parmname;
	foreach $parmname (@parmnames) {
		my $keyname = lc ($parmname);
		croak (__PACKAGE__ . "::get() called with an illegal named parameter: '$keyname'") if (exists ($self->{-legal}) and not exists ($self->{-legal}->{$keyname}));	
		push (@results,$self->{-parms}->{$keyname});
	}
	if (wantarray) {
		return @results;
	} else {
		return $results[$#results];
	}
}

################################################################

=over 4

=item C<exists($parm_name);>

Returns true if the parameter specifed by $parm_name (qv.
has been initialized), false if it does not exist.

  if ($parms->exists(-help) {
      # do stuff
  }

=back

=cut

sub exists {
	my ($self) = shift;
	
	my ($name) = @_;

	$name = lc ($name);
	CORE::exists ($self->{-parms}->{$name});
}

################################################################

=over 4

=item C<list_parms;>

Returns the list of parameter names. (Names are always
presented in lowercase).

Example:

  my (@parm_names) = $parms->list_parms;

=back

=cut

sub list_parms {
	my ($self) = shift;

	my (@names) = @{$self->{-name_list}};

	return @names;
}

################################################################

=over 4

=item C<all_parms;>

Returns an anonymous hash containing all the currently
set keys and values. This hash is suitable for usage
with Class::NamedParms or Class::ParmList for setting
keys/values. It works by making a shallow copy of
the data. This means that it copies the scalar values.
In the case of simple numbers and strings, this produces
a new copy, in the case of references to hashes and arrays or
objects, it returns the references to the original objects.

Example:

  my $parms = $parms->all_parms;

=back

=cut

sub all_parms {
	my ($self) = shift;

	my (@parm_list) = $self->list_parms;
	my ($all_p) = {};
	foreach my $parm (@parm_list) {
		$all_p->{$parm} = $self->get($parm);
	}
	$all_p;
}

################################################################

=over 4

=item C<error;>

Returns the error message for the most recent invokation of 
'new'.  (Static method - does not require an object to function)

Example:

     my $error_message = Class::ParmList->error;
     die ($error_message);

=back

=cut

sub error {
	$error;
}

#######################################################################
# Non-public methods                                                  #
#######################################################################

#######################################################################

# Keeps 'AUTOLOAD' from sucking cycles during object destruction
sub DESTROY {}

#######################################################################

=head1 COPYRIGHT

Copyright 1999, Benjamin Franz (<URL:http://www.nihongo.org/snowhare/>) and 
FreeRun Technologies, Inc. (<URL:http://www.freeruntech.com/>). All Rights Reserved.
This software may be copied or redistributed under the same terms as Perl itelf.

=head1 AUTHOR

Benjamin Franz

=head1 TODO

Everything.

=cut

1;
