package Class::Gomor::Hash;

# $Date: 2005/01/17 21:25:20 $
# $Revision: 1.2 $

use strict;
use warnings;

our $VERSION = '0.20';

require Exporter;
our @ISA = qw(Exporter);

use Carp;

our $Debug = 0;
our @EXPORT_OK = qw($Debug);

sub new {
   my $invocant = shift;
   my $class    = ref($invocant) || $invocant;

   $class->checkParams({ @_ }, [ @{$class->getAccessors} ]);

   bless({ @_ }, $class);
}

sub checkParams {
   my $self = shift;
   my ($userParams, $accessors) = @_;

   for my $u (keys %$userParams) {
      my $valid;
      my $exists;
      for (@$accessors) {
         ($u eq $_) ? $valid++ : next;
         do { $exists++; last } if exists $userParams->{$u};
      }
      unless ($valid) {
         croak("$self: invalid parameter: `$u'");
         return undef;
      }
      unless ($exists) {
         croak("$self: parameter is undef: `$u'");
         return undef;
      }
   }

   1;
}

sub getIsaTree {
   my $self    = shift;
   my $classes = shift;

   no strict 'refs';

   for (@{$self. '::ISA'}) {
      push @$classes, $_;
      $_->getIsaTree($classes) if $_->can('getIsaTree');
   }
}

sub getAccessors {
   my $self = shift;

   no strict 'refs';
 
   my @classes = ( $self );
   $self->getIsaTree(\@classes);

   my @accessors;
   for (@classes) {
      @accessors = ( @accessors, @{$_. '::AS'} ) if @{$_. '::AS'};
      @accessors = ( @accessors, @{$_. '::AA'} ) if @{$_. '::AA'};
      @accessors = ( @accessors, @{$_. '::AO'} ) if @{$_. '::AO'};
   }

   \@accessors;
}
   
sub buildAccessorsScalar {
   my $self      = shift;
   my $accessors = shift;

   no strict 'refs';

   for my $a (@{$accessors}) {
      *{$self. '::'. $a} = sub { shift->_AccessorScalar($a, @_) }
   }
}

sub buildAccessorsArray {
   my $self      = shift;
   my $accessors = shift;

   no strict 'refs';

   for my $a (@{$accessors}) {
      *{$self. '::'. $a} = sub { shift->_AccessorArray($a, @_) } 
   }
}

sub _AccessorScalar {
   my ($self, $sca) = (shift, shift);
   @_ ? $self->{$sca} = shift
      : $self->{$sca};
}

sub _AccessorArray {
   my ($self, $ary) = (shift, shift);
   @_ ? $self->{$ary} = shift
      : @{$self->{$ary}};
}

sub debugPrint {
   my $invocant = shift;
   my ($level, $msg) = @_;

   return if (! $Debug || $Debug < $level);

   (my $pm = ref($invocant) || $invocant) =~ s/^.*:://;
   $msg =~ s/^/DEBUG: $pm: /gm;
   print STDERR "$msg\n";
}

1;

=head1 NAME

Class::Gomor::Hash - class and object builder, hash version

=head1 SYNPOSIS

   # Create a base class in BaseClass.pm
   package My::BaseClass;

   require Class::Gomor::Hash;
   our @ISA = qw(Class::Gomor::Hash);

   our @AS = qw(attribute1 attribute2);
   our @AA = qw(attribute3 attribute4);
   our @AO = qw(other);

   sub new { shift->SUPER::new(@_) }

   My::BaseClass->buildAccessorsScalar(\@AS);
   My::BaseClass->buildAccessorsArray(\@AA);

   sub other {
      my $self = shift;
      @_ ? $self->{other} = [ split(/\n/, shift) ]
         : @{$self->{other}};
   }

   1;

   # Create a subclass in SubClass.pm
   package My::SubClass;

   require My::BaseClass;
   require Class::Gomor::Hash;
   our @ISA = qw(My::BaseClass Class::Gomor::Hash);

   our @AS = qw(subclassAttribute);

   My::SubClass->buildAccessorsScalar(\@AS);

   sub new {
      shift->SUPER::new(
         attribute1 => 'val1',
         attribute2 => 'val2',
         attribute3 => [ 'val3', ],
         attribute4 => [ 'val4', ],
         other      => [ 'none', ],
         subclassAttribute => 'subVal',
      );
   }

   1;


   # A program using those classes

   my $new = My::SubClass->new;

   my $val1     = $new->attribute1;
   my @values3  = $new->attribute3;
   my @otherOld = $new->other;

   $new->other("str1\nstr2\nstr3");
   my @otherNew = $new->other;
   print "@otherNew\n";

   $new->attribute2('newValue');
   $new->attribute4([ 'newVal1', 'newVal2', ]);

=head1 DESCRIPTION

This module is yet another class builder. This one adds parameter checking in B<new> constructor, that is to check for attributes existence, and definedness. Since objects are built as hashes, this module is suffixed by Hash.

In order to validate parameters, the module needs to find attributes, and that is the reason for declaring attributes in global variable names @AS, @AA, @AO. They respectively state for Attribute Scalar, Attribute Array and Attribute Other. The last one is used to avoid autocreation of accessors, that is you put in your own ones.

Attribute validation is performed by looking at classes hierarchy, by following @ISA tree inheritance.

The loss in speed by validating all attributes is quite negligeable on a decent machine (Pentium IV, 2.4 GHz), and with Perl 5.8.x.

=head1 GLOBAL VARIABLE

=over 4

=item B<$Debug>

Import it in your namespace like this:

use Class::Gomor::Hash qw($Debug);

This variable is used by the B<debugPrint> method.

=back

=head1 METHODS

=over 4

=item B<new> [ (hash) ]

Object constructor. This is where user passed attributes (hash argument) are checked against valid attributes (gathered by B<getAccessors> method). Valid attributes are those that exists (doh!), and have not an undef value.

=item B<checkParams> (scalar, scalar)

The attribute checking method takes two arguments, the first is user passed attributes (as a hash reference), the second is the list of valid attributes, gathered via B<getAccessors> method (as an array ref). A message is displayed and the application dies if not valid.

=item B<getIsaTree> (scalar)

A recursive method. You pass a class in an array reference as an argument, and then the @ISA array is browsed, recursively. The array reference passed as an argument is increased with new classes, pushed into it.

=item B<getAccessors>

This method returns available attributes for calling class. It uses B<getIsaTree> to search recursively in class hierarchy. It then returns an array reference with all possible attributes.

=item B<buildAccessorsScalar> (scalar)

Accessor creation method. Takes an array reference containing all scalar attributes to create.

=item B<buildAccessorsArray> (scalar)

Accessor creation method. Takes an array reference containing all array attributes to create.

=item B<debugPrint> (scalar, scalar)

First argument is a debug level. It is compared with global B<$Debug>, and if it is less than it, the second argument (a message string) is displayed. This method exists since I use it, maybe you will not like it.

=back

=head1 AUTHOR
      
Patrice E<lt>GomoRE<gt> Auffret
      
=head1 COPYRIGHT AND LICENSE
  
Copyright (c) 2004-2005, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See Copying file in the source distribution archive.

=cut
