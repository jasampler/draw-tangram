#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;

# Draw Tangram - Copyright 2014 Carlos Rica Espinosa
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details: http://www.gnu.org/licenses/
#
# Help and code for the program: http://github.com/jasampler/draw-tangram/

my $VERSION = '1.1';

my $PI_P4 = atan2(1, 1); #PI/4 rad (45 grad)
my $SQRT2 = sqrt(2); #hypotenuse
my $DECIMALS = 3;
my $MARGIN = 0.5;
my $DEFAULT_MULTIPLIER = 100;
my $DEFAULT_NAME_OFFSET = 5;

my $STYLE_LINES = 'LINES';
my $STYLE_FILLED = 'FILLED';
my $STYLE_SEPARATED = 'SEPARATED';

my %DEFAULT_PARAMS = (
	'inc_ang'    => 0,
	'multiplier' => 1,
	'start_x'    => 0,
	'start_y'    => 0,
	'flip'       => 0,
);

my %DEFAULT_CONFIG = (
	'multiplier' => $DEFAULT_MULTIPLIER,
	'background' => 1,
	'names'      => 0,
);

my $CLASS_PIECE = 'pc';
my $CLASS_NAME = 'nm';
my $CLASS_BACKGROUND = 'bg';

my $DEF_PC_COL = 'black';
my $DEF_NM_COL = 'red';
my $DEF_BG_COL = 'white';

my %DEFAULT_STYLE_PIECES = ( #polygon
	$STYLE_LINES => 'stroke-linejoin:round;' .
		" stroke:$DEF_PC_COL; stroke-width:3px; fill:none;",
	$STYLE_FILLED => 'stroke-linejoin:round;' .
		" stroke:$DEF_PC_COL; stroke-width:1px; fill:$DEF_PC_COL;",
	$STYLE_SEPARATED => 'stroke-linejoin:round;' .
		" stroke:$DEF_BG_COL; stroke-width:5px; fill:$DEF_PC_COL;",
);

my $DEFAULT_STYLE_BACKGROUND = "fill:$DEF_BG_COL; stroke:$DEF_BG_COL;" .
		' stroke-width:2px;'; #rect
my $DEFAULT_STYLE_NAMES = "font-size:36px; fill:$DEF_NM_COL;"; #text

process_input();

sub process_input {
	my %args;
	getopt('bnfrstm', \%args);
	if (@ARGV == 0) {
		print_help();
		return;
	}
	my $file = shift @ARGV;
	my %config;
	if (exists $args{'f'}) {
		$config{'flip'} = !is_false(lc($args{'f'}));
	}
	if (exists $args{'r'}) {
		$config{'inc_ang'} = +$args{'r'};
	}
	if (exists $args{'m'}) {
		$config{'multiplier'} = +$args{'m'};
	}
	if (exists $args{'s'}) {
		my $style = $args{'s'};
		if (exists $DEFAULT_STYLE_PIECES{$style}) {
			$style = compose_style($style);
		}
		$config{'style'} =  "\n" . $style . "\n";
	}
	elsif (exists $args{'t'}) {
		$config{'style'} = read_style_file($args{'t'});
	}
	if (!exists $config{'style'}) { #default style:
		my $style = compose_style($STYLE_LINES);
		$config{'style'} =  "\n" . $style . "\n";
		$config{'background'} = 1;
		$config{'names'} = 1;
	}
	if (exists $args{'b'}) {
		$config{'background'} = !is_false(lc($args{'b'}));
	}
	if (exists $args{'n'}) {
		$config{'names'} = !is_false(lc($args{'n'}));
	}
	my $fh;
	if ($file eq '-') {
		$fh = *STDIN;
	}
	else {
		open($fh, "<", $file) or die "Can't open file: '$file': $!";
	}
	my (@pieces, @hidden_edges, $err_str);
	my $n = 0;
	while (<$fh>) {
		chomp;
		my $orig_line = $_;
		my $line = $_;
		$n++;
		$line =~ s/^\s*//;
		my @pieces_line = parse_line($line, \$err_str);
		if ($err_str) {
			close($fh) if ($file ne '-');
			print STDERR "error: line $n: $err_str: $orig_line\n";
			return;
		}
		for my $piece (@pieces_line) {
			if (circular_vertices($piece)) {
				push @pieces, $piece;
			}
			else {
				push @hidden_edges, @$piece;
			}
		}
	}
	close($fh) if ($file ne '-');
	my %fig = ('hidden_edges'=>\@hidden_edges, 'pieces'=>\@pieces);
	print_figure(\%fig, \%config);
}

