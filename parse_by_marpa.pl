#!/usr/bin/perl -CSDA

use 5.010;
use strict;
use warnings;
use English qw( -no_match_vars );
use Marpa::R2 2.038000;
use Data::Dumper; 

my $grammar = Marpa::R2::Scanless::G->new(
    {   
        source          => \(<<'END_OF_SOURCE'),

:default ::= action => [ values ]

:start ::= tree


tree ::= '(' tree_elems ')' 
tree_elems ::= tree_elem* 
tree_elem ::= name para tree 


para ::= '(' para_elems ')'
para_elems ::= para_elem* 
para_elem ::= name valu 
valu ::= name | numb | text | para


numb ~ '0.0' | [-+] numb_more
numb_more ~ non_zero digits_any '.' digits_any non_zero 
numb_more ~ non_zero digits_any '.0'
numb_more ~ '0.' digits_any non_zero


name ~ letter name_elems
name_elems ~ name_elem* 
name_elem ~ alnum | '_' alnum 


digit ~ [0-9]
non_zero ~ [1-9]
digits_any ~ [0-9]*
letter ~ [[:alpha:]]
alnum ~ letter | digit 


text ~ '"' text_elems '"'
text_elems ~ text_elem* 
text_elem ~ [^"\\] | '\' ["\\tn] 

:discard ~ space
:discard ~ comment

comment ~ comment_terminated | comment_unterminated
comment_terminated ~ '#' comment_body space_vertical
comment_unterminated ~ '#' comment_body
comment_body ~ not_space_vertical*

space ~ [\s]+
space_vertical ~ [\x{a}\x{b}\x{c}\x{d}\x{2028}\x{2029}]
not_space_vertical ~ [^\x{a}\x{b}\x{c}\x{d}\x{2028}\x{2029}]

END_OF_SOURCE
    }
);

my $re = Marpa::R2::Scanless::R->new( { grammar => $grammar });

my $in = join "\n", <STDIN>; 

$re->read(\$in);
# print Dumper(${$re->value});



