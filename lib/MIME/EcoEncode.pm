package MIME::EcoEncode;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw($VERSION);
our @EXPORT = qw(mime_eco);
our $VERSION = '0.61';

use MIME::Base64;

use constant HEAD   => '=?UTF-8?B?';
use constant HEAD_J => '=?ISO-2022-JP?B?';
use constant TAIL   => '?=';

our $LF;  # line feed
our $BPL; # bytes per line

our $ADD_ENC_WORD;
our $REG_RP;

sub mime_eco {
    my $str = shift;
    my $charset = shift || 'UTF-8';

    our $LF  = shift || "\n"; # line feed
    our $BPL = shift || 76;   # bytes per line

    my $mode = shift;
    $mode = 2 unless defined $mode;
    my $lss = shift;
    $lss = 25 unless defined $lss;

    our $ADD_ENC_WORD;
    our $REG_RP;

    my $csn;
    my $pos;
    my $np;
    my $refsub;
    my $reg_rp1;

    my ($w1, $w1_len, $w2);
    my ($sps, $sps_len);
    my $sp1 = '';
    my $sp1_bak;
    my $result;
    my $ascii;
    my $tmp;
    my $count = 0;

    return '' unless defined $str;
    return $str if $str =~ /^\s*$/;

    if ($charset eq 'UTF-8') {
	$csn = 1;
    }
    elsif ($charset eq 'ISO-2022-JP') {
	$csn = 0;
    }
    else {
	return undef;
    }
    my ($trailing_crlf) = ($str =~ /(\n|\r|\x0d\x0a)$/o);

    $str =~ tr/\n\r//d;

    $str =~ /(\s*)(\S+)/gc;
    ($sps, $w2) = ($1, $2);

    if ($w2 =~ /[^21-\x7e]/) {
	$ascii = 0;
	$sps_len = length($sps);
	if ($sps_len > $lss) {
	    $result = substr($sps, 0, $lss);
	    $w1 = substr($sps, $lss) . $w2;
	    $pos = $lss;
	}
	else {
	    $result = $sps;
	    $w1 = $w2;
	    $pos = $sps_len;
	}
    }
    else {
	$ascii = 1;
	$result = '';
	$w1 = "$sps$w2";
	$pos = 0;
    }

    if ($mode == 2) {
	$mode = ($w1 =~ /^(?:Subject:|Comments:)$/i) ? 0 : 1;
    }
    if ($mode == 1) {
	$refsub = \&add_enc_word_sth;
	if ($csn == 1) {
	    $reg_rp1 = qr/\)\,?$/;
            $ADD_ENC_WORD = \&add_enc_word_utf8;
            $REG_RP = qr/(\){1,3}\,?)$/;
        }
        else {
	    $reg_rp1 = qr/\e\(B[\x21-\x7e]*\)\,?$/;
            $ADD_ENC_WORD = \&add_enc_word_7bit_jis;
            $REG_RP = qr/\e\(B[\x21-\x7e]*?(\){1,3}\,?)$/;
        }
    }
    else {
        $refsub = ($csn == 1) ?
            \&add_enc_word_utf8 : \&add_enc_word_7bit_jis;
    }

    while ($str =~ /(\s*)(\S+)/gc) {
	($sps, $w2) = ($1, $2);
	if ($w2 =~ /[^\x21-\x7e]/) {
	    $sps_len = length($sps);
	    if ($ascii) { # "ASCII \s+ non-ASCII"
		$sp1_bak = $sp1;
		$sp1 = chop($sps);
		$w1 .= $sps if $sps_len > $lss;
		$w1_len = length($w1);
		if ($count == 0) {
		    $result = $w1;
		    $pos = $w1_len;
		}
		else {
		    if (($count > 1) and ($pos + $w1_len + 1 > $BPL)) {
                        $result .= "$LF$sp1_bak$w1";
                        $pos = $w1_len + 1;
                    }
                    else {
                        $result .= "$sp1_bak$w1";
                        $pos += $w1_len + 1;
                    }
		}
		if ($sps_len <= $lss) {
		    if ($pos + $sps_len - 1 > $BPL) {
			$result .= substr($sps, 0, $BPL - $pos) . $LF
			    . substr($sps, $BPL - $pos);
			$pos += $sps_len - $BPL - 1;
		    }
		    else {
			$result .= $sps;
			$pos += $sps_len - 1;
		    }
		}
		$w1 = $w2;
	    }
	    else { # "non-ASCII \s+ non-ASCII"
		if (($mode == 1) and ($sps_len <= $lss)) {
		    if ($w1 =~ /$reg_rp1/ or $w2 =~ /^\(/) {
			if ($count == 0) {
			    $result .= &$refsub($w1, $pos, \$np, 0);
			}
			else {
			    $tmp = &$refsub($w1, 1 + $pos, \$np, 0);
			    $result .= ($tmp =~ s/^ /$sp1/) ?
				"$LF$tmp" : "$sp1$tmp";
			}
			$pos = $np;
			$sp1 = chop($sps);
			if ($pos + $sps_len - 1 > $BPL) {
			    $result .= substr($sps, 0, $BPL - $pos) . $LF
				. substr($sps, $BPL - $pos);
			    $pos += $sps_len - $BPL - 1;
			}
			else {
			    $result .= $sps;
			    $pos += $sps_len - 1;
			}
			$w1 = $w2;
		    }
		    else {
			$w1 .= "$sps$w2";
		    }
		}
		else {
		    $w1 .= "$sps$w2";
		}
	    }
	    $ascii = 0;
	}
	else { # "ASCII \s+ ASCII" or "non-ASCII \s+ ASCII"
	    $w1_len = length($w1);
	    if ($ascii) { # "ASCII \s+ ASCII"
		if ($count == 0) {
                    $result = $w1;
                    $pos = $w1_len;
                }
		else {
		    if (($count > 1) and ($pos + $w1_len + 1 > $BPL)) {
                        $result .= "$LF$sp1$w1";
                        $pos = $w1_len + 1;
                    }
                    else {
                        $result .= "$sp1$w1";
                        $pos += $w1_len + 1;
                    }
		}
	    }
	    else { # "non-ASCII \s+ ASCII"
		if ($count == 0) {
		    $result .= &$refsub($w1, $pos, \$np, 0);
                    $pos = $np;
                }
		else {
		    $tmp = &$refsub($w1, 1 + $pos, \$np, 0);
		    $result .= ($tmp =~ s/^ /$sp1/) ? "$LF$tmp" : "$sp1$tmp";
		    $pos = $np;
		}
	    }
	    $sps_len = length($sps);
	    if ($pos >= $BPL) {
		$sp1 = substr($sps, 0, 1);
		$w2 = substr($sps, 1) . $w2;
	    }
	    elsif ($pos + $sps_len - 1 > $BPL) {
		$result .= substr($sps, 0, $BPL - $pos);
		$sp1 = substr($sps, $BPL - $pos, 1);
		$w2 = substr($sps, $BPL - $pos + 1) . $w2;
		$pos = $BPL;
	    }
	    else {
		$sp1 = chop($sps);
		$result .= $sps;
		$pos += $sps_len - 1;
	    }
	    $w1 = $w2;
	    $ascii = 1;
	}
	$count++ if $count <= 1;
    }
    ($sps) = ($str =~ /(.*)/g); # All space of the remainder

    if ($ascii) {
	$w1 .= $sps;
	if ($count == 0) {
	    $result = $w1;
	}
	else {
	    $w1_len = length($w1);
	    if (($count > 1) and ($pos + $w1_len + 1 > $BPL)) {
		$result .= "$LF$sp1$w1";
	    }
	    else {
		$result .= "$sp1$w1";
	    }
	}
    }
    else {
	$sps_len = length($sps);
	if ($count == 0) {
	    if ($sps_len > $lss) {
		$w1 .= substr($sps, 0, $sps_len - $lss);
		$result .= &$refsub($w1, $pos, \$np, $lss) .
		    substr($sps, $sps_len - $lss);
	    }
	    else {
		$result .= &$refsub($w1, $pos, \$np, $sps_len) . $sps;
	    }
	}
	else {
	    if ($sps_len > $lss) {
		$w1 .= substr($sps, 0, $sps_len - $lss);
		$tmp = &$refsub($w1, 1 + $pos, \$np, $lss) .
		    substr($sps, $sps_len - $lss);
	    }
	    else {
		$tmp = &$refsub($w1, 1 + $pos, \$np, $sps_len) . $sps;
	    }
	    $result .= ($tmp =~ s/^ /$sp1/) ? "$LF$tmp" : "$sp1$tmp";
	}
    }
    return $trailing_crlf ? $result . $trailing_crlf : $result;
}


