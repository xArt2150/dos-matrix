;all functions return result in register ax
masm
.model small
.stack 500h

.n  equ 0dh
_32 equ db 66h
_00 equ dw 0000h

wait_retrace macro
local a
  push dx
  mov  dx, 3dah
a:
  in  al, dx
  and al, 08h
  jz  a
  pop dx
endm

screen_off macro
  cli
  push dx
  mov  dx, 3c4h
  mov  al, 1
  out  dx, al
  inc  dx
  in   al, dx
  or   al, 00100000b
  out  dx, al
  pop  dx
  sti
endm

screen_on macro
  cli
  push dx
  mov  dx, 3c4h
  mov  al, 1
  out  dx, al
  inc  dx
  in   al, dx
  and  al, 11011111b
  out  dx, al
  pop  dx
  sti
endm

RGB struc
  r db ?
  g db ?
  b db ?
; _reserved db ? ;for align
RGB ends

VgaInfoBlock struc
  VESASignature db "VBE2"
  VESAVersion   dw ?
  OEMStringPtr  dd ?
  Capabilities  db 4 dup (?)
  VideModePtr   dd ?
  TotalMemory   dw ?

  oemsoftwarerev    dw ?
  oemvendornameptr  dd ?
  oemproductnameptr dd ?
  oemproductrevptr  dd ?
  Reserved          db 222 dup (?)
  oemdata           db 256 dup (?)
VgaInfoBlock ends

ModeInfoBlock struc
  ;Mandatory information for all VBE revisions
  ModeAttributes   dw ?
  WinAAttributes   db ?
  WinBAttributes   db ?
  WinGranularity   dw ?
  WinSize          dw ?
  WinASegment      dw ?
  WinBSegment      dw ?
  WinFunctPtr      dd ?
  BytesPerScanLine dw ?

  ;Mandatory information for VBE 1.2 and above
  XResolution    dw ?
  YResolution    dw ?
  XCharSize      db ?
  YCharSize      db ?
  NumberOfPlanes db ?
  BitsPerPixel   db ?
  NumberOfBanks  db ?
  MemoryModel    db ?
  BankSize       db ?
  NumberOfImagePages db ?
  Reserved0      db 1

  ;Direct Color fields (required for direct/6 and YUV/7 memory models)
  RedMaskSize         db ?
  RedFieldPosition    db ?
  GreenMaskSize       db ?
  GreenFieldPosition  db ?
  BlueMaskSize        db ?
  BlueFieldPosition   db ?
  RsvdMaskSize        db ?
  RsvdFieldPosition   db ?
  DirectColorModeInfo db ?

  ;Mandatory information for VBE 2.0 and above
  PhysBasePtr dd ?
  Reserved1   dd 0
  Reserved2   dw 0

  ;Mandatory information for VBE 3.0 and above
  LinButesPerScanLine   dw ?
  BnkNumberOfImagePages db ?
  LinNumberOfImagePages db ?
  LinRedMaskSize        db ?
  LinRedFieldPosition   db ?
  LinGreenMaskSize      db ?
  LinGreenFieldPosition db ?
  LinBlueMaskSize       db ?
  LinBlueFieldPosition  db ?
  LinRsvdMaskSize       db ?
  LinRsvdFieldPosition  db ?
  MaxPixelClock         dd ?

  Reserved3 db 189 dup (?)
ModeInfoBlock ends

.data
;----------------------
;this section containe the images of chars
;здесь будет шрифт
;char 8x14
db 528 dup (0)
db 1504 dup (?)

;----------------------
;back buffer for matrix
;временный буфер
matrix db 64*2*30 dup (0)

;-----------------------------
;|1|0|0|1|0|1|1|1|0|1|0|0|0|1| - 1 есть символ
;|0|1|0|1|0|1|1|1|0|1|1|0|0|1| - 0 нет символа
;|1|0|0|1|0|1|1|1|0|1|0|0|1|1| - положение символа на экране:
;|1|0|0|1|0|1|0|1|0|1|1|0|1|1| x = col * 10
;|1|0|1|0|0|1|1|0|0|1|0|0|0|1| y = row * 16 + смещение (цикл полного сдвига вниз)
;-----------------------------
;+ (0-16) - смещение таблицы на экране
;----------------------
vgainfo VgaInfoBlock <>
modeinfo ModeInfoBlock <>
color RGB <>
db 10 dup (?)
mas    db "Hello!",0dh,"How are you?",0dh,"My name is Artsem",0
press  db 0dh,"Press any key to continue.",0
x      dw 0
y      dw 0
xres   dw 160
yres   dw 25
attrib db 0ah
char   db 0
val    dw 0
seed1  dw 13h
seed2  dw 4h

