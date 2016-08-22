package mypdfapi;
use PDF::API2;
use PDF::API2::Util;
use Text::PDF::FileAPI;
use Text::PDF::AFont;
use Text::PDF::Page;
use Text::PDF::Utils;
use Text::PDF::TTFont;
use Text::PDF::TTFont0;

our @ISA="PDF::API2";

sub mediabox {
        my ($self,$x1,$y1,$x2,$y2) = @_;
        if(defined $x2) {
                $self->{pages}->{'MediaBox'}=PDFArray(
                        map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
                );
        } elsif(defined $x1) {
                $self->{pages}->{'MediaBox'}=PDFArray(
                        map { PDFNum(float($_)) } (0,0,$x1,$y1)
                );
        }
        my @mb = map {$_->{'val'}} $self->{pages}->{'MediaBox'}->elementsof;
        print "mb= @mb \n";
        return @mb;
}


=item $pageobj = $pdf->mergepage $sourcepdf, $sourceindex, $targetpage

Returns $targetpage, which is merged with $sourcepdf,$sourceindex.

B<Note:> on $index

	-1,0 ... returns the last page
	1 ... returns page number 1

=cut

sub mergepage {
	my $self=shift @_;
	my $s_pdf=shift @_;
	my $s_idx=shift @_||0;
	my $t_page=shift @_;
	my ($s_page);

	$s_page=$s_pdf->openpage($s_idx);
	
	$self->{apiimportcache}=$self->{apiimportcache}||{};
	$self->{apiimportcache}->{$s_pdf}=$self->{apiimportcache}->{$s_pdf}||{};

	foreach my $k (qw( MediaBox ArtBox TrimBox BleedBox CropBox Rotate B Dur Hid Trans AA PieceInfo LastModified SeparationInfo ID PZ )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = PDF::API2::walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
	foreach my $k (qw( Thumb Annots )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = PDF::API2::walk_obj({},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
	foreach my $k (qw( Resources )) {
		$s_page->{$k}=$s_page->find_prop($k);
		next unless(defined $s_page->{$k});
		$s_page->{$k}->realise if(ref($s_page->{$k})=~/Objind$/);

		$t_page->{$k}=PDFDict() unless (defined $t_page->{$k});
		foreach my $sk (qw( ColorSpace XObject ExtGState Font Pattern ProcSet Properties Shading )) {
			next unless(defined $s_page->{$k}->{$sk});
			$s_page->{$k}->{$sk}->realise if(ref($s_page->{$k}->{$sk})=~/Objind$/);
			$t_page->{$k}->{$sk}=PDFDict();
			foreach my $ssk (keys %{$s_page->{$k}->{$sk}}) {
				next if($ssk=~/^ /);
				$t_page->{$k}->{$sk}->{$ssk} = PDF::API2::walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k}->{$sk}->{$ssk});
			}
		}
	}
	if(defined $s_page->{Contents}) {
		$s_page->fixcontents;
		$t_page->{Contents}=PDFArray() unless (defined $t_page->{Contents});

		foreach my $k ($s_page->{Contents}->elementsof) {
			my $content=PDFDict();
			$self->{pdf}->new_obj($content);
			$t_page->{Contents}->add_elements($content);

			$k->realise;
		#	$k->read_stream(1);
			
			if($k->{Filter}){
				$content->{'Filter'}=PDFArray($k->{Filter}->elementsof);
				$content->{' nofilt'}=1;
				$content->{' stream'}=$k->{' stream'};
			} else {
				$content->{' stream'}=substr($k->{' stream'},0,$k->{Length}->val-1);
			}
			
		}
	}
	return($t_page);
}

package Text::PDF::Array;

=head2 $a->unhisft_elements

Prepends the given elements to the array. An element is only added if it 
is defined.

=cut

sub unshift_elements
    {
    my ($self) = shift;
    my ($e);
    
    foreach $e  (reverse @_)
    { unshift (@{$self->{' val'}}, $e) if defined $e; }
    $self;
}                                                                       