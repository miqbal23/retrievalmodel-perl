package UnigramLM;

use 5.010;

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
#   doc_len_file : reference to document length file
#   total_word : value of total tokens in collection
sub new {
    my $class = shift;
    my $self = {
        _collection => shift,
        _vocabulary => shift,
        _docno_list => shift,
        _doc_len_file => shift,
        _total_word => shift
   };

   bless $self, $class;
   return $self;
}

# method search : searching thru the documents using Unigram Language Model calculation
# args :
#   query : string entry of the query
#   lambda : lambda value of Unigram Language Model formula
sub search {
    my ($self, $line, $lambda) = @_;
    # clean and split the query
    $line =~ tr/A-Z/a-z/;
    my @query = split /[\?\-\.\s+]/, $line;

    # stem the query
    my @stemmed = ();
    foreach (@query) {
        my $stemmed_word = $stemmer->stemword($_);
        push @stemmed, $stemmed_word;
    }

    my %prob;       # for storing each term frequency in each document
    my %doc_len;    # for storing document length of each article

    open OCCURFILE, "<".$self->{_docno_list} or die "Cannot open document list file\n";
    while (my $occur_entry = <OCCURFILE>) {
        my ($token, $doclist) = split /\s+/, $occur_entry;
        # if token found in docno_list, extract the document index list
        if ($token ~~ @stemmed) {
            my @docno = split (/\|/, $doclist);
            # repeat for each document index found
            foreach my $doc (@docno) {
                print "Reading $doc\n";

                # search for documents' length in doc_len file
                open DOC_LEN, "<".$self->{_doc_len_file} or die "Cannot open document length file\n";
                while (my $entry = <DOC_LEN>) {
                    my ($doc_idx, $doc_length) = split /\s+/, $entry;
                    if ($doc_idx eq $doc) {
                        # print "Get length of $doc : $doc_length\n";
                        $doc_len{$doc} = $doc_length;
                    }
                }
                close DOC_LEN;

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
                            $word = $stemmer->stemword($word);

                            # if the token found in text article, count the occurences
                            if ($word eq $token) {
                                if (exists $prob{$doc}{$token}) {
                                    $prob{$doc}{$token}++;
                                } else {
                                    $prob{$doc}{$token} = 1;
                                }
                            }                        
                        }
                    }
                }
            }
        }
    }

    my %document_prob;          # for storing the result of calculating ULM
    my %collection_freq;        # for storing collection frequency of terms
    my $total_token = $self->{_total_word}; # storing total tokens in collection

    open VOCAB, "<".$self->{_vocabulary} or die "Cannot open vocabulary file";
    while (<VOCAB>) {
        # search for collection frequency value in vocabulary file
        my ($token, $colfreq, $docfreq) = split /\s+/, $_;
        $collection_freq{$token} = $colfreq;
    }
    close VOCAB;

    # calculate the probability of each document
    foreach my $doc (keys %prob) {
        $document_prob{$doc} = 1;                   # because probability of each documents are equal, we started with one
        foreach my $token (keys %{$prob{$doc}}) {
            # multiply each calculation with previous calculation's result
            $document_prob{$doc} *= ((1-$lambda)*($prob{$doc}{$token}/$doc_len{$doc})) + ($lambda*($collection_freq{$token}/$total_token));
        }
    }

    return %document_prob;
}