xg_res dw 640
yg_res dw 480
sss    dd 65536
temp   dd ?
tempw  dw ?
last_k dw -1

_signature db "VESA Signature:  ",0
_version   db "VESA Version:    ",0
_memory    db "Total memory:    ",0
_nBanks    db "Number of banks: ",0
_BankSize  db "Bank size:       ",0
_res       db "About 640x480x32:",0dh,0
_error     db "Error! Press any key to exit",0
_exit      db "Program terminated. Press any key to continue...",0
_copyright db "Author: Korolyov Artyom PO521. Press any key to continue...",0
_image     db "back.raw",0
_font      db "font.fnt",0
_a         db "Note: this is a demo!",0

.code
;-------------------------------------------------
load_font proc
  push dx
  push cx
  push bx

  mov ax, 3d00h
  mov dx, offset _font
  int 21h

  mov bx, ax
  mov ah, 3fh
  mov dx, 528
  mov cx, 1504
  int 21h

  mov ah, 3eh
  int 21h

  pop bx
  pop cx
  pop dx
  ret
endp
;---------------------------------------------------------------------------------------
calc_graphics_offset proc _x:WORD, _y:WORD ;uses ax - y, bx - x; return result in ax
  push bp
  mov bp, sp

  _32
  sub dx, dx
  _32
  sub ax, ax
  mov ax, _y
  _32
  mov bx, ax
  _32
  ; shl ax, 9
  db 0c1h
  db 0e0h
  db 09h
  _32
  ; shl bx, 7
  db 0c1h
  db 0e3h
  db 07h
  _32
  add ax, bx
  mov dx, _x
  _32
  add ax, dx
  _32
  mov bx, ax
  _32
  ; shr ax, 16
  db 0c1h
  db 0e8h
  db 10h
  mov dx, ax
  _32
  ; shl ax, 16
  db 0c1h
  db 0e0h
  db 10h
  _32
  sub bx, ax
  mov bp, bx
  xor bx, bx
  cmp last_k, dx
  je _next
  mov last_k, dx
  call dword ptr offset modeinfo.WinFunctPtr
  _next:
  mov ax, bp ;d

  pop bp
  ret 4
endp
;---------------------------------------------------------------------------------------
clear_text_screen proc
  push es
  push cx
  push dx
  push bx

  mov ax, 0b800h
  mov es, ax

  mov cx, 2000
  xor dx,dx
  xor bx,bx
  @@cl_up:
    mov es:[bx], dx
    inc bx
    inc bx
  loop @@cl_up

  pop bx
  pop dx
  pop cx
  pop es
  mov x, 0
  mov y, 0
  ret
endp
;---------------------------------------------------------------------------------------
;calculate offset in video buffer
calc_offset proc
  push bx
  mov  ax, y
  mov  bx, ax
  shl  ax, 7
  shl  bx, 5
  add  ax, bx
  add  ax, x
  pop  bx
  ret
endp
;---------------------------------------------------------------------------------------
;this function return the length of the string, including zero symbol at the end of the string
StrLength proc ptStr:WORD
  push bp
  mov  bp,sp
  push si
  push cx

  mov si, [bp + 4]
  xor cx,cx
  @@a10:
    lodsb
    inc cx
    cmp al, 0
  jne @@a10

  mov ax, cx

  pop cx
  pop si
  pop bp

  ret 2
endp
;---------------------------------------------------------------------------------------
;convert 16bit integer value to ASCII string
inttostr proc ptStr:WORD, Value:WORD
  push bp
  mov  bp, sp
  push es
  push di
  push si
  push cx
  push dx

  mov ax, @data
  mov es, ax

  mov di, ptStr
  mov si, di
  mov ax, Value
  mov cx, 10

  @@first:
  cmp ax, 10
  jb @@last
  xor dx, dx
  div cx
  or  dl, 30h
  mov [di], dl
  inc di
  jmp @@first

  @@last:
  or  al, 30h
  mov [di], al
  mov byte ptr [di+1],0

  ;reverse

  @@rev:
  cmp di, si
  jbe @@end

  mov dl, [di]
  mov al, [si]
  mov [di], al
  mov [si], dl
  dec di
  inc si
  jmp @@rev

  @@end:

  pop dx
  pop cx
  pop si
  pop di
  pop es
  pop bp
  ret 4
