;;
;; Gramado MBR - 
;; Esse é o MBR que é montado no VHD na hora de sua criação.
;; Será o primeiro setor do disco.
;; Essa rotina carrega o BM.BIN na memória e passa o comando para ele. 
;; Além de passar argumentos.
;;
;; É um VHD de 32MB. 
;; A primeira partição é a partição do sistema e está formatada
;; em fat16 com 512 bytes por cluster.
;;
;; Obs: 
;; Não mudar os endereços de segmento e offset usados 
;; para não arrumar problemas.
;;
;; History:
;;     2017 - Fred Nora.
;;


;;
;; Partition table:
;; See:
;;     https://thestarman.pcministry.com/asm/mbr/PartTables.htm
;;


END_OF_CLUSTER EQU 0xFFFF
;;END_OF_CLUSTER2 EQU 0xFFF8


ROOTDIRSTART EQU (BUFFER_NAME)
ROOTDIRSIZE  EQU (BUFFER_NAME+4)
;datasector      EQU (BUFFER_NAME)
;cluster         EQU (BUFFER_NAME+2)
;SAVE3           EQU (BUFFER_NAME+4)
;CylinderNumbers EQU (BUFFER_VOLUME_ID)



;; 16bit. Esse é o MBR do VHD.
[bits 16]

    jmp START

;BPB Personalizado para o VHD de 32MB usado pelo Gramado.
BUFFER_NAME           db "MSDOS5.0"    ;GRAMADO.
BPB:
BytesPerSector        dw 0x0200
SectorsPerCluster     db 1
ReservedSectors       dw 62      ;; 62
TotalFATs             db 0x02
MaxRootEntries        dw 0x0200
TotalSectorsSmall     dw 0x0000  ;; (CHS=963/4/17-5)(Number of sectors - number of hidden sectors)
MediaDescriptor       db 0xF8
SectorsPerFAT         dw 246    
SectorsPerTrack       dw 17      ;; 19 SPT.  
NumHeads              dw 4       ;; 4 HEADS. Number of surfaces
HiddenSectors         dd 5       ;; 1+1+3 ( mbr + vbr + reserved sectors depois do vbr)
TotalSectorsLarge     dd 0       ;; Number of sectors, if 'TotalSectorsSmall = 0'.
DriveNumber           db 0x80    
Flags                 db 0x00    ;; ?? Current Head ??
Signature             db 0x29    ;; 41
BUFFER_VOLUME_ID      dd 0x980E63F5
VolumeLabel           db "GRAMADO    "   ;;11 bytes
SystemID              db "FAT16   "


;;
;;=================================
;;


DAPSizeOfPacket db 10h
DAPReserved     db 00h
DAPTransfer     dw 0001h
DAPBuffer       dd 00000000h
DAPStart        dq 0000000000000000h


datasector  dw  0x0000    ;Início da área de dados.
cluster     dw  0x0000


;absoluteSector db 0x00
;absoluteHead   db 0x00
;absoluteTrack  db 0x00

;CylinderNumbers:  dd 0  ;;dword



;;
;; == Messages ==================================================
;;

;; The image name.
ImageName     db "BM      BIN", 0x0D, 0x0A, 0x00

;; 'R' = Root fail.
msgFailure    db "R", 0x00 

;...



;;
;; ====================================
;; START:
;;     Real Start.
;;

START:
    ;nop
;Step1: 

    ; Code located at 0x7C00, adjust segment registers to 0x07C0:0.
    ; Create stack.   0:6000h
    
    cli
    mov  ax, 0x07C0
    mov  ds, ax
    mov  es, ax
    mov  ax, 0x0000
    mov  ss, ax
    mov  sp, 0x6000
    sti


Step2:
    mov byte [DriveNumber], byte dl 

    ;cmp dl, byte 0x80
    ;jne FAILURE

    ;;Clear the Screen.
Step3: 
    mov ax, 02h
    int 010h


;Step4:
    ;@todo: Certificar que int 13h é suportada.	

;Step5:
    ;@todo: Reset driver.


    ;;
    ;; ** As informações sobre disco serão pegadas no BM.BIN **
    ;;
 
 