# add encoded-word (for structured header)
#   parameters:
#     sp  : start position (indentation of the first line)
#     ep  : end position of last line (call by reference)
#     rll : room of last line (default: 0)
sub add_enc_word_sth {
    my ($str, $sp, $ep, $rll) = @_;

    our $BPL; # bytes per line

    our $ADD_ENC_WORD;
    our $REG_RP;

    my ($lp, $rp); # '(' & ')' : left/right parenthesis
    my ($lp_len, $rp_len) = (0, 0);
    my $tmp;

    if ($str =~ s/^(\({1,3})//) {
	$lp = $1;
	$lp_len = length($lp);
	$sp += $lp_len;
    }
    if ($str =~ /$REG_RP/) {
	$rp = $1;
	$rp_len = length($rp);
	$rll = $rp_len;
	substr($str, -$rp_len) = '';
    }
    $tmp = &$ADD_ENC_WORD($str, $sp, $ep, $rll);
    if ($lp_len > 0) {
	if ($tmp !~ s/^ / $lp/) {
	    $tmp = $lp . $tmp;
	}
    }
    if ($rp_len > 0) {
	$tmp .= $rp;
	$$ep += $rp_len;
    }
    return $tmp;
}


# add encoded-word for 7bit-jis string
sub add_enc_word_7bit_jis {
    my ($str, $sp, $ep, $rll) = @_;

    return '' if $str eq '';

    our $LF;  # line feed
    our $BPL; # bytes per line

    my $k_in = 0; # ascii: 0, zen: 1 or 2, han: 9
    my $k_in_bak = 0;
    my $ec;
    my $ec_bak = '';
    my ($c, $cl);
    my ($w, $w_len) = ('', 0);
    my ($chunk, $chunk_len) = ('', 0);
    my $enc_len;
    my $result = '';
    my $str_pos;
    my $str_len = length($str);
    my $ll_flag = 0;

    # encoded size + sp (18 is HEAD_J + TAIL)
    my $ep_tmp = int(($str_len + 2) / 3) * 4 + 18 + $sp;

    if ($ep_tmp + $rll <= $BPL) {
	$$ep = $ep_tmp;
	return HEAD_J . encode_base64($str, '') . TAIL;
    }
    $ll_flag = 1 if $ep_tmp <= $BPL;
    while ($str =~ /\e(..)|(.)/g) {
	($ec, $c) = ($1, $2);
	if (defined $ec) {
	    $ec_bak = $ec;
	    $w .= "\e$ec";
	    $w_len += 3;
	    if ($ec eq '(B') {
		$k_in = 0;
	    }
	    elsif ($ec eq '$B') {
		$k_in = 1;
	    }
	    else {
		$k_in = 9;
	    }
	    next;
	}
	if (defined $c) {
	    if ($k_in == 0) {
		$w .= $c;
		$w_len++;
	    }
	    elsif ($k_in == 1) {
		$cl = $c;
		$k_in = 2;
		next;
	    }
	    elsif ($k_in == 2) {
		$w .= "$cl$c";
		$w_len += 2;
		$k_in = 1;
	    }
	    else {
		$w .= $c;
                $w_len++;
	    }
	}

	# encoded size (18 is HEAD_J + TAIL, 3 is "\e\(B")
	$enc_len =
	    int(($chunk_len + $w_len + ($k_in ? 3 : 0) + 2) / 3) * 4 + 18;

	if ($sp + $enc_len > $BPL) {
            if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
            }
            else {
		if ($k_in_bak) {
		    $chunk .= "\e\(B";
		    $w = "\e$ec_bak" . $w;
		    $w_len += 3;
		}
                $result .= HEAD_J . encode_base64($chunk, '') . TAIL . "$LF ";
            }
	    $str_pos = pos($str);

	    # encoded size (19 is 18 + space)
	    $ep_tmp = int(($str_len - $str_pos + $w_len + 2) / 3) * 4 + 19;
	    if ($ep_tmp + $rll <= $BPL) {
		$chunk = $w . substr($str, $str_pos);
		last;
	    }
	    $ll_flag = 1 if $ep_tmp <= $BPL;
            $chunk = $w;
            $chunk_len = $w_len;
            $sp = 1; # 1 is top space
        }
        else {
	    if ($ll_flag and pos($str) == $str_len) { # last char
		if ($k_in_bak) {
		    $chunk .= "\e\(B";
		    $w = "\e$ec_bak" . $w;
		    $w_len += 3;
		}
		$result .= HEAD_J . encode_base64($chunk, '') . TAIL . "$LF ";
		$ep_tmp = int(($w_len + 2) / 3) * 4 + 19;
		$chunk = $w;
		last;
	    }
            $chunk .= $w;
            $chunk_len += $w_len;
        }
	$k_in_bak = $k_in;
	$w = '';
	$w_len = 0;
    }
    $$ep = $ep_tmp;
    return $result . HEAD_J . encode_base64($chunk, '') . TAIL;
}


