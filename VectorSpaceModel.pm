package VectorSpaceModel;

use Stem;
my $stemmer = new Stem();

use ParseDocument;
my $parDoc = new ParseDocument();

use XML::Simple;
my $xmlParser = new XML::Simple;

# class constructor, keeping the value of vocabulary and document list file
# args :
#   collection_file : reference to corpus
#   vocabfile : reference to vocabulary file
#   docno_file : reference to document list file
sub new {
    my $class = shift;
    my $self = {
        _collection => shift,
        _vocabulary => shift,
        _docno_list => shift,
        _total_doc => shift
   };

   bless $self, $class;
   return $self;
}

# method search : searching thru the documents using VSM model calculation
# args :
#   query : string entry of the query
#   tf-idf : flag to determine the using of TF (FALSE) or TF-IDF (TRUE)
sub search {
    my ($self, $line, $flag) = @_;
    # print "@_\n";
    # clean and split the query
    $line =~ tr/A-Z/a-z/;
    my @query = split /[\?\-\.\s+]/, $line;

    # stem the query
    my @stemmed = ();
    foreach (@query) {
        my $stemmed_word = $stemmer->stemword($_);
        push @stemmed, $stemmed_word;
    }
    
    my %documents;          # hash for storing term-document matrix
    my %idf;                # hash for calculating IDF weight

    open OCCURFILE, "<".$self->{_docno_list} or die "Cannot open document list file\n";
    while (my $occur_entry = <OCCURFILE>) {
        my ($token, $doclist) = split /\s+/, $occur_entry;
        if ($token ~~ @stemmed) {                     # if token word matches with any words in query
            my @docno = split (/\|/, $doclist);       # retrieve the document lists of each terms
            # loop for each document list
            foreach my $doc (@docno) {
                print "Reading $doc\n";
                # call restructureDocument to restructure the collections
                my @array = $parDoc->restructureDocument($self->{_collection});
                # loop for each result of restructure
                foreach my $string (@array) {
                    # parse XML
                    my $data = $xmlParser->XMLin($string);
                    # if document contains same doc no in query
                    if ($data->{NO} eq $doc) {
                        # retrieve the body text, and do cleaning
                        my $text = $data->{TEKS};
                        $text =~ tr/A-Z/a-z/;
                        $text =~ s/["'\&\#\^\$\*\%]/ /g;
                        
                        # repeat for each word found in this document
                        foreach my $word (split /[\+\?\.\(\)\[\]\{\}\|\\,\/\:\_\-\;\s+]/, $text) {
                            # stem the word
                            $word = $stemmer->stemword($word);

                            if ($flag == 0) {           # if TF-IDF flag is FALSE (0)
                                $idf{$word} = 1;        # only use TF weight
                            } else {                    # if flag is TRUE (1), calculate IDF for each word (w.r.t. document frequency)
                                open VOCABFILE, "<".$self->{_vocabulary} or die "Cannot open vocabulary file\n";
                                while (my $entry = <VOCABFILE>) {
                                    my ($term_word, $colfreq, $docfreq) = split /\s+/, $entry;          # split each entries
                                    if ($term_word eq $word) {                                          # if term found in current entry,
                                        $idf{$word} = log($self->{_total_doc}/$docfreq)/log(10);        # calculate the idf of the term by taking 
                                    }
                                }
                                close VOCABFILE;
                            }

                            # count up every occurence of word (for TF weight)
                            if (exists $documents{$doc}{$word}) {
                                $documents{$doc}{$word}++;
                            } else {
                                $documents{$doc}{$word} = 1;
                            }
                        }
                    }
                }
            }
        }
    }
    close OCCURFILE;

    my %query_weight;       # hash for counting weight of each terms in query
    # weigh term in query
    foreach my $query_term (@stemmed) {
        if (exists $query_weight{$query_term}) {
            $query_weight{$query_term}++;
        } else {
            $query_weight{$query_term} = 1;
        }
    }
    my $query_sum = 0;      # counter for total weight in query
    foreach my $query_term (keys %query_weight) {
        $query_weight{$query_term} *= $idf{$query_term};
        $query_sum += $query_weight{$query_term}**2;
        # print "$query_term\t tf-idf : $query_weight{$query_term}\n";
    }
    my $query_norm = sqrt($query_sum);

    # calculate the similarity
    my %similarity;         # hash for similarity of each documents with query
    foreach my $doc (sort keys %documents) {
        my $sum = 0;        # sum for calculating term similarities ()
        my $doc_sum = 0;    # sum for calculating document normal size

        # loop for each token in current document
        foreach my $token (keys %{$documents{$doc}}) {
            #calculate tf-idf (by multiplying previous counted tf weight with idf calculation)
            $documents{$doc}{$token} *= $idf{$token};
            # sum the weight for document size normalization
            $doc_sum += $documents{$doc}{$token};
            # loop for summing up term similarities
            foreach my $query_token (keys %query_weight) {
                # if token in document found in query tokens, the sum the multiplication of both (for similarity counting)
                if ($token eq $query_token) {
                    $sum += $documents{$doc}{$token}*$query_weight{$token};
                }
            }
        }

        # assign the value to hash based from cosine similarity formula
        $similarity{$doc} = $sum / (sqrt($doc_sum) * $query_norm);
        # print "$doc\t sum : $sum,\t document normal : ".sqrt($doc_sum).",\t query normal : $query_norm,\t similarity : ".$similarity{$doc}."\n";
    }

    # return the similarity result
    return %similarity;
}

1;
