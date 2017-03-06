/*
  This file convert raw bitmap to bit font
  
  00 FF 00 FF FF FF 0 0 -> 01011100
  
*/

#include <math.h>
#include <fstream.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <stdlib.h>

ifstream file;
unsigned char a=0;
unsigned char ch;
ofstream fout;

void main(void)
{
  file.open("font(8x1504)(8x16).raw",ios::in|ios::binary);
  fout.open("font.fnt",ios::binary|ios::out|ios::trunc);

  for(unsigned int j = 0; j < 1504; ++j) {
    unsigned char i=1;
    a=0;
    while(i) {
      file.get(ch);
      if(!ch) {
        a+=i;
      }
      _asm {
        mov al, i
        shl al, 1
        mov i, al
      }
    }
    fout.put(a);
  }
  fout.close();
  file.close();
}