sub prn {
	print STDERR $_[0], "\n";
}

sub print_help {
	my $s = "            ";
	prn("Usage: $0 [OPTION] [TEXT_FILE]");
	prn("");
	prn("Reads a TEXT_FILE describing a Tangram figure and");
	prn("generates its graphical representation in SVG format.");
	prn("Additional help in: http://github.com/jasampler/draw-tangram/");
	prn("");
	prn("  -b YESNO  Adds or removes the background.");
	prn("  -n YESNO  Adds or removes the names of the vertices.");
	prn($s."YESNO can be YES or NO to enable or disable the feature.");
	prn("  -f YESNO  If YES, flips the figure horizontally.");
	prn("  -r ANGLE  Rotates the figure by an ANGLE.");
	prn($s."The ANGLE must be a number that will be multiplied by PI/4.");
	prn("  -s STYLE  Defines the style block of the SVG file.");
	prn($s."STYLE can be one of the predefined styles $STYLE_LINES,");
	prn($s."$STYLE_FILLED or $STYLE_SEPARATED, " .
		"or can be all styles in one line.");
	prn($s."The default STYLE is $STYLE_LINES with background and names.");
	prn("  -t FILE   Replaces the style block with the contents of");
	prn($s."the file FILE. If the FILE contains an <style> tag, then");
	prn($s."it will only put that block, to get it from other SVG.");
	prn("  -m VALUE  Sets the multiplier of the unit of length.");
	prn($s."By default is 100 and predefined styles are chosen for it,");
	prn($s."so the style should be changed when setting this value.");
}

sub read_style_file {
	my $file = shift;
	open(my $fh, "<", $file) or die "Can't open file: '$file': $!";
	my $style = do { local $/; <$fh> };
	close($fh);
	if ($style =~ m/<style\b[^>]*>/) {
		$style = substr($style, $+[0]);
	}
	if ($style =~ m/<\/style>/) {
		$style = substr($style, 0, $-[0]);
	}
	return $style;
}

sub circular_vertices {
	my $edges = shift;
	if (@$edges > 1) {
		my $first = $$edges[0];
		my $last = $$edges[@$edges - 1];
		if ($$first{'ini'} eq $$last{'end'}) {
			return 1;
		}
	}
	return 0;
}

sub calc_rational {
	my ($num, $den, $r_err) = @_;
	$num = +$num;
	if ($den ne '') { #denominator can be empty
		$den = +$den;
		if ($den == 0) {
			$$r_err = 'division by zero';
		}
		else {
			$num /= $den;
		}
	}
	return $num;
}

