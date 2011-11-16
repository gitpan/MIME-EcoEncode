#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 20;
#use Test::More 'no_plan';
BEGIN { use_ok('MIME::EcoEncode') };

use Encode qw/from_to/;
use MIME::EcoEncode;

my $str;

$str = 'test';
is(mime_eco($str, 'UTF-8'), 'test', 'ASCII (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), 'test', 'ASCII (ISO-2022-JP)');

$str = "test\n";
is(mime_eco($str, 'UTF-8'), "test\n", 'ASCII+\n (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), "test\n", 'ASCII+\n (ISO-2022-JP)');

$str = 't12346789' x 8;
is(mime_eco($str, 'UTF-8'), $str, 'ASCII x 80 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), $str, 'ASCII x 80 (ISO-2022-JP)');

$str = 'Subject: ' . '123467890' x 8;
is(mime_eco($str, 'UTF-8'), "Subject:\n " . '123467890' x 8,
   "\'Subject: \'" . ' + ASCII x 80 (UTF-8)');
is(mime_eco($str, 'ISO-2022-JP'), "Subject:\n " . '123467890' x 8,
   "\'Subject: \'" . ' + ASCII x 80 (ISO-2022-JP)');


$str = '日本語あいうえおアイウエオ' x 2;
is(mime_eco($str, 'UTF-8'),
   "=?UTF-8?B?" .
   "5pel5pys6Kqe44GC44GE44GG44GI44GK44Ki44Kk44Km44Ko44Kq5pel5pys6Kqe?=\n" .
   " =?UTF-8?B?44GC44GE44GG44GI44GK44Ki44Kk44Km44Ko44Kq?=",
   'WideCharacter only (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "=?ISO-2022-JP?B?" .
   "GyRCRnxLXDhsJCIkJCQmJCgkKiUiJSQlJiUoJSpGfEtcOGwkIiQkGyhC?=\n" .
   " =?ISO-2022-JP?B?GyRCJCYkKCQqJSIlJCUmJSglKhsoQg==?=",
   'WideCharacter only (ISO-2022-JP)');


$str = "  Subject:  Re:  [XXXX 0123]  Re:  アa  イi  ウu  A-I-U\n";
is(mime_eco($str, 'UTF-8'),
   " Subject: Re: [XXXX 0123] Re: =?UTF-8?B?44KiYSDjgqRpIOOCpnU=?= A-I-U\n",
   '\s\s+ASCII+WideCharacter+\n (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   " Subject: Re: [XXXX 0123] Re: " .
   "=?ISO-2022-JP?B?GyRCJSIbKEJhIBskQiUkGyhCaSA=?=\n" .
   " =?ISO-2022-JP?B?GyRCJSYbKEJ1?= A-I-U\n",
   '\s\s+ASCII+WideCharacter+\n (ISO-2022-JP)');


$str = 'Subject: あいうえお アイウエオ ｱｲｳｴｵ A-I-U-E-O';
is(mime_eco($str, 'UTF-8'),
   "Subject: " .
   "=?UTF-8?B?44GC44GE44GG44GI44GKIOOCouOCpOOCpuOCqOOCqiDvvbHvvbI=?=\n" .
   " =?UTF-8?B?772z77207721?= A-I-U-E-O",
   'ASCII+WideCharacter+HankakuKana (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject: " .
   "=?ISO-2022-JP?B?GyRCJCIkJCQmJCgkKhsoQiAbJEIlIiUkJSYlKCUqGyhCIA==?=\n" .
   " =?ISO-2022-JP?B?GyhJMTIzNDUbKEI=?= A-I-U-E-O",
   'ASCII+WideCharacter+HankakuKana (ISO-2022-JP)');


$str = 'Subject: Re: あ A い I';
is(mime_eco($str, 'UTF-8', "|\n", 17),
   "Subject: Re:|\n =?UTF-8?B?44GC?=|\n A|\n =?UTF-8?B?44GE?=|\n I",
   '$lf="|\n", $bpf=17 (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP', "|\n", 31),
   "Subject: Re:|\n =?ISO-2022-JP?B?GyRCJCIbKEI=?=|\n A|\n" .
   " =?ISO-2022-JP?B?GyRCJCQbKEI=?=|\n I",
   '$lf="|\n", $bpf=31 (ISO-2022-JP)');


$str = 'Subject: Re: あ A い I う U え E お O';
is(mime_eco($str, 'UTF-8'),
   "Subject: " .
   "Re: =?UTF-8?B?44GC?= A =?UTF-8?B?44GE?= I =?UTF-8?B?44GG?= U\n" .
   " =?UTF-8?B?44GI?= E =?UTF-8?B?44GK?= O",
   'ASCII+WideCharacter (UTF-8)');
from_to($str, 'UTF-8', '7bit-jis');
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject: " .
   "Re: =?ISO-2022-JP?B?GyRCJCIbKEI=?= A =?ISO-2022-JP?B?GyRCJCQbKEI=?=\n" .
   " I =?ISO-2022-JP?B?GyRCJCYbKEI=?= U =?ISO-2022-JP?B?GyRCJCgbKEI=?= E\n" .
   " =?ISO-2022-JP?B?GyRCJCobKEI=?= O",
   'ASCII+WideCharacter (ISO-2022-JP)');
$MIME::EcoEncode::JCODE_COMPAT = 1;
is(mime_eco($str, 'ISO-2022-JP'),
   "Subject: " .
   "Re: =?ISO-2022-JP?B?GyRCJCIbKEI=?= A =?ISO-2022-JP?B?GyRCJCQbKEI=?=\n" .
   " I\n" .
   " =?ISO-2022-JP?B?GyRCJCYbKEI=?= U\n" .
   " =?ISO-2022-JP?B?GyRCJCgbKEI=?= E\n" .
   " =?ISO-2022-JP?B?GyRCJCobKEI=?= O",
   'ASCII+WideCharacter (JCODE_COMPAT=1)');
