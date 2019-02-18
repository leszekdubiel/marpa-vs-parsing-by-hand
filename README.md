

# Marpa vs parsing by hand

The problem was to parse such a simple language described here: 

https://github.com/leszekdubiel/lists-and-trees

I have prepaired Marpa grammar and simple perl program. 

When fed with 3MB file Marpa runs 8 seconds, while handcrafted solution with regexes in perl5 takes 1 seconds. 

There is another comparison discussed here: http://blogs.perl.org/users/jeffrey_kegler/2011/11/marpa-v-perl-regexes-some-numbers.html . 