sub parse_line {
	my ($line, $r_err) = @_;
	$$r_err = '';
	my @pieces;
	while (length($line) > 0) {
		last if ($line =~ m/^\#/);
		my @edges;
		my $inc = 0;
		my $rat = qr/\s*([-+]?[0-9]+)\/?([0-9]*)\s*/;
		if ($line =~ s/^\<$rat\>\s*//) {
			$inc = calc_rational($1, $2, $r_err);
			return () if ($$r_err);
		}
		if ($line =~ m/^\w+(\s*-\s*\w+)+\s*\<$rat(,$rat)*\>\s*
				\[$rat(:$rat)?(,$rat(:$rat)?)*\]\s*;/x) {
			$line =~ s/([^\<]*)\<([^\>]*)\>\s*\[([^\]]*)\]\s*;\s*//;
			my ($v1, $v2, $v3) = ($1, $2, $3);
			$v1 =~ s/\s//g;
			my @vertices = split m/-/, $v1;
			my @angles = split m/,/, $v2;
			my @lengths = split m/,/, $v3;
			my $n = @vertices - 1;
			if ($n != @angles) {
				$$r_err = "number of angles differ from $n";
				return ();
			}
			if ($n != @lengths) {
				$$r_err = "number of lengths differ from $n";
				return ();
			}
			my @edges;
			for (my $i = 0; $i < $n; $i++) {
				$angles[$i] =~ m/^$rat/;
				my ($a1, $a2) = ($1, $2);
				my $ang = calc_rational($a1, $a2, $r_err);
				return () if ($$r_err);
				if ($lengths[$i] !~ m/^$rat:$rat/) {
					$lengths[$i] .= ':0';
				}
				$lengths[$i] =~ m/^$rat:$rat/;
				my ($n1, $n2, $s1, $s2) = ($1, $2, $3, $4);
				my $len = calc_rational($n1, $n2, $r_err);
				return () if ($$r_err);
				my $sqr = calc_rational($s1, $s2, $r_err);
				push @edges, {
					'ini' => $vertices[$i],
					'end' => $vertices[$i + 1],
					'ang' => $ang + $inc,
					'len' => [$len, $sqr]
				};
			}
			push @pieces, \@edges;
		}
		elsif ($line =~ m/^\w+\s*(\[$rat,$rat(:$rat)?\]\s*\w+\s*)+;/) {
			$line =~ s/^(\w+)\s*([^;]*);\s*//;
			my ($prev, $rest) = ($1, $2);
			while (length($rest) > 0) {
				my ($a1, $a2, $n1, $n2, $s1, $s2, $end);
				if ($rest =~ s /^\[$rat,$rat\]\s*(\w+)\s*//) {
					($a1, $a2, $n1, $n2, $s1, $s2, $end) =
						($1, $2, $3, $4, '0', '', $5);
				}
				elsif ($rest =~
					s/^\[$rat,$rat:$rat\]\s*(\w+)\s*//) {
					($a1, $a2, $n1, $n2, $s1, $s2, $end) =
						($1, $2, $3, $4, $5, $6, $7);
				}
				my $ang = calc_rational($a1, $a2, $r_err);
				return () if ($$r_err);
				my $len = calc_rational($n1, $n2, $r_err);
				return () if ($$r_err);
				my $sqr = calc_rational($s1, $s2, $r_err);
				return () if ($$r_err);
				push @edges, {
					'ini' => $prev,
					'end' => $end,
					'ang' => $ang + $inc,
					'len' => [$len, $sqr]
				};
				$prev = $end;
			}
			push @pieces, \@edges;
		}
		else {
			$$r_err = 'piece syntax';
			return ();
		}
	}
	return @pieces;
}

sub is_false {
	my $val = shift;
	return (!defined($val)) || (!$val) || $val eq 'false' || $val eq 'no';
}

