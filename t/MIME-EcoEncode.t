#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 35;
#use Test::More 'no_plan';
BEGIN { use_ok('MIME::EcoEncode') };

use Encode qw/from_to/;
use MIME::EcoEncode;

my $str;

$str = 'test';
is(mime_eco($str, 'UTF-8'), $str, 'ASCII (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str, 'ASCII (ISO-2022-JP)');

$str = "test\n";
is(mime_eco($str, 'UTF-8'), $str, 'ASCII . "\n" (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str, 'ASCII . "\n" (ISO-2022-JP)');

$str = 'a' x 80;
is(mime_eco($str, 'UTF-8'), $str, 'ASCII x 80 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str, 'ASCII x 80 (ISO-2022-JP)');

$str = 'Subject: ' . 'a' x 80;
is(mime_eco($str, 'UTF-8'), $str,
   "\'Subject: \'" . ' . ASCII x 80 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str,
   "\'Subject: \'" . ' . ASCII x 80 (ISO-2022-JP)');

$str = ' ' x 80;
is(mime_eco($str, 'UTF-8'), $str,  'SP x 80 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str, 'SP x 80 (ISO-2022-JP)');

$str = ('a' x 80 . ' ') x 3;
is(mime_eco($str, 'UTF-8'), 'a' x 80 . ' ' . 'a' x 80 . "\n " .
   'a' x 80 . ' ', '(ASCII x 80 + SP) x 3 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), 'a' x 80 . ' ' . 'a' x 80 . "\n " .
   'a' x 80 . ' ', '(ASCII x 80 + SP) x 3 (ISO-2022-JP)');


$str = '日本語あいうえおアイウエオ' x 2;
is(mime_eco($str, 'UTF-8'),
   "=?UTF-8?B?" .
   "5pel5pys6Kqe44GC44GE44GG44GI44GK44Ki44Kk44Km44Ko44Kq5pel5pys6Kqe?=\n" .
   " =?UTF-8?B?44GC44GE44GG44GI44GK44Ki44Kk44Km44Ko44Kq?=",
   'non-ASCII only (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "=?ISO-2022-JP?B?" .
   "GyRCRnxLXDhsJCIkJCQmJCgkKiUiJSQlJiUoJSpGfEtcOGwkIiQkGyhC?=\n" .
   " =?ISO-2022-JP?B?GyRCJCYkKCQqJSIlJCUmJSglKhsoQg==?=",
   'non-ASCII only (ISO-2022-JP)');


$str = '  ' . 'あ' . '  ';
is(mime_eco($str, 'UTF-8'), '  =?UTF-8?B?44GC?=  ',
   'SP SP non-ASCII SP SP (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'), '  =?ISO-2022-JP?B?GyRCJCIbKEI=?=  ',
   'SP SP non-ASCII SP SP (ISO-2022-JP)');


$str = '  ' . 'あ' . '  ';
is(mime_eco($str, 'UTF-8', undef, undef, undef, 0), '=?UTF-8?B?ICDjgYIgIA==?=',
   '$lss=0 (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP', undef, undef, undef, 0),
   '=?ISO-2022-JP?B?ICAbJEIkIhsoQiAg?=', '$lss=0 (ISO-2022-JP)');


$str = "  Subject:  Re:  [XXXX 0123]  Re:  アa  イi  ウu  A-I-U\n";
is(mime_eco($str, 'UTF-8'),
   "  Subject:  Re:  [XXXX 0123]  Re:  =?UTF-8?B?44KiYSAg44KkaSAg44KmdQ==?=" .
   " \n A-I-U\n",
   'SP SP ASCII non-ASCII . "\n" (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "  Subject:  Re:  [XXXX 0123]  Re:  =?ISO-2022-JP?B?GyRCJSIbKEJhICA=?=" .
   "\n =?ISO-2022-JP?B?GyRCJSQbKEJpICAbJEIlJhsoQnU=?=  A-I-U\n",
   'SP SP ASCII non-ASCII . "\n" (ISO-2022-JP)');


$str = 'Subject: あいうえお アイウエオ ｱｲｳｴｵ A-I-U-E-O';
is(mime_eco($str, 'UTF-8'),
   "Subject: " .
   "=?UTF-8?B?44GC44GE44GG44GI44GKIOOCouOCpOOCpuOCqOOCqiDvvbHvvbI=?=\n" .
   " =?UTF-8?B?772z77207721?= A-I-U-E-O",
   'ASCII non-ASCII HankakuKana (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject: " .
   "=?ISO-2022-JP?B?GyRCJCIkJCQmJCgkKhsoQiAbJEIlIiUkJSYlKCUqGyhCIA==?=\n" .
   " =?ISO-2022-JP?B?GyhJMTIzNDUbKEI=?= A-I-U-E-O",
   'ASCII non-ASCII HankakuKana (ISO-2022-JP)');


$str = 'Subject: Re: あ A い I';
is(mime_eco($str, 'UTF-8', "|\n", 17),
   "Subject: Re:|\n =?UTF-8?B?44GC?=|\n A|\n =?UTF-8?B?44GE?=|\n I",
   '$lf="|\n", $bpl=17 (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP', "|\n", 31),
   "Subject: Re:|\n =?ISO-2022-JP?B?GyRCJCIbKEI=?=|\n A|\n" .
   " =?ISO-2022-JP?B?GyRCJCQbKEI=?=|\n I",
   '$lf="|\n", $bpl=31 (ISO-2022-JP)');


$str = 'Subject: Re: あ A い I う U え E お O';
is(mime_eco($str, 'UTF-8'),
   "Subject: " .
   "Re: =?UTF-8?B?44GC?= A =?UTF-8?B?44GE?= I =?UTF-8?B?44GG?= U\n" .
   " =?UTF-8?B?44GI?= E =?UTF-8?B?44GK?= O",
   'ASCII non-ASCII (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject: " .
   "Re: =?ISO-2022-JP?B?GyRCJCIbKEI=?= A =?ISO-2022-JP?B?GyRCJCQbKEI=?=\n" .
   " I =?ISO-2022-JP?B?GyRCJCYbKEI=?= U =?ISO-2022-JP?B?GyRCJCgbKEI=?= E\n" .
   " =?ISO-2022-JP?B?GyRCJCobKEI=?= O",
   'ASCII non-ASCII (ISO-2022-JP)');


$str = "Subject:\tア a\tイ i\tウ u\t\tA-I-U";
is(mime_eco($str, 'UTF-8'),
   "Subject:\t=?UTF-8?B?44Ki?= a\t=?UTF-8?B?44Kk?= i\t=?UTF-8?B?44Km?= u" .
   "\t\tA-I-U",
   'ASCII non-ASCII . "\t" (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject:\t=?ISO-2022-JP?B?GyRCJSIbKEI=?= a" .
   "\t=?ISO-2022-JP?B?GyRCJSQbKEI=?= i\n" .
   "\t=?ISO-2022-JP?B?GyRCJSYbKEI=?= u\t\tA-I-U",
   'ASCII non-ASCII . "\t" (ISO-2022-JP)');


$str = 'Subject: ' . 'x' x 50 . ' ' x 50 . 'あ';
is(mime_eco($str, 'UTF-8'),
   'Subject: ' . 'x' x 50 . ' ' x 49 . "\n =?UTF-8?B?44GC?=",
   'Long SP (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'),
   'Subject: ' . 'x' x 50 . ' ' x 49 . "\n =?ISO-2022-JP?B?44GC?=",
   'Long SP (ISO-2022-JP)');


