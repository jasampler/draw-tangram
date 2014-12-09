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

my $VERSION = '1.5';

my $PI_P4 = atan2(1, 1); #PI/4 rad (45 deg)
my $SQRT2 = sqrt(2); #hypotenuse
my $DECIMALS = 3;
my $MARGIN = 0.5;
my $DEFAULT_MULTIPLIER = 100;
my $DEFAULT_NAME_OFFSET = 5;

my $STYLE_LINES = 'LINES';
my $STYLE_FILLED = 'FILLED';
my $STYLE_SEPARATED = 'SEPARATED';

my %DEFAULT_CONFIG = (
	'inc_ang'    => calc_rational('0', ''),
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

my $RATIONAL_MASK = qr/\s*(-?[0-9]+)\/?([0-9]*)\s*/;

process_input();

sub process_input {
	my %args;
	my $ok = getopts('b:n:f:r:s:m:', \%args);
	if (!$ok || @ARGV == 0) {
		print_help();
		return;
	}
	my $config = process_config(%args);
	for my $file (@ARGV) {
		process_file($file, $config);
	}
}

sub print_err {
	print STDERR "error: " . $_[0] . "\n";
}

sub process_config {
	my %args = @_;
	my %config = %DEFAULT_CONFIG;
	if (exists $args{'f'}) {
		$config{'flip'} = !is_false(lc($args{'f'}));
	}
	if (exists $args{'r'}) {
		if ($args{'r'} =~ m/^$RATIONAL_MASK$/) {
			my $err_str = '';
			my $inc_ang = calc_rational($1, $2, \$err_str);
			if ($err_str) {
				print_err("not valid: $args{'r'}: $err_str");
			}
			else {
				$config{'inc_ang'} = $inc_ang;
			}
		}
		else {
			print_err("angle not in the format N/D: $args{'r'}");
		}
	}
	if (exists $args{'m'}) {
		if ($args{'m'} =~ m/^\d+$/) {
			$config{'multiplier'} = int($args{'m'});
		}
		else {
			print_err("multiplier not an integer: $args{'m'}");
		}
	}
	if (exists $args{'s'}) {
		my $style = $args{'s'};
		if (exists $DEFAULT_STYLE_PIECES{$style}) {
			$config{'style'} = compose_style($style);
		}
		else {
			$config{'style'} = read_style_file($style);
		}
	}
	else { #default style:
		$config{'style'} = compose_style($STYLE_LINES);
		$config{'background'} = 1;
		$config{'names'} = 1;
	}
	if (exists $args{'b'}) {
		$config{'background'} = !is_false(lc($args{'b'}));
	}
	if (exists $args{'n'}) {
		$config{'names'} = !is_false(lc($args{'n'}));
	}
	return \%config;
}

sub process_file {
	my ($file, $config) = @_;
	my $fh;
	if ($file eq '-') {
		$fh = *STDIN;
	}
	else {
		if ($file =~ m/\.svg$/i) {
			print_err("SVG input file: '$file'");
			return;
		}
		unless (open($fh, "<", $file)) {
			print_err("Can't open file: '$file': $!");
			return;
		}
	}
	my (@pieces, $err_str);
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
			print_err("$file: line $n: $err_str: $orig_line");
			return;
		}
		for my $piece (@pieces_line) {
			push @pieces, $piece;
		}
	}
	close($fh) if ($file ne '-');
	my $ofile = $file;
	if ($ofile eq '-') {
		$fh = *STDOUT;
	}
	else {
		if ($ofile !~ s/\.\w+$/.svg/) {
			$ofile .= '.svg';
		}
		unless (open($fh, ">", $ofile)) {
			print_err("Can't write file: '$ofile': $!");
			return;
		}
	}
	print $fh gen_figure_svg(\@pieces, $config);
	close($fh) if ($ofile ne '-');
}