sub print_figure {
	my ($fig, $config_param) = @_;
	my %config = %DEFAULT_CONFIG;
	for my $key (keys %$config_param) {
		$config{$key} = $$config_param{$key};
	}
	my %params = %DEFAULT_PARAMS;
	if (exists $config{'inc_ang'}) {
		$params{'inc_ang'} = $config{'inc_ang'};
	}
	if ($config{'flip'}) {
		$params{'flip'} = 1;
	}
	my %dimensions;
	my %positions;
	calc_positions($fig, \%params, \%positions, \%dimensions);
	#calculate width, height, start_x and start_y from dimensions:
	my $width =  fmt_val(($dimensions{'max_x'} - $dimensions{'min_x'} +
			2 * $MARGIN) * $config{'multiplier'});
	my $height = fmt_val(($dimensions{'max_y'} - $dimensions{'min_y'} +
			2 * $MARGIN) * $config{'multiplier'});
	$params{'start_x'} = -$dimensions{'min_x'} + $MARGIN;
	$params{'start_y'} = -$dimensions{'min_y'} + $MARGIN;
	$params{'multiplier'} = $config{'multiplier'};
	%positions = ();
	calc_positions($fig, \%params, \%positions);
	print '<?xml version="1.0" standalone="no"?>', "\n";
	print '<svg version="1.1" xmlns="http://www.w3.org/2000/svg"', "\n" .
		" width=\"$width\" height=\"$height\">", "\n";
	print "<style type=\"text/css\">", $config{'style'}, "</style>\n";
	if ($config{'background'}) {
		print "<rect class=\"$CLASS_BACKGROUND\" x=\"0\" y=\"0\"" .
			" width=\"100%\" height=\"100%\" />\n";
	}
	print_pieces($$fig{'pieces'}, \%positions);
	if ($config{'names'}) {
		my $default_div = $DEFAULT_MULTIPLIER / $DEFAULT_NAME_OFFSET;
		print_names(\%positions, $params{'multiplier'} / $default_div);
	}
	print "</svg>\n";
}

sub compose_style {
	my $type = shift;
	my $style =  ".$CLASS_PIECE {$DEFAULT_STYLE_PIECES{$type}}";
	$style .= " .$CLASS_NAME {$DEFAULT_STYLE_NAMES}";
	$style .= " .$CLASS_BACKGROUND {$DEFAULT_STYLE_BACKGROUND}";
	return $style;
}

sub print_names {
	my ($positions, $offset) = @_;
	for my $name (sort(keys %$positions)) {
		my $pos = $$positions{$name};
		my $pos_x = fmt_val($$pos{'x'} + $offset);
		my $pos_y = fmt_val($$pos{'y'} - $offset);
		print "<text class=\"$CLASS_NAME\"" .
			" x=\"$pos_x\" y=\"$pos_y\">$name</text>\n";
	}
}

sub print_pieces {
	my ($pieces, $positions) = @_;
	for (my $p = 0; $p < @$pieces; $p++) {
		my $piece = $$pieces[$p];
		my @piece_edges;
		for (my $e = 0; $e < @$piece; $e++) {
			my $edge = $$piece[$e];
			push @piece_edges, $edge;
		}
		print_piece(\@piece_edges, $positions);
	}
}

sub calc_positions {
	my ($fig, $params, $positions, $dimensions) = @_;
	my $hidden_edges = $$fig{'hidden_edges'};
	my $pieces = $$fig{'pieces'};
	for (my $p = 0; $p < @$pieces; $p++) {
		my $piece = $$pieces[$p];
		for (my $e = 0; $e < @$piece; $e++) {
			my $edge = $$piece[$e];
			if ($p == 0 && $e == 0) {
				my $mult = $$params{'multiplier'};
				$$positions{$$edge{'ini'}} = {
					'x'=>$mult * $$params{'start_x'},
					'y'=>$mult * $$params{'start_y'},
				};
			}
			if (calc_edge_positions($edge, $hidden_edges,
					$params, $positions)) {
				if (defined($dimensions)) {
					my $pos = $$positions{$$edge{'ini'}};
					update_dimensions($pos, $dimensions);
					$pos = $$positions{$$edge{'end'}};
					update_dimensions($pos, $dimensions);
				}
			}
		}
	}
}

sub update_dimensions {
	my ($pos, $dimensions) = @_;
	if (!defined $$dimensions{'max_x'}) {
		$$dimensions{'max_x'} = $$pos{'x'};
		$$dimensions{'max_y'} = $$pos{'y'};
		$$dimensions{'min_x'} = $$pos{'x'};
		$$dimensions{'min_y'} = $$pos{'y'};
		return;
	}
	if ($$pos{'x'} > $$dimensions{'max_x'}) {
		$$dimensions{'max_x'} = $$pos{'x'};
	}
	if ($$pos{'y'} > $$dimensions{'max_y'}) {
		$$dimensions{'max_y'} = $$pos{'y'};
	}
	if ($$pos{'x'} < $$dimensions{'min_x'}) {
		$$dimensions{'min_x'} = $$pos{'x'};
	}
	if ($$pos{'y'} < $$dimensions{'min_y'}) {
		$$dimensions{'min_y'} = $$pos{'y'};
	}
}

