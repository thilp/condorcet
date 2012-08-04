# RP Condorcet

## Introduction

### What is the RP Condorcet method?

The ranked pairs (RP) Condorcet method is a voting system that, given a
set of preferences ballots, produces a sorted list of winners. It
guarantees that each winner is the candidate that was prefered, in a
pair-confrontation, to all those ranked lower. This method has been
created by Nicolaus Tideman in 1987.

> "If there is a candidate who is preferred over the other candidates,
when compared in turn with each of the others, RP guarantees that
candidate will win." [1]

Compared to the basic Condorcet method, RP always produces an answer
because it is not paralysed by the tricky case known as the voting
paradox [2].

### What is this script?

Given a file (formatted as described below), this script computes the RP
Condorcet method on the corresponding vote and produces a sorted list of
the winners of this vote. Ties are supported.

The script was created and tested using [3], and it follows perfectly
its behavior with all the examples, simple to complex, that were tested.

## Usage

### Script call

The script displays its usage when called without any argument.

To compute the result of a vote with the RP Condorcet method, just give
a file name as an argument to the script:

    $> ./rpcondorcet.pl FILENAME

You can enable the _verbose mode_ by adding the `-v` option:

    $> ./rpcondorcet.pl -v FILENAME

### File format

Here is an example of a file used by the script:

    # A := Albert
    # J := John
    
    40: A > J > S
    S=J>A
    35:J>S>A
    # S := Seiko
    25:S > A = J

The file describing a vote which we want to evaluate with this script
must follow this rule: __each of its line must be of one of the
following types:__

1. __EMPTY LINE__: this line is only composed of blanks (possibly spaces
   and tabulations, and a _end-of-line_ character).
2. __BALLOT LINE__: `[<NUM>:] <ID> {<SEP> <ID>}*`, where:
    * `[X]` means that `X` is optionnal,
    * `{X}*` means that `X` can be repeated zero or more times,
    * `<NUM>` represents the number of ballots of the described kind,
    * `<ID>` is an __identifier__, that is a sequence of one or more
    characters delimited by spaces, tabulations, end-of-line or `<SEP>`,
    * `<SEP>` is a __separator__ and is either ">" or "=". For instance,
    "X > Y" means that X is prefered to Y, and "X = Y" means that X and
    Y are equally evaluated by the voter.
3. __ALIAS LINE__: `# <ID> := <SENTENCE>`, where `<ID>` is the name used
   in the ballot lines and `<SENTENCE>` is any sequence of characters
   ended by a _end-of-line_ character.

An __alias line__ is used by the script when displaying the result of the
vote: it replace the `<ID>` by the `<SENTENCE>` everywhere it has to be
printed. This way, one can easily write a ballot file with simple, short
`<ID>`s, and get back a comfortable, complete display of the result. If
more than one alias line exists for the same `<ID>`, only the last one
will be used.

__The blank characters are mainly ignored__, except in a `<SENTENCE>`, so
that you can write your vote file in a clear, human-readable way.

## References
* [1]: [Ranked Pairs on Wikipedia](https://en.wikipedia.org/wiki/Ranked_Pairs)
* [2]: [Voting paradox on Wikipedia](https://en.wikipedia.org/wiki/Voting_paradox)
* [3]: [Voting calculator of Eric Gorr](http://condorcet.ericgorr.net)
