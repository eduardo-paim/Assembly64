;-----------------------------------------------------------------------------;
; Author: Ege Balcı (egebalci[at]pm[dot]me)
; Version: 1.1 (29 April 2023)
; Architecture: x86
; Size: 129 bytes
;-----------------------------------------------------------------------------;

[BITS 32]

; Input: The CRC32 hash of the module and function name.
; Output: The address of the function will be in EAX.
; Clobbers: EAX (caller needs to clear the hash on the stack)
; Un-Clobbered: EBX, ESI, EDI, ESP and EBP can be expected to remain un-clobbered.
; Note: This function assumes the direction flag has allready been cleared via a CLD instruction.

%define CRC32_SEED 0x00

api_call:
  pushad                 ; We preserve all the registers for the caller, bar EAX and ECX.
  mov ebp, esp           ; Create a new stack frame
  xor eax, eax           ; Zero EAX (upper 3 bytes will remain zero until function is found)
  mov edx, [fs:eax+48]   ; Get a pointer to the PEB
  mov edx, [edx+12]      ; Get PEB->Ldr
  mov edx, [edx+20]      ; Get the first module from the InMemoryOrder module list
next_mod:                ;
  mov esi, [edx+40]      ; Get pointer to modules name (unicode string)
  movzx ecx, word [edx+38] ; Set ECX to the length we want to check
  xor edi, edi           ; Clear EDI which will store the hash of the module name
  mov edi, CRC32_SEED    ; Set the initial CRC32 seed value
loop_modname:            ;
  lodsb                  ; Read in the next byte of the name
  cmp al, 'a'            ; Some versions of Windows use lower case module names
  jl not_lowercase       ;
  sub al, 0x20           ; If so normalise to uppercase
not_lowercase:           ;
  crc32 edi,al           ; Calculate CRC32 value
  loop loop_modname      ; Loop until we have read enough

  ; We now have the module hash computed
  push edx               ; Save the current position in the module list for later
  push edi               ; Save the current module hash for later
  ; Proceed to iterate the export address table,
  mov edx, [edx+16]      ; Get this modules base address
  mov ecx, [edx+60]      ; Get PE header

  ; use ecx as our EAT pointer here so we can take advantage of jecxz.
  mov ecx, [ecx+edx+120] ; Get the EAT from the PE header
  jecxz get_next_mod1    ; If no EAT present, process the next module
  add ecx, edx           ; Add the modules base address
  push ecx               ; Save the current modules EAT
  mov ebx, [ecx+32]      ; Get the rva of the function names
  add ebx, edx           ; Add the modules base address
  mov ecx, [ecx+24]      ; Get the number of function names
  ; now ecx returns to its regularly scheduled counter duties

  ; Computing the module hash + function hash
get_next_func:           ;
  jecxz get_next_mod     ; When we reach the start of the EAT (we search backwards), process the next module
  mov edi, [ebp-8]       ; Reset the current module hash
  dec ecx                ; Decrement the function name counter
  mov esi, [ebx+ecx*4]   ; Get rva of next module name
  add esi, edx           ; Add the modules base address
  ; And compare it to the one we want
loop_funcname:           ;
  lodsb                  ; Read in the next byte of the ASCII function name
  crc32 edi,al           ; Calculate CRC32
  cmp al, ah             ; Compare AL (the next byte from the name) to AH (null)
  jne loop_funcname      ; If we have not reached the null terminator, continue
  cmp edi, [ebp+36]      ; Compare the hash to the one we are searching for
  jnz get_next_func      ; Go compute the next function hash if we have not found it

  ; If found, fix up stack, call the function and then value else compute the next one...
  pop eax                ; Restore the current modules EAT
  mov ebx, [eax+36]      ; Get the ordinal table rva
  add ebx, edx           ; Add the modules base address
  mov cx, [ebx+2*ecx]    ; Get the desired functions ordinal
  mov ebx, [eax+28]      ; Get the function addresses table rva
  add ebx, edx           ; Add the modules base address
  mov eax, [ebx+4*ecx]   ; Get the desired functions RVA
  add eax, edx           ; Add the modules base address to get the functions actual VA
  ; We now fix up the stack and perform the call to the desired function...
finish:
  mov [esp+36], eax      ; Overwrite the old EAX value with the desired api address for the upcoming popad
  pop ebx                ; Clear off the current modules hash
  pop ebx                ; Clear off the current position in the module list
  popad                  ; Restore all of the callers registers, bar EAX, ECX and EDX which are clobbered
  ret                    ; Return to the caller with function address inside EAX
  ; We now automagically return to the correct caller...

get_next_mod:            ;
  pop edi                ; Pop off the current (now the previous) modules EAT
get_next_mod1:           ;
  pop edi                ; Pop off the current (now the previous) modules hash
  pop edx                ; Restore our position in the module list
  mov edx, [edx]         ; Get the next module
  jmp short next_mod     ; Process this module
