package MMT::PrettyCirc2Koha::Subscription;

use MMT::Pragmas;

#External modules

#Local modules
use MMT::Validator;
my $log = Log::Log4perl->get_logger(__PACKAGE__);

#Inheritance
use MMT::KohaObject;
use base qw(MMT::KohaObject);

#Exceptions
use MMT::Exception::Delete;

=head1 NAME

MMT::PrettyCirc2Koha::Subscription - Transforms a bunch of PrettyCirc data into Koha subscriptions

=cut

# Build the subscriptions here based on the individual serials analyzed for each Biblio.
our %subscriptions;

sub analyzePeriodicals($b) {
  while (defined(my $textPtr = $b->{next}->())) {
    my $o;
    eval {
      my @colNames = $b->{csv}->column_names();
      $o = {};
      $b->{csv}->bind_columns(\@{$o}{@colNames});
      $b->{csv}->parse($$textPtr);
    };
    if ($@) {
      $log->error("Unparseable .csv-row!\n$@\nThe unparseable row follows\n$$textPtr");
      next;
    }
    analyzePeriodical($o, $b);
  }
}

sub createFillerSubscriptions($b) {
  while (my ($biblionumber, $s) = each(%subscriptions)) {
    build($s, {}, $b);
    $log->debug("Writing ".$s->{biblionumber}) if $log->is_debug();
    $b->writeToDisk( $s->serialize() );
  }
}

=head2 analyzePeriodical

=cut

sub analyzePeriodical($o, $b) {
  my $items = $b->{Items}->get($o->{Id_Item});
  unless ($items && @$items) {
    $log->error("Periodical '".$o->{Id}."' - Doesn't have an attached Item? Cannot link to a biblio.");
    return;
  }
  my $biblionumber = $items->[0]->{Id_Title};
  unless ($biblionumber) {
    $log->error("Periodical '".$o->{Id}."' - Attached item is missing the biblionumber?");
    return;
  }

  #Sanitate dates
  $o->{PeriodDate} = MMT::Validator::parseDate($o->{PeriodDate}) if $o->{PeriodDate};

  $subscriptions{$biblionumber} = bless({biblionumber => $biblionumber, itemnumber => $o->{Id_Item}, subscriptionid => $biblionumber}, 'MMT::PrettyCirc2Koha::Subscription') unless $subscriptions{$biblionumber};
  my $s = $subscriptions{$biblionumber};

  # look for the lowest start date
  $s->{startdate} = '2100-01-01' unless $s->{startdate}; #Seed this value high, so pretty much any real value will be less than this starting date
  if ($o->{PeriodDate} && $o->{PeriodDate} lt $s->{startdate}) {
    $s->{startdate} = $o->{PeriodDate};
  }
  elsif ($o->{PeriodYear} && $o->{PeriodYear} =~ /^\d\d\d\d/ && $o->{PeriodYear} lt $s->{startdate}) {
    $s->{startdate} = $o->{PeriodYear}.'-01-01';
  }

  # look for the biggest end date
  $s->{enddate} = $o->{PeriodYear} unless $s->{enddate};
  if ($o->{PeriodYear} && $o->{PeriodYear} =~ /^\d\d\d\d/ && $o->{PeriodYear} gt $s->{enddate}) {
    $s->{enddate} = $o->{PeriodYear}.'-12-31';
  }
}

=head2 build

 @param1 PrettyCirc data object
 @param2 Builder

=cut

