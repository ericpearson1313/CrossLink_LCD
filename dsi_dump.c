#include <stdio.h>


unsigned char parity (unsigned long val)
{ // calc XOR parity bit of 24 bits
	unsigned long parity;
	parity = val & 0x00ffffff;
	parity ^= parity >> 12;
	parity ^= parity >> 6;
	parity ^= parity >> 3;
	parity ^= ( parity >> 2 ) ^ ( parity >> 1 );
	return( (unsigned char)(parity & 1) );
}

unsigned char mipi_ecc( unsigned char c0, unsigned char c1, unsigned char c2 )
{
	unsigned long hdr;
	unsigned char ecc;
	ecc = 0;
	hdr = c0 | (c1<<8) | (c2<<16);
	if(parity(hdr & 0b111100010010110010110111)) ecc|=0x01;           
	if(parity(hdr & 0b111100100101010101011011)) ecc|=0x02;
	if(parity(hdr & 0b011101001001101001101101)) ecc|=0x04;
	if(parity(hdr & 0b101110001110001110001110)) ecc|=0x08;
	if(parity(hdr & 0b110111110000001111110000)) ecc|=0x10;
	if(parity(hdr & 0b111011111111110000000000)) ecc|=0x20;
	return(ecc);
}

unsigned mipi_crc( unsigned char c, unsigned crc_in )
{
	unsigned crc, bit, tog, wrd;
	crc = crc_in; // init to 0xffff
	for( int ii = 0; ii < 8; ii++ ) {
		bit = (c >> ii) & 1;
		tog = ( crc & 1  ) ^ bit;
		wrd = ( tog ) ? 0x8408 : 0;
		crc = ( crc >> 1 ) ^ wrd;
	}
	return( crc );
/*
   function [15:0] crc_round;
        input d;
        input [15:0] cin;
        begin
            crc_round = {   cin[0] ^ d,
                            cin[15:12],
                            cin[11] ^ cin[0] ^ d,
                            cin[10:5],
                            cin[4] ^ cin[0] ^ d,
                            cin[3:1] };
        end
    endfunction
*/
}