my $from = 'From: OKAZAKI Sakurako  <sakura@example.jp>';
$str = $from . '  (岡崎 桜子)';
is(mime_eco($str, 'UTF-8'),
   $from . '  (=?UTF-8?B?5bKh5bSOIOahnA==?=' . "\n "
   . '=?UTF-8?B?5a2Q?=)',
   'structured header (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   $from . '  (=?ISO-2022-JP?B?GyRCMiwbKEI=?=' . "\n "
   . '=?ISO-2022-JP?B?GyRCOmobKEIgGyRCOnk7UhsoQg==?=)',
   'structured header (ISO-2022-JP)');


$str = '    (あ)  (((あ)))  (あ  (あ))  (あ  (あ))    ';
is(mime_eco($str, 'UTF-8'),
   '    (=?UTF-8?B?44GC?=)  (((=?UTF-8?B?44GC?=)))  (=?UTF-8?B?44GC?= ' .
   "\n" .
   ' (=?UTF-8?B?44GC?=))  (=?UTF-8?B?44GC?=  (=?UTF-8?B?44GC?=))    ',
   'comment in comment (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   '    (=?ISO-2022-JP?B?GyRCJCIbKEI=?=)' .
   '  (((=?ISO-2022-JP?B?GyRCJCIbKEI=?=))) ' .
   "\n" .
   ' (=?ISO-2022-JP?B?GyRCJCIbKEI=?=  (=?ISO-2022-JP?B?GyRCJCIbKEI=?=)) ' .
   "\n" .
   ' (=?ISO-2022-JP?B?GyRCJCIbKEI=?=  (=?ISO-2022-JP?B?GyRCJCIbKEI=?=))    ',
   'comment in comment (ISO-2022-JP)');