;Step6:

    ;; O STEP6 FOI RETIRADO E AGORA ESTÁ NO PARA O BM.BIN
    ;; DESSE MODO NÃO PRECISAMOS MAIS PASSAR ARGUMENTOS PARA O BM.BIN 
    ;; PASSAREMOS SOMENTE O 'DRIVE NUMBER'


;Step7:

    ;; Carregamentos...
    ;; Carregar o ROOT.
    ;; #todo: 
    ;; Cuidadosamente rever os cálculos feitos aqui para permitir que
    ;; que carreguemos o sistema usando discos de vários tamanhos. 
    ;; Por enquanto estamos predeterminando as diretrizes de 
    ;; carregamento. 

LOAD_ROOT:

	;;  559 (root)
	;; ( MBR + Reserved Sectors + VBR + Hidden Sectors + TotalFATs * SectorsPerFAT )
	;; (  1  +      62          +  1  +    3           +    2      *     246)
	;; =================================================================
	;;   1 - mbr (*hidden) 
	;;  62 - Reserved sectors.
	;;   1 - vbr (*hidden) (VBR da primeira partição)
	;; 246 - fat1
	;; 246 - fat2
	;;   3 - Hidden sectors. (*hidden)
	;;  32 - root. (512 entradas)
	;; xxx - data area.


	;; ## data area location ## 
	;; Calcula o início da área de dados.
	;; Compute size of root directory and store in "cx".


    xor  cx, cx
    mov  ax, 32                   ; 32 byte. Tamanho de uma entrada de diretório.
    mul  WORD [MaxRootEntries]    ; 512. Tamanho total do diretório dado em bytes. (32*512) bytes.
    div  WORD [BytesPerSector]    ; ((32*512)/512) O número total de bytes no diretório, dividido pela quantidade de bytes por setor.
    mov  WORD [ROOTDIRSIZE], ax
    mov cx, ax                    ; Coloca o resultado em cx. (Quantidade de setores no diretório raiz.)


	;; Root location
	;; Compute location(LBA) of root directory and store in "ax".


    xor ax, ax
    mov  al, BYTE [TotalFATs]    ; 2. Number of FATs.
    mul  WORD [SectorsPerFAT]    ; 246. Sectors used by FATs.


	; +62. Adiciona os setores reservados. 
	; +5.  Adiciona os setores escondidos. (1+1+3) 
	; 5 = ( 1 MBR + 1 VBR + 3 hidden sectors )

    add  ax, WORD [ReservedSectors]  
    add  ax, WORD [HiddenSectors]    
    
	; *** Nesse momento ax contém o setor inicial do root dir ***
	; vamos adicionar o tamanho do diretório raiz dado em setores. 
	; [ROOTDIRSIZE]
	; Dessa forma ex contém o setor onde inicia a área de dados.

    mov word [ROOTDIRSTART], ax
    add  ax, cx

    mov  WORD [datasector], ax


    ;; SIMULANDO o data area para testes.
    ;; mov  WORD [datasector], 591

    ;; Obs: 
    ;; A variável 'datasector' precisa ser inicializada aqui, 
    ;; pois é usada mais à frente na rotina de conversão.

	;; Obtivemos com o cálculo:
	;; cx           = Tamanho do diretório raiz, dado em número de setores.
	;; [datasector] = Início da área de dados.

	;;
	;; * Carregar o diretório raiz em es:bx 0x07C0:0200.
	;;

	;;
	;; Obs: Me parece seguro permitirmos que carregue o diretório raiz inteiro,
	;;      Porém desnecessário ainda.


	;; 559 (root)
	;; ( MBR + Reserved Sectors + VBR + Hidden Sectors + TotalFATs * SectorsPerFAT )
	;; (  1  +      62          +  1  +    3           +    2      *     246)
	;;==============================
	;;   1 - mbr (*hidden) 
	;;  62 - Reserved sectors.
	;;   1 - vbr (*hidden) (VBR da primeira partição)  	
	;; 246 - fat1
	;; 246 - fat2
	;;   3 - Hidden sectors. (*hidden)
	;;  32 - root. (512 entradas)
	;; xxx - data area.


