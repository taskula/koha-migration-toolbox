package MMT::ATranslationTable;

use MMT::Pragmas;

#External modules
use YAML::XS;
use File::Basename;

#Local modules
my $log = Log::Log4perl->get_logger(__PACKAGE__);

#Exceptions
use MMT::Exception::Delete;

=head1 NAME

MMT::ATranslationTable - Abstract class, translates object attributes (source data column values) into Koha specific versions.

=head2 DESCRIPTION

Used to translate configurable parameters, such as item types or location or borrower categorycodes, etc.

These can be used as a modular extension to the core KohaObject (Patron, Item, ...) builder functions, to delegate
more complex logic to translation tables.

=cut

=head2 new

 @param1 HASHRef of constructor params: {
  file => 'translationTables/borrowers.categorycode.yaml' #file containing the translation rules
 }

=cut

sub new {
  $log->trace("Constructor(@_)") if $log->is_trace();
  $log->logdie(__PACKAGE__." is an abstract class") if ($_[0] eq __PACKAGE__);
  my ($class, $p) = _validate(@_);
  my $self = bless({}, $class);
  $self->{_params} = $p;
  $self->{_params}->{fileName} = File::Basename::fileparse($self->{_params}->{file});
  $self->_loadMappings();
  return $self;
}
sub _validate($class, $p) {
  my $var; #Simply reduce duplication at a cost of slight awkwardness
  $var = 'file';      MMT::Validator::isFileReadable($p->{$var}, $var, undef);
  return @_;
}

sub logId($s) {
  return ref($s).'('.$s->{_params}->{fileName}.')';
  #return ref($s); # The old, less verbose version
}

=head2 _loadMappings

Load the translation instructions from the configuration file

=cut

sub _loadMappings($s) {
  $s->{_mappings} = YAML::XS::LoadFile($s->{_params}->{file}) or die("Failed to load '".$s->{_params}->{file}."'. $!");
  $log->debug($s->logId()." loaded mappings: ".MMT::Validator::dumpObject($s->{_mappings})." from file '".$s->{_params}->{file}."'");

  for my $k (keys %{$s->{_mappings}}) {
    if ($k !~ /^[a-zA-Z0-9_]+$/g) {
      die("Mapping '$k' contains invalid characters. For safety reasons use only [a-zA-Z0-9_] as valid codes in Koha");
    }
  }
}

=head2 translate

Has the same subroutine signature as the MMT::Builder build steps, so one can easily use these TranslationTable-subroutines
to extend the functionality of the core MMT::KohaObject subclass (Item, Patron, Issue, ...) naturally via translation table
rules.

 @param1 MMT::KohaObject-subclass, the object for whom the translation table is translating for
 @param2 HASHRef, Voyager data row hashified
 @param3 MMT::Builder, Builder configured to build the KohaObject.
 @param4 value to translate
 @param5... Rest of the parameters are moved to the translation table subroutine hook for a specific value, eg. 'MMT::TranslationTable::NoteType::popUp()'
 @returns the translated value
 @dies $DELETE if the Object in processing should be removed from migration

=cut

my $re_isSubroutineCall = qr{(.+)\(\s*(.*)\s*\)$};
sub translate($s, $kohaObject, $voyagerObject, $builder, $val, @otherArgs) {
  my $kohaVal = $s->{_mappings}->{$val} if defined($val);

  #Dereference references to reach the real rule
  my $depth = 0;
  while (defined($kohaVal) && $kohaVal =~ /^ref\((.+?)\)$/) {
    $kohaVal = $s->{_mappings}->{$1} if defined($1);
    $log->trace("Tracing reference '$1' to '$kohaVal'");

    if ($depth++ > 10) {
      $log->fatal($s->logId()." is trying to translate value '".($val ? $val : 'undef')."', but there is a mapping table reference loop!");
      last;
    }
  }

  #Check if using the fallback catch-all -value
  if (not(defined($kohaVal)) ||
      ($val eq '' && not(defined($kohaVal)))) {
    $kohaVal = $s->{_mappings}->{'_DEFAULT_'};
  }
  if (not(defined($kohaVal))) {
    warning(@_);
    $log->error($s->logId()." is trying to translate value '".($val ? $val : 'undef')."', but no translation rule exists");
    return undef;
  }

  if ($kohaVal eq '$DELETE') {
    MMT::Exception::Delete->throw("Marked for deletion in '".$s->{_params}->{file}."'. Translatable value='$val'");
  }
  elsif (not(ref($kohaVal)) && $kohaVal =~ $re_isSubroutineCall) {
    my $method = $1;
    my @params = ($kohaObject, $voyagerObject, $builder, $val, [split(/\s*,\s*/, $2)], (@otherArgs ? \@otherArgs : []));

    $log->trace("Invoking ".$s->logId()."->$method(@params)") if $log->is_trace();
    my $rv = $s->$method(@params);
    $log->trace("Returning ".$s->logId()."->$method(@params) with '".MMT::Validator::dumpObject($rv)."'.") if $log->is_trace();
    return $rv;
  }
  else {
    $log->trace("Returning ".$s->logId()." value '$val' translated to '$kohaVal'.") if $log->is_trace();
    return $kohaVal;
  }
  die "Don't know what to do with val '$val'. Program should never enter here...";
}

=head2 translateByCode

The same subroutine call as translate() but using the code-string as a translation table lookup key, instead of the numeric id.

As the code can be the same as the id, we need to prepend + to the translation table code keys to clearly distinguish them from the duplicate id-values.

This subroutine transparently deals with this, so you don't have to.

=cut

sub translateByCode {
  $_[4] = '+'.$_[4]; #Prepend + to the lookup key
  return translate(@_);
}

=head2 warning

Generic fallback to show a warning about a missing value translation

=cut

sub warning($s, $kohaObject, $voyagerObject, $builder, $originalValue='', $tableParams=undef, $transParams=undef) {
  $log->warn("No mapping for value '$originalValue' in '".ref($s)."'");
  return undef; #Prevent implicit truthy return value from breaking things
}

return 1;
