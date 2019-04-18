#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <mosquittopp.h>

/* Test data taken from
 * http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt but modified for
 * updated standard (no 5, 6 byte lengths) */

void assert_invalid(const char *str)
{
	if(mosqpp::validate_utf8(str, strlen(str)) == 0){
		printf("ERROR assert_invalid: %s\n", str);
		exit(1);
	}
}

void assert_valid_len(const char *str, int len)
{
	if(mosqpp::validate_utf8(str, strlen(str)) != 0){
		printf("ERROR assert_valid: %s\n", str);
		exit(1);
	}
}

void assert_valid(const char *str)
{
	assert_valid_len(str, strlen(str));
}

int main(int argc, char *argv[])
{
	/* 1  Some correct UTF-8 text */
	assert_valid("You should see the Greek word 'kosme':       \"κόσμε\"");

	/* 2  Boundary condition test cases */
	/* 2.1  First possible sequence of a certain length */
	assert_valid_len("2.1.1  1 byte  (U-00000000):        \"\0\"", 39);
	assert_valid("2.1.2  2 bytes (U-00000080):        \"\"");
	assert_valid("2.1.3  3 bytes (U-00000800):        \"ࠀ\"");
	assert_valid("2.1.4  4 bytes (U-00010000):        \"𐀀\"");

	/* 2.2  Last possible sequence of a certain length */

	assert_valid("2.2.1  1 byte  (U-0000007F):        \"\"");
	assert_valid("2.2.2  2 bytes (U-000007FF):        \"߿\"");
	assert_valid("2.2.3  3 bytes (U-0000FFFF):        \"￿\"");
	// FIXME assert_valid("2.2.4  4 bytes (U-001FFFFF):        \"����\"");

	/* 2.3  Other boundary conditions */

	assert_valid("2.3.1  U-0000D7FF = ed 9f bf = \"퟿\"");
	assert_valid("2.3.2  U-0000E000 = ee 80 80 = \"\"");
	assert_valid("2.3.3  U-0000FFFD = ef bf bd = \"�\"");
	assert_valid("2.3.4  U-0010FFFF = f4 8f bf bf = \"􏿿\"");
	/* This used to be valid in pre-2003 utf-8 */
	assert_invalid("2.3.5  U-00110000 = f4 90 80 80 = \"����\"");

	/* 3  Malformed sequences */
	/* 3.1  Unexpected continuation bytes */
	assert_invalid("3.1.1  First continuation byte 0x80: \"�\"");
	assert_invalid("3.1.2  Last  continuation byte 0xbf: \"�\"");
	assert_invalid("3.1.3  2 continuation bytes: \"��\"");
	assert_invalid("3.1.4  3 continuation bytes: \"���\"");
	assert_invalid("3.1.5  4 continuation bytes: \"����\"");
	assert_invalid("3.1.6  5 continuation bytes: \"�����\"");
	assert_invalid("3.1.7  6 continuation bytes: \"������\"");
	assert_invalid("3.1.8  7 continuation bytes: \"�������\"");

	/* 3.1.9  Sequence of all 64 possible continuation bytes (0x80-0xbf): */
	assert_invalid("����������������");
    assert_invalid("����������������");
    assert_invalid("����������������");
    assert_invalid("����������������\"");

	/* 3.2  Lonely start characters */

	/* 3.2.1  All 32 first bytes of 2-byte sequences (0xc0-0xdf),
       each followed by a space character: */
	assert_invalid("\"� � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � \"");

	/* 3.2.2  All 16 first bytes of 3-byte sequences (0xe0-0xef),
       each followed by a space character: */
	assert_invalid("\"� � � � � � � � � � � � � � � � \"");

	/* 3.2.3  All 8 first bytes of 4-byte sequences (0xf0-0xf7),
       each followed by a space character: */
	assert_invalid("\"� � � � � � � � \"");

	/* 3.2.4  All 4 first bytes of 5-byte sequences (0xf8-0xfb),
       each followed by a space character: */
	assert_invalid("\"� � � � \"");

	/* 3.2.5  All 2 first bytes of 6-byte sequences (0xfc-0xfd),
       each followed by a space character: */
	assert_invalid("\"� � \"");

	/* 3.3  Sequences with last continuation byte missing

	All bytes of an incomplete sequence should be signalled as a single
	malformed sequence, i.e., you should see only a single replacement
	character in each of the next 10 tests. (Characters as in section 2) */

	assert_invalid("3.3.1  2-byte sequence with last byte missing (U+0000):     \"�\"");
	assert_invalid("3.3.2  3-byte sequence with last byte missing (U+0000):     \"��\"");
	assert_invalid("3.3.3  4-byte sequence with last byte missing (U+0000):     \"���\"");
	assert_invalid("3.3.4  5-byte sequence with last byte missing (U+0000):     \"����\"");
	assert_invalid("3.3.5  6-byte sequence with last byte missing (U+0000):     \"�����\"");
	assert_invalid("3.3.6  2-byte sequence with last byte missing (U-000007FF): \"�\"");
	assert_invalid("3.3.7  3-byte sequence with last byte missing (U-0000FFFF): \"�\"");
	assert_invalid("3.3.8  4-byte sequence with last byte missing (U-001FFFFF): \"���\"");
	assert_invalid("3.3.9  5-byte sequence with last byte missing (U-03FFFFFF): \"����\"");
	assert_invalid("3.3.10 6-byte sequence with last byte missing (U-7FFFFFFF): \"�����\"");

	/* 3.4  Concatenation of incomplete sequences

		All the 10 sequences of 3.3 concatenated, you should see 10 malformed
		sequences being signalled:*/

	assert_invalid("\"�����������������������������\"");

	/* 3.5  Impossible bytes

		The following two bytes cannot appear in a correct UTF-8 string */

	assert_invalid("3.5.1  fe = \"�\"");
	assert_invalid("3.5.2  ff = \"�\"");
	assert_invalid("3.5.3  fe fe ff ff = \"����\"");

	/* 4  Overlong sequences

		The following sequences are not malformed according to the letter of
		the Unicode 2.0 standard. However, they are longer then necessary and
		a correct UTF-8 encoder is not allowed to produce them. A "safe UTF-8
		decoder" should reject them just like malformed sequences for two
		reasons: (1) It helps to debug applications if overlong sequences are
		not treated as valid representations of characters, because this helps
		to spot problems more quickly. (2) Overlong sequences provide
		alternative representations of characters, that could maliciously be
		used to bypass filters that check only for ASCII characters. For
		instance, a 2-byte encoded line feed (LF) would not be caught by a
		line counter that counts only 0x0a bytes, but it would still be
		processed as a line feed by an unsafe UTF-8 decoder later in the
		pipeline. From a security point of view, ASCII compatibility of UTF-8
		sequences means also, that ASCII characters are *only* allowed to be
		represented by ASCII bytes in the range 0x00-0x7f. To ensure this
		aspect of ASCII compatibility, use only "safe UTF-8 decoders" that
		reject overlong UTF-8 sequences for which a shorter encoding exists. */

	/* 4.1  Examples of an overlong ASCII character

		With a safe UTF-8 decoder, all of the following five overlong
		representations of the ASCII character slash ("/") should be rejected
		like a malformed UTF-8 sequence, for instance by substituting it with
		a replacement character. If you see a slash below, you do not have a
		safe UTF-8 decoder! */

	assert_invalid("4.1.1 U+002F = c0 af             = \"��\"");
	assert_invalid("4.1.2 U+002F = e0 80 af          = \"���\"");
	assert_invalid("4.1.3 U+002F = f0 80 80 af       = \"����\"");
	assert_invalid("4.1.4 U+002F = f8 80 80 80 af    = \"�����\"");
	assert_invalid("4.1.5 U+002F = fc 80 80 80 80 af = \"������\"");

	/* 4.2  Maximum overlong sequences

		Below you see the highest Unicode value that is still resulting in an
		overlong sequence if represented with the given number of bytes. This
		is a boundary test for safe UTF-8 decoders. All five characters should
		be rejected like malformed UTF-8 sequences. */

	assert_invalid("4.2.1  U-0000007F = c1 bf             = \"��\"");
	assert_invalid("4.2.2  U-000007FF = e0 9f bf          = \"���\"");
	assert_invalid("4.2.3  U-0000FFFF = f0 8f bf bf       = \"����\"");
	assert_invalid("4.2.4  U-001FFFFF = f8 87 bf bf bf    = \"�����\"");
	assert_invalid("4.2.5  U-03FFFFFF = fc 83 bf bf bf bf = \"������\"");

	/* 4.3  Overlong representation of the NUL character

		The following five sequences should also be rejected like malformed
		UTF-8 sequences and should not be treated like the ASCII NUL
		character. */

	assert_invalid("4.3.1  U+0000 = c0 80             = \"��\"");
	assert_invalid("4.3.2  U+0000 = e0 80 80          = \"���\"");
	assert_invalid("4.3.3  U+0000 = f0 80 80 80       = \"����\"");
	assert_invalid("4.3.4  U+0000 = f8 80 80 80 80    = \"�����\"");
	assert_invalid("4.3.5  U+0000 = fc 80 80 80 80 80 = \"������\"");

	/* 5  Illegal code positions

		The following UTF-8 sequences should be rejected like malformed
		sequences, because they never represent valid ISO 10646 characters and
		a UTF-8 decoder that accepts them might introduce security problems
		comparable to overlong UTF-8 sequences. */

	/* 5.1 Single UTF-16 surrogates */

	assert_invalid("5.1.1  U+D800 = ed a0 80 = \"�\"");
	assert_invalid("5.1.2  U+DB7F = ed ad bf = \"�\"");
	assert_invalid("5.1.3  U+DB80 = ed ae 80 = \"�\"");
	assert_invalid("5.1.4  U+DBFF = ed af bf = \"�\"");
	assert_invalid("5.1.5  U+DC00 = ed b0 80 = \"�\"");
	assert_invalid("5.1.6  U+DF80 = ed be 80 = \"�\"");
	assert_invalid("5.1.7  U+DFFF = ed bf bf = \"�\"");

	/* 5.2 Paired UTF-16 surrogates */

	assert_invalid("5.2.1  U+D800 U+DC00 = ed a0 80 ed b0 80 = \"��\"");
	assert_invalid("5.2.2  U+D800 U+DFFF = ed a0 80 ed bf bf = \"��\"");
	assert_invalid("5.2.3  U+DB7F U+DC00 = ed ad bf ed b0 80 = \"��\"");
	assert_invalid("5.2.4  U+DB7F U+DFFF = ed ad bf ed bf bf = \"��\"");
	assert_invalid("5.2.5  U+DB80 U+DC00 = ed ae 80 ed b0 80 = \"��\"");
	assert_invalid("5.2.6  U+DB80 U+DFFF = ed ae 80 ed bf bf = \"��\"");
	assert_invalid("5.2.7  U+DBFF U+DC00 = ed af bf ed b0 80 = \"��\"");
	assert_invalid("5.2.8  U+DBFF U+DFFF = ed af bf ed bf bf = \"��\"");

	/* 5.3 Noncharacter code positions

		The following "noncharacters" are "reserved for internal use" by
		applications, and according to older versions of the Unicode Standard
		"should never be interchanged". Unicode Corrigendum #9 dropped the
		latter restriction. Nevertheless, their presence in incoming UTF-8 data
		can remain a potential security risk, depending on what use is made of
		these codes subsequently. Examples of such internal use:

		- Some file APIs with 16-bit characters may use the integer value -1
		= U+FFFF to signal an end-of-file (EOF) or error condition.

		- In some UTF-16 receivers, code point U+FFFE might trigger a
		byte-swap operation (to convert between UTF-16LE and UTF-16BE).

		With such internal use of noncharacters, it may be desirable and safer
		to block those code points in UTF-8 decoders, as they should never
		occur legitimately in incoming UTF-8 data, and could trigger unsafe
		behaviour in subsequent processing.

		Particularly problematic noncharacters in 16-bit applications: */

	assert_valid("5.3.1  U+FFFE = ef bf be = \"￾\"");
	assert_valid("5.3.2  U+FFFF = ef bf bf = \"￿\"");

	/* Other noncharacters: */

	assert_valid("5.3.3  U+FDD0 .. U+FDEF = \"﷐﷑﷒﷓﷔﷕﷖﷗﷘﷙﷚﷛﷜﷝﷞﷟﷠﷡﷢﷣﷤﷥﷦﷧﷨﷩﷪﷫﷬﷭﷮﷯\"");

	/* 5.3.4  U+nFFFE U+nFFFF (for n = 1..10) */

	assert_valid("\"🿾🿿𯿾𯿿𿿾𿿿񏿾񏿿񟿾񟿿񯿾񯿿񿿾񿿿򏿾򏿿򟿾򟿿򯿾򯿿򿿾򿿿󏿾󏿿󟿾󟿿󯿾󯿿󿿾󿿿􏿾􏿿\"");


	return 0;
}
