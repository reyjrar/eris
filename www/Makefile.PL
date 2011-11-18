# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'eris';
all_from 'lib/eris.pm';

requires 'Catalyst::Runtime' => '5.80003';
requires 'Catalyst::Model::DBIC';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Authentication::Credential::Kerberos';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Action::REST';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::JSON';
requires 'Catalyst::View::Mason';
requires 'parent';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
requires 'CHI';
requires 'DBIx::Connector';
requires 'DateTime::Format::Pg';
requires 'DateTime::Format::HTTP';
requires 'Exception::Class::DBI';
requires 'Net::DNS';
requires 'Net::IP::Resolver';
requires 'Regexp::Common';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