sub print_help {
	my $SEPARATED = $STYLE_SEPARATED;
	my $MULTIPLIER = $DEFAULT_MULTIPLIER;
	print STDERR <<"EOF";
Usage: $0 [OPTIONS] TEXT_FILE ...

Reads a TEXT_FILE with instructions to draw a Tangram figure
and generates its graphical representation in SVG format.
Additional help in: http://github.com/jasampler/draw-tangram/

  -b YESNO  Adds or removes the background.
  -n YESNO  Adds or removes the names of the vertices.
            YESNO can be YES or NO to enable or disable the feature.
  -f YESNO  If YES, flips the figure horizontally.
  -r ANGLE  Rotates the figure by an ANGLE. The ANGLE must be a number or
            fraction that will be multiplied by PI/4 radians (45 degrees).
  -s STYLE  Defines the style block of the SVG file. STYLE can be one
            of the predefined styles $STYLE_LINES, $STYLE_FILLED or $SEPARATED,
            or a FILE containing the style code. If the FILE contains a
            <style> tag, like in other SVG, only this block will be used.
            The default STYLE is $STYLE_LINES with background and names.
  -m VALUE  Sets the multiplier of the unit of length.
            By default is $MULTIPLIER and predefined styles are chosen for it,
            so the style should be changed when setting this value.
EOF
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
	if ($den ne '') { #denominator can be empty
		if (+$den == 0) {
			$$r_err = 'division by zero';
			return {};
		}
	}
	else {
		$den = 1;
	}
	return {'num' => +$num, 'den' => +$den};
}

sub rational_to_num {
	my $rat = shift;
	return $$rat{'num'} / $$rat{'den'};
}

sub rational_to_str {
	my $rat = shift;
	return $$rat{'num'} . '/' . $$rat{'den'};
}

sub sum_rationals {
	my ($r1, $r2) = @_;
	my ($num, $den);
	if ($$r1{'den'} == $$r2{'den'}) {
		$num = $$r1{'num'} + $$r2{'num'};
		$den = $$r1{'den'};
	}
	else {
		$num = $$r1{'num'} * $$r2{'den'} + $$r2{'num'} * $$r1{'den'};
		$den = $$r1{'den'} * $$r2{'den'};
	}
	return {'num' => $num, 'den' => $den};
}

sub parse_line {
	my ($line, $r_err) = @_;
	$$r_err = '';
	my @pieces;
	my $rat = $RATIONAL_MASK;
	while (length($line) > 0) {
		last if ($line =~ m/^\#/);
		my @edges;
		my $piece_angle = calc_rational('0', '');
		my $relative = 0;
		if ($line =~ s/^\<$rat\>\s*//) {
			$piece_angle = calc_rational($1, $2, $r_err);
			return () if ($$r_err);
		}
		if ($line =~ m/^\w+(\s*-\s*\w+)+\s*\<\s*\@?$rat(,$rat)*\>\s*
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
			if ($angles[0] =~ s/^\s*\@//) {
				$relative = 1;
			}
			my $last_ang = calc_rational('0', '');
			for (my $i = 0; $i < $n; $i++) {
				$angles[$i] =~ m/^$rat/;
				my ($a1, $a2) = ($1, $2);
				my $ang = calc_rational($a1, $a2, $r_err);
				return () if ($$r_err);
				if ($relative) {
					$ang = sum_rationals($ang, $last_ang);
				}
				if ($lengths[$i] !~ m/^$rat:$rat/) {
					$lengths[$i] .= ':0';
				}
				$lengths[$i] =~ m/^$rat:$rat/;
				my ($n1, $n2, $s1, $s2) = ($1, $2, $3, $4);
				my $len = calc_rational($n1, $n2, $r_err);
				return () if ($$r_err);
				my $sqr = calc_rational($s1, $s2, $r_err);
				return () if ($$r_err);
				push @edges, {
					'ini' => $vertices[$i],
					'end' => $vertices[$i + 1],
					'ang' => $ang,
					'len' => [$len, $sqr]
				};
				$last_ang = $ang;
			}
		}
		elsif ($line =~ m/^\w+\s*\<\s*\@?$rat\>\s*
				\[$rat(:$rat)?\]\s*\w+\s*
				(\<$rat\>\s*\[$rat(:$rat)?\]\s*\w+\s*)*;/x) {
			$line =~ s/^(\w+)\s*//;
			my $prev = $1;
			if ($line =~ s/^\<\s*\@/\</) {
				$relative = 1;
			}
			my $last_ang = calc_rational('0', '');
			while ($line !~ m/^;/) {
				$line =~ s/^\<([^\>]*)\>\s*
					\[([^\]]*)\]\s*(\w+)\s*//x;
				my ($angle, $length, $end) = ($1, $2, $3);
				$angle =~ m/^$rat/;
				my ($a1, $a2) = ($1, $2);
				my $ang = calc_rational($a1, $a2, $r_err);
				return () if ($$r_err);
				if ($relative) {
					$ang = sum_rationals($ang, $last_ang);
				}
				if ($length !~ m/^$rat:$rat/) {
					$length .= ':0';
				}
				$length =~ m/^$rat:$rat/;
				my ($n1, $n2, $s1, $s2) = ($1, $2, $3, $4);
				my $len = calc_rational($n1, $n2, $r_err);
				return () if ($$r_err);
				my $sqr = calc_rational($s1, $s2, $r_err);
				return () if ($$r_err);
				push @edges, {
					'ini' => $prev,
					'end' => $end,
					'ang' => $ang,
					'len' => [$len, $sqr]
				};
				$prev = $end;
				$last_ang = $ang;
			}
			$line =~ s/^;\s*//;
		}
		else {
			$$r_err = 'piece syntax';
			return ();
		}
		push @pieces, {
			'piece_angle' => $piece_angle,
			'edges' => \@edges
		};
	}
	return @pieces;
}

