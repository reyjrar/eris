package eris::View::PDF::SurplusSheet;

use strict;
use warnings;
use parent 'Catalyst::View';
use File::Spec;
use File::Temp;
use PDF::Reuse;
use PDF::Reuse::Util;
use eris;

our $_PDF_TEMPLATE = File::Spec->catfile(
	eris->path_to(qw(root static docs))->absolute->stringify,
	q{SurplusSheet.pdf}
);

our @_PDF_POSITIONS = (
	# First Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	77,		792-65	], opt => ''		},
		make		 => { coords => [	280,	792-65	], opt => 'center'	},
		model		 => { coords => [	77,		792-102	], opt => ''		},
		serial_no	 => { coords => [	220,	792-102	], opt => 'center'	},
		name		 => { coords => [	345,	792-210	], opt => 'center'	},
		date		 => { coords => [	210,	792-240	], opt => ''		},
	},
	# Second Sheet
	{
		# FIELD				X		Y						Options
		proerty_tag	 => { coords => [	77,		792-326	], opt => ''		},
		make		 => { coords => [	280,	792-326	], opt => 'center'	},
		model		 => { coords => [	77,		792-360	], opt => ''		},
		serial_no	 => { coords => [	220,	792-360	], opt => 'center'	},
		name		 => { coords => [	345,	792-465	], opt => 'center'	},
		date		 => { coords => [	210,	792-495	], opt => ''		},
	},
	# Third Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	77,		792-580	], opt => ''		},
		make		 => { coords => [	280,	792-580	], opt => 'center'	},
		model		 => { coords => [	77,		792-615	], opt => ''		},
		serial_no	 => { coords => [	220,	792-615	], opt => 'center'	},
		name		 => { coords => [	345,	792-720	], opt => 'center'	},
		date		 => { coords => [	210,	792-750	], opt => ''		},
	},
);

=head1 NAME

eris::View::PDF::SurplusSheet - Create a view for Surplus Sheets

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=cut

sub process {
	my ($self,$c) = @_;

	my $output = $self->render_pdf( $c->stash->{sheet_info} );

	$c->response->content_type('application/pdf');
	$c->response->headers->header("Content-Disposition" => q{attachment; filename=SurplusSheet.pdf} );
	$c->response->body( $output );
}


sub render_pdf {
	my ($self,$sheets) = @_;

	# Create a Temp File
	my $filename = File::Temp->tmpnam();
	prFile( $filename );

	# Fill out the sheets
	my @copy = @{ $sheets };
	my $page = 0;
	while( @copy ) {
		++$page;
		# Page Break
		prPage() if( $page > 1 );
		# Initialize to PDF Template
		prForm( { file => $_PDF_TEMPLATE } );	
		# Write the form
		foreach my $pos (@_PDF_POSITIONS) {
			last unless @copy;	# exit if there's no more data
			my $rec = shift @copy;
			foreach my $field (keys %{ $pos }) {
				prText( @{ $pos->{$field}{coords} }, $rec->{$field}, $pos->{$field}{opt} );
			}
		}	
	}
	# Write and Close the File
	prEnd();	

	# Slurp File contents into $pdf
	my $pdf = undef;
	local $/ = undef;
	open my $pfh, '<', $filename;
	$pdf = (<$pfh>);
	close $pfh;
	unlink $filename;

	return $pdf;
}

=head1 AUTHOR

Brad Lhotsky <brad@divisionbyzero.net>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
