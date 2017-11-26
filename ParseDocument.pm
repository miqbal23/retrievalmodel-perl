#!/usr/bin/perl 

package ParseDocument;

use 5.010;

use Stem;
my $stemmer = new Stem();

use XML::Simple;
my $parser = new XML::Simple;

# hashes for counting, keys are word itself, sorted by keys
my %vocab;      # hashes for vocabulary (and list of occurences)
my %colfreq;    # hashes for global term frequency (collection frequency)
my %docfreq;    # hashes for document frequency (number of docs where certain word exist)

# constructor
sub new {
    my $class = shift;
    my $self = {
        _vocabulary => "documents/vocabulary.txt",          # store collection frequency and document frequency
        _document_list => "documents/doclist.txt",          # store list of occurences for each token
        _doc_len => "documents/doc_len.txt"                 # store length of each documents
    };
    return bless $self, $class;
}

# method parseDoc, parse the document, generate document-list and vocabulary file
# args : 
#   $infile  : source of collections
#   $outfile : output file to store index
# return :
#   $count : total counted article processed
#   $total_token : total token recognized
sub parseDoc {
    my ($self, $input) = @_;
    
    # restructure document
    my @result = &restructureDocument($self, $input);
    print "Finished reading documents \n";

    my $count;
    my $total_token = 0;

    open DOC_LEN, ">".$self->{_doc_len} or die "Cannot open document_length file.\n";
    
    foreach my $string (@result) {
        my $data = $parser->XMLin($string);
        my $text = $data->{your_text_tag};          # change with document content tag
        my $docno = $data->{your_document_no_tag};  # change with document index no. tag
        $docno =~ s/ //g;
        
        my $doc_len = &tokenize($text, $docno);
        $total_token += $doc_len;
        print DOC_LEN "$docno\t$doc_len\n";
        $count++;
    }
    close DOC_LEN;

    print "Finished tokenizing collections\n";
    print "Finished printing document length in ".$self->{_doc_len}."\n";

    open VOCAB, ">".$self->{_vocabulary} or die "Cannot open vocabulary file.\n";
    open DOCNO_LIST, ">".$self->{_document_list} or die "Cannot open document_list file.\n";
    
    foreach my $token (sort (keys %vocab)) {
        print VOCAB "$token\t$colfreq{$token}\t$docfreq{$token}\n";
        print DOCNO_LIST "$token\t$vocab{$token}\n";
    }

    print "Finished printing ".$self->{_vocabulary}."\n";
    print "Finished printing ".$self->{_document_list}."\n";

    close VOCAB;
    close DOCNO_LIST;
    
    return ($count, $total_token);
}

# method for tokenizing collections
# return :
#   $doc_counter =  total token created from current document
sub tokenize {
    my ($string, $docno) = @_;
    my @this_doc_token = ();
    $string =~ tr/A-Z/a-z/;
    $string =~ s/["'\&\#\^\$\*\%]/ /g;

    my $doc_counter = 0;
    foreach my $word (split /[\+\?\.\(\)\[\]\{\}\|\\,\/\:\_\-\;\s+]/, $string) {
        $word = $stemmer->stemword($word);

        if (exists $colfreq{$word}) {
            $colfreq{$word}++;
        } else {
            $colfreq{$word} = 1;
        }

        if($word ~~ @this_doc_token) {
            next;
        } else {
            push @this_doc_token, $word;

            if (exists $docfreq{$word}) {
                $vocab{$word} = join("|", $vocab{$word}, $docno);
                $docfreq{$word}++;
            } else {
                $docfreq{$word} = 1;
                $vocab{$word} = $docno;
            }
        }

        $doc_counter++
    }
    return $doc_counter;
}

# method for re-structuring documents
# output : 
#   @array : document collection reshaped into array, each array equals to one document with one root tag
sub restructureDocument {
    my ($self, $infile) = @_;
    open XMLFILE, "<".$infile or die "Cannot open".$infile."\n";

    my $doc = "";
    my @array;

    while (my $line = <XMLFILE>) {
        chomp $line;
        $line =~ s/&/&amp;/g;
        if ($line =~ /<your_document_root_tag>/) { $doc = $line; }      # change with root tag 
        elsif ($line =~ /<\/your_document_root_tag>/) {                 # of your document
            $doc = $doc.$line;
            push @array, $doc;
        }
        else { $doc = $doc.$line; }
    }
    close XMLFILE;

    return @array;
}

# method to get the vocabulary filename
# return :
#   $vocabulary = reference of vocabulary file
sub getVocabFile {
    my ($self) = @_;
    return $self->{_vocabulary};
}

# method to get the document_list filename
# return :
#   $document_list = reference or document-list file
sub getDocNoFile {
    my ($self) = @_;
    return $self->{_document_list};
}

sub getDocLenFile {
    my ($self) = @_;
    return $self->{_doc_len};
}
1;