sub print_piece {
	my ($piece_edges, $positions) = @_;
	if (@$piece_edges == 0) { return; }
	my @verts;
	for (my $e = 0; $e < @$piece_edges; $e++) {
		my $edge = $$piece_edges[$e];
		my $ini = $$edge{'ini'};
		my $end = $$edge{'end'};
		if (@verts == 0) {
			push @verts, $ini, $end;
		}
		elsif ($ini eq $verts[@verts - 1]) { push @verts, $end; }
		elsif ($end eq $verts[@verts - 1]) { push @verts, $ini; }
		elsif ($ini eq $verts[0]) { unshift @verts, $end; }
		elsif ($end eq $verts[0]) { unshift @verts, $ini; }
		else {
			print STDERR "unimplemented: unchained edge " .
					"$ini-$end\n";
		}
	}
	my $points = '';
	for (my $v = 1; $v < @verts; $v++) {
		my $pos = $$positions{$verts[$v]};
		$points .= ' ' if ($v > 1);
		$points .= fmt_val($$pos{'x'}) . ',' . fmt_val($$pos{'y'});
	}
	print "<polygon class=\"$CLASS_PIECE\" points=\"$points\" />\n";
}

sub fmt_val {
	return sprintf('%.' . $DECIMALS . 'f', shift);
}

sub find_vert {
	my ($hidden_edges, $positions, $params) = @_;
	if (!defined $hidden_edges) { return; }
	for (my $e = 0; $e < @$hidden_edges; $e++) {
		my $edge = $$hidden_edges[$e];
		my $ini = $$edge{'ini'};
		my $end = $$edge{'end'};
		if (exists($$positions{$ini}) && !exists($$positions{$end})) {
			$$positions{$end} = get_vert_pos($edge,
					$$positions{$ini}, $params);
		}
		elsif (exists($$positions{$end}) && !exists($$positions{$ini})){
			$$positions{$ini} = get_vert_pos($edge,
					$$positions{$end}, $params, 'REVERSE');
		}
	}
}

sub calc_edge_positions {
	my ($edge, $hidden_edges, $params, $positions) = @_;
	my $ini = $$edge{'ini'};
	my $end = $$edge{'end'};
	if ((!exists($$positions{$ini})) && (!exists($$positions{$end}))) {
		find_vert($hidden_edges, $positions, $params);
	}
	if ((!exists($$positions{$ini})) && (!exists($$positions{$end}))) {
		print STDERR "ERROR: unable to make edge $ini-$end\n";
		return 0;
	}
	if (!exists($$positions{$end})) {
		$$positions{$end} = get_vert_pos($edge, $$positions{$ini},
						$params);
	}
	elsif (!exists($$positions{$ini})) {
		$$positions{$ini} = get_vert_pos($edge, $$positions{$end},
						$params, 'REVERSE');
	}
	return 1;
}

sub get_length {
	my $len = shift;
	return $$len[0] + $$len[1] * $SQRT2;
}

sub get_vert_pos {
	my ($edge, $ini_pos, $params, $reverse) = @_;
	my $ang = $$edge{'ang'} + $$params{'inc_ang'};
	if ($$params{'flip'}) {
		$ang = -$ang + 4; #horizontal flip
	}
	$ang = -$PI_P4 * $ang;
	my $dx = cos($ang);
	my $dy = sin($ang);
	my $total_len = $$params{'multiplier'} * get_length($$edge{'len'});
	if (defined $reverse) {
		$total_len = -$total_len;
	}
	return {
		'x'=>$$ini_pos{'x'} + $dx * $total_len,
		'y'=>$$ini_pos{'y'} + $dy * $total_len,
	};
}