endp

;-------------------------------------------------------------------------------------------
;write null-terminated string to screen that in text mode
write0 PROC ptStr:WORD
  push bp
  mov  bp, sp
  push es
  push si
  push di
  push dx

  mov ax, 0b800h
  mov es, ax
  mov si, [bp + 4]

  call calc_offset
  mov  di, ax
  mov  dh, attrib

  @@a1:
    mov dl, ds:[si]
  cmp dl, 0
  je @@a15
    cmp dl, 0dh
    jne @@a14
      mov x, 0
      inc y
      call calc_offset
      mov di, ax
      inc si
      jmp @@a1
  @@a14:mov es:[di], dx
    inc si
    add di, 2
    add x, 2
  jmp @@a1
@@a15:
  pop dx
  pop di
  pop si
  pop es
  pop bp
  ret 2
ENDP
;-------------------------------------------------------------------------------------------
;write fixed number of charachers in string to screen in text mode
write PROC ptStr:WORD, N:WORD
  push bp
  mov  bp, sp
  push es
  push si
  push di
  push cx

  mov  ax, 0b800h
  push ax
  pop  es
  mov  si, [bp + 4]

  call calc_offset
  mov  di, ax
  mov  ah, attrib
  mov  cx, [bp + 6]
  add  x, cx
  @@a2:
    mov al, ds:[si]
    mov es:[di], ax
    inc si
    add di, 2
  loop @@a2
  
  a14:
  
  pop cx
  pop di
  pop si
  pop es
  pop bp

  ret 4
endp

;-----------------------------------------------------------------------------
;get information about vesa
do_vesa_info proc
  mov ax, @data    ;load address of data segment
  mov es, ax      ;and copy it to es
  mov ax, 4f00h    ;vesa function
  mov di, offset vgainfo
  int 10h      ;get vesainfo

  ;output text - VESA Signature
  mov  bx, offset _signature
  push bx
  call write0

  ;output vesa signature
  mov  attrib, 0ch  ;attribut of text
  mov  ax, 4    ;number of char to out
  push ax
  mov  bx, offset vgainfo.VESASignature
  push bx
  call write

  ;output text - VESA Version
  mov  attrib, 0ah
  mov  x, 0    ;go to new line
  inc  y
  mov  bx, offset _version
  push bx
  call write0

  ;conver int version to string
  mov  attrib, 0ch
  mov  ax, vgainfo.VESAVersion
  xchg ah, al
  push ax
  mov  bx, offset mas
  push bx
  call inttostr

  ;out version
  push bx
  call write0

  ;out text - Total memory
  mov  attrib, 0ah
  mov  x, 0
  inc  y
  mov  bx, offset _memory
  push bx
  call write0

  mov  ax, vgainfo.TotalMemory
  ;shl ax, 6
  push ax
  mov  bx, offset mas
  push bx
  call inttostr

  mov  attrib, 0ch
  push bx
  call write0

  mov  bx, offset vgainfo.oemvendornameptr
  mov  dx, [bx]
  mov  ax, [bx+2]
  push ds
  mov  ds, ax

  push dx
  mov  x,0
  inc  y
  call write0
  mov  dx, [bx+4]
  mov  ax, [bx+6]
  mov  ds, ax
  push dx
  call write0
  mov  dx, [bx+8]
  mov  ax, [bx+10]
  mov  ds, ax
  push dx
  call write0

  xor ax,ax
  int 16h

  call clear_text_screen

  mov  attrib, 00011001b
  mov  bx, offset _res
  push bx
  call write0

  call do_mode_info

  pop ds

  ret