sub is_false {
	my $val = shift;
	return (!defined($val)) || (!$val) || $val eq 'false' || $val eq 'no';
}

sub gen_figure_svg {
	my ($pieces, $params) = @_;
	my (%dimensions, %positions);
	calc_positions($pieces, $$params{'inc_ang'}, $$params{'flip'},
			\%positions, \%dimensions);
	#calculate width, height, start_x and start_y from dimensions:
	my $width =  fmt_val(($dimensions{'max_x'} - $dimensions{'min_x'} +
			2 * $MARGIN) * $$params{'multiplier'});
	my $height = fmt_val(($dimensions{'max_y'} - $dimensions{'min_y'} +
			2 * $MARGIN) * $$params{'multiplier'});
	$$params{'start_x'} = -$dimensions{'min_x'} + $MARGIN;
	$$params{'start_y'} = -$dimensions{'min_y'} + $MARGIN;
	my $svg = '<?xml version="1.0" standalone="no"?>' . "\n";
	$svg .= '<svg version="1.1" xmlns="http://www.w3.org/2000/svg"' . "\n" .
		" width=\"$width\" height=\"$height\">" . "\n";
	$svg .= "<style type=\"text/css\">" . $$params{'style'} . "</style>\n";
	if ($$params{'background'}) {
		$svg .= "<rect class=\"$CLASS_BACKGROUND\" x=\"0\" y=\"0\"" .
			" width=\"100%\" height=\"100%\" />\n";
	}
	$svg .= gen_pieces_svg($pieces, \%positions, $params);
	if ($$params{'names'}) {
		$svg .= gen_names_svg(\%positions, $params);
	}
	$svg .= "</svg>\n";
}

sub compose_style {
	my $type = shift;
	return "\n.$CLASS_PIECE {$DEFAULT_STYLE_PIECES{$type}}" .
		" .$CLASS_NAME {$DEFAULT_STYLE_NAMES}" .
		" .$CLASS_BACKGROUND {$DEFAULT_STYLE_BACKGROUND}\n";
}

sub gen_names_svg {
	my ($positions, $params) = @_;
	my $offset = $DEFAULT_NAME_OFFSET / $DEFAULT_MULTIPLIER;
	my $svg = '';
	for my $name (sort(keys %$positions)) {
		my $pos = $$positions{$name};
		my $pos_x = fmt_val($$params{'multiplier'} *
			($$params{'start_x'} + $$pos{'x'} + $offset));
		my $pos_y = fmt_val($$params{'multiplier'} *
			($$params{'start_y'} + $$pos{'y'} - $offset));
		$svg .= "<text class=\"$CLASS_NAME\"" .
			" x=\"$pos_x\" y=\"$pos_y\">$name</text>\n";
	}
	return $svg;
}

