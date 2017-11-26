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
#   $query : string entry of the query
#   $lambda : lambda value of Unigram Language Model formula
# return :
#   %document_prob = result of retrieval, with document no. as hash key and the probability as value
sub search {
    my ($self, $line, $lambda) = @_;
    $line =~ tr/A-Z/a-z/;
    my @query = split /[\?\-\.\s+]/, $line;

    my @stemmed = ();
    foreach (@query) {
        my $stemmed_word = $stemmer->stemword($_);
        push @stemmed, $stemmed_word;
    }

    my %prob;
    my %doc_len;

    open OCCURFILE, "<".$self->{_docno_list} or die "Cannot open document list file\n";
    while (my $occur_entry = <OCCURFILE>) {
        my ($token, $doclist) = split /\s+/, $occur_entry;
        if ($token ~~ @stemmed) {
            my @docno = split (/\|/, $doclist);
            foreach my $doc (@docno) {
                print "Reading $doc\n";

                open DOC_LEN, "<".$self->{_doc_len_file} or die "Cannot open document length file\n";
                while (my $entry = <DOC_LEN>) {
                    my ($doc_idx, $doc_length) = split /\s+/, $entry;
                    if ($doc_idx eq $doc) {
                        $doc_len{$doc} = $doc_length;
                    }
                }
                close DOC_LEN;

                my @array = $parDoc->restructureDocument($self->{_collection});
                foreach my $string (@array) {
                    my $data = $xmlParser->XMLin($string);
                    if ($data->{NO} eq $doc) {
                        my $text = $data->{TEKS};
                        $text =~ tr/A-Z/a-z/;
                        $text =~ s/["'\&\#\^\$\*\%]/ /g;
                        
                        foreach my $word (split /[\+\?\.\(\)\[\]\{\}\|\\,\/\:\_\-\;\s+]/, $text) {                        
                            $word = $stemmer->stemword($word);

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

    my %document_prob;
    my %collection_freq;
    my $total_token = $self->{_total_word}; 

    open VOCAB, "<".$self->{_vocabulary} or die "Cannot open vocabulary file";
    while (<VOCAB>) {
        my ($token, $colfreq, $docfreq) = split /\s+/, $_;
        $collection_freq{$token} = $colfreq;
    }
    close VOCAB;

    foreach my $doc (keys %prob) {
        $document_prob{$doc} = 1;
        foreach my $token (keys %{$prob{$doc}}) {
            $document_prob{$doc} *= ((1-$lambda)*($prob{$doc}{$token}/$doc_len{$doc})) + ($lambda*($collection_freq{$token}/$total_token));
        }
    }

    return %document_prob;
}