.loadRoot:

	; 559 - Início do diretório raiz.
	; 32  - Quantos setores carregar. Tamanho do diretório raiz.
	; 0x0200 - Offset para encontrarmos o endereço onde devemos 
	; carregar o root na memória. (seg:off) 

    mov  ax, word [ROOTDIRSTART]
    mov  cx, word [ROOTDIRSIZE]
    mov  bx, 0x0200
    call  ReadSectors

;.msg:

	;Uma mensagem de espaçamento.
	;pusha
	;mov  si, msgCRLF
	;call  DisplayMessage
	;popa

	;;
	;; Procurando o arquivo BM.BIN no diretório raiz.
	;;
	

.searchFile:

    ; Browse root directory for binary image
    mov  cx, WORD [MaxRootEntries]    ; Load loop counter.
    mov  di, 0x0200                   ; Determinando o offset do início do diretório.

.LOOP:
    push  cx
    mov  cx, 0x000B       ; Eleven character name.
    mov  si, ImageName    ; Image name to find.
    pusha
    call  DisplayMessage
    popa
    push  di
    rep  cmpsb            ; Test for entry match.
    pop  di
    je  LOAD_FAT          ; Se o arquivo foi encontrado.
    pop  cx
    add  di, 0x0020       ; Queue next directory entry.
    loop  .LOOP
    jmp  FAILURE


	;;
	;; Load the FAT in es:bx 0x17C0:0200.
	;; #bugbug Size?
	;;

LOAD_FAT:

    ;nop

;.msg:

    ;pusha
    ;mov  si, msgFAT
    ;call  DisplayMessage
    ;popa

    ; dx = Cluster inicial do arquivo a ser carregado.
    ; Save starting cluster of boot image.
    ; Salvamos o número do cluster inicial da Imagem. 
    ; Isso foi obtido na entrada do diretório.
    ; File's first cluster.

    mov dx, WORD [di + 0x001A]
    mov WORD [cluster], dx 


    ;; Efetuando o carregamento da fat no buffer es:bx. 
    ;; 0x17C0:0200.


	;;===================================
	;; #bugbug: 
	;; SE CARREGAR A FAT INTEIRA DÁ PROBLEMA. !!!! 
	;; (246/2)
	;; Estamos carregando apenas metade da fat.
	;; ?? Por que ?? Qual é o problema ??
	;;===================================
	
.loadFAT:

    ;Configurando o segmento 'es'. 
    mov ax, 0x17C0
    mov es, ax   

	; Read FAT into memory (17C0:0200).
	; Obs: Confiar no cáculo do início da LBA é perigoso, apesar de necessário.
	; Por enquanto vamos determiná-lo.
	; Obs: É possível confiarmos no cálculo do tamanho da fat, mesmo assim, vamos
	; por enquanto, determiná-lo.
	; Obs: Não estamos carregando a FAT inteira. Isso pode ser arriscado, mas 
	; por enquanto, como temos poucos arquivos, vamos carrega apenas metade da FAT.
    
	; Compute location of FAT and store in "ax".
	; Calculado qual é a LBA inicial da FAT e salvando em 'ax'.

    mov ax, WORD [HiddenSectors]      ; 5 setores escondidos.
    add ax, WORD [ReservedSectors]    ; 62 setores reservados.


	; #debug
	; mov  ax, 67                              
	; SIMULANDO Determinando a LBA inicial da FAT, apezar de termos calculado.

	; #bugbug
	; Estamos carregando apenas metade da fat.
	; Falha se tentarmos carregar ela inteira.

    mov  cx,  (246/2) ; WORD [SectorsPerFAT]  ;  Metade da fat.
    mov  bx, 0x0200                           ;  Determinando o offset da FAT.
    call  ReadSectors


    ;; Carregar o arquivo BM.BIN na memória em es:bx, 
    ;; 0:8000h.

;.msgSpace:
    
    ;Mensagem de espaçamento.
    ;mov  si, msgCRLF
    ;call  DisplayMessage


