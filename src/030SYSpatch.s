********************************************************************
*
*	030SYSpatch.x version 2.11 for MC68030 on X68030
*
*	IPL/IOCS-ROM �ɂȂ����p�b�`������(��)
*
********************************************************************

	.include IOCSCALL.MAC
	.include DOSCALL.MAC

	.include SYSpatch.MAC

	.cpu	68030

MAGIC_NO1	equ	'X030'
MAGIC_NO2	equ	'2.11'

MAGIC_040	equ	'040T'

VER215		equ	-1
VER301		equ	0
VER302		equ	1

SYS030		equ	1
SYS_30		equ	0

	.text

		dc.l	-1
		dc.w	$8000
		dc.l	device_strategy
		dc.l	device_interrupt
		dc.b	'030SYSp*'

device_reqhead:
		ds.l	1

device_strategy:
		move.l	a5,device_reqhead
		rts

device_interrupt:
		movem.l	d1-d7/a0-a6,-(sp)
		movea.l	(device_reqhead,pc),a5
		tst.b	(2,a5)
		beq	device_initialize
device_error_exit:
		move.w	#$5003,d0
device_exit:
		move.b	d0,(3,a5)
		ror.w	#8,d0
		move.b	d0,(4,a5)
		ror.w	#8,d0
		movem.l	(sp)+,d1-d7/a0-a6
		rts

device_initialize:
		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#4,sp

		cmpi.l	#MAGIC_040,(ROM_TOP)
		beq	SYSpatched

		move.l	Hu_MEMMAX,d0
		move.l	d0,RAM_END
		subi.l	#$10000,d0
		movea.l	d0,a1
		tst.w	d0
		bne	invalid_param

		move.l	d0,SYStop
		subi.l	#PAGE_SIZE*2,d0
		movea.l	d0,a2
		move.l	d0,Hu_MEMMAX

		move.l	18(a5),a0
skipname:	tst.b	(a0)+
		bne	skipname
getparam:	move.b	(a0)+,d1
		bne	@f
		move.b	(a0)+,d1
		beq	no_param

@@:		cmpi.b	#'*',d1
		bne	@f
		st	F_RAM_END
		bra	getparam

@@:		cmpi.b	#'@',d1
		bne	@f
		SRAM_WE
		bset.b	#4,SCSIFLAG		* MPU�]��
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'A',d1
		bne	@f
		SRAM_WE
		bset.b	#7,SCSIFLAG		* �]���o�C�g���ݒ�
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'B',d1
		bne	@f
		SRAM_WE
		st	POOON			* �ہ`��ݒ�
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'C',d1
		bne	@f
		st	F_SCSISWC
		bra	getparam

@@:		cmpi.b	#'!',d1
		bne	@f
		subi.l	#ROMDB_LEN,d0	* ROMDB�̈�擪
		st	F_ROMDB
		move.l	d0,dbtop
		bra	getparam

@@:		cmpi.b	#'0',d1
		bne	@f
		st	F_SWAP_MEM
		bra	getparam

@@:		cmpi.b	#'1',d1
		bne	@f
		st	F_WP_PATCH
		bra	getparam

@@:		cmpi.b	#'$',d1
		bne	@f
		st	F_DBON
		bra	getparam

@@:		cmpi.b	#'+',d1
		bne	@f
		st	F_DEVCALL
		bra	getparam

@@:		cmpi.b	#'x',d1
		bne	@f
		move.l	d0,-(sp)
		bsr	numin
		move.l	d0,X68030_pal_data
		move.l	(sp)+,d0
		bra	getparam

@@:		cmpi.b	#'M',d1
		bne	@f
		move.b	#1,F_EXPMAP
		bra	getparam

@@:		cmpi.b	#'N',d1
		bne	@f
		move.b	#2,F_EXPMAP
		bra	getparam

@@:		cmpi.b	#'e',d1
		bne	@f
		move.l	d0,-(sp)
		bsr	numin
		cmpi.l	#$00C00000,d0
		bhi	opt_e_exit
		move.w	d0,d1
		andi.w	#$1fff,d1
		bne	opt_e_exit
		move.l	d0,(VMM_MAX)
opt_e_exit:	move.l	(sp)+,d0
		bra	getparam

@@:		bra	getparam


no_param:	move.l	d0,Hu_MEMMAX	* �����Ń������m��

		bsr	MPUcheck	** MPU�𔻒肷��
		tst.l	d0
		beq	initial_0

		pea	skip_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
MPU_is_EC03:
		clr.w	d0
		move.b	(F_EXPMAP,pc),d0
		mulu.w	#PAGE_SIZE,d0
		add.l	d0,Hu_MEMMAX
		move.b	F_RAM_END(pc),d0
		beq	initial_error
		move.l	RAM_END(pc),Hu_MEMMAX	* �m�ۂ�����������ԋp
						* �����v���O�������Ȃ�
		bra	initial_error