endp
;------------------------------------------------------------------------------
;get information about video mode
do_mode_info proc ;mode:word
  push bp
  push cx
  push es
  push di
  push bx

  mov attrib, 0ch

  mov ax, @data
  mov es, ax
  mov ax, 4f01h
  mov cx, 112h
  mov di, offset modeinfo
  int 10h

  mov bx, offset mas

  push modeinfo.xresolution
  push bx
  call inttostr
  push bx
  call write0

  mov  al, 'x'
  mov  ah, 0h
  mov  word ptr [bx], ax
  push bx
  call write0

  push modeinfo.yresolution
  push bx
  call inttostr
  push bx
  call write0

  mov  al, 'x'
  mov  ah, 0h
  mov  word ptr [bx], ax
  push bx
  call write0

  mov al, modeinfo.bitsperpixel
  cbw
  push ax
  push bx
  call inttostr
  push bx
  call write0

  pop bx
  pop di
  pop es
  pop cx
  pop bp
  ret
endp
;-----------------------------------------------------------------
;put pixel
put_pixel proc _x:word, _y:word, lpColor:word
  push bp
  mov  bp, sp
  push bx
  push dx
  push es
  push si

  mov si, lpColor
    
  mov  ax, _y  ;_y
  mov  bx, _x  ;_x
  push ax
  push bx
  call calc_graphics_offset

  mov bx, ax
  mov ax, 0a000h
  mov es, ax

  mov dx, 3c4h
  mov ax, 0102h  ;b
  out dx, ax
  mov al, byte ptr ds:[si+2]
  mov es:[bx], al
  mov ax, 0202h  ;g
  out dx, ax
  mov al, byte ptr ds:[si+1]
  mov es:[bx], al
  mov ax, 0402h  ;r
  out dx, ax
  mov al, byte ptr ds:[si]
  mov es:[bx], al

  pop si
  pop es
  pop dx
  pop bx
  pop bp
  ret 6
endp
;----------------------------------------------------------------
;put image on screen at x,y
;first two words in RowData must be _width and _height
put_image proc _x:word, _y:word, lpStr:word
  push bp
  mov  bp, sp
  push bx
  push cx
  push dx
  push di

  mov ax, 3d00h
  mov dx, lpStr
  int 21h

  mov si, offset mas

  mov bx, ax
  mov ah, 3fh
  mov dx, si
  mov cx, 2
  int 21h

  add si, 2
  mov ah, 3fh
  mov dx, si
  int 21h

  mov di, _x

  mov cx, ds:[si]
.img1: ;x - di
  push cx
  mov  si, offset mas
  mov  cx, ds:[si]
.img2:
  push cx
  mov  ah, 3fh
  mov  dx, offset color
  mov  cx, 3
  int  21h
  pop  cx

  push dx
  mov  ax, _y
  push ax
  push di
  call put_pixel
  inc  di
loop .img2
  pop cx
  inc _y
  mov di, _x
loop .img1
  pop di
  pop dx
  pop cx
  pop bx
  pop bp
  ret 6
endp
;----------------------------------------------------------------
;draw a char
put_char proc _x:word, _y:word, lpChar:word, lpColor:word
  push bp
  mov bp, sp
  push si

  xor ax, ax
  mov al, byte ptr [lpChar]
  shl ax, 4

  mov si, ax
  mov cx, 16
  mov bx, _x
  mov dx, _y
.putchar1:
  mov al, byte ptr ds:[si]
  push cx
  mov cx, 8
.putchar2:
  shr al, 1
  jnc .putcharend
  push ax
  push lpColor
  push dx
  push bx
  call put_pixel
  pop ax
.putcharend:
  inc bx
loop .putchar2
  pop cx
  inc dx
  mov bx, _x
  inc si
loop .putchar1

   pop si
  pop bp
  ret 8
endp
;----------------------------------------------------------------
;draw string
g_write0 proc _x:word, _y:word, lpStr:word, lpColor:word
  push bp
  mov  bp, sp
  push si
  push dx
  push bx

  xor ax, ax
  mov si, lpStr
  mov dx, _x
  mov bx, _y

.g_write0_start:
  mov al, byte ptr ds:[si]
  cmp al, 0
  je .g_write0_end
  cmp al, 0dh
  jne .g_write0_next
  add bx, 15
  mov dx, _x
  inc si
  mov al, byte ptr ds:[si]
.g_write0_next:
  push bx
  push dx
  push lpColor
  push ax
  push bx
  push dx
  call put_char
  pop dx
  pop bx
  add dx, 8
  inc si
  jmp .g_write0_start
