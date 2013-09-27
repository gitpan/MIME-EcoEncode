package MIME::EcoEncode;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw($VERSION);
our @EXPORT = qw(mime_eco mime_deco);
our $VERSION = '0.93';

use MIME::Base64;
use MIME::QuotedPrint;

use constant TAIL => '?=';

our $LF;   # line feed
our $BPL;  # bytes per line
our $MODE; # unstructured : 0, structured : 1, auto : 2

our $HEAD; # head string
our $HTL;  # head + tail length
our $UTF8;
our $REG_W;
our $ADD_EW;
our $REG_RP;

sub mime_eco {
    my $str = shift;
    my $charset = shift || 'UTF-8';

    our $LF  = shift || "\n"; # line feed
    our $BPL = shift || 76;   # bytes per line
    our $MODE = shift;
    $MODE = 2 unless defined $MODE;

    my $lss = shift;
    $lss = 25 unless defined $lss;

    our $HEAD; # head string
    our $HTL;  # head + tail length
    our $UTF8 = 1;
    our $REG_W = qr/(.)/;
    our $ADD_EW;
    our $REG_RP;

    my $jp = 0;

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
    return undef
	unless $charset =~ /^([-0-9A-Za-z_]+)(?:\*[^\?]*)?(\?[QB])?$/i;

    my $cs = lc($1);
    $charset .= '?B' unless defined $2;

    my $q_enc = ($charset =~ /Q$/i) ? 1 : 0;
    $HEAD = '=?' . $charset . '?';
    $HTL = length($HEAD) + 2;

    if ($cs ne 'utf-8') {
	$UTF8 = 0;
	if ($cs eq 'iso-2022-jp') {
	    return undef if $q_enc;
	    $jp = 1;
	}
	elsif ($cs eq 'gb2312') { # Simplified Chinese
	    $REG_W = qr/([\xa1-\xfe][\xa1-\xfe]|.)/;
	}
	elsif ($cs eq 'euc-kr') { # Korean
	    $REG_W = qr/([\xa1-\xfe][\xa1-\xfe]|.)/;
	}
	elsif ($cs eq 'big5') { # Traditional Chinese
	    $REG_W = qr/([\x81-\xfe][\x40-\x7e\xa1-\xfe]|.)/;
	}
	else { # Single Byte (Latin, Cyrillic, ...)
	    ;
	}
    }
    my ($trailing_crlf) = ($str =~ /(\n|\r|\x0d\x0a)$/o);

    $str =~ tr/\n\r//d;
    $str =~ /(\s*)(\S+)/gc;
    ($sps, $w2) = ($1, $2);

    if ($w2 =~ /[^\x21-\x7e]/) {
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

    if ($MODE == 2) {
	$MODE = ($w1 =~ /^(?:Subject:|Comments:)$/i) ? 0 : 1;
    }
    if ($MODE == 0) {
	$refsub = $jp ? \&add_ew_j : $q_enc ? \&add_ew_q : \&add_ew_b;
    }
    else {
	$refsub = \&add_ew_sh;
	if ($jp) { # 7bit_jis
	    $reg_rp1 = qr/\e\(B[\x21-\x7e]*\)\,?$/;
            $REG_RP = qr/\e\(B[\x21-\x7e]*?(\){1,3}\,?)$/;
	    $ADD_EW = \&add_ew_j;
	}
	else {
	    $reg_rp1 = qr/\)\,?$/;
            $REG_RP = qr/(\){1,3}\,?)$/;
	    $ADD_EW = $q_enc ? \&add_ew_q : \&add_ew_b;
        }
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
		    if ($pos >= $BPL) {
			$result .= $LF . $sps;
			$pos = $sps_len - 1;
		    }
		    elsif ($pos + $sps_len - 1 > $BPL) {
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
		if (($MODE == 1) and ($sps_len <= $lss)) {
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
sub add_ew_sh {
    my ($str, $sp, $ep, $rll) = @_;

    our $ADD_EW;
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
    $tmp = &$ADD_EW($str, $sp, $ep, $rll);
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
sub add_ew_j {
    my ($str, $sp, $ep, $rll) = @_;

    return '' if $str eq '';

    our $HEAD; # head string
    our $HTL;  # head + tail length
    our $LF;   # line feed
    our $BPL;  # bytes per line

    my $k_in = 0; # ascii: 0, zen: 1 or 2, han: 9
    my $k_in_bak = 0;
    my ($ec, $c, $cl);
    my $ec_bak = '';
    my ($w, $w_len) = ('', 0);
    my ($chunk, $chunk_len) = ('', 0);
    my $enc_len;
    my $result = '';
    my $str_pos;
    my $str_len = length($str);
    my $ll_flag = 0;
    my $ee = 0; # end ESC length (0 or 3)
    my $str_len_ee = $str_len;

    # encoded size + sp
    my $ep_v = int(($str_len + 2) / 3) * 4 + $HTL + $sp;

    if ($ep_v + $rll <= $BPL) {
	$$ep = $ep_v;
	return $HEAD . encode_base64($str, '') . TAIL;
    }

    my $max_len  = int(($BPL - $HTL - $sp) / 4) * 3;
    my $max_len2 = int(($BPL - $HTL - 1) / 4) * 3;
    my $kv;

    $ll_flag = 1 if $ep_v <= $BPL;
    if ($str =~ s/\e\(B$//) {
	$ee = 3;
	$str_len_ee -= 3;
    }
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
	$kv = $k_in ? 3 : 0; # 3 is "\e\(B"
	if ($chunk_len + $w_len + $kv > $max_len) {
            if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
            }
            else {
		if ($k_in_bak) {
		    $chunk .= "\e\(B";
		    if ($k_in) {
			if ($k_in_bak == $k_in) {
			    $w = "\e$ec_bak" . $w;
			    $w_len += 3;
			}
		    }
		    else {
			$w = $c;
                        $w_len = 1;
		    }
		}
                $result .= $HEAD . encode_base64($chunk, '') . TAIL . "$LF ";
            }
	    $str_pos = pos($str);

	    # encoded size (1 is space)
	    $ep_v =
		int(($str_len - $str_pos + $w_len + 2) / 3) * 4 + $HTL + 1;

	    if ($ep_v + $rll <= $BPL) {
		$chunk = $w . substr($str, $str_pos);
		$chunk .= "\e\(B" if $ee;
		last;
	    }
	    $ll_flag = 1 if $ep_v <= $BPL;
            $chunk = $w;
            $chunk_len = $w_len;
            $sp = 1; # 1 is top space
	    $max_len = $max_len2;
        }
        else {
	    if ($ll_flag and pos($str) == $str_len_ee) { # last char
		if ($chunk_len == 0) { # size over at the first time
		    $result = ' ';
		}
		else {
		    if ($k_in_bak) {
			$chunk .= "\e\(B";
			if ($k_in) {
			    if ($k_in_bak == $k_in) {
				$w = "\e$ec_bak" . $w;
				$w_len += 3;
			    }
			}
			else {
			    $w = $c;
			    $w_len = 1;
			}
		    }
		    $result .=$HEAD
			. encode_base64($chunk, '') . TAIL . "$LF ";
		}
		if ($ee) {
		    $w .= "\e\(B";
		    $w_len += 3;
		}
		$ep_v = int(($w_len + 2) / 3) * 4 + $HTL + 1; # 1 is space
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
    $$ep = $ep_v;
    return $result . $HEAD . encode_base64($chunk, '') . TAIL;
}


# add encoded-word for "B" encoding
sub add_ew_b {
    my ($str, $sp, $ep, $rll) = @_;

    return '' if $str eq '';

    our $LF;   # line feed
    our $BPL;  # bytes per line
    our $HEAD; # head string
    our $HTL;  # head + tail length
    our $UTF8;
    our $REG_W;

    my ($chunk, $chunk_len) = ('', 0);
    my $w_len;
    my $result = '';
    my $str_pos = 0;
    my $str_len = length($str);

    # encoded size + sp
    my $ep_v = int(($str_len + 2) / 3) * 4 + $HTL + $sp;

    if ($ep_v + $rll <= $BPL) {
	$$ep = $ep_v;
	return $HEAD . encode_base64($str, '') . TAIL;
    }

    utf8::decode($str) if $UTF8; # UTF8 flag on

    if ($ep_v <= $BPL) {
	$str =~ s/$REG_W$//;
	my $w = $1;
	utf8::encode($w) if $UTF8; # UTF8 flag off
	$$ep = int((length($w) + 2) / 3) * 4 + $HTL + 1; # 1 is space
	utf8::encode($str) if $UTF8; # UTF8 flag off
	$result = ($str eq '') ? ' ' :
	    $HEAD . encode_base64($str, '') . TAIL . "$LF ";
	return $result . $HEAD . encode_base64($w, '') . TAIL;
    }

    my $max_len  = int(($BPL - $HTL - $sp) / 4) * 3;
    my $max_len2 = int(($BPL - $HTL - 1) / 4) * 3;

    while ($str =~ /$REG_W/g) {
	my $w = $1;
	utf8::encode($w) if $UTF8; # UTF8 flag off
	$w_len = length($w); # size of one character

	if ($chunk_len + $w_len > $max_len) {
	    if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
	    }
	    else {
		$result .= $HEAD . encode_base64($chunk, '') . TAIL . "$LF ";
	    }
	    $str_pos += $chunk_len;

	    # encoded size (1 is space)
            $ep_v = int(($str_len - $str_pos + 2) / 3) * 4 + $HTL + 1;
            if ($ep_v + $rll <= $BPL) {
		utf8::encode($str) if $UTF8; # UTF8 flag off
                $chunk = substr($str, $str_pos);
                last;
            }
	    if ($ep_v <= $BPL) {
		$str =~ s/$REG_W$//;
		$w = $1;
		utf8::encode($w) if $UTF8; # UTF8 flag off
		$w_len = length($w);
		utf8::encode($str) if $UTF8; # UTF8 flag off
		$chunk = substr($str, $str_pos);
		$result .= $HEAD . encode_base64($chunk, '') . TAIL . "$LF ";
		$ep_v = int(($w_len + 2) / 3) * 4 + $HTL + 1; # 1 is space
		$chunk = $w;
		last;
	    }
	    $chunk = $w;
	    $chunk_len = $w_len;
	    $sp = 1; # 1 is top space
	    $max_len = $max_len2;
	}
	else {
	    $chunk .= $w;
	    $chunk_len += $w_len;
	}
    }
    $$ep = $ep_v;
    return $result . $HEAD . encode_base64($chunk, '') . TAIL;
}


# add encoded-word for "Q" encoding
sub add_ew_q {
    my ($str, $sp, $ep, $rll) = @_;

    return '' if $str eq '';

    our $LF;   # line feed
    our $BPL;  # bytes per line
    our $MODE; # unstructured : 0, structured : 1
    our $HEAD; # head string
    our $HTL;  # head + tail length
    our $UTF8;
    our $REG_W;

    my $enc_len;
    my $result = '';

    # '.' is added to invalidate RFC 2045 6.7.(3)
    my $qstr = encode_qp($str . '.', '');

    my $qstr_len;
    my $chunk_qlen = 0;
    my $w_qlen;

    local *qlen;

    chop($qstr); # cut '.'
    $qstr =~ s/_/=5F/g;
    $qstr =~ tr/ /_/;
    $qstr =~ s/\t/=09/g;
    if ($MODE) { # structured
	$qstr =~ s/([^\w\!\*\+\-\/\=])/sprintf("=%X",ord($1))/ego;
	*qlen = sub {
	    my $str = shift;
	    return length($str) * 3 - ($str =~ tr/ A-Za-z0-9\!\*\+\-\///) * 2;
	};
    }
    else { # unstructured
	$qstr =~ s/\?/=3F/g;
	*qlen = sub {
	    my $str = shift;
	    return length($str) * 3 - ($str =~ tr/ -\<\>\@-\^\`-\~//) * 2;
	};
    }
    $qstr_len = length($qstr);

    my $ep_v = $qstr_len + $HTL + $sp;

    if ($ep_v + $rll <= $BPL) {
	$$ep = $ep_v;
	return $HEAD . $qstr . TAIL;
    }

    utf8::decode($str) if $UTF8; # UTF8 flag on

    if ($ep_v <= $BPL) {
	$str =~ s/$REG_W$//;
	my $w = $1;
	utf8::encode($w) if $UTF8; # UTF8 flag off
	$w_qlen = qlen($w);
	$$ep = $w_qlen + $HTL + 1; # 1 is space
	$result = ($str eq '') ? ' ' :
	    $HEAD . substr($qstr, 0, $qstr_len - $w_qlen, '') . TAIL . "$LF ";
	return $result . $HEAD . $qstr . TAIL;
    }

    while ($str =~ /$REG_W/g) {
	my $w = $1;
	utf8::encode($w) if $UTF8; # UTF8 flag off
	$w_qlen = qlen($w);
	$enc_len = $chunk_qlen + $w_qlen + $HTL;
	if ($sp + $enc_len > $BPL) {
	    if ($chunk_qlen == 0) { # size over at the first time
		$result = ' ';
	    }
	    else {
		$result .= $HEAD . substr($qstr, 0, $chunk_qlen, '')
		    . TAIL . "$LF ";
	    }
	    $qstr_len -= $chunk_qlen;
	    $ep_v = $qstr_len + $HTL + 1; # 1 is space

            if ($ep_v + $rll <= $BPL) {
                last;
            }
	    if ($ep_v <= $BPL) {
		$str =~ s/$REG_W$//;
		$w = $1;
		utf8::encode($w) if $UTF8; # UTF8 flag off
		$w_qlen = qlen($w);
		$result .= $HEAD . substr($qstr, 0, $qstr_len - $w_qlen, '')
		    . TAIL . "$LF ";
		$ep_v = $w_qlen + $HTL + 1; # 1 is space
		last;
	    }
	    $chunk_qlen = $w_qlen;
	    $sp = 1; # 1 is top space
	}
	else {
	    $chunk_qlen += $w_qlen;
	}
    }
    $$ep = $ep_v;
    return $result . $HEAD . $qstr . TAIL;
}


sub mime_deco {
    my $str = shift;
    my $cb = shift;

    my ($charset, $lang, $b_enc, $q_enc);
    my $result = '';
    my $enc = 0;
    my $w_bak = '';
    my $sp_len = 0;
    my ($lp, $rp); # '(' & ')' : left/right parenthesis

    my $reg_ew =
        qr{^
           =\?
           ([-0-9A-Za-z_]+)                          # charset
           (?:\*([A-Za-z]{1,8}(?:-[A-Za-z]{1,8})*))? # language (RFC 2231)
           \?
           (?:
               [Bb]\?([0-9A-Za-z\+\/]+={0,2})\?=     # "B" encoding
           |
               [Qq]\?([\x21-\x3e\x40-\x7e]+)\?=      # "Q" encoding
           )
           $}x;

    my ($trailing_crlf) = ($str =~ /(\n|\r|\x0d\x0a)$/o);
    $str =~ tr/\n\r//d;

    if ($cb) {
	for my $w (split /([\s]+)/, $str) {
	    $w =~ s/^(\(*)//;
	    $lp = $1;
	    $w =~ s/(\)*)$//;
	    $rp = $1;
            if ($w =~ qr/$reg_ew/o) {
                ($charset, $lang, $b_enc, $q_enc) = ($1, $2, $3, $4);
                $lang = '' unless defined $lang;
		substr($result, -$sp_len) = "" if ($enc and !$lp);
                if (defined $q_enc) {
                    $q_enc =~ tr/_/ /;
                    $result .= $lp . &$cb($w, $charset, $lang,
					  decode_qp($q_enc)) . $rp;
                }
                else {
                    $result .= $lp . &$cb($w, $charset, $lang,
					  decode_base64($b_enc)) . $rp;
                }
                $enc = 1;
            }
            else {
		if ($enc) {
		    if ($w =~ /^\s+$/) {
			$sp_len = length($w);
		    }
		    else {
			$enc = 0;
		    }
		}
                $result .= $lp . $w . $rp;
            }
        }
    }
    else {
        my $cs1 = '';
	my $res_cs1 = '';
	my $res_lang1 = '';
	for my $w (split /([\s]+)/, $str) {
            $w =~ s/^(\(*)//;
            $lp = $1;
            $w =~ s/(\)*)$//;
            $rp = $1;
            if ($w =~ qr/$reg_ew/o) {
                ($charset, $lang, $b_enc, $q_enc) = ($1, $2, $3, $4);
                if ($charset !~ /^US-ASCII$/i) {
                    if ($cs1) {
                        if ($cs1 ne lc($charset)) {
                            $result .= $w;
                            $enc = 0;
                            next;
                        }
                    }
                    else {
                        $cs1 = lc($charset);
			$res_cs1   = $charset || '';
			$res_lang1 = $lang    || '';
                    }
                }
		substr($result, -$sp_len) = "" if ($enc and !$lp);
                if (defined $q_enc) {
                    $q_enc =~ tr/_/ /;
                    $result .= $lp . decode_qp($q_enc) . $rp;
                }
                else {
                    $result .= $lp . decode_base64($b_enc) . $rp;
                }
		$enc = $rp ? 0 : 1;
            }
            else {
		if ($enc) {
		    if ($w =~ /^\s+$/) {
			$sp_len = length($w);
		    }
		    else {
			$enc = 0;
		    }
		}
                $result .= $lp . $w . $rp;
            }
        }
	if ($cs1 eq 'iso-2022-jp') { # remove redundant ESC sequences
	    $result =~ s/(\e..)([^\e]+)\e\(B(?=\1)/$1$2\n/g;
	    $result =~ s/\n\e..//g;
	    $result =~ s/\e\(B(\e..)/$1/g;
	}
	if (wantarray) {
	    return ($trailing_crlf ? $result . $trailing_crlf : $result,
		    $res_cs1, $res_lang1);
	}
    }
    return $trailing_crlf ? $result . $trailing_crlf : $result;
}

1;
__END__

=head1 NAME

MIME::EcoEncode - MIME Encoding (Economical)

=head1 SYNOPSIS

 use MIME::EcoEncode;
 $encoded = mime_eco($str, 'UTF-8');        # encode utf8 string
 $encoded = mime_eco($str, 'UTF-8?B');      # ditto ("B" encoding)
 $encoded = mime_eco($str, 'UTF-8?Q');      # ditto ("Q" encoding)
 $encoded = mime_eco($str, 'UTF-8*XX');     # XX is RFC2231's language
 $encoded = mime_eco($str, 'UTF-8*XX?B');   # ditto ("B" encoding)
 $encoded = mime_eco($str, 'UTF-8*XX?Q');   # ditto ("Q" encoding)
 $encoded = mime_eco($str, 'GB2312');       # encode euc-cn string
 $encoded = mime_eco($str, 'EUC-KR');       # encode euc-kr string
 $encoded = mime_eco($str, 'Big5');         # encode big5 string
 $encoded = mime_eco($str, 'ISO-2022-JP');  # encode 7bit-jis string
 $encoded = mime_eco($str, $sbcs);          # $sbcs :
                                            #   single-byte charset
                                            #     (e.g. 'ISO-8859-1')

 $decoded = mime_deco($encoded);            # decode encoded string
                                            #   (for single charset)

 ($decoded, $charset, $language)            # return array
          = mime_deco($encoded);            #   (for single charset)

 use Encode;
 $decoded = mime_deco($encoded, \&cb);      # cb is callback subroutine
                                            #   (for multiple charsets)

 # Example of callback subroutine
 sub cb {
   my ($encoded_word, $charset, $language, $decoded_word) = @_;
   encode_utf8(decode($charset, $decoded_word));
 }

=head1 DESCRIPTION

This module implements RFC 2047 Mime Header Encoding.

=head2 Options

  $encoded = mime_eco($str, $charset, $lf, $bpl, $mode, $lss);
               # $charset : 'UTF-8' / 'UTF-8?Q' / 'UTF-8*XX' /
               #            'GB2312' / 'EUC-KR' / 'Big5' /
               #            'ISO-2022-JP' / ...
               #            (default: 'UTF-8')
               #              Note: "B" encoding is all defaults.
               #                    'ISO-2022-JP?Q' is not supported.
               #                    The others are all encoded as
               #                    single-byte string.
               # $lf      : line feed (default: "\n")
               # $bpl     : bytes per line (default: 76)
               # $mode    : 0 : unstructured header (e.g. Subject)
               #            1 : structured header (e.g. To, Cc, From)
               #            2 : auto (Subject or Comments ? 0 : 1)
               #            (default: 2)
               # $lss     : length of security space (default: 25)

=head2 Examples

Ex1 - normal (structured header)

  use MIME::EcoEncode;
  my $str = "From: Sakura <sakura\@example.jp> (\xe6\xa1\x9c)\n";
  print mime_eco($str);

Ex1's output:

  From: Sakura <sakura@example.jp> (=?UTF-8?B?5qGc?=)

Ex2 - "Q" encoding + RFC2231's language

  use MIME::EcoEncode;
  my $str = "From: Sakura <sakura\@example.jp> (\xe6\xa1\x9c)\n";
  print mime_eco($str, 'UTF-8*ja-JP?Q');

Ex2's output:

  From: Sakura <sakura@example.jp> (=?UTF-8*ja-JP?Q?=E6=A1=9C?=)

Ex3 - continuous spaces

  use MIME::EcoEncode;
  my $str = "From: Sakura  <sakura\@example.jp>    (\xe6\xa1\x9c)\n";
  print mime_eco($str);

Ex3's output:

  From: Sakura  <sakura@example.jp>    (=?UTF-8?B?5qGc?=)

Ex4 - unstructured header (1)

  use MIME::EcoEncode;
  my $str = "Subject: Sakura (\xe6\xa1\x9c)\n";
  print mime_eco($str);

Ex4's output:

  Subject: Sakura =?UTF-8?B?KOahnCk=?=

Ex5 - unstructured header (2)

  use MIME::EcoEncode;
  my $str = "Subject: \xe6\xa1\x9c  Sakura\n";
  print mime_eco($str);

Ex5's output:

  Subject: =?UTF-8?B?5qGc?=  Sakura

Ex6 - 7bit-jis string

  use Encode;
  use MIME::EcoEncode;
  my $str = "Subject: \xe6\xa1\x9c  Sakura\n";
  print mime_eco(encode('7bit-jis', decode_utf8($str)), 'ISO-2022-JP');

Ex6's output:

  Subject: =?ISO-2022-JP?B?GyRCOnkbKEI=?=  Sakura

=head1 SEE ALSO

For more information, please visit http://www.nips.ac.jp/~murata/mimeeco/

=head1 AUTHOR

MURATA Yasuhisa E<lt>murata@nips.ac.jpE<gt>

=head1 COPYRIGHT

Copyright (C) 2011-2013 MURATA Yasuhisa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