initial_0:
		bsr	SYSpatch_main		** �V�X�e���Ƀp�b�`�𓖂Ă�(����:a1)
		tst.l	d0
		beq	initial_ok

		tst.b	(F_MPU_is_EC030,pc)
		bne	MPU_is_EC03

		pea	ng_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
		DOS	_INKEY
		bra	initial_error

initial_ok:
		move.l	(VMM_MAX,pc),d7
		beq	vmm_set_skip
		move.l	(Hu_MEMMAX),d1
		move.l	d7,(Hu_MEMMAX)
		lea	(vmm_st_msg,pc),a0
		bsr	numout
		movea.l	d1,a1
		move.w	#(1<<10),d2
@@:		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		cmpa.l	d7,a1
		bcs	@b
		move.l	a1,d1
		lea	(vmm_ed_msg,pc),a0
		bsr	numout
		pea	(vmm_use1_msg,pc)
		DOS	_PRINT
		addq.l	#4,sp
vmm_set_skip:
		tst.b	(F_ROMDB,pc)
		beq	skip_setup_romdb
		tst.b	(F_DBON,pc)
		beq	skip_exp_map
		movem.l	d0-d7/a0-a6,-(sp)
		movea.l	ROMDB_INST,a0
		lea	$1000,a6
		jsr	(a0)
		movem.l	(sp)+,d0-d7/a0-a6
		pea	setup_romdb(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	skip_exp_map

skip_setup_romdb:
		tst.b	(F_EXPMAP,pc)
		beq	skip_exp_map
		bsr	expand_mapping
skip_exp_map:
		pea	ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
initial_end:
		move.l	#device_initialize,(14,a5)
device_normal_exit:
		clr.l	d0
		bra	device_exit

initial_error:
		bra	device_error_exit

SYSpatched:
		pea	patched_msg(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	initial_error

invalid_param:	pea	usage(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	initial_error

		dc.b	'!'
device_name:	dc.b	13,10
		dc.b	'030SYSpatch.x v'
		dc.l	MAGIC_NO2
		dc.b	' for MC68030 on X68030 by bisco',13,10
		dc.b	'         special thanks BEEPs , PUNA',13,10,0

usage:		dc.b	13,10
		dc.b	'�p�b�`�pRAM�̃G���A��64K�o�C�g���E����͂���Ă��܂��B',13,10
		dc.b	'config.sys�̐擪�œo�^���Ă��������B',13,10
		dc.b	13,10,0

skip_message:
		dc.b	'MC68030�ł͂���܂���B�p�b�`���X�L�b�v���܂��B',13,10
		dc.b	13,10,0
patched_msg:	dc.b	27,'[35m[[ 040TURBO ]]',27,'[m',13,10,0
ok_message:
		dc.b	'�p�b�`��Ƃ��������܂���',13,10
		dc.b	13,10,0
ng_message:
		dc.b	'�p�b�`��Ƃ𒆒f���܂�',13,10
		dc.b	'----- �����L�[�������Ă������� -----',13,10
		dc.b	13,10,0
setup_romdb:
		dc.b	'ROMDB���N�����܂���',13,10,0

vmm_use1_msg:	dc.b	'���z���C��������['
vmm_st_msg:	dc.b	'00000000�`'
vmm_ed_msg:	dc.b	'00000000'
		dc.b	']���g���܂�',13,10,0


F_RAM_END:	dc.b	0	* '*'
F_DBON:		dc.b	0	* '$'
F_DEVCALL:	dc.b	0	* '+'
F_SCSISWC:	dc.b	0	* 'C'
F_MPU_is_EC030:	dc.b	0
		.even
VMM_MAX:	dc.l	0	* 'e'


*------------------------------------------------------------
**		�P�U�i������a0����l��d0�Ɏ��o��
*------------------------------------------------------------
*------------------------------------------------------------
**		d1�̒l���P�U�i������ɂ���a0�ɏo��
*------------------------------------------------------------

	.include 030_comm1.s

