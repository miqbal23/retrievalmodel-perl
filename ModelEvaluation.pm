package ModelEvaluation;

use 5.010;

sub new {
    my $class = shift;
    my $self = {
        _relevance_file => shift
   };

   bless $self, $class;
   return $self;
}

sub evaluate {
    my ($self, $model_outfile, $query_code) = @_;
    my @relv_judge;
    
    # open relevance judgement file
    open REL_FILE, "<".$self->{_relevance_file} or die "Cannot open relevance judgement file \n";
    while (my $line = <REL_FILE>) {
        my @line_entry = split /\s+/, $line;
        my $query_no = shift @line_entry;
        my $doc_no = shift @line_entry;

        # retrieve relevance judgement based from query code given
        if ($query_no eq $query_code) {
            push @relv_judge, $doc_no;
        }
    }
    close REL_FILE;

    my @model_result;
    open MODEL_FILE, "<".$model_outfile or die "Cannot open VSM result file";
    while (my $line = <MODEL_FILE>) {
        my @result_entry = split /\s+/, $line;
        shift @result_entry; shift @result_entry;

        # retrieve all document index into single array
        my $document_result = shift @result_entry;
        push @model_result, $document_result;
    }
    close VSM;

    my $document_processed = 0;         # counter for MAP calculation
    my $precision_count = 0;            # counter for Precision and Recall calculation
    my @prec_array;                     # array to store precision timeline (after every iteration)
    foreach my $item_result (@model_result) {
        $document_processed++;

        # MAP = average precision when recall increased
        # recall increased = a doc no in relevance judgement found in model output (during the iteration)
        if ($item_result ~~ @relv_judge) {
            $precision_count++;                                         # count up
            my $curr_prec = $precision_count / $document_processed;     # calculate current precision
            print "Precision at $document_processed documents : $curr_prec\n";
            push @prec_array, $curr_prec;                               # collect the precision value
        }
    }

    # calculate precision and recall
    my $precision = $precision_count / scalar @model_result;
    my $recall = $precision_count / scalar @relv_judge;

    # count Mean Average Precision (MAP)
    my $prec_sum = 0;
    foreach (@prec_array) {
        $prec_sum += $_;
    }
    my $avg_precision = $prec_sum/scalar @prec_array;

    return $precision, $recall, $avg_precision;
}

1;