# add encoded-word for utf8 string
sub add_enc_word_utf8 {
    my ($str, $sp, $ep, $rll) = @_;

    return '' if $str eq '';

    our $LF;  # line feed
    our $BPL; # bytes per line

    my ($chunk, $chunk_len) = ('', 0);
    my $w_len;
    my $enc_len;
    my $result = '';
    my $str_pos = 0;
    my $str_len = length($str);

    # encoded size + sp (12 is HEAD + TAIL)
    my $ep_tmp = int(($str_len + 2) / 3) * 4 + 12 + $sp;

    if ($ep_tmp + $rll <= $BPL) {
	$$ep = $ep_tmp;
	return HEAD . encode_base64($str, '') . TAIL;
    }

    utf8::decode($str); # UTF8 flag on

    if ($ep_tmp <= $BPL) {
	my $w = chop($str);
	utf8::encode($w); # UTF8 flag off
	$$ep = int((length($w) + 2) / 3) * 4 + 13; # 13 is 12 + space
	utf8::encode($str); # UTF8 flag off
	$result = ($str eq '') ? ' ' :
	    HEAD . encode_base64($str, '') . TAIL . "$LF ";
	return $result . HEAD . encode_base64($w, '') . TAIL;
    }

    for my $w (split //, $str) {
	utf8::encode($w); # UTF8 flag off
	$w_len = length($w); # size of one character

	# encoded size (12 is HEAD + TAIL)
	$enc_len = int(($chunk_len + $w_len + 2) / 3) * 4 + 12;

	if ($sp + $enc_len > $BPL) {
	    if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
	    }
	    else {
		$result .= HEAD . encode_base64($chunk, '') . TAIL . "$LF ";
	    }
	    $str_pos += $chunk_len;

	    # encoded size (13 is 12 + space)
            $ep_tmp = int(($str_len - $str_pos + 2) / 3) * 4 + 13;
            if ($ep_tmp + $rll <= $BPL) {
		utf8::encode($str); # UTF8 flag off
                $chunk = substr($str, $str_pos);
                last;
            }
	    if ($ep_tmp <= $BPL) {
		$w = chop($str);
		utf8::encode($w); # UTF8 flag off
		$w_len = length($w);
		utf8::encode($str); # UTF8 flag off
		$chunk = substr($str, $str_pos);
		$result .= HEAD . encode_base64($chunk, '') . TAIL . "$LF ";
		$ep_tmp = int(($w_len + 2) / 3) * 4 + 13; # 13 is 12 + space
		$chunk = $w;
		last;
	    }
	    $chunk = $w;
	    $chunk_len = $w_len;
	    $sp = 1; # 1 is top space
	}
	else {
	    $chunk .= $w;
	    $chunk_len += $w_len;
	}
    }
    $$ep = $ep_tmp;
    return $result . HEAD . encode_base64($chunk, '') . TAIL;
}

1;
__END__

=head1 NAME

MIME::EcoEncode - MIME Encoding (Economical)

=head1 SYNOPSIS

 use MIME::EcoEncode;
 $encoded = mime_eco($str, 'UTF-8'); # encode utf8 string
 $encoded = mime_eco($str, 'ISO-2022-JP'); # encode 7bit-jis string

=head1 DESCRIPTION

This module implements RFC 2047 Mime Header Encoding.

=head2 OPTIONS

  $encoded = mime_eco($str, $charset, $lf, $bpl, $mode, $lss);
               # $charset : 'UTF-8' or 'ISO-2022-JP'
               # $lf      : line feed (default: "\n")
               # $bpl     : bytes per line (default: 76)
               # $mode    : 0 : unstructured header
               #            1 : structured header
               #            2 : auto (Subject or Comments ? 0 : 1)
               #            (default: 2)
               # $lss     : length of security space (default: 25)

=head1 SEE ALSO

For more information, please visit http://www.nips.ac.jp/~murata/mimeeco/

=head1 AUTHOR

MURATA Yasuhisa E<lt>murata@nips.ac.jpE<gt>

=head1 COPYRIGHT

Copyright (C) 2011-2012 MURATA Yasuhisa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