int main( int argc, char **argv ) 
{
	FILE *lfp, *bmp;
	lfp = stdin;

	// Open up a BMP file and write header
	unsigned char header[54] = {
		0x42, 0x4d, //4D42
		0x36, 0x98, 0x3a, 0x00, //003A9836
		0x00, 0x00, //0000
		0x00, 0x00, //0000
		0x36, 0x00, 0x00, 0x00, //00000F36

		0x28, 0x00, 0x00, 0x00, //00000028
		0x20, 0x03, 0x00, 0x00, //00000320
		//0x40, 0x06, 0x00, 0x00, //00000640 bot->top
		0xC0, 0xF9, 0xFF, 0xFF, // top to bot
		0x01, 0x00, //0001
		0x18, 0x00, //0018;
		0x00, 0x00, 0x00, 0x00, //00000000
		0x00, 0x98, 0x3A, 0x00, //003A9800
		0xC3, 0x0E, 0x00, 0x00, //00000EC3
		0xC3, 0x0E, 0x00, 0x00, //00000EC3
		0x00, 0x00, 0x00, 0x00, //00000000
		0x00, 0x00, 0x00, 0x00 }; //00000000
	bmp = fopen("dsi.bmp", "wb");
	for( int ii = 0; ii < 54; ii++ )
		fputc( header[ii], bmp );
	

	
	// Read and dump DSI messages
	unsigned char c, c1, c2, c3, r, g, b;
	unsigned char ecc;
	unsigned crc;
	unsigned int len;
	c = fgetc( lfp );
	while( !feof( lfp ) ) {
		switch( c ) {
		// Synch Bytes ignore
		case 0x00:
		case 0xb8: // sync bytes
			break;
		// Short 4 bytes
		case 0x05:
		case 0x01:
		case 0x21:
			printf("%02x", c );
			c1 = fgetc( lfp );
			printf(" %02x", c1 );
			c2 = fgetc( lfp );
			printf(" %02x", c2 );
			c3 = fgetc( lfp );
			printf(" %02x", c3 );
			ecc = mipi_ecc( c, c1, c2 );
			if( ecc == c3 ) {
				printf(" OK\n");
			} else {
				printf(" ERR\n");
				fprintf( stderr, "ECC mismatch, stream %02x, calc %02x\n", c3, ecc );
			}
			break;
		// Long print
		case 0x29:
		case 0x39:
			// read header
			printf("%02x", c );
			c1 = fgetc( lfp );
			printf(" %02x", c1 );
			c2 = fgetc( lfp );
			printf(" %02x", c2 );
			c3 = fgetc( lfp );
			printf(" %02x", c3 );
			ecc = mipi_ecc( c, c1, c2 );
			if( ecc == c3 ) {
				printf(" OK");
			} else {
				printf(" ERR");
				fprintf( stderr, "ECC mismatch, stream %02x, calc %02x\n", c3, ecc );
			}
			// Read payload
			len = c1 + (c2<<8);
			crc = 0xffff;
			for( int ii = 0; ii < len; ii++ ) {
				c = fgetc( lfp );
				crc = mipi_crc( c, crc );
				printf(" %02x", c );
			}
			// Read CRC
			c1 = fgetc( lfp );
			printf(" %02x", c1 );
			c2 = fgetc( lfp );
			printf(" %02x", c2 );
			if( crc == (c1+(c2<<8)) ) {
				printf(" OK");
			} else {
				printf(" ERR");
				fprintf( stderr, "CRC mismatch, stream %04x, calc %04x\n", (c1+(c2<<8)), crc );
			}
			printf("\n" );
			break;
		// Long ignore
		case 0x09:
		case 0x19:
			// read header
			c1 = fgetc( lfp );
			c2 = fgetc( lfp );
			c3 = fgetc( lfp );
			ecc = mipi_ecc( c, c1, c2 );
			if( ecc == c3 ) {
			} else {
				fprintf( stderr, "ECC mismatch, stream %02x, calc %02x\n", c3, ecc );
			}
			// Read payload
			len = c1 + (c2<<8);;
			crc = 0xffff;
			for( int ii = 0; ii < len; ii++ ) {
				c = fgetc( lfp );
				crc = mipi_crc( c, crc );
			}
			// Read CRC
			c1 = fgetc( lfp );
			c2 = fgetc( lfp );
			if( crc == (c1+(c2<<8)) ) {
			} else {
				fprintf( stderr, "CRC mismatch, stream %04x, calc %04x\n", (c1+(c2<<8)), crc );
			}
			break;
		// Long pixel line, print and write bmp
		case 0x3E:
			// read header
			printf("%02x", c );
			c1 = fgetc( lfp );
			printf(" %02x", c1 );
			c2 = fgetc( lfp );
			printf(" %02x", c2 );
			c3 = fgetc( lfp );
			printf(" %02x", c3 );
			ecc = mipi_ecc( c, c1, c2 );
			if( ecc == c3 ) {
				printf(" OK");
			} else {
				printf(" ERR");
				fprintf( stderr, "ECC mismatch, stream %02x, calc %02x\n", c3, ecc );
			}
			// Pels
			len = c1 + (c2<<8);;
			crc = 0xffff;
			for( int ii = 0; ii < len; ii+= 3 ) {
				// Read RGB from DSI
				r = fgetc( lfp );
				g = fgetc( lfp );
				b = fgetc( lfp );
				printf(" %02x %02x, %02x", r, g, b );
				// Calc CRC
				crc = mipi_crc( r, crc );
				crc = mipi_crc( g, crc );
				crc = mipi_crc( b, crc );
				// Write BMP as BGR
				fputc( b, bmp );
				fputc( g, bmp );
				fputc( r, bmp );
			}
			// Read CRC
			c1 = fgetc( lfp );
			printf(" %02x", c1 );
			c2 = fgetc( lfp );
			printf(" %02x", c2 );
			if( crc == (c1+(c2<<8)) ) {
				printf(" OK");
			} else {
				printf(" ERR");
				fprintf( stderr, "CRC mismatch, stream %04x, calc %04x\n", (c1+(c2<<8)), crc );
			}
			printf("\n" );
			break;
		default:
			printf("Err: %02x\n", c );
			break;
		}
		c = fgetc( lfp );
	} 
	fclose( lfp );
	fclose( bmp );
	return( 0 );
}

			
