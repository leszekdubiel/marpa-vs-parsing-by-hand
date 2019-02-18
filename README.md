

# Marpa vs parsing by hand

The problem was to parse such a simple language described here: 

https://github.com/leszekdubiel/lists-and-trees

There are two programs `parse_by_hand.pl` and `parse_by_marpa.pl`. In my tests Marpa runs 3 times slower than
regular expresssion. This is not bad escpecially that I don't use XS and there are some problem you wouldn't
be able to solve by regular expressions only. 

More to read: http://blogs.perl.org/users/jeffrey_kegler/2011/11/marpa-v-perl-regexes-some-numbers.html . 

Here is log from tests:    https://github.com/leszekdubiel/marpa-vs-parsing-by-hand/blob/master/log_from_tests.txt




