#!/bin/bash 

for TEST in data_huge.txt data_more.txt data_medi.txt data_tiny.txt; do 
	for PROG in parse_by_hand.pl parse_by_marpa.pl; do 
		printf "\n\n\n\ntest file \"$TEST\", program \"$PROG\" \n\n" 
		printf "file size: %s\n" "$(du -s -h "$TEST")"
		printf "timing:\n" 
		time cat "$TEST" | ./"$PROG" >/dev/null
	done
done


