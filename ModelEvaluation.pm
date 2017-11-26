package ModelEvaluation;

use 5.010;

# class constrcutor
sub new {
    my $class = shift;
    my $self = {
        _relevance_file => shift
   };

   bless $self, $class;
   return $self;
}

# method evaluate, evaluate the result of retrieval using the relevance judgement file provided
# args :
#   $model_outfile = reference to file containing retrieval model result 
#   $query_code = index no of query chosen to be processed
# return :
#   $precision : precision value
#   $recall : recall value
#   $avg_precision : MAP value wrt. to relevance judgement and document retrieved from model
sub evaluate {
    my ($self, $model_outfile, $query_code) = @_;
    my @relv_judge;
    
    open REL_FILE, "<".$self->{_relevance_file} or die "Cannot open relevance judgement file \n";
    while (my $line = <REL_FILE>) {
        my @line_entry = split /\s+/, $line;
        my $query_no = shift @line_entry;
        my $doc_no = shift @line_entry;

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

        my $document_result = shift @result_entry;
        push @model_result, $document_result;
    }
    close VSM;

    my $document_processed = 0;
    my $precision_count = 0;
    my @prec_array;
    foreach my $item_result (@model_result) {
        $document_processed++;

        # MAP = average precision when recall increased
        # recall increased = a doc no in relevance judgement found in model output (during the iteration)
        if ($item_result ~~ @relv_judge) {
            $precision_count++;
            my $curr_prec = $precision_count / $document_processed;
            print "Precision at $document_processed documents : $curr_prec\n";
            push @prec_array, $curr_prec;
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