sub build($self, $o, $b) {
  #$self->setKeys                 ($o, $b, [['bib_id' => 'biblionumber'], ['component_id' => 'subscriptionid']]);

  #$self->setLibrarian           ($o, $b); #| varchar(100) | YES  |     |         |                |
  $self->setStartdate            ($o, $b); #| date         | YES  |     | NULL    |                |
  #$self->setAqbooksellerid      ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setCost                ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setAqbudgetid          ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setWeeklength          ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setMonthlength         ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setNumberlength        ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setPeriodicity         ($o, $b); #| int(11)      | YES  | MUL | NULL    |                |
  #$self->setCountissuesperunit  ($o, $b); #| int(11)      | NO   |     | 1       |                |
  #$self->setNotes               ($o, $b); #| mediumtext   | YES  |     | NULL    |                |
  $self->setStatus               ($o, $b); #| varchar(100) | NO   |     |         |                |
  #$self->setLastvalue1          ($o, $b); #| int(11)      | YES  |     | NULL    |                |
  #$self->setInnerloop1          ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setLastvalue2          ($o, $b); #| int(11)      | YES  |     | NULL    |                |
  #$self->setInnerloop2          ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setLastvalue3          ($o, $b); #| int(11)      | YES  |     | NULL    |                |
  #$self->setInnerloop3          ($o, $b); #| int(11)      | YES  |     | 0       |                |
  #$self->setFirstacquidate      ($o, $b); #| date         | YES  |     | NULL    |                |
  #$self->setManualhistory       ($o, $b); #| tinyint(1)   | NO   |     | 0       |                |
  #$self->setIrregularity        ($o, $b); #| text         | YES  |     | NULL    |                |
  #$self->setSkip_serialseq      ($o, $b); #| tinyint(1)   | NO   |     | 0       |                |
  #$self->setLetter              ($o, $b); #| varchar(20)  | YES  |     | NULL    |                |
  #$self->setNumberpattern       ($o, $b); #| int(11)      | YES  | MUL | NULL    |                |
  #$self->setLocale              ($o, $b); #| varchar(80)  | YES  |     | NULL    |                |
  #$self->setDistributedto       ($o, $b); #| text         | YES  |     | NULL    |                |
  #$self->setInternalnotes       ($o, $b); #| longtext     | YES  |     | NULL    |                |
  #$self->setCallnumber          ($o, $b); #| text         | YES  |     | NULL    |                |
  $self->setLocation             ($o, $b); #| varchar(80)  | YES  |     |         |                |
  $self->setBranchcode           ($o, $b); #| varchar(10)  | NO   |     |         |                |
  #$self->setLastbranch          ($o, $b); #| varchar(10)  | YES  |     | NULL    |                |
  $self->setSerialsadditems      ($o, $b); #| tinyint(1)   | NO   |     | 0       |                |
  $self->setStaffdisplaycount    ($o, $b); #| varchar(10)  | YES  |     | NULL    |                |
  $self->setOpacdisplaycount     ($o, $b); #| varchar(10)  | YES  |     | NULL    |                |
  #$self->setGraceperiod         ($o, $b); #| int(11)      | NO   |     | 0       |                |
  $self->setEnddate              ($o, $b); #| date         | YES  |     | NULL    |                |
  $self->setClosed               ($o, $b); #| int(1)       | NO   |     | 0       |                |
  #$self->setReneweddate         ($o, $b); #| date         | YES  |     | NULL    |                |
  #$self->setItemtype            ($o, $b); #| varchar(10)  | YES  |     | NULL    |                |
  #$self->setPreviousitemtype    ($o, $b); #| varchar(10)  | YES  |     | NULL    |                |
}

sub id {
  return $_[0]->{biblionumber};
}

sub logId($s) {
  return 'Subscription: '.$s->id();
}

sub setStartdate($s, $o, $b) {
  unless ($s->{startdate}) {
    #Voyager seems to have so very few subsription.start_date -values that it is better to default it
    $s->{startdate} = '2000-01-01'; #Koha must have a koha.subscription.startdate
  }
}
sub setStatus($s, $o, $b) {
  $s->{status} = 1;
}
sub setLocation($s, $o, $b) {
  my $item = $b->{Items}->get($s->{itemnumber})->[0];
  my $branchcodeLocation = $b->{LocationId}->translate(@_, $item->{Id_Location});
  $s->{location} = $branchcodeLocation->{location};
}
sub setBranchcode($s, $o, $b) {
  my $item = $b->{Items}->get($s->{itemnumber})->[0];
  $s->{branchcode} = $b->{Branchcodes}->translate(@_, $item->{Id_Library});

  unless ($s->{branchcode}) {
    MMT::Exception::Delete->throw($s->logId()."' has no branchcode. Set a default in the TranslationTable rules!");
  }
}
sub setSerialsadditems($s, $o, $b) {
  $s->{serialsadditems} = 0;
}
sub setStaffdisplaycount($s, $o, $b) {
  $s->{staffdisplaycount} = 52;
}
sub setOpacdisplaycount($s, $o, $b) {
  $s->{opacdisplaycount} = 52;
}
sub setEnddate($s, $o, $b) {
  unless ($s->{enddate}) {
    #Voyager seems to have so very few component_pattern.end_date -values that it is better to default it
    $s->{enddate} = '2018-12-31';
  }
}
sub setClosed($s, $o, $b) {
  $s->{closed} = 1; #Currently only bare minimums are migrated, so enumeration cannot atm. continue in Koha from where voyager left off.
}

return 1;