;.msgImage:

    ;Mensagem avisando que vamos carregar.
    ;mov  si, msgImg
    ;call  DisplayMessage
    

.setupBuffers:

    ; Configurando o buffer para o arquivo. (es:bx), 0:8000h.
    mov ax, 0
    mov es, ax        ; Segment.
    mov bx, 0x8000    ; Offset.


    ; Salvando o offset do buffer do arquivo.
    push  bx

	;; Nesse momento a FAT já está na memória, precisamos indicar 
	;; em gs:bx o endereço do buffer onde carregamos a fat.


    ;; Indicando o segmento onde a FAT está carregada.
    mov ax, 0x17C0    ; FAT Segment
    mov gs, ax

	;;
	;; * Carregar o arquivo na memória em es:bx, 0:8000h.
	;;


__loop_LOAD_IMAGE:

    ;; Em 'bx' está o offset do buffer do arquivo.
    
    ; Recuperando o offset do buffer do arquivo.
    pop  bx                                  


    ; Vamos converter Cluster em LBA.
    mov  ax, WORD [cluster]    ; Cluster inicial do arquivo, obtido na entrada no diretório.
    call  ClusterLBA           ; Convert cluster to LBA.

	;; Carregamos apenas um cluster de cada vez.
	;; No nosso caso, um cluster só tem um setor.

.loadImage:

    xor  cx, cx
    mov  cl, BYTE [SectorsPerCluster]    ; 1. Sectors to read.
    call  ReadSectors

.saveThis:

	; Vamos savar o offset do próximo setor a ser carregado.
	; Onde deve ficar o próximo setor. ??

    push bx
    

    ; Agora temos que saber qual será o próximo cluster.
    ; Vamos calcular o deslocamento dentro da fat para obtermos o 
    ; o local onde encontraremos o valor do próximo cluster.
    ; Salvaremos em 'dx'.
    ; lembrando que a fat está em gs:bx.

    mov ax, WORD [cluster]    ; identify current cluster
    add ax, ax                ; 16 bit(2 byte) FAT entry
    mov bx, 0x0200            ; location of FAT in memory
    add bx, ax                ; index into FAT    
    mov dx, WORD [gs:bx]      ; read two bytes from FAT

    ; Saving new cluster.
    ; Em 'dx', está o valor do próximo cluster.

.DONE:
    mov  WORD [cluster], dx 

    ; Test for end of file.
    ; Testamos para ver se é o último cluster. 
    ; 0xFFFF ? or 0xFFF8 ?
    ; Se esse foi o último cluster então prosseguiremos.
    ; Caso contrário volta para o loop.

.testEOF: 
    cmp  dx, END_OF_CLUSTER  
    jne  __loop_LOAD_IMAGE

    ;;
    ;; Done!
    ;;

DONE:
    ;nop

    ; Pass an argument to the next stage.
    ; Disk Number.

;Step8:
    mov dl, byte [DriveNumber]


    ; Passando o comando para o BM.BIN em 0:8000h.
 
;Step9:

.FLY:

    PUSH WORD  0         ;; cs
    PUSH WORD  0x8000    ;; offset 
    RETF




;; ***********************************************
;; ReadSectors:
;; 
;;     Reads "cx" sectors from disk starting at "ax" 
;; into memory location "es:bx"
;; ************************************************

ReadSectors:

    mov WORD [DAPBuffer]   ,bx
    mov WORD [DAPBuffer+2] ,es
    mov WORD [DAPStart]    ,ax

    ; Tentativas.
    
.MAIN:
    mov di, 0x0005  

.SECTORLOOP:

    push  ax
    push  bx
    push  cx

    push si
    mov ah, 0x42
    mov dl, 0x80
    mov si, DAPSizeOfPacket
    int 0x13
    pop si
 
    jnc  .__SUCCESS    ; Test for read error.
    xor  ax, ax        ; BIOS reset disk.
    int  0x13          ; Invoke BIOS.
    
    dec  di            ; Decrement error counter.
    
    pop  cx
    pop  bx
    pop  ax

    ; Attempt to read again
    jnz  .SECTORLOOP    

;.fail:
    int  0x18


