=begin
PSI-Sigma: A splicing-detection method for short-read and long-read RNA-seq data
© Kuan-Ting Lin, 2018-2024
PSI-Sigma is free for non-commercial purposes by individuals at an academic or non-profit institution.
For commercial purposes, please contact tech transfer office of CSHL via narayan@cshl.edu
=end
=cut
#!/usr/bin/perl -w

	use strict;
	use Statistics::R;

	my ($fn,$min) = @ARGV;
    
	print "Minimum number of samples for p-value = $min\n";
	
	my @rawp;
	my @p;
	my @fdr;
	my @dPSI;
	my @symbol;
	my $linecount = 0;
	my @output;
	my @q;
	my $header = "-";
	my @removedp;
	print "Reading... $fn\n";
	open(FILE,"$fn") || die "Aborting.. Can't open $fn : $!\n";
	while(my $line=<FILE>){
		chomp $line;
		$linecount++;
		if($linecount == 1){
			$header = $line;
			next;
		}
		my $p = 1;
		my $q = 1;
		my $deltaPSI = 0;
		my $symbol = "-";
		my ($region,$gn,$exon,$event,$num_n,$num_t,$exontype,$ENST,$dPSI,$pvalue,$fdr,$nvalues,$tvalues,$dbid) = split(/\t/,$line);
		push(@rawp,$p);
		next if($num_n < $min || $num_t < $min);
		next if($pvalue eq "NaN");
		my @nvalues = split(/\|/,$nvalues);
		my @tvalues = split(/\|/,$tvalues);
		my ($ncount,$tcount) = (0,0);
		foreach my $n(@nvalues){
			next if($n eq "na");
			$ncount++ if($n > 0 && $n < 100);
		}
		foreach my $t(@tvalues){
			next if($t eq "na");
			$tcount++ if($t > 0 && $t < 100);
		}

		if($ncount > 1 || $tcount > 1){
		}else{
			push(@removedp,$pvalue);
			next;
		}
		$p = $pvalue;
		$q = $fdr;
		$deltaPSI = $dPSI;
		$symbol = $gn;
		push(@rawp,$p);
		push(@p,$p);
		push(@q,$q);
		push(@dPSI,$deltaPSI);
		push(@symbol,$symbol);
		push(@output,$line);
		
	}
	close(FILE);
    
    print "number of p-value = " . scalar @p . "\n";
    #densityplot(\@rawp);
   
	my $qvalues = rqvalue(\@p);
    my @qvalues = @$qvalues;

    my $outfn = $fn;
    if(-e $fn . ".rawpvalue.txt.tar.gz"){
    	print "rawpvalue.txt.tar.gz existed. (no backup)\n";
    }else{
    	print "Backup rawpvalue.txt\n";
		system("mv $fn $fn.rawpvalue.txt");
		system("tar zcvf $fn.rawpvalue.txt.tar.gz $fn.rawpvalue.txt");
		system("rm $fn.rawpvalue.txt");
    }
    
	print "Outputing... $outfn\n";
	open(OUT,">$outfn") || die "Aborting.. Can't open $outfn : $!\n";
	print OUT "$header\n";
	for(my $i = 0;$i < scalar @output;$i++){
		my ($region,$gn,$exon,$event,$n,$t,$exontype,$ENST,$dPSI,$pvalue,$fdr,$nvalues,$tvalues,$dbid) = split(/\t/,$output[$i]);
		$fdr = $qvalues[$i];
		print OUT "$region\t$gn\t$exon\t$event\t$n\t$t\t$exontype\t$ENST\t$dPSI\t$pvalue\t$fdr\t$nvalues\t$tvalues\t$dbid\n";
	}
	close(OUT);

sub rqvalue{
    my $p = shift;
	my $R = Statistics::R->new();
	my $qvalues = "-";
	$R->run(q`a<-installed.packages()`);
	$R->run(q`packages<-a[,1]`);
	my $available = $R->get(q`is.element("qvalue", packages)`);
	if($available eq "TRUE"){
		print "## Note: qvalue module is available.\n";
		print "Doing ... qvalue from R\n"; 
		$R->run(q`library(qvalue)`);
		$R->run(q`options(max.print=999999)`);
		$R->set('p',\@$p);
		$R->run(q`qvalue <- qvalue(p=p)`);
		$R->run(q`q <- qvalue$qvalues`);
		$qvalues = $R->get('q');
	}else{
		print "## Note: qvalue module isn't available. Switch to p.adjust().\n";
		print "Doing ... p.adjust from R\n"; 
		$R->run(q`options(max.print=999999)`);
		$R->set('p',\@$p);
		$R->run(q`q <- p.adjust(p,method="BH")`);
		$qvalues = $R->get('q');
	}
	$R->run(q`tiff("pvalue_dist.tiff")`);
	$R->run(q`plot(density(p))`);
	$R->run(q`dev.off()`);
	$R->run(q`tiff("qvalue_dist.tiff")`);
	$R->run(q`plot(density(q))`);
	$R->run(q`dev.off()`);
	return $qvalues;
}

sub densityplot{
    my $p = shift;
	my $R = Statistics::R->new();
	$R->run(q`options(max.print=999999)`);
	$R->set('p',\@$p);
	$R->run(q`tiff("rawpvalue_dist.tiff")`);
	$R->run(q`plot(density(p))`);
	$R->run(q`dev.off()`);
	return 1;
}