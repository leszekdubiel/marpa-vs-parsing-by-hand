#!/usr/bin/perl -CSDA

use utf8; 
use strict; 
use Modern::Perl qw{2017}; 
no warnings qw{uninitialized numeric}; 
no autovivification qw{fetch store exists delete}; 
use Carp; 
use Data::Dumper; 
use Config; 
use Scalar::Util qw{looks_like_number}; 
use POSIX qw{strftime mktime}; 
use Time::Local; 
use Digest::MD5 qw{md5}; 
use Encode; 

# Liczby powinny być typu "double", czyli mieć 15 znaczących cyfr. Zatem najmniejszą liczbą jaką
# można zaprezentować jest "0.00000000000001", a największą "99999999999999.5". Liczby piszemy zawsze
# ze znakiem (nie dotyczy zera) oraz częścią dziesiętną.

$Config{uselongdouble} and croak "niekompatybilny format liczb w perlu, używa longdouble zamiast double"; 
$Config{doublesize} == 8 or croak "niekompatybilny format liczb w perlu, używa innych niż 8-bajtowych double"; 

sub numb_extr { 
	my ($a) = @_; 
	ref $a eq 'SCALAR' or croak "nieprawidłowa referencja"; 
	$$a =~ /\G(?:\s++|#.*+)*+([-+]?\d*(\.\d*)?)/gc or croak "liczba była spodziewana " . cite(substr $$a, pos $$a, 240); 
	my $n = $1; 
	$n eq '0.0' and return 0; 
	$n =~ /\A[-+](?!0.0\z)(?=[1-9]|0\.)\d+\.\d+(?<=[.\d][1-9]|\.0)\z/ or croak "nieprawidłowa liczba " . cite(substr $n, 0, 240) . " " . cite(substr $$a, pos $$a, 240); 
	length $n <= 15 + 2 or croak "za długa liczba " . cite(substr $n, 0, 240) . " " . cite(substr $$a, pos $$a, 240); 
	$n = 0 + $n; 
	#        1234567890.12345
	abs $n > 99999999999999.9 and croak "liczba spoza zakresu " . cite(substr $n, 0, 240) . " " . cite(substr $$a, pos $$a, 240); 
	return 0 + $n; 
}

sub numb_repr { 
	my ($n, $p) = @_; 
	looks_like_number $n or croak "nieprawidłowa liczba " . cite(substr $n, 0, 240); 
	$p =~ /\A(|[1-9][0-9]?)\z/ or croak "nieprawidłowa dokładność " . cite(substr $p, 0, 240); 
	#        1234567890.12345
	abs $n < 0.00000000000001 and return \"0.0"; 
	abs $n > 99999999999999.9 and croak "liczba spoza zakresu " . cite(substr $n, 0, 240); 
	my $k = index((sprintf '%+.15f', $n), '.'); 
	if ($p) { 
		$p <= 15 or croak "nieprawidłowa dokładność " . cite(substr $p, 0, 240); 
		$p = $k if $p < $k && abs $n >= 1; 
		$n = 0 + sprintf "%\+.*e", $p - 1, $n; 
	}
	my $a = sprintf '%+.*f', 15 + 1 - $k, $n; 
	$a =~ s/(\d)0+$/$1/; 
	$a =~ /\A[-+](?!0.0\z)(?=[1-9]|0\.)\d+\.\d+(?<=[.\d][1-9]|\.0)\z/ or croak "nieprawidłowa liczba " . cite(substr $a, 0, 240); 
	length $a <= 15 + 2 or croak "za długa liczba " . cite(substr $a, 0, 240); 
	return \$a; 
}


# Parametr jest parą nazwa-wartość. Nazwą jest dowolny ciąg znaków złożony z liter, cyfr i podkreśleń,
# przy czym podkreślenia nie mogą być sąsiednimi znakami, pierwszym znakiem musi być litera, a ostatnim
# nie może być podkreślenie. Wartością może być nazwa, liczba lub tekst. Tekst jest dowolnym ciągiem
# znaków umieszczonym między cudzysłowami, nie może zawierać znaków kontrolnych, sekwencje '\\', '\"', '\n',
# '\t' oznaczają odpowiednio ukośnik, cudzysłów, nową linię i tabulator.  Lista parametrów to ciąg par
# nazwa-wartość zamknięty między nawiasami. Przykład parametrów:
#
#	(
#		Order_Number "PN/123/90"
#		Order_Date (
#			Year "2009"
#			Month "12"
#			Day "24"
#		)
#		Client "Metron Tech"
#		Client_Data (
#			Name "Metron_Tech"
#			Address (
#				Country "Poland"
#				City "Krakow"
#				Street "Podhalanska 242s"
#				Post (
#					Code "34-700"
#					Name "Poczta Rabka"
#				)
#			)
#			TaxId "7223-1123-132"
#			Remarks "Other name could be \"Metron Technology\"..."
#		)
#	)

sub para_extr { 
	my ($a) = @_; 
	ref $a eq 'SCALAR' or croak "nieprawidłowa referencja"; 
	my %p; 
	$$a =~ /\G(?:\s++|#.*+)*+\(/gc or croak "nawias na początku parametrów był spodziewany " . cite(substr $$a, pos $$a, 240); 
	while ($$a =~ /\G(?:\s++|#.*+)*+([[:alpha:]](?:_?[[:alnum:]])*+)(?:\s++|#.*+)*+/gc) { 
		my $n = $1; 
		if ($$a =~ /\G([[:alpha:]](?:_?[[:alnum:]])*+|"(?:[^\\"[:cntrl:]]++|\\[\\"nt])*+")/gc) { 
			$p{$n} = $1; 
		} elsif ($$a =~ /\G(?=[-+.\d])/gc) { 
			$p{$n} = numb_extr($a); 
		} elsif ($$a =~ /\G(?=\()/gc) { 
			$p{$n} = para_extr($a); 
		} else { 
			croak "wartość parametru " . cite(substr $n, 0, 240) . " była spodziewana " . cite(substr $$a, pos $$a, 240); 
		}
	}
	$$a =~ /\G(?:\s++|#.*+)*+\)(?:\s++|#.*+)*+/gc or croak "nazwa parametru była spodziewana " . cite(substr $$a, pos $$a, 240); 

	# we wrześniu 2016 miałem dziwne kłopoty; programy "report.pl" dla historii wykonanych zadań czasami
	# się zawieszały i po czterech godzinach znikały z listy procesów -- zawieszały się jakby seriami;
	# doszło nawet do sytuacji, że firma alarmowała, że obciążenie serwera jest nienormalnie duże;
	# nie znalazłem rozwiązania, ale raczej coś z optymalizją stringów w perlu było źle, bo wywołanie
	# "list_extr"  dla "\"(\" . $inp . \")\"" trwało dziesięć razy dłużej niż "sprintf \"(%s)\", $inp";
	# szukałem przyczyny i skrypt zupełnie losowo się zacinał na kilka godzin, totalnie obciążając serwer;
	# udało mi się odtworzyć błąd -- przy pewnym tekście skrypt pracował 30 sekund, przy minimalnie
	# większym/mniejszym pół sekundy; szukałem rozwiązania tutaj: http://www.perlmonks.org/?node_id=1172994
	# ; odkryłem, że tylko na obecnej wersji Debiana tak działa, więc zgłosiłem błąd do samego Debiana
	# tutaj: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=839600 ; opiekun pakietu testował to i na
	# szczęście udało mu się odtworzyć błąd, zrobił minimalny program demonstracyjny i założył
	# błąd u twórców języka Perl: https://rt.perl.org/Public/Bug/Display.html?id=129802 ;
	
	# nie wiem jak obejść problem, więc jest to nieco prymitywne; mianowicie jeśli program liczy zbyt
	# długo, czyli wpada w wyżej opisany błąd, to wystarczy zmienić długość stringu o jeden bajt i
	# szybkość wraca do normy -- zatem jeśli działa zbyt długo, to dopisuję spację na koniec stringu;
	# przy dopisaniu czegokolwiek do stringu kasuje się "pos", więc go odtwarzam;
	state $t = time; 
	if (time > $t + 25) { 
		my $x = pos $$a; 
		$$a .= " "; 
		pos $$a = $x; 
		printf STDERR "powiększono tekst \"$a\" o spację, aby uniknąć spadku wydajności Perl\n"; 
		$t = time; 
	}
	time - $^T < 120 or croak "zbyt długi czas obliczeń"; 

	return \%p; 
}

sub para_repr { 
	my ($p) = @_; 
	ref $p eq 'HASH' or croak "nieprawidłowa referencja"; 
	my $t = "("; 
	for my $n (sort keys %$p) { 
		$n =~ /\A[[:alpha:]](?:_?[[:alnum:]])*\z/ or croak "nieprawidłowa nazwa parametru " . cite(substr $n, 0, 240); 
		if (ref $$p{$n} eq 'HASH') { 
			$t .= "$n ${para_repr($$p{$n})} "; 
		} elsif ($$p{$n} =~ /\A(?:[[:alpha:]](?:_?[[:alnum:]])*|"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*")\z/) { 
			$t .= "$n $$p{$n} "; 
		} elsif (looks_like_number $$p{$n}) { 
			$t .= "$n ${numb_repr($$p{$n})} "; 
		} else { 
			croak "nieprawidłowa wartość parametru " . cite(substr $n, 0, 240) . " " . cite(substr $$p{$n}, 0, 240); 
		}
	}
	$t =~ s/ $//; 
	return \"$t)"; 
}

# sprawdzanie czy dane są poprawne 
sub okay_numb { return looks_like_number $_[0] && abs $_[0] <= 99999999999999.9; }
sub okay_name { return $_[0] =~ /\A[[:alpha:]](?:_?[[:alnum:]])*\z/; }
sub okay_text { return $_[0] =~ /\A"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*"\z/; }
sub okay_data { 
	return ref $_[0] eq 'HASH'
		? okay_parm($_[0]) 
		: (($_[0] =~ /\A(?:[[:alpha:]](?:_?[[:alnum:]])*|"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*")\z/) 
			|| (looks_like_number $_[0] && abs $_[0] <= 99999999999999.9)) 
}
sub okay_parm { 
	ref $_[0] eq 'HASH' or croak "nieprawidłowa referencja"; 
	while (my ($k,$v) = each %{$_[0]}) { 
		$k =~ /\A[[:alpha:]](?:_?[[:alnum:]])*\z/ && okay_data($v) or return 0; 
	}
	return 1;
}



# Lista jest uporządkowanym ciągiem elementów, gdzie każdy element składa się z nazwy i parametrów. Przykład
# listy:
#
#	(
# 		Omni	(Qty -45.0 Who "Kowlaski Sp. z o.o" Anum +123.988732)
# 		Atos	(Qty -4.0)
# 		Pluton	(Znum 0.0 Qty -9.0 When "2009-12-31")
# 		Helios	(Qty -1.0)
#	)

sub list_extr { 
	my ($a) = @_; 
	ref $a eq 'SCALAR' or croak "nieprawidłowa referencja"; 
	my @l; 
	$$a =~ /\G(?:\s++|#.*+)*+\(/gc or croak "nawias na początku listy był spodziewany " . cite(substr $$a, pos $$a, 240); 
	while ($$a =~ /\G(?:\s++|#.*+)*+([[:alpha:]](?:_?[[:alnum:]])*)(?:\s++|#.*+)*+/gc) { 
		push @l, {name => $1, para => para_extr($a)}; 
	}
	$$a =~ /\G(?:\s++|#.*+)*+\)(?:\s++|#.*+)*+/gc or croak "nazwa elementu listy była spodziewana " . cite(substr $$a, pos $$a, 240); 
	return \@l; 
}

sub list_repr { 
	my ($l, $i) = @_; 
	ref $l eq 'ARRAY' or croak "nieprawidłowa referencja"; 
	my $t = "(\n"; 
	for my $e (@$l) { 
		$$e{name} =~ /\A[[:alpha:]](?:_?[[:alnum:]])*\z/ or croak "nieprawidłowa nazwa elementu listy " . cite(substr $$e{name}, 0, 240); 
		$t .= "$i\t$$e{name} ${para_repr($$e{para})}\n"; 
	} 
	return \"$t$i)\n"; 
}



# Drzewo składa się z ułożonych hierarchicznie węzłów. Każdy węzeł ma parametry i węzły podrzędne. Ta
# funkcja wczytuje listę drzew umieszczoną pomiędzy nawiasami. Przykład drzewa:
#
#	(
# 		A (Info "this is node A") (
# 			B (Info "This is node B, parent is A") (
# 			)
# 			C (Info "This is node C, has 3 children") (
# 				D (X +4.5 Y -5.0) (
# 				)
# 				E (X +4.9 Y -9.0) (
# 				)
# 				F (X +2.1 Y -12.0) (
# 				)
# 			)
# 			G (Info "This is child G of node A") (
# 			)
# 		)
# 		B (Info "This is node B") (
# 		)
# 		A (Info "this is another with name A") (
# 			X () (
# 			)
# 			Y () (
# 			)
# 		)	
# 	)

sub tree_extr { 
	my ($a) = @_; 
	ref $a eq 'SCALAR' or croak "nieprawidłowa referencja"; 
	my @t; 
	$$a =~ /\G(?:\s++|#.*+)*+\(/gc or croak "nawias na początku drzewa był spodziewany " . cite(substr $$a, pos $$a, 240); 
	while ($$a =~ /\G(?:\s++|#.*+)*+([[:alpha:]](?:_?[[:alnum:]])*)(?:\s++|#.*+)*+/gc) { 
		my $n = $1; # scope
		push @t, {name => $n, para => para_extr($a), chil => tree_extr($a)}; 
	}
	$$a =~ /\G(?:\s++|#.*+)*+\)(?:\s++|#.*+)*+/gc or croak "nazwa węzła drzewa była spodziewana " . cite(substr $$a, pos $$a, 240); 
	return \@t; 
}

sub tree_repr { 
	my ($t, $i) = @_; 
	ref $t eq 'ARRAY' or croak "nieprawidłowa referencja"; 
	my $a = "(\n"; 
	for my $n (@$t) { 
		$$n{name} =~ /\A[[:alpha:]](?:_?[[:alnum:]])*\z/ or croak "nieprawidłowa nazwa węzła drzewa " . cite(substr $$n{name}, 0, 240); 
		$a .= "$i\t$$n{name} ${para_repr($$n{para})} ${tree_repr($$n{chil}, \"\t$i\")}"; 
	} 
	return \"$a$i)\n"; 
}



# Cytowanie i odcytowanie tekstu; jeśli tekst jest niepoprawny (zawiera znaki specjalne, lub złe sekwencje z
# ukośnikiem), to wycinam cudzysłowy i początkowy fragment, który jest poprawny, zamieniam znaki niedrukowalne
# na krzyżyki, zgłaszam jako błąd.

sub cite { 
	my ($s) = @_; 
	$s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; $s =~ s/\n/\\n/g; $s =~ s/\t/\\t/g; 
	$s =~ s/\A/"/g; $s =~ s/\z/"/g; 
	if ($s !~ /\A"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*"\z/) { 
		$s =~ s/\A"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*//; $s =~ s/"\z//; 
		$s =~ s/[[:cntrl:]]/#/g; 
		croak "nieprawidłowy tekst \"" . (substr $s, 0, 240) . "\""; 
	}
	return $s; 
}
sub unci { 
	my ($s) = @_; 
	if ($s !~ /\A"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*"\z/) { 
		$s =~ s/\A"(?:[^\\"[:cntrl:]]+|\\[\\"nt])*//; $s =~ s/"\z//; 
		$s =~ s/[[:cntrl:]]/#/g; 
		croak "nieprawidłowy tekst \"" . (substr $s, 0, 240) . "\""; 
	}
	$s =~ s/\A"//; $s =~ s/"\z//; 
	$s =~ s/\\t/\t/g; $s =~ s/\\n/\n/g; $s =~ s/\\"/"/g; $s =~ s/\\\\/\\/g; 
	return $s; 
}

# INLINED PROGRAM TO READ AND WRITE 

my $t = do { local $/; <STDIN> }; 
defined $t or croak "nie można wczytać danych wejściowych " . cite($!); 
$t .= " "; chop $t; # Perl Bug 129802

print ${tree_repr(tree_extr(\$t))}; 


1; 