sub gen_pieces_svg {
	my ($pieces, $positions, $params) = @_;
	my $svg = '';
	for my $piece (@$pieces) {
		my $edges = $$piece{'edges'};
		if (circular_vertices($edges)) {
			$svg .= gen_piece_svg($edges, $positions, $params);
		}
	}
	return $svg;
}

sub calc_positions {
	my ($pieces, $inc_ang, $flip, $positions, $dimensions) = @_;
	for (my $p = 0; $p < @$pieces; $p++) {
		my $piece = $$pieces[$p];
		my $angle = sum_rationals($$piece{'piece_angle'}, $inc_ang);
		my $edges = $$piece{'edges'};
		for (my $e = 0; $e < @$edges; $e++) {
			my $edge = $$edges[$e];
			if ($p == 0 && $e == 0) {
				$$positions{$$edge{'ini'}} = {
					'x' => 0,
					'y' => 0,
				};
			}
			if (calc_edge_positions($edge, $angle, $flip,
						$positions)) {
				my $pos = $$positions{$$edge{'ini'}};
				update_dimensions($pos, $dimensions);
				$pos = $$positions{$$edge{'end'}};
				update_dimensions($pos, $dimensions);
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

sub gen_piece_svg {
	my ($piece_edges, $positions, $params) = @_;
	if (@$piece_edges == 0) { return; }
	my @verts;
	for my $edge (@$piece_edges) {
		my $ini = $$edge{'ini'};
		my $end = $$edge{'end'};
		if (@verts == 0) {
			push @verts, $ini;
		}
		push @verts, $end;
	}
	my $points = '';
	for (my $v = 1; $v < @verts; $v++) {
		my $pos = $$positions{$verts[$v]};
		$points .= ' ' if ($v > 1);
		$points .= fmt_pos($pos, $params);
	}
	return "<polygon class=\"$CLASS_PIECE\" points=\"$points\" />\n";
}

sub fmt_val {
	my $val = sprintf('%.' . $DECIMALS . 'f', shift);
	if ($val =~ m/^-0\.0+$/) {
		$val = substr($val, 1);
	}
	return $val;
}

sub calc_edge_positions {
	my ($edge, $angle, $flip, $positions) = @_;
	my $ini = $$edge{'ini'};
	my $end = $$edge{'end'};
	if (!exists $$positions{$ini}) {
		print STDERR "ERROR: unable to make edge $ini-$end\n";
		return 0;
	}
	my $pos = get_vert_pos($edge, $$positions{$ini}, $angle, $flip);
	if (!exists $$positions{$end}) {
		$$positions{$end} = $pos;
	}
	else {
		my $oldpos = fmt_pos($$positions{$end});
		my $newpos = fmt_pos($pos);
		if ($oldpos ne $newpos) {
			print STDERR "WARNING: $end position $newpos " .
				"in $ini-$end differs than previous $oldpos\n";
		}
	}
	return 1;
}

sub fmt_pos {
	my ($pos, $params) = @_;
	my $x = $$pos{'x'};
	my $y = $$pos{'y'};
	if ($params) {
		$x = $$params{'multiplier'} * ($$params{'start_x'} + $x);
		$y = $$params{'multiplier'} * ($$params{'start_y'} + $y);
	}
	return fmt_val($x) . ',' . fmt_val($y);
}

sub get_length {
	my $len = shift;
	return rational_to_num($$len[0]) + rational_to_num($$len[1]) * $SQRT2;
}

sub get_vert_pos {
	my ($edge, $ini_pos, $angle, $flip) = @_;
	my $ang = rational_to_num($$edge{'ang'}) + rational_to_num($angle);
	if ($flip) {
		$ang = -$ang + 4; #horizontal flip
	}
	$ang = -$PI_P4 * $ang;
	my $dx = cos($ang);
	my $dy = sin($ang);
	my $total_len = get_length($$edge{'len'});
	return {
		'x'=>$$ini_pos{'x'} + $dx * $total_len,
		'y'=>$$ini_pos{'y'} + $dy * $total_len,
	};
}