.g_write0_end:
  pop bx
  pop dx
  pop si
  pop bp
  ret 8
endp
;----------------------------------------------------------------
;set video mode 112 (640x480x16.8M)
set_mode proc
  ;установка видео режима 112h
  ;при ошибке вывод соответствующего сообщени¤
  ;иначе сбор сведений в modeinfo
  ;должна вызыватьс¤ до начала процесса рисовани¤
  ;и после определени¤ хар-ик всех доступных видеорежимов

  ;выключаем экран
  screen_off

  push bx
  mov  ax, 4f02h
  mov  bx, 112h
  int  10h
  cli
  ;устанавливаем режим байтов контроллера ЁЋ“
  push dx
  mov  dx, 3d4h
  mov  al, 17h
  out  dx, al
  inc  dx
  in   al, dx
  or   al, 01000000b
  out  dx, al

  ;сбрасываем режим "двойное слово" контроллера ЁЋ“
  dec dx
  mov al, 14h
  out dx, al
  inc dx
  in  al, dx
  and al, 10111111b
  out dx, al
  
  ;сбрасываем режим "цепочка 4"
  mov dx, 3c4h
  mov al, 4
  out dx, al
  inc dx
  in  al, dx
  and al, 11110111b
  out dx, al
  
  ;разрешаем все плоскости дл¤ записи
  dec dx
  mov al, 2
  out dx, al
  inc dx
  or  al, 00001111b
  out dx, al
  sti
  pop dx

  ;включаем экран
  screen_on
  push es
  push cx
  push di

  mov ax, @data
  mov es, ax
  mov ax, 4f01h
  mov cx, 112h
  mov di, offset modeinfo
  int 10h

  mov color.r, 0
  mov color.g, 0
  mov color.b, 255
  mov dx, offset color

  mov ax, offset _nBanks
  sub cx,cx

  push dx
  push ax
  push cx
  push cx
  call g_write0

  sub ax, ax
  mov al, modeinfo.numberofbanks
  cbw
  mov bx, offset mas

  push ax
  push bx
  call inttostr

  push dx
  push bx
  mov  ax, 200
  push cx
  push ax
  call g_write0

  mov ax, offset _a
  mov bx, 0
  add cx, 20

  push dx
  push ax
  push cx
  push bx
  call g_write0

  pop di
  pop cx
  pop es
  
  xor ax,ax
  jmp set_mode_exit
  
  set_mode_error_exit:
  mov ax, 3
  int 10h
  mov bx, offset _error
  mov y, 0
  mov x, 0

  push bx
  call write0

  xor ax,ax
  int 16h
  mov ax, 0ffffh
  
  set_mode_exit:
  pop bx
  ret
endp
;------------------------------------------
;show splash
splash proc
  mov  bx, offset _image
  push bx
  sub  bx, bx
  push bx
  push bx
  call put_image

  mov color.b, 255
  mov color.r, 0
  mov color.g, 0
  mov bx, offset color
  push bx
  mov bx, offset _copyright
  push bx
  mov bx, 465
  push bx
  sub bx, bx
  push bx
  call g_write0

  sub ax,ax
  int 16h
  ret
endp
; generate random value
rand proc
  mov  cx, seed1
  mov  bx, seed2
  mov  dx, 015ah
  mov  ax, 4e35h
  push si
  xchg si, ax
  xchg dx, ax
  test ax,ax
  je  _111
  mul  bx
_111:
  jcxz _222
  xchg cx, ax
  mul  si
  add  ax, cx
_222:
  xchg si, ax
  mul  bx
  add  dx, si
  pop  si
  add  ax, 0001h
  adc  dx, 0000h
  mov  seed1, dx
  mov  seed2, ax
  mov  ax, seed1
  cwd
  ret
endp
;------------------------------------------
;fill first line
fill_line proc
;random x
  call rand
  and ax, 003fh
  mov x, ax
;random char
  call rand
  and ax, 003fh
  add ax, 59
  mov char, al
;clear first line (note: only for test!!!)
  mov cx, 32
_32
  sub ax, ax
  mov si, offset matrix

_f1:
_32
  mov word ptr ds:[si], ax
  add si, 4
