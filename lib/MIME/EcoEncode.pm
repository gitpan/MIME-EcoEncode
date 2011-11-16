package MIME::EcoEncode;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw($JCODE_COMPAT $VERSION);

our @EXPORT = qw(mime_eco);
our $VERSION = '0.32';

our $JCODE_COMPAT = 0; # compatible with Jcode

use constant HEAD   => '=?UTF-8?B?';
use constant HEAD_J => '=?ISO-2022-JP?B?';
use constant TAIL   => '?=';

sub mime_eco {
    my $str = shift;
    my $charset = shift || 'UTF-8';
    my $lf  = shift || "\n";
    my $bpl = shift || 76;
    my $pos = 0;
    my $np;
    my $refsub;

    my @words;
    my $wpart = '';

    my $result = '';
    my $word_len;
    my $word1 = 0;
    my $tmp;

    return '' unless defined $str;
    return '' if $str eq '';

    if ($charset eq 'UTF-8') {
	$refsub = \&add_enc_word_utf8;
    }
    elsif ($charset eq 'ISO-2022-JP') {
	$refsub = \&add_enc_word_7bit_jis;
    }
    else {
	return undef;
    }
    my ($trailing_crlf) = ($str =~ /(\n|\r|\x0d\x0a)$/o);

    for my $word (split /\s+/, $str) {
	if ($word =~ /[^\x21-\x7e]/) {
	    if ($wpart eq '') {
		$wpart = $word;
	    }
	    else {
		$wpart .= " $word";
	    }
	}
	else {
	    if ($wpart ne '') {
		push(@words, $wpart);
		$wpart = '';
	    }
	    push(@words, $word);
	}
    }
    push(@words, $wpart) if $wpart ne '';

    for my $word (@words) {
	if ($word eq '') {
	    $word1 = 1;
	    next;
	}
	if ($word =~ /[^\x21-\x7e]/) {
	    if ($pos == 0 and $word1 == 0) {
		$tmp = &$refsub($word, 0, $lf, $bpl, \$np);
	    }
	    else {
		$tmp =
		    &$refsub($word, 1 +
				    ($JCODE_COMPAT ? length($result) : $pos),
				    $lf, $bpl, \$np);
		$result .= ($tmp =~ /^ /) ? $lf : ' ';
	    }
	    $result .= $tmp;
	    $pos = $np;
	}
	else {
	    $word_len = length($word);
	    if ($word_len > $bpl) {
		$result .= "$lf $word";
		$pos = $word_len + 1;
		next;
	    }
	    if ($pos == 0 and $word1 == 0) {
		$result = $word;
		$pos = $word_len;
		next;
	    }
	    if ($pos + $word_len + 1 > $bpl) {
		$result .= "$lf $word";
		$pos = $word_len + 1;
	    }
	    else {
		$result .= " $word";
		$pos += $word_len + 1;
	    }
	}
    }
    return $trailing_crlf ? $result . $trailing_crlf : $result;
}


# add encorded-word for 7bit-jis string
#   parameters:
#     str : 7bit-jis string
#     sp  : start position (indentation of the first line)
#     lf  : line feed (default: "\n")
#     bpl : bytes per line (default: 76)
#     ep  : end position of last line (call by reference)
sub add_enc_word_7bit_jis {
    require MIME::Base64;
    my($str, $sp, $lf, $bpl, $ep) = @_;

    return '' if $str eq '';

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

    # encoded size + sp (18 is HEAD_J + TAIL)
    my $ep_tmp = int(($str_len + 2) / 3) * 4 + 18 + $sp;
    if ($ep_tmp <= $bpl) {
	$$ep = $ep_tmp;
	return HEAD_J . MIME::Base64::encode_base64($str, '') . TAIL;
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

	# encoded size (18 is HEAD_J + TAIL, 3 is "\e\(B")
	$enc_len =
	    int(($chunk_len + $w_len + ($k_in ? 3 : 0) + 2) / 3) * 4 + 18;

	if ($sp + $enc_len > $bpl) {
            if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
            }
            else {
		if ($k_in_bak) {
		    $chunk .= "\e\(B";
		    $w = "\e$ec_bak" . $w;
		    $w_len += 3;
		}
                $result .= HEAD_J .
		    MIME::Base64::encode_base64($chunk, '') . TAIL . "$lf ";
            }
	    $str_pos = pos($str);

	    # encoded size (19 is 18 + space)
	    $ep_tmp = int(($str_len - $str_pos + $w_len + 2) / 3) * 4 + 19;
	    if ($ep_tmp <= $bpl) {
		$chunk = $w . substr($str, $str_pos);
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
	$k_in_bak = $k_in;
	$w = '';
	$w_len = 0;
    }
    $$ep = $ep_tmp;
    return $result . HEAD_J . MIME::Base64::encode_base64($chunk, '') . TAIL;
}


# add encorded-word for utf8 string
sub add_enc_word_utf8 {
    require MIME::Base64;
    my($str, $sp, $lf, $bpl, $ep) = @_;

    return '' if $str eq '';

    my ($chunk, $chunk_len) = ('', 0);
    my $w_len;
    my $enc_len;
    my $result = '';

    # encoded size + sp (12 is HEAD + TAIL)
    my $ep_tmp = int((length($str) + 2) / 3) * 4 + 12 + $sp;
    if ($ep_tmp <= $bpl) {
	$$ep = $ep_tmp;
	return HEAD . MIME::Base64::encode_base64($str, '') . TAIL;
    }

    utf8::decode($str); # UTF8 flag on

    for my $w (split //, $str) {
	utf8::encode($w); # UTF8 flag off
	$w_len = length($w); # size of one character

	# encoded size (12 is HEAD + TAIL)
	$enc_len = int(($chunk_len + $w_len + 2) / 3) * 4 + 12;

	if ($sp + $enc_len > $bpl) {
	    if ($chunk_len == 0) { # size over at the first time
		$result = ' ';
	    }
	    else {
		$result .= HEAD .
		    MIME::Base64::encode_base64($chunk, '') . TAIL . "$lf ";
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
    $$ep = $sp + $enc_len;
    return $result . HEAD . MIME::Base64::encode_base64($chunk, '') . TAIL;
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

=head2 GLOBAL VARIABLES

$MIME::EcoEncode::JCODE_COMPAT # compatible with Jcode (0 or 1)

=head2 OPTIONS

  $encoded = mime_eco($str, $charset, $lf, $bpl);
               # $charset : 'UTF-8' or 'ISO-2022-JP'
               # $lf      : line feed (default: "\n")
               # $bpl     : bytes per line (default: 76)

=head1 SEE ALSO

For more information, please visit http://www.nips.ac.jp/~murata/mimeeco/

=head1 AUTHOR

MURATA Yasuhisa E<lt>murata@nips.ac.jpE<gt>

=head1 COPYRIGHT

Copyright (C) 2011 MURATA Yasuhisa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
