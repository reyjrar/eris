#!/usr/bin/env perl

use strict;
use warnings;

use YAML;
use Data::Dumper;
use Try::Tiny;
use POE qw(
	Component::Client::eris
);

#--------------------------------------------------------------------------#
# Argument Handling

#--------------------------------------------------------------------------#
# Main Program Loops
POE::Session->create(
	inline_states => {
		_start					=> \&debug_start,
		_stop					=> sub { },
		_child					=> sub { },
		process_message			=> \&process_message,
	},
);

POE::Component::Client::eris->spawn(
	Subscribe		=> [ qw(fullfeed) ],
	MessageHandler	=> sub {
		my $msg = shift;
		$poe_kernel->post('debug' => 'process_message' => $msg);
	},
);

POE::Kernel->run();
exit 0;
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Startup the Storage Environment
sub debug_start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	
	$kernel->alias_set('debug');
	print "Started debugging connector\n";

}

#--------------------------------------------------------------------------#
# Process Message
sub process_message {
	my ($kernel,$heap,$msg) = @_[KERNEL,HEAP,ARG0];

	$msg->{datetime_obj} = ref $msg->{datetime_obj};

	print YAML::Dump $msg;
}