loop _f1

  mov ax, x
  shl ax, 1
  add ax, offset matrix
  mov si, ax
  mov al, char
  mov ah, 255
  mov word ptr [si], ax

  mov ax, x
  mov bx, ax
  shl ax, 3
  shl bx, 1
  add ax, bx

  mov color.r, 0
  mov color.g, 255
  mov color.b, 0
  mov bx, offset color

  sub dx, dx
  mov dl, char
  sub cx, cx

  push bx
  push dx
  push cx
  push ax
  call put_char
    
  ret
endp

scroll proc
  mov cx, 64*28+1
  mov si, offset matrix
  mov bx, 64*2*28
_scroll1:
  mov ax, [si+bx]
  cmp ah, 255
  jne _scrnext
  push si
  push bx
  push cx
  call rand
  and ax, 003fh
  add ax, 59
  pop cx
  pop bx
  pop si
  mov ah, 255
  mov [si+bx+128],ax
_scrnext:
  mov [si+bx+128],ax
  sub bx, 2
loop _scroll1

  ret
endp

;предназначалась дл¤ организации хвоста у букв, но ввиду тормознутости
;программы в реальном режиме пришлось об этом забыть
grad proc
  call rand
  and ax, 3fh
  mov x, ax
  call rand
  and ax, 3fh
  mov char, ax
  call rand
  and ax, 11111111b
  mov y, ax
  call rand
  and ax, 11111111b
  mov attrib, ax
  ret
endp

;очистка экрана в графическом режиме
clear proc
  mov ax, 0a000h
  mov es, ax
  sub dx,dx
  sub bx, bx
  call dword ptr offset modeinfo.WinFunctPtr
  mov dx, 3c4h
  mov ax, 0702h  ;all
  out dx, ax
  sub dx,dx

_clear2:
  sub di, di
  _32
  sub ax, ax
  sub cx, cx
_clear1:
  _32
  mov es:[di], ax
  add di,4
  inc cx
  cmp cx, 16384
  jne _clear1
  sub bx, bx
  inc dx
  call dword ptr offset modeinfo.WinFunctPtr
  cmp dx, 5
  jne _clear2

  sub dx,dx
  sub bx, bx
  call dword ptr offset modeinfo.WinFunctPtr
  ret
endp

;обеспечивает плавный сдвиг всего экрана вниз на 16 пикселей
_out proc
  mov y, 0
  mov si, offset matrix
  mov cx, 2
  mov tempw, 0

_out3:

  push cx
  call clear
  mov ax, tempw
  mov y, ax
  add tempw, 8
  mov cx, 29
  mov bx, 0
wait_retrace
_out2:
  push cx
  mov x, 0
  mov cx, 64
_out1:
  mov dx, ds:[si+bx]
  inc bx
  inc bx


  mov ax, offset color
  mov color.r, 0
  mov color.g, dh
  mov color.b, 0
  sub dh,dh

  push cx
  push bx

  push ax
  push dx
  mov ax, y
  push ax
  mov ax, x
  push ax
  call put_char

  pop bx
  pop cx
  add x, 10
loop _out1
  pop cx
  add y, 16
loop _out2
wait_retrace

  pop cx
loop _out3

  ret
endp

start:

  ;очистка экрана и установка текстового режима 3
  mov ax, 3
  int 10h

  mov ax, @data
  mov ds, ax

  ;загрузка шрифта
  call load_font

  ;вывод информации о VESA и видеокарте
  call do_vesa_info
  push offset press
  mov attrib, 0ah
  call write0

  ;ждем нажати¤ клавиши клавиатуры
  xor ax,ax
  int 16h

  ;уcтанавливаем графический режим
  call set_mode
  cmp ax, 0ffffh
  je exit

  xor ax,ax
  int 16h

  ;показываем заставку
  call splash

  ;главный цикл
  _1:

  ;уставим букву в первой строке
  ;и сохран¤ем ее позицию во временном буфере
  call fill_line

  ;сдвигаем вниз весь экран
  call _out

  ;сдвигаем вниз временный буфер
  call scroll
  
  ; call grad
  ; mov ax, 000h
  ; int 16h

  ;напр¤мую провер¤ем нажатие клавиши ESC
  in  al, 60h
  cmp al, 81h
  ;если не ESC - повторим цикл
  jne _1

  ;сваливаем
  exit:

  mov ax, 3
  int 10h

  mov ax, 4c00h
  int 21h

end start