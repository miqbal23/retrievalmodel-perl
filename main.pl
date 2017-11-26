use 5.010;

use ParseDocument;
my $parser = new ParseDocument();


my $collection = "directory/your_collection_filename";  # change with directory to collection file

my ($result, $total_word) = $parser->parseDoc($collection);
print "Total documents in collection : ".$result."\n";
print "Total words in collection : ".$total_word."\n";

my $queryfile = "your_query_filename";      # change with directory to query file
my %queries;

open QUERIES, "<".$queryfile or die "Cannot open ".$queryfile."\n";
while (<QUERIES>) {
    my @query = split /[\?\-\.\s+]/, $_;
    my $query_no = shift @query;
    $queries{$query_no} = join(" ", @query);
    print "$query_no $queries{$query_no}\n";
}
close QUERYFILE;

# ask user for query to be processed
my $selected_query;
my $selected_query_code;
print "Please choose a query code : ";
while (<STDIN>) {
    chomp;
    if ($_ eq "") { die "No query chosen, quitting...\n"; }                     
    elsif (exists $queries{$_}) {                                          
        print "Your query is : ".$queries{$_}."\n";
        $selected_query = $queries{$_};                                     
        $selected_query_code = $_;
        last;
    } else {
        print "No query exists. Please type another : ";
    }
}

# retrieve generated files from reading and parsing collection
my $vocabulary_file = $parser->getVocabFile();
my $docno_file = $parser->getDocNoFile();
my $doclen_file = $parser->getDocLenFile();

my %model_result;
my $model_outfile;

print "Which model do you want to process this query? (type the number) :\n";
print "1. Vector Space Model\n2. Unigram Language Model\n";
while (<STDIN>) {
    chomp;
    if ($_ eq "") { die "No model chosen, quitting...\n"; }
    elsif ($_ eq "1") {     # user choose Vector Space Model
        print "Processing with Vector Space Model\n";
        $model_outfile = "your_vsm_result_file";           # change with output file's directory

        use VectorSpaceModel;
        my $vsmodel = new VectorSpaceModel($collection, $vocabulary_file, $docno_file, $result);
        # subroutine to search the index
        # flag for weighting method used :
        #   1 : TF-IDF
        #   0 : TF only
        my $flag = 1;
        %model_result = $vsmodel->search($selected_query, $flag);
        last;
    } elsif ($_ eq "2") {       # user choose Unigram Language Model
        print "Processing with Unigram Language Model\n";
        $model_outfile = "your_unigram_result_file";     # change with output file's directory
        
        use UnigramLM;
        my $unimodel = new UnigramLM($collection, $vocabulary_file, $docno_file, $doclen_file, $total_word);  
        # subroutine to search the documents
        # lambda : parameters for value of lambda (refer to Unigram Language Model formula)
        my $lambda = 0.5;
        %model_result = $unimodel->search($selected_query, $lambda);
        last;
    } else {
        print "No model exists. Please type another : ";
    }
}

# print the result to file
&printResult($selected_query_code, $model_outfile, \%model_result);

# evaluate model performance
use ModelEvaluation;
my $model_eval = new ModelEvaluation($relevance);
my $relevance = "your_relevance_judgement_file";        # change with directory of relevance judgement file

my ($precision, $recall, $avg_precision) = $model_eval->evaluate($model_outfile, $selected_query_code);
print "Evaluation result of model performance :\n";
print "Precision : $precision\tRecall : $recall\tMean Average Precision (MAP) : $avg_precision\n";

# subroutine to print result to file
# args :
#   $query_code : code of query being searched in documents
#   $file : file of printing destination
#   %result : hash of result from search process
sub printResult {
    my $query_code = shift;
    my $file = shift;
    my %result = %{shift ()};
    my $count = 1;
    
    open OUTFILE, ">".$file or die "Cannot open output file\n";
    foreach my $document (sort {$result{$b} <=> $result{$a}} keys %result) {
        print OUTFILE "$query_code\t$count\t$document\t$result{$document}\n";
        $count++;
    }

    print "Successfully printed results to ".$file."\n";
    close OUTFILE;
    return 1;
}