.__SUCCESS:

    ; Importante: 
    ; Mensagem de progresso.
    
    ;mov  si, msgProgress
    ;call  DisplayMessage
    
    pop  cx
    pop  bx
    pop  ax

    ; Queue next buffer.
    add bx, WORD [BytesPerSector] 
    cmp bx, 0x0000
    jne .NextSector

    ; Trocando de segmento.

    push ax
    mov  ax, es
    add  ax, 0x1000
    mov  es, ax
    pop  ax

.NextSector:

    inc  ax                     ; Queue next sector.
    mov WORD [DAPBuffer], bx
    mov WORD [DAPStart], ax
    loop  .MAIN                 ; Read next sector.
    RET
 
 
;; ************************************************
;; ClusterLBA:
;;
;;     Convert FAT cluster into LBA addressing scheme
;;     LBA = (cluster - 2) * sectors per cluster
;; *************************************************

ClusterLBA:

    sub ax, 0x0002                      ; zero base cluster number
    xor cx, cx
    mov cl, BYTE [SectorsPerCluster]    ; convert byte to word
    mul cx
    add ax, WORD [datasector]           ; base data sector
    RET



;; ********************************************************
;; DisplayMessage:
;;
;;     Display ASCIIZ string at "ds:si" via BIOS.
;;     Standadr print string routine.
;; ********************************************************

DisplayMessage:

    lodsb                  ; Load next character.
    or al, al              ; Test for NUL character.
    jz .DONE
    mov ah, 0x0E           ; BIOS teletype. 
    mov bx, 0x0007         ; Página e atributo.  
    int 0x10               ; Invoke BIOS.
    jmp  DisplayMessage
.DONE:
    RET

    ;;
    ;; Fail!
    ;;

FAILURE:

    ; Para economizar espaço.
    ; int 0x18  
    
    mov si, msgFailure
    call DisplayMessage
    
    mov ah, 0x00
    int 0x16        ; await keypress
    int 0x19        ; warm boot computer


    ;;
    ;; Partition table support.
    ;;

    ; Colocando a partition table no lugar certo. 
    ; (0x1BE).

    TIMES 446-($-$$) DB 0 



;; ======================================================
;;  PARTITION TABLE 
;; ======================================================
;; http://cars.car.coocan.jp/misc/chs2lba.html
;; https://en.wikipedia.org/wiki/Partition_type
;; VHD info:
;;(CHS=963/4/17)
;; Types:
;; 0x04 - FAT16, less than 32 MB
;; 0x06 - FAT16, greater than 32 MB
;; 0xEF - EFI FAT12/FAT16 
;; ...
;; 0xEF:
;;     EFI, FAT12/FAT16.
;;     MBR, Service FS,	Intel,	EFI.
;;     EFI system partition. 
;;     Can be a FAT12, FAT16, FAT32 (or other) file system.


; Partition 0. 
P0:

;; begin (4 bytes)
.flag:                db  0x80     
.hcs_inicial:         db  1, 1, 0       ; h,c,s      

; end (4 bytes)
.os_type:             db  0xEF          ; EFI FAT12/FAT16.       
.hcs_final:           db  0x03, 0x4A, 0xCF  ; h,c,s (3, 255, 16)    0001 0000b

; relative
.lba_inicial:         dd  0x3F          ; First sector. (63, vbr).

; size
.tamanho_da_particao: dd  65512         ; in sectors. 


; (obs: Os dois bits mais altos de s pertencem al c)
; (17406*512)=8911872
; (8911872/1024) = 8703 kb


; s
; 0001 0000b
; (11)01 0000b  *bits exportados;
; 11010000 = d0
; 11001111 = cf

; c
; 34a = 842 ...    
; 34a = 0011 0100 1010
; 00(11) 0100 1010   *bits inportados de s.

;size
;0x0000FFE8 = 65512


; Partition 1, 2 and 3.
P1: dd 0,0,0,0 
P2: dd 0,0,0,0 
P3: dd 0,0,0,0 


; Signature.

MBR_SIG: 

    TIMES 510-($-$$) DB 0
    DW 0xAA55
    
  
;;
;; End.
;;
    
