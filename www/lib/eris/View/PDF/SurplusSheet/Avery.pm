package eris::View::PDF::SurplusSheet::Avery;

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
	q{SurplusSheet-Avery.pdf}
);

our @_PDF_POSITIONS = (
	# First Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	24,		792-91	], opt => ''		},
		make		 => { coords => [	92,		792-91	], opt => ''		},
		model		 => { coords => [	24,		792-124	], opt => ''		},
		serial_no	 => { coords => [	92,		792-124	], opt => ''		},
		date		 => { coords => [	92,		792-243	], opt => ''		},
	},
	# Second Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	324,	792-91	], opt => ''		},
		make		 => { coords => [	392,	792-91	], opt => ''		},
		model		 => { coords => [	324,	792-124	], opt => ''		},
		serial_no	 => { coords => [	392,	792-124	], opt => ''		},
		date		 => { coords => [	392,	792-243	], opt => ''		},
	},
	# Third Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	24,		792-337	], opt => ''		},
		make		 => { coords => [	92,		792-337	], opt => ''		},
		model		 => { coords => [	24,		792-368	], opt => ''		},
		serial_no	 => { coords => [	92,		792-368	], opt => ''		},
		date		 => { coords => [	92,		792-488	], opt => ''		},
	},
	# Fourth Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	324,	792-337	], opt => ''		},
		make		 => { coords => [	392,	792-337	], opt => ''		},
		model		 => { coords => [	324,	792-368	], opt => ''		},
		serial_no	 => { coords => [	392,	792-368	], opt => ''		},
		date		 => { coords => [	392,	792-488	], opt => ''		},
	},
	# Fifth Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	24,		792-577	], opt => ''		},
		make		 => { coords => [	92,		792-577	], opt => ''		},
		model		 => { coords => [	24,		792-608	], opt => ''		},
		serial_no	 => { coords => [	92,		792-608	], opt => ''		},
		date		 => { coords => [	92,		792-728	], opt => ''		},
	},
	# Sixth Sheet
	{
		# FIELD				X		Y						Options
		property_tag => { coords => [	324,	792-577	], opt => ''		},
		make		 => { coords => [	392,	792-577	], opt => ''		},
		model		 => { coords => [	324,	792-608	], opt => ''		},
		serial_no	 => { coords => [	392,	792-608	], opt => ''		},
		date		 => { coords => [	392,	792-728	], opt => ''		},
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
	# Set the US Letter Layout
	prMbox( 0, 0, 612, 792 );

	# Fill out the sheets
	my @copy = @{ $sheets };
	my $page = 0;
	while( @copy ) {
		++$page;
		# Page Break
		prPage() if( $page > 1 );
		# Initialize to PDF Template
		prForm( { file => $_PDF_TEMPLATE } );	
		prFontSize(8);
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
