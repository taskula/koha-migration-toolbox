## IN THIS FILE
##
## PrettyLib/Circ database extraction script configuration
##
## This file should always be next to the extract.pl-script and be named config.perl
## This is a pure-perl config entity so no funny config file parsing is needed.
##

return {
  # The Name of the ODBC (D)ata (S)ource (N)ame to connect into the system.
  # You must use the Windows ODBC Data Source Administration tool to configure
  # a PrettyLib/Circ as ODBC data source to be accessible for the Perl's DBD::ODBC -driver.
  db_dsn => "PrettyCirc",

  # Depending on how the Windows user is authorized to access various resources this might be the username
  # of the Windows-user account or a specific DB account.
  db_username => "",

  # Same as above, not needed if authorizing as the Windows system user.
  db_password => "",

  # The "database" name, eg. PrettyLib or PrettyCirc, or whatever is the name of the DB
  db_catalog => "PrettyCirc",

  # Schema withing the DB. Typically odb
  db_schema => "dbo",

  # This is only needed if doing introspection for a specific table. Should be left emtpy.
  db_table => "",

  # Directory where to export the table dumps
  export_path => "PrettyCircExport",

  # Try some magic to fix encoding issues
  db_reverse_decoding => 1,

  # Where the PSCP-program is?
  # This is used to ship the database dumps via ssh to the remote fileserver.
  # You can download a new version of pscp from here, if the included version is not compatible with your system:
  #    https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
  pscp_filepath => 'pscp.exe',

  # User on the remote file server
  ssh_user => 'beastttk',

  # Password of the remote server user
  ssh_pass => '1234',

  # IP/hostname of the remote fileserver
  ssh_host => '127.0.0.1',

  # In which directory the DB dump should be put into?
  ssh_shipping_dir => 'private/PKKS',

  # Encrypt the cleartext passwords in the PrettyLib DB, so they will never leave the server unprotected.
  # Requires the Perl module
  #   Crypt::Eksblowfish::Bcrypt
  # to be installed
  # The value must be 0, or the cost of the hashing operation from 1-9. 8 takes ~1s per customer in the DB
  # Be aware, if this setting is on, the conversion pipeline cannot enforce proper password hygiene standards,
  # such as the password being longer than 1 character.
  # Passwords of length 1 can happen in some libraries with old library systems.
  bcrypt_customer_passwords => 2,
};

