%define sys_exit 60
%define sys_close 3
%define sys_open 2
%define buffer_size 8000


section .data 

; The data is stored in form of 256-bit 'mask'
occurances0_255 TIMES 4 DQ 0
correct0_255 TIMES 4 DQ 0		; 'Mask' of the first element of the sequence
filed DQ 0 				; File descriptor
number_of_read DQ 0			; Number of read bytes to buffer
; Counter of already analyzed bytes is r15

section .bss

buf resb buffer_size 			; Buffer for reading


section .text	
	global _start 

%macro read 0
	xor rax, rax 			; set rax to zero (number of sys_read instruction)
	mov rdi, [filed]		; save file descriptor to rdi (required by sys_read)
	mov rsi, buf			; rdi to buf address 
	mov rdx, buffer_size		; set rdx to size of the buffer
	syscall 			; read(rdi, buf, buffer_size) 
	mov [number_of_read], eax 	; get number of read bytes
	xor r15, r15
%endmacro

%macro add_number_to_template 0
	; get byte to cl		
	xor rcx, rcx
	mov cl, BYTE[buf+r15]
	
	; set corresponding bit
	bts [correct0_255], rcx
	
	; if it's been already on, exit_fail
	jb exit_fail
%endmacro


%macro read_sequence 0
	%%read_sequence_start:
	; if(counter == buffer_size) then we have to read
	cmp r15, buffer_size
	jne %%while1_dont_read
	read
	%%while1_dont_read:
	; if(number_of_read == counter) then it's the end
	cmp [number_of_read], r15
	je check_if_ok

	;get byte		
	xor rcx, rcx
	mov cl, BYTE[buf+r15]
	
	; is sequence finished
	cmp cl, 0
	je %%ok
	
	bts [occurances0_255], rcx
	jb exit_fail
	inc r15
	jmp %%read_sequence_start 

%%ok:

%endmacro

_start: 
	; Initializing             
	cmp qword [rsp], 2 		; check if (argc == 2) 
	jne exit_fail 			; jump to exit_fail
	
	mov rdi, [rsp + 16]		; get file name
	mov rax, sys_open
	xor rsi, rsi			; set rsi to zero (mode = read only) 
	syscall 			; open(rdi, 0, 0)

	mov [filed], rax		; save file descriptor to variable
	xor r15,r15			; r15 - counter of already analyzed bytes


	read 				; reading to buffer
	; if it's empty, exit_fail
	cmp DWORD [number_of_read], 0
	je exit_fail

	;while(buf[counter] != 0)
	while0:	
		xor rbx,rbx
		mov bl, BYTE[buf+r15]
		cmp bl, 0		; check if next byte is null	
		je end_while0
		add_number_to_template
		inc r15			; increase counter
		jmp while0
	end_while0:
	
	inc r15

	;while(counter != number_of_read)
	while1:
		; if (counter == buffer_size), then we have to read more
		cmp r15, buffer_size
		jne while1_dont_read
		read
		while1_dont_read:
		; if (number_of_read == counter), then we finish
		cmp [number_of_read], r15
		je exit_ok
	
		; clearing the mask
		mov QWORD [occurances0_255], 0
		mov QWORD [occurances0_255 + 8], 0
		mov QWORD [occurances0_255 + 16], 0
		mov QWORD [occurances0_255 + 24], 0

		read_sequence

		; comparing masks
		check_if_ok:		
		mov r12, QWORD [occurances0_255]
		cmp r12, [correct0_255]
		jne exit_fail
		mov r13, QWORD [occurances0_255 + 8]
		cmp r13, [correct0_255 + 8]
		jne exit_fail
		mov r14, QWORD [occurances0_255 + 16]
		cmp r14, [correct0_255 + 16]
		jne exit_fail
		mov r14, QWORD [occurances0_255 + 24]
		cmp r14, [correct0_255 + 24]
		jne exit_fail
		inc r15

	jmp while1

%macro close_file 0 
	mov rax, sys_close
	mov rdi, [filed] 		; prepare file_descriptor
	syscall

%endmacro


exit_ok: 
	close_file
	mov rax, sys_exit 		; 60 -> exit
	xor rdi, rdi 
	syscall 			; exit(0)

exit_fail: 
	close_file
	mov rax, sys_exit 		; 60 -> exit
	mov rdi, 1
	syscall				; exit(1)
