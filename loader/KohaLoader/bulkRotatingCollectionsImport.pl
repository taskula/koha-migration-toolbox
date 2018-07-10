#!/usr/bin/perl

use Modern::Perl;

BEGIN {
    use FindBin;
    eval { use lib $FindBin::Bin; };
}

use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use Getopt::Long;
use C4::Items;
use C4::RotatingCollections;

use ConversionTable::ItemnumberConversionTable;
use Data::Dumper;

binmode( STDOUT, ":encoding(UTF-8)" );
my ( $input_file, $number, $verbose) = ('',0,undef);
my $itemnumberConversionTable = 'itemnumberConversionTable';

$|=1;

GetOptions(
    'file:s'                               => \$input_file,
    'i|inConversionTable:s'                => \$itemnumberConversionTable,
    'n:f'                                  => \$number,
    'verbose'                              => \$verbose,
);

my $help = <<HELP;

perl bulkRotatingCollectionsImport.pl --file /home/koha/migration/Siirtolaina.migrateme -n 1200

Migrates the Perl-serialized MMT-processed rotating collection-files to Koha.

  --file               The perl-serialized HASH of rotCols.

  -n                   How many items to migrate? Defaults to all.

  --inConversionTable  From which file to read the conversion between itemnumber and Item's barcode.
                       File is generated by the bulkItemImport.pl and has the following content:

                           itemnumber:newItemnumber:barcode
                           10001000:1:541N00010001
                           10001001:2:541N00010013
                           10001074:3:541N00010746
                           ...

                       Defaults to 'itemnumberConversionTable'. You shouldn't need to touch this.

HELP

unless ($input_file) {
    die "$help\n\nYou must give the Rotating Collections-file.";
}


my $fh = IO::File->new( $input_file, "<:encoding(utf-8)" );
$itemnumberConversionTable =     ConversionTable::ItemnumberConversionTable->new($itemnumberConversionTable, 'read');
my $dbh = C4::Context->dbh;
#!! Copypaste from C4::RotatingCollections::AddItemToCollection() !! Might be stale code!
my $rotColItemInsertSth = $dbh->prepare("
    INSERT INTO collections_tracking (
        colId,
        itemnumber,
        origin_branchcode,
        date_added
    ) VALUES (?, ?, ?, ?)
");

sub migrate_rotColItem {
    my ( $rotColItem ) = @_;

    #See if a rotating collection exists for this from-to-branch -route
    my $rotColTitle = 'Kirkas ' . $rotColItem->{origin_branch} . '->' . $rotColItem->{transfer_branch};
    my ($colId, $colTitle, $colDesc, $colBranchcode) = C4::RotatingCollections::GetCollectionByTitle($rotColTitle);
    unless ($colId) {
        my ( $success, $errorcode, $errormessage ) = C4::RotatingCollections::CreateCollection($rotColTitle,
                                                  'Konversion aikainen siirtokokoelma',
                                                  $rotColItem->{origin_branch});
        ($colId, $colTitle, $colDesc, $colBranchcode) = C4::RotatingCollections::GetCollectionByTitle($rotColTitle);
        if ($errormessage) {
            print "\nRotCol for itemnumber ".$rotColItem->{itemnumber}.", failed adding a host Rotating Collection. Error '$errormessage'\n.";
            return;
        }
    }

    $rotColItemInsertSth->execute(
        $colId,
        $rotColItem->{itemnumber},
        $rotColItem->{origin_branch},
        $rotColItem->{date_added},
    );
}


sub newFromRow {
    no strict 'vars';
    eval shift;
    my $s = $VAR1;
    use strict 'vars';
    warn $@ if $@;
    return $s;
}

my $i = 0;
while (<$fh>) {
    $i++;
    print ".";
    print "\n$i" unless $i % 100;

    my $rotColItem = newFromRow($_);

    $rotColItem->{barcode} = $itemnumberConversionTable->fetchBarcode(  $rotColItem->{itemnumber}  );
    unless ($rotColItem->{barcode}) {
        print "\nRotCol for itemnumber ".$rotColItem->{itemnumber}." has no Barcode/Item in the itemnumberConversionTable!\n";
        next();
    }

    $rotColItem->{itemnumber} = C4::Items::GetItemnumberFromBarcode(  $rotColItem->{barcode}  );
    unless ($rotColItem->{itemnumber}) {
        print "\nRotCol for barcode ".$rotColItem->{barcode}." and itemnumber ".$rotColItem->{itemnumber}." has no Item in Koha!\n";
        next();
    }

#    unless ($itemnumber == $rotColItem->{itemnumber}) {
#        print "\nRotCol for barcode ".$rotColItem->{barcode}." and itemnumber ".$rotColItem->{itemnumber}." matched an Item with different itemnumber '$itemnumber'??\n";
#        next();
#    }

    migrate_rotColItem( $rotColItem );

    last if $number && $i == $number;
}
