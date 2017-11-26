# Retrieval Model (in Perl)

This is a repository for Perl code implementing
* Vector Space Model (both using TF and TF-IDF)
* Unigram Language Model

File required :
* Collection file, in XML format with multiple root tag, eg.:
```{xml}
<DOC>
    <TITLE> ... </TITLE>
    <DOCNO> ... </DOCNO>
    ...
</DOC>

<DOC>
    <TITLE> ... </TITLE>
    <DOCNO> ... </DOCNO>
    ...
</DOC>
...
```
* Query file, with format of (accepting user input as query TBD) :
```
query_code      query
```
* Relevance judgement file (based from query given), with format :
```
query_code      document_no
```

After retrieving documents using the model, the result will be evaluated using 3 measures : Accuracy, Recall, Mean Average Precision (MAP), by using relevance judgement file.

### Drawbacks
There are problem in reading special characters during parsing and tokenization (reason unknown, but the usage of XML library for parsing assumed to be the main cause)