*------------------------------------------------------------
*  MPU�`�F�b�N(���Ӗ�
*------------------------------------------------------------
MPUcheck:
		move.l	$0010,-(sp)		* �s�����߂̃G���g����ޔ�
		move.l	#MPUcheck_trap,$0010	* �s�����߂��g���b�v
		nop
		movec	CAAR,d0			* 68000/68040 �ŕs������
		movec	CACR,d0
		bset.l	#13,d0			* WA bit
		movec	d0,CACR
		movec	CACR,d0
		btst.l	#13,d0			* 68020 �ł� zero �ɂȂ�͂�
		beq	MPU_is_020
		clr.l	d0
MPUcheck_1:
		move.l	(sp)+,$0010
		rts

MPUcheck_trap:
		moveq	#-1,d0
		move.l	#MPUcheck_1,(2,sp)
		rte

MPU_is_020:	moveq	#-1,d0
		bra	MPUcheck_1

*------------------------------------------------------------
*  �p�b�`���[�`��
*------------------------------------------------------------
SYSpatch_main:
		bsr	pre_patch
		tst.l	d0
		bne	patch_error
patch_1:
		bsr	post_patch
		tst.l	d0
		bne	patch_error
patch_2:
		moveq	#0,d0
patch_error:
		bsr	CFLUSH
		rts

*------------------------------------------------------------
*  �N���O��IPL/IOCS-ROM�̃p�b�`
*	A1:�p�b�`�pRAM�̐擪�Ԓn
*	A2:MMU�e�[�u���J�n�Ԓn
*------------------------------------------------------------
pre_patch:
		movem.l	d1/d2/a0-a3,-(sp)
		move.w	sr,-(sp)
		ori.w	#$700,sr		* �����֎~

		IOCS	_ROMVER
		cmpi.l	#$13921127,d0		* v1.3 92/11/27
		bne	romver_error

		move.l	a1,d0
		andi.l	#$000FFFFF,d0
		cmpi.l	#$000F0000,d0
		bne	align_error

		lea	ROM_TOP,a3

		cmpi.l	#MAGIC_NO1,(a3)		** �p�b�`�ϊm�F�p�L�[�P
		bne	pre_patch_1st
		cmpi.l	#MAGIC_NO2,4(a3)	** �p�b�`�ϊm�F�p�L�[�Q
		bne	pre_patch_1st

		exg	a1,a3
		move.l	#$10000-4,d1
		tst.b	(F_ROMDB,pc)
		beq	@f
		move.l	#(PMEM_MAX-ROMDB_TOP)-4,d1
		lea	ROMDB_TOP,a1
@@:		bsr	crc_calc
		exg	a1,a3
		cmp.l	(a3,d1.l),d0
		beq	pre_patch_ok

	******************************
	** �p�b�`���čŏ��̃X�e�[�W **
	******************************
pre_patch_1st:
		clr.l	-(sp)
		pmove.l	(sp),TC			* MMU disable
		addq.l	#4,sp

		move.w	#$10000/4-1,d1
		lea	ROM_TOP,a0		** IPL/IOCS-ROM��RAM��ɓW�J
		move.l	a1,a3
loop_pre_patch2:
		move.l	(a0)+,d0
		move.l	d0,(a3)
		cmp.l	(a3)+,d0
		bne	memory_error
		dbra	d1,loop_pre_patch2

		tst.b	(F_ROMDB,pc)
		beq	skip_romdb_install

		move.w	#ROMDB_LEN/4-1,d1
		lea	ROMDB_TOP,a0		* ROMDB��RAM��ɓW�J
		movea.l	(dbtop,pc),a3
loop_pre_patch2_romdb:
		move.l	(a0)+,d0
		move.l	d0,(a3)
		cmp.l	(a3)+,d0
		bne	memory_error
		dbra	d1,loop_pre_patch2_romdb

skip_romdb_install:

		bsr	mmu_table		** MMU�e�[�u���쐬 & MMU�C�l�[�u��

	******************************************************************
	**								**
	**  ���̎��_�łq�n�l�̈�̓p�b�`�q�n�l�̈�(RAM)�ɂȂ��Ă���	**
	**  �p�b�`�q�n�l�̈�(RAM)�̕����A�h���X�� (SYSpat) �Ɋi�[	**
	**								**
	******************************************************************

		lea	ROM_TOP,a1

		bsr	check_mmu_active
		tst.l	d0
		bne	mmu_inactive_error

		bsr	patch_rom_new_code	** ROM�ւ̒ǉ��R�[�h��������
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_rom_code		** �ύX�������R�[�h���p�b�`
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_romdb		** ROMDB�̃p�b�`�ƃ}�b�s���O
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_wotaku		** ����ݒ�
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_rom_magic		** �ʐݒ�
		tst.l	d0
		bne	pre_patch_error

		bsr	patchWP
		bra	pre_patch_ok

pre_patch_restart:
		pea	restart_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		clr.l	d0
		move.l	d0,d1
		jmp	$00FF0038		** �p�b�`�q�n�l�Ń��X�^�[�g

pre_patch_ok:
		lea	ROM_TOP,a1
		move.w	($0400+$8F*4),d1
		cmp.w	SYStop(pc),d1		** IOCS$8F(ROMVER)�̃G���g����ROM���w���Ă邩�H
		beq	pre_patch_restart
		move.l	a1,d0
		swap	d0
		cmp.w	d0,d1			** �p�b�`ROM�_���A�h���X���w���Ă邩�H
		bne	patch_restart_error

		move.w	#$f000,d1
		bsr	new_IOCS_AC_ffc75a
		move.l	d0,d1
		lea	pre_patch_ok_message_data(pc),a0
		bsr	numout
		move.b	(pre_patch_ok_message_data+2,pc),pre_patch_ok_message_data+10+2
		move.b	(pre_patch_ok_message_data+3,pc),pre_patch_ok_message_data+10+3
		pea	pre_patch_ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		tst.b	(F_ROMDB,pc)
		beq	skip_romdb_inst_ok
		pea	romdb_use_ok_msg(pc)
		DOS	_PRINT
		addq.l	#4,sp
skip_romdb_inst_ok

		moveq	#0,d0
pre_patch_end:
		move.w	(sp)+,sr
		movem.l	(sp)+,d1/d2/a0-a3
		rts

patch_restart_error:
		pea	ng_restart_message(pc)
		bra	pre_patch_error_exit

pre_patch_error:
		pea	ng_pre_patch_message(pc)
		bra	pre_patch_error_exit

romver_error:
		pea	ng_romver_message(pc)
		bra	pre_patch_error_exit

memory_error:
		move.l	a2,d1
		subq.l	#4,d1
		lea	ng_memory_message_data(pc),a0
		bsr	numout
		pea	ng_memory_message(pc)
		bra	pre_patch_error_exit

mmu_inactive_error:
		clr.l	-(sp)
		pmove.l	(sp),TC
		addq.l	#4,sp
		st	F_MPU_is_EC030
		pea	mmu_inactive_message(pc)
		bra	pre_patch_error_exit

align_error:
		pea	ng_align_message(pc)
pre_patch_error_exit:
		DOS	_PRINT
		addq.l	#4,sp
		moveq	#-1,d0
		bra	pre_patch_end

romdb_use_ok_msg:
		dc.b	'ROMDB���g���܂�',13,10,0
pre_patch_ok_message:
		dc.b	'IPL/IOCS��RAM['
pre_patch_ok_message_data:
		dc.b	'00000000�`0000FFFF]��ɃR�s�[���ăp�b�`���܂���',13,10,0
restart_message:
		dc.b	'�p�b�`����IPL/IOCS-RAM��Ń��X�^�[�g���܂��B',13,10,0
ng_pre_patch_message:
		dc.b	'IPL/IOCS-RAM�̃p�b�`���ł��܂���ł����B',13,10,0
ng_romver_message:
		dc.b	'IPL/IOCS-ROM�̃o�[�W�������Ⴂ�܂��B',13,10,0
ng_memory_message:
		dc.b	'�p�b�`�pRAM('
ng_memory_message_data:
		dc.b	'00000000)�̃A�N�Z�X�ŃG���[���������܂����B',13,10,0
ng_align_message:
		dc.b	'�p�b�`�pRAM�̃A�h���X���s�K���ł��B',13,10,0
ng_restart_message:
		dc.b	'���X�^�[�g�����Ɉُ킪����܂��B',13,10,0
mmu_inactive_message:
		dc.b	'MC68EC030�ł��B�p�b�`�𒆒f���܂��B',13,10,0
	.even

;-----------------------------------------------------------------------------
; MMU�����삵�Ă��邩�݂� 68030/68EC030 �̔���(���얢�m�F)
;-----------------------------------------------------------------------------
check_mmu_active:
		moveq	#-1,d0
		move.l	a0,-(sp)
		move.l	$0008,-(sp)		* �o�X�G���[�̃G���g����ޔ�
		movea.l	sp,a0
		move.l	#BUSERR_trap,$0008	* �o�X�G���[���g���b�v
		nop
		move.l	(a1),d0
		move.l	#MAGIC_NO1,(a1)		* �o�X�G���[�`�F�b�N
		move.l	d0,(a1)
		clr.l	d0
BUSERR_trap:	movea.l	a0,sp
		move.l	(sp)+,$0008
		movea.l	(sp)+,a0
		rts

*------------------------------------------------------------
*  MMU�e�[�u���쐬�^IOCS ROM�̈�Ƀp�b�`RAM���}�b�s���O
*	A2:MMU�e�[�u���pRAM�̐擪�Ԓn
*	I/O�G���A���L���V���I�t�ɂȂ�悤�ȃe�[�u�������
*------------------------------------------------------------
mmu_table:
		movem.l	d1-d3/a0-a2,-(sp)

		bsr	MakeMMUtable

	********************
	** MMU enable     **
	********************

		move.l	a2,d3
		
		movea.l	(SYStop,pc),a2
		lea	(MTBL_OFS,a2),a2
		lea	(root_reg,pc),a0
		move.l	a2,(4,a0)		* MMU table
		pmove.q	(a0),CRP		* CRP
		pmove.q	(a0),SRP		* SRP
		pmove.l	(8,a0),TC		* TC
		bsr	CFLUSH

		movea.l	d3,a2
		
		lea	(a2),a1
		moveq	#2-1,d3			; long format �ɂ���� 1-page �����Ȃ�
@@:		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		bset.l	#2,d2			* WP bit
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		dbra	d3,@b

		move.l	a2,d1
		lea	mmu_table_ok_message_data(pc),a0
		bsr	numout
		pea	mmu_table_ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		moveq	#0,d0
		movem.l	(sp)+,d1-d3/a0-a2
		rts

root_reg:	dc.l	$8000_0002
		dc.l	0						; root address
		dc.l	%1000_0010_1101_0000_0111_0111_0101_0000	; TC register
*			 E      SF page IS   TIA  TIB  TIC  TID

mmu_table_ok_message:
	dc.b	'MMU-table['
mmu_table_ok_message_data:
	dc.b	'00000000�`]���쐬���܂���',13,10,0
	.even

*------------------------------------------------------------
*  �N����̃p�b�`
*------------------------------------------------------------

	.include 030_postpat.s


*********************************************************
** IPL/IOCS-ROM�ɒǉ�����R�[�h
**	A1:�p�b�`�pRAM�̐擪�Ԓn
*********************************************************
patch_rom_new_code:
		movem.l	d1/d2/a0-a3,-(sp)

		lea	table_rom_new_code(pc),a0
		move.w	#(table_rom_new_code_end-table_rom_new_code-4)/2-1,d2
		move.l	(a0)+,d0		** ��փ��[�`���̏������݃A�h���X�Z�o
		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,a2

loop_rom_new_code:
		move.w	(a0)+,(a2)+		** �p�b�`
		dbra	d2,loop_rom_new_code
		move.l	d1,a2			** a2:new_code�̐擪

** �p�b�`�v���O�������̐�΃A�h���X�������P�[�g
patch_rom_new_code_relocate:
		move.l	(a0)+,d2		** �����P�[�g�e�[�u��
		beq	patch_rom_new_code_jmp

		move.l	(a2,d2.l),d0		** ��փ��[�`���̊Y���A�h���X
		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,(a2,d2.l)
		bra	patch_rom_new_code_relocate

** �p�b�`�v���O�������̐�΃A�h���X�������P�[�g
patch_rom_new_code_jmp:
		move.l	(a0)+,d0		** jmp�e�[�u��
		beq	patch_rom_new_code_end

		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,a3			** �p�b�`���ׂ��A�h���X

		move.l	(a0)+,d0
		add.l	a2,d0			** ��փ��[�`���̃G���g���A�h���X

		move.w	#OP_JMP,(a3)+		** jmp �̃R�[�h
		move.l	d0,(a3)
		bra	patch_rom_new_code_jmp

patch_rom_new_code_end:
		moveq	#0,d0
		movem.l	(sp)+,d1/d2/a0-a3
		rts

*---------------------------------------------------------
table_rom_new_code:
		dc.l	$00FFF000	** ���̔Ԓn�̓t���[
					** �ȉ��̃v���O�������]�������
*---------------------------------------------------------

*---------------------------------------------------------
* IOCS-AC:�L���b�V�����䃋�[�`���̒ǉ��@�\
*---------------------------------------------------------
new_IOCS_AC_ffc75a:
		movem.l	d1/d2,-(sp)
		moveq	#-1,d0
		cmpi.w	#$F000,d1
		beq	new_IOCS_AC_F000
		cmpi.w	#$F002,d1
		beq	new_IOCS_AC_F002
		cmpi.w	#$F001,d1
		beq	new_IOCS_AC_F001
		cmpi.w	#$8000,d1
		beq	new_IOCS_AC_8000
		cmpi.w	#$8001,d1
		beq	new_IOCS_AC_8001
		cmpi.w	#$8004,d1
		beq	new_IOCS_AC_8004
org_IOCS_AC_entry
		jmp	$FFC760


	.include 030_iocs_ac.s


*---------------------------------------------------------
* �u�[�g���̏���
*---------------------------------------------------------
new_BOOT_ff0038:
		move.w	#$2700,sr
		lea	$2000,sp
		reset
		moveq	#0,d0
		movec	d0,CACR				; cache off
		move.w	#%00_1000_0000_1000,d0
		movec	d0,CACR				; cache flush
		pflusha

		movea.l	(SYStop,pc),a2
		suba.l	#PAGE_SIZE*2,a2
		bsr	MakeMMUtable

		lea	(a2),a1
		moveq	#2-1,d3			; long format �ɂ���� 1-page �����Ȃ�
@@:		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		bset.l	#2,d2			* WP bit
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		dbra	d3,@b

		bsr	patchWP

		tst.l	ROMDB_INST
		bne	org_BOOT_entry

		cmpi.b	#2,(F_EXPMAP,pc)
		bne	org_BOOT_entry

		lea	LABWORK,a1
		move.l	#PABWORK,d2
		bsr	set_area_mapping
		moveq	#-1,d2
		bsr	set_memory_mode
		move.l	d0,d2
		bclr.l	#2,d2
		bsr	set_memory_mode
org_BOOT_entry:
		jmp	$FF0042

F_EXPMAP:	dc.b	0	* 'M' 'N'
	.even

*---------------------------------------------------------
* �u�[�g���̓�ȕ\��
*---------------------------------------------------------
X68030_logo_disp:
		moveq	#1,d1
		move.l	(X68030_pal_data,pc),d2
		IOCS	_TPALET
		move.w	#7,d1
		moveq	#_B_COLOR,d0
		rts

X68030_pal_data:	* X68030�̐F  �f�t�H���g�͐Ԃ��ۂ��F
	dc.l	$07C0


*---------------------------------------------------------
* MMU table �����
*---------------------------------------------------------
MakeMMUtable:
		movem.l	d0-d3/a0-a2,-(sp)

		move.l	a2,d3

	********************
	** make TIA table **
	********************

		movea.l	(SYStop,pc),a2
		lea	(MTBL_OFS,a2),a2
		lea	128*4+%1010(a2),a0  * TIA��128���̌��TIB�������B%10 �� DT=$2 �̂���
		move.w	#128-1,d2
loop_set_TIA:
		move.l	a0,-(sp)
		move.l	a2,-(sp)
		bsr	mem_write	  * TIA�͑S�ē���TIB�e�[�u�����w��
		addq.l	#8,sp
		addq.l	#4,a2
		dbra	d2,loop_set_TIA	  * X68030�����8bit���f�R�[�h���ĂȂ�����

	********************
	** make TIB table **
	********************

;;;		lea	128*4+%1011(a2),a0  * TIB��128���̌��TIC�������B%11 �� DT=$3 �̂���
		movea.l	d3,a0
		lea	(%1011,a0),a0
		move.w	#128/2-1,d2
loop_set_TIB:
		move.l	a0,-(sp)
		move.l	a2,-(sp)	  * X68030�����8bit���f�R�[�h���ĂȂ�����
		bsr	mem_write
		addi.l	#64*4,(sp)	  * TIB�̎n�߂�64�ƌ��64�͓���TIC���w��
		bsr	mem_write
		addq.l	#8,sp
		addq.l	#4,a2
		lea	32*8(a0),a0	  * TIC��32�Â�
		dbra	d2,loop_set_TIB

;;;		lea	128/2*4(a2),a2	  * TIB�̌㔼64����i�߂�TIC�g�b�v��
		movea.l	d3,a2

	********************
	** make TIC table **
	********************

		lea	(TIC_table_define_mode,pc),a0
		lea	TIC_table_define(pc),a1	* �A�h���X�͈͂��Ƃɐݒ�
		move.l	(a1)+,d1		* RAM top
		move.l	d3,d2			* MMU top
		or.l	(a1)+,d2
		move.l	d2,d3
		andi.w	#$E000,d2
loop_set_TIC:
		cmp.l	d2,d1
		blt	next_TIC
		move.l	d3,d1
		move.l	(a1)+,d2
		move.l	d2,d3
		beq	end_make_MMU_table
		addq.l	#4,a0
		andi.w	#$E000,d2
next_TIC:
		tst.b	(F_SWAP_MEM,pc)
		beq	no_SYSpat_area
		move.l	d1,d0
		swap	d0
		cmp.w	(SYStop,pc),d0		* �p�b�`�̈�H
		bne	no_SYSpat_area
		move.w	#$00FF,d0		* �_���q�n�l�A�h���X
		bra	set_swap_TIC

no_SYSpat_area:
		move.l	d1,d0
		swap	d0
		cmpi.w	#$00FF,d0		* �q�n�l�̈�H
		bne	no_p_ROM_area
		move.w	(SYStop,pc),d0		* �_���p�b�`�A�h���X
set_swap_TIC:
		move.l	(a0),-(sp)
		move.l	a2,-(sp)
		bsr	mem_write
		swap	d0
		move.l	d0,(sp)
		pea	(4,a2)
		bsr	mem_write
		lea	(12,sp),sp
		addq.l	#8,a2
		bra	next_PAGE

no_p_ROM_area:
		move.l	(a0),-(sp)
		move.l	a2,-(sp)
		bsr	mem_write
		move.l	d1,(sp)
		pea	(4,a2)
		bsr	mem_write
		lea	(12,sp),sp
		addq.l	#8,a2
next_PAGE:
		addi.l	#PAGE_SIZE,d1
		bra	loop_set_TIC

end_make_MMU_table:
		pflusha
		movem.l	(sp)+,d0-d3/a0-a2
		rts

TIC_table_define:
		****	address
		dc.l	$00000000	* MEM
		dc.l	$00000000	* MMU table & Patched ROM
		dc.l	$00C00000	* I/O(Cache-Inhibit)
		dc.l	$00EC0000	* User I/O
		dc.l	$00ED0000	* SRAM & others
		dc.l	$00F00000	* ROM
		dc.l	$01000000	* dummy
		dc.l	0

TIC_table_define_mode:
		****	      G S C MUWDt
		dc.l	%1110010000000001	*MEM
		dc.l	%1110010100000001	*patch
		dc.l	%1110010101000001	*I/O
		dc.l	%1110010001000001	*User I/O
		dc.l	%1110010101000001	*SRAM & others
		dc.l	%1110010100000001	*ROM


F_SWAP_MEM:	dc.b	0	* '0'
	.even

*---------------------------------------------------------
* �p�b�`ROM�̈�����C�g�v���e�N�g
*---------------------------------------------------------
patchWP:	movem.l	d0-d3/a1,-(sp)
		moveq	#$10000/PAGE_SIZE-1,d1
		lea	ROM_TOP,a1
		move.l	(SYStop,pc),d3
		bsr	loop_patchWP

		tst.b	(F_ROMDB,pc)
		beq	@f
		moveq	#ROMDB_LEN/PAGE_SIZE-1,d1
		lea	ROMDB_TOP,a1
		move.l	(dbtop,pc),d3
		bsr	loop_patchWP

@@:		movem.l	(sp)+,d0-d3/a1
		rts

loop_patchWP:	moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		ori.b	#%1000_0100,d2
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		tst.b	(F_WP_PATCH,pc)
		bne	@f
		exg	d3,a1
		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		ori.b	#%1000_0100,d2
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		exg	a1,d3
@@:		dbra	d1,loop_patchWP
		rts

F_ROMDB:	dc.b	0	* '!'
F_WP_PATCH:	dc.b	0	* '1'
dbtop:		dc.l	0
		.even

*---------------------------------------------------------
* �_���A�h���X�֘A�T�u���[�`���E�����Ăяo��
*---------------------------------------------------------
set_area_mapping:
		movem.l	d1/d2,-(sp)
		bra	new_IOCS_AC_F001

set_memory_mode:
		movem.l	d1/d2,-(sp)
		bra	new_IOCS_AC_F002


table_rom_new_code_end:

**�ȉ������P�[�V�������
		dc.l	org_IOCS_AC_entry+2-(table_rom_new_code+4)
		dc.l	org_BOOT_entry+2-(table_rom_new_code+4)
		dc.l	0
**�ȉ��{���̃R�[�h���Ƀp�b�`���Ēǉ��R�[�h�ւ̃W�����v
		dc.l	$FFC75A
		dc.l	new_IOCS_AC_ffc75a-(table_rom_new_code+4)
		dc.l	$FF0038
		dc.l	new_BOOT_ff0038-(table_rom_new_code+4)
		dc.l	0

*********************************************************
* ROMDB�̃}�b�s���O
*********************************************************
patch_romdb:
		movem.l	d1-d3/a1,-(sp)

		tst.b	(F_ROMDB,pc)
		beq	patch_romdb_nasi

		move.l	#PAGE_SIZE,d3
		moveq	#ROMDB_LEN/PAGE_SIZE-1,d1
		lea	ROMDB_TOP,a1		* �}�b�s���O��_���A�h���X
		move.l	(dbtop,pc),d2		* �}�b�s���O�������A�h���X
loop_dbmap:
		bsr	set_area_mapping
		adda.l	d3,a1
		add.l	d3,d2
		dbra	d1,loop_dbmap
		bra	patch_romdb_ok_end

patch_romdb_nasi:
		clr.l	ROMDB_INST
patch_romdb_ok_end:
		moveq	#0,d0
		movem.l	(sp)+,d1-d3/a1
		rts

*********************************************************
** IPL/IOCS-ROM���̃v���O�����̃p�b�`
*********************************************************
patch_rom_code:
		movem.l	d1/a0/a2,-(sp)

		lea	table_rom_code(pc),a0
		move.l	#ROM_TOP,d0
loop_rom_code:
		move.w	(a0)+,d0	** �p�b�`���Ă錳�A�h���X
		beq	patch_rom_code_end
		move.l	d0,a2		** �A�h���X
		move.w	(a0)+,(a2)	** �p�b�`
		bra	loop_rom_code

patch_rom_code_end:
		moveq	#0,d0

		movem.l	(sp)+,d1/a0/a2
		rts

	.even

table_rom_code:
	dc.w	$0D96
	dc.w		$604E		* movea.l a7,a0	 -> bra.s $00FF0DE6
		** �\�t�g�E�F�A���Z�b�g�� MMU disable �ɂȂ�Ȃ���[�ɂ���

	dc.w	$0042
	dc.w		$F000
	dc.w	$0044
	dc.w		$2400
	dc.w	$0046
	dc.w		$203C
	dc.w	$0048
	dc.w		$0000
	dc.w	$004A
	dc.w		$0808
	dc.w	$004C
	dc.w		$4E7B
	dc.w	$004E
	dc.w		$0002
	dc.w	$0050
	dc.w		$7A00
		** �Ȃ�ƂȂ��C���I�ύX
		**  00FF0042	moveq	#$00,d5		 -> pflusha
		**  00FF0044	cmp.l	$00FF1AF6(pc),d0 -> move.l  #$0808,d0
		**  00FF0048	bne.s	$00FF0052	 -> movec   d0,CACR
		**  00FF004A	cmp.l	$00FF1AFA(pc),d1 -> 
		**  00FF004E	bne.s	$00FF0052	 -> 
		**  00FF0050	moveq	#$FF,d5		 -> moveq   #0,d5

	dc.w	0

*---------------------------------------------------------
* ���^�N�ȃp�b�`
*---------------------------------------------------------
patch_wotaku:
		movem.l	d1/a0/a2,-(sp)

		tst.b	(F_SCSISWC,pc)
		beq	@f
		move.l	$FFCD0E+$B*4,$FFCD0E+$4*4
		move.l	$FFCD0E+$C*4,$FFCD0E+$5*4
@@:

		lea	$FF0EA0,a0
		move.w	#OP_JSR,(a0)+
		move.l	(table_rom_new_code,pc),d1
		addi.l	#X68030_logo_disp-(table_rom_new_code+4),d1
		move.l	d1,(a0)			* jump address

		lea	(wotaku_rom_code,pc),a0
@@:		move.l	(a0)+,d0
		beq	patch_wotaku_end
		move.l	d0,a2
		move.w	(a0)+,(a2)
		bra	@b

patch_wotaku_end:
		movea.l	(SCSI_addr1,pc),a2
		move.w	(HSCSI_code1,pc),(a2)
		movea.l	(SCSI_addr2,pc),a2
		moveq	#32-1,d0
		move.w	(HSCSI_code2,pc),d1
@@:		move.w	d1,(a2)+
		dbra	d0,@b

		lea	(X68030_logo_data,pc),a0
		lea	$FF12AC,a2
		moveq	#224/4-1,d0
@@:		move.l	(a0)+,(a2)+
		dbra	d0,@b

		moveq	#0,d0
patch_wotaku_exit:
		movem.l	(sp)+,d1/a0/a2
		rts


wotaku_rom_code:
	dc.l	$FF1260			* 'Memory Managiment Unit(MMU)'�̃X�y���~�X
	dc.w		'em'			       ~
	dc.l	$FF02B6			* �u�[�g��ʂ����������ԕ\��
	dc.w		$2048
	dc.l	$FF02B8
	dc.w		$2048
	dc.l	$FF1202
	dc.w		'in'
	dc.l	$FF1204
	dc.w		'g '
	dc.l	$FF1206
	dc.w		'Un'
	dc.l	$FF1208
	dc.w		'it'
	dc.l	0	** end1 **	��ȃp�b�`�͂��̑O�ɒǉ����Ă���

SCSI_addr1:	dc.l	$FFD320
HSCSI_code1:	lsr.l  #5,d2

SCSI_addr2:	dc.l	$FFD330
HSCSI_code2:	move.b (a4),(a1)+

X68030_logo_data:
	dc.b	$03,$ff,$f9,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$80
	dc.b	$0c,$c0,$c0,$ff,$83,$fe,$1f,$f8,$3f,$e0,$ff,$80,$01,$80,$0c,$c1
	dc.b	$83,$ff,$cf,$ff,$3f,$fc,$ff,$f3,$ff,$c0,$00,$c0,$06,$63,$07,$01
	dc.b	$dc,$07,$70,$1d,$c0,$77,$01,$c0,$00,$c0,$06,$66,$06,$01,$d8,$03
	dc.b	$60,$0d,$80,$36,$00,$c0,$00,$60,$03,$3c,$06,$00,$1c,$06,$60,$0d
	dc.b	$80,$36,$00,$c0,$00,$60,$03,$38,$0f,$ff,$1f,$fe,$c0,$18,$00,$6c
	dc.b	$01,$80,$00,$30,$01,$90,$0f,$ff,$9f,$fc,$c0,$18,$1f,$ec,$01,$80
	dc.b	$01,$30,$01,$80,$0c,$03,$b8,$1e,$c0,$18,$1f,$cc,$01,$80,$03,$98
	dc.b	$00,$c0,$18,$01,$b0,$0e,$c0,$18,$00,$e8,$01,$80,$07,$98,$00,$c0
	dc.b	$18,$03,$60,$0d,$80,$36,$00,$d8,$03,$00,$0c,$cc,$00,$60,$18,$03
	dc.b	$60,$0d,$80,$36,$00,$d8,$03,$00,$18,$cc,$00,$60,$1c,$07,$70,$1d
	dc.b	$c0,$77,$01,$dc,$07,$00,$30,$66,$00,$30,$1f,$fe,$7f,$f9,$ff,$e7
	dc.b	$ff,$9f,$fe,$00,$60,$66,$00,$30,$0f,$f8,$3f,$e0,$ff,$c3,$fe,$0f
	dc.b	$f8,$00,$ff,$f3,$ff,$f8,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


**********************************************************
** IPL/IOCS-ROM�p�b�`�ʐݒ�
**********************************************************
patch_rom_magic:
		movem.l	d1/a1,-(sp)

		lea	ROM_TOP,a1

		** �p�b�`�m�F�p�L�[���ߍ���
		move.l	#MAGIC_NO1,(a1)
		move.l	#MAGIC_NO2,(4,a1)

		move.l	#$10000-4,d1
		tst.b	(F_ROMDB,pc)
		beq	@f
		move.l	#(PMEM_MAX-ROMDB_TOP)-4,d1
		lea	ROMDB_TOP,a1
@@:		bsr	crc_calc
		move.l	d0,(a1,d1.l)
		** ��j��m�F�p CRC ���ߍ���

		clr.l	d0
		movem.l	(sp)+,d1/a1
		rts

**********************************************************
** Human ver3.0[12]�̒��̃p�b�`
**********************************************************

	.include 030_hupat.s


**********************************************************
** �p�b�`�ʐݒ�
**********************************************************
patch_etc_magic:
	movem.l	d1/d2/a0-a2,-(sp)

	** �ǉ��R�[�h�̐擪�A�h���X
	movea.l	table_rom_new_code(pc),a2

	** MPU�t���O���R�ɃZ�b�g(���Ӗ��ȁc)
	move.b	#3,MPUTYPE

	** Human.sys SUPERVISOR Protect���p�b�`�ݒ�
	lea	$6800,a0
	move.l	#$13C000E8,d0
	move.l	#$60014E75,d1
	moveq	#$10,d2
	swap	d2
HuSUPER_set_code_search:
	addq.l	#2,a0			* Human.sys �p�b�`���ĉӏ��̒T��
	cmpa.l	d2,a0			* �P�l�o�C�g�z������ُ�I������
	bcc	HuSUPER_code_error
	cmp.l	(a0),d0
	bne	HuSUPER_set_code_search
	cmp.l	4(a0),d1
	bne	HuSUPER_set_code_search
	move.w	#OP_JMP,(a0)+		* jmp op code
	move.l	a2,d1
	addi.l	#HuSUPER-(table_rom_new_code+4),d1
	move.l	d1,(a0)			* jump address
	pea	HuSUPER_copy_msg(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.b	(human_version,pc),d0
	lea	(p1_data,pc),a1
	move.l	(a1)+,a0
	cmpi.b	#VER215,d0
	beq	@f
	move.l	(a1)+,a0
	cmpi.b	#VER301,d0
	beq	@f
	move.l	(a1)+,a0
@@:
	cmpi.l	#$43E8_0100,(a0)	; lea ($100,a0),a1
	bne	skip_clearBSS_set
	move.l	a2,d1
	addi.l	#clearBSS-(table_rom_new_code+4),d1
	move.w	#OP_JMP,(a0)+
	move.l	d1,(a0)
skip_clearBSS_set:
	moveq	#0,d0

patch_etc_magic_exit
	movem.l	(sp)+,d1/d2/a0-a2
	rts

p1_data:
	.dc.l	$9936		; 2.15
	.dc.l	$9802		; 3.01
	.dc.l	$98a0		; 3.02


HuSUPER_code_error
	pea	HuSUPER_error_msg(pc)
	DOS	_PRINT
	addq.l	#4,sp
	moveq	#-1,d0
	bra	patch_etc_magic_exit

HuSUPER_copy_msg:
	dc.b	'HuSUPER��ݒ肵�܂���'
	dc.b	13,10,0
HuSUPER_error_msg:
	dc.b	'HuSUPER��ݒ�ł��܂���ł���',13,10,0
	.even

*------------------------------------------------------------
* CRC ���v�Z����
* in	A1 : �A�h���X
*	D1 : ����
* out	D0 : �v�Z����
*------------------------------------------------------------
crc_calc:	movem.l	d1-d4/a0/a1,-(sp)
		lea	(CRC_WORK,pc),a0
		move.w	#256-1,d2
		move.l	#$EDB88320,d3
1:		move.l	d2,d4
		moveq	#8-1,d0
2:		lsr.l	#1,d4
		bcc	@f
		eor.l	d3,d4
@@:		dbra	d0,2b
		move.l	d4,(a0,d2.w*4)
		dbra	d2,1b

		moveq	#-1,d0
		clr.w	d4
@@:		move.b	(a1)+,d4
		eor.b	d0,d4
		move.l	(a0,d4.w*4),d3
		lsr.l	#8,d0
		eor.l	d3,d0
		subq.l	#1,d1
		bne	@b
		not.l	d0
		movem.l	(sp)+,d1-d4/a0/a1
		rts

*------------------------------------------------------------
* ����������???
*------------------------------------------------------------
expand_mapping:
	movea.l	Hu_MEMMAX,a3
	lea	$4000,a2
	move.l	#PAGE_SIZE,d5
	clr.w	d6
	move.b	(F_EXPMAP,pc),d6

	move.l	a2,d1
	cmpi.w	#1,d6
	beq	@f
	sub.l	d5,d1
@@:	lea	(pa1,pc),a0
	bsr	numout
	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,d1
	subq.l	#1,d1
	lea	(pa2,pc),a0
	bsr	numout

	move.l	a3,d1
	lea	(la1,pc),a0
	bsr	numout
	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,d1
	subq.l	#1,d1
	lea	(la2,pc),a0
	bsr	numout

	move.w	d6,d7
	subq.w	#1,d7
re_map_loop:
		movea.l	a3,a1
		move.l	a2,d2

		bsr	set_area_mapping	; ���g�p�������̍Ĕz�u
		move.l	d2,-(sp)		; �����A�h���X���v�b�V��
		moveq	#-1,d2
		bsr	set_memory_mode		; �y�[�W�ݒ�̎擾
		bclr.l	#2,d0			; 'W' �����Z�b�g
		move.w	d0,d2
		bsr	set_memory_mode		; �y�[�W���̐ݒ�
		move.l	(sp)+,a1		; �_���A�h���X�Ƃ��ă|�b�v
		moveq	#-1,d2
		bsr	set_memory_mode		; �y�[�W�ݒ�̎擾
		bset.l	#2,d0			; �O�̂��� 'W' ���Z�b�g
		move.w	d0,d2
		bsr	set_memory_mode		; �y�[�W���̐ݒ�

		adda.l	d5,a3
		suba.l	d5,a2
	dbra	d7,re_map_loop

	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,Hu_MEMMAX
	pea	(expm1,pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

expm1:		dc.b	'�����A�h���X['
pa1:		dc.b	'00000000�`'
pa2:		dc.b	'00000000]��',13,10
		dc.b	'�_���A�h���X['
la1:		dc.b	'00000000�`'
la2:		dc.b	'00000000]�Ƀ}�b�s���O���܂���',13,10,0

	.even

***********************************************************************************************
command_exec:
		move.w	#$1a,-(sp)
		DOS	_INPOUT
		addq.l	#2,sp

		moveq	#1,d1
		moveq	#-1,d2
		IOCS	_TPALET
		move.l	d0,-(sp)

		move.l	a2,-(sp)

		pea	$ff0e76		* ROM��΃A�h���X
		DOS	_SUPER_JSR
		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#8,sp

		movea.l	(sp)+,a2
		tst.b	(a2)+
		bne	skip_c1
		pea	(pressmes,pc)
		DOS	_PRINT
		addq.l	#4,sp
		DOS	_INKEY
skip_c1:	moveq	#1,d1
		move.l	(sp)+,d2
		IOCS	_TPALET

		DOS	_EXIT

pressmes:	dc.b	13,10,'press key.',13,10,0


	.bss

RAM_END:	ds.l	1
CRC_WORK:	ds.l	256

	.end	command_exec
