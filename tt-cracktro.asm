.586
.model flat,stdcall
.mmx
option casemap:none


;#1599 RCDATA DISCARDABLE  "msx\\chiptune.xm"

	include		\masm32\INCLUDE\windows.inc
	include		\masm32\INCLUDE\kernel32.inc
	includelib	\masm32\LIB\kernel32.lib
	include		\masm32\INCLUDE\user32.inc
	includelib	\masm32\LIB\user32.lib
	include		\masm32\INCLUDE\comctl32.inc
	includelib	\masm32\LIB\comctl32.lib
	include		\masm32\INCLUDE\gdi32.inc
	includelib	\masm32\LIB\gdi32.lib
	
	include		./gfx/pnglib.inc
	includelib	./gfx/pnglib.lib

	include 	\masm32\INCLUDE\winmm.inc
	includelib 	\masm32\LIB\winmm.lib
	include		./msx/ufmod.inc
	includelib	./msx/ufmod.lib

	WinMain				PROTO	:HINSTANCE,:HINSTANCE,:LPSTR,:SDWORD
	WndProc				PROTO	:HWND,:UINT,:WPARAM,:LPARAM
	LoadPng				PROTO	:DWORD,:DWORD
	PreMul				PROTO	:DWORD
	AlphaBlend2			PROTO	:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:BOOL
	PaintText 			PROTO	:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD
	RefreshFrame		PROTO	


.const
	ID_FRAME			equ		1500
	ID_EXIT				equ		1511
	ID_CURSOR			equ		1597
	ID_ICON				equ		1598
	ID_XM				equ		1599
	; PNG sizes/placements
	Frame_Size_X		equ		617
	Frame_Size_Y		equ		285
	Generate_Size_X		equ		96
	Generate_Size_Y		equ		26
	Exit_Size_X			equ		54
	Exit_Size_Y			equ		23
	Gen_Left			equ		257
	Gen_Right			equ		Gen_Left + Generate_Size_X - 1
	Gen_Top				equ		188
	Gen_Bottom			equ		Gen_Top + Generate_Size_Y - 1
	Exit_Left			equ		278
	Exit_Right			equ		Exit_Left + Exit_Size_X - 1
	Exit_Top			equ		240;218
	Exit_Bottom			equ		Exit_Top + Exit_Size_Y - 1
	; Hover mask
	H_MAIN				equ		00001b
	H_GEN				equ		00010b
	H_EXIT				equ		00100b

	Fade_Speed			equ		10
	; Text/Cursor stuff
	CursorShow			equ		'_'
	widthCursorShow		equ		6 ; "*" = 6 pixels in width.. it depends on Font and Font settings !
	CursorHide			equ		' '
	widthCursorHide		equ		2 ; " " = 2 pixels in width.. it depends on Font and Font settings !
	CursorSpeed			equ		18
	ScrollerSpeed		equ		18
	ScrWndWidth			equ		416 ; must be divisible by 8 !!!! ---> 416 / 8 = 52

.data
	ClassName			db		"Kolor",0
	ptZero				POINT	<0,0>
	blender				BLENDFUNCTION	<AC_SRC_OVER,0,0,AC_SRC_ALPHA>
	BIH					BITMAPINFOHEADER	<sizeof(BITMAPINFOHEADER),Frame_Size_X,Frame_Size_Y,1,32,BI_RGB,NULL,NULL,NULL,NULL,NULL>
	FontKey				LOGFONT	<14,0,0,0,FW_DONTCARE,0,0,0,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,\
									ANTIALIASED_QUALITY,DEFAULT_PITCH or FF_DONTCARE,"Impact">
									
						include 	./msx/msx.inc
	xmSize 				equ $ - table
	
.data?
	hInstance			HINSTANCE	?
	hWin				dd		?
	; PNG related
	dcScreen			dd		?
	dcMem				dd		?
	dibMain				dd		?
	dibFrame			dd		?
	bFrame				dd		?
	bGenerate			dd		?
	bExit				dd		?
	hOldBmp				dd		?
	sizeFrame			dd		?,?
	sizeButton			dd		?,?
	Transparency		dd		?
	bm					BITMAP	<>
	pBblank				dd		?
	dcTxt				dd		?
	dibTxt 				dd		?
	; Scroller
	dcScroller			dd		?
	dibScroller			dd		?
	ScrollerSizeX		dd		?
	ScrollerSizeY		dd		?
	bminfoScroller		BITMAP	<?>
	ScrollerTxtSize		dd		?
	ScrActX				dd		?
	; Mouse tracking
	TME					TRACKMOUSEEVENT <>
	MouseInside			BOOL	?
	; Window moving
	MoveDlg				BOOL	?
	Rect				RECT	<>
	OldPos				POINT	<>
	NewPos				POINT	<>
	; Hover stuff
	hitpoint			POINT	<>
	HOVER_FLAG			db		?
	BTN_FLAG			BOOL	?
	GenCol				BOOL	?
	ExitCol				BOOL	?
	; Text boxes
	CursorFlag			BOOL	?
	CursorCounter		dw		?
	Cursor				dw		?
	keys				db 		256 dup (?)
	keyTimer			dd		?
	txtName				db		50 dup (?)
	txtSerial			db		100 dup (?)
	CursorTimer			dd		?
	; Clipboard copy
	lenName				dd		?
	nLen				dd		?
	hMem				dd		?
	pMem				dd		?

include Config.asm
	
.code
start:
	invoke GetModuleHandle, NULL
	mov    hInstance,eax
	invoke InitCommonControls
	invoke WinMain, hInstance,NULL,NULL, SW_SHOWDEFAULT
	invoke ExitProcess,eax

WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:SDWORD
	LOCAL wc:WNDCLASSEX, msg:MSG
	
	mov   wc.cbSize,SIZEOF WNDCLASSEX
	mov   wc.style, CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
	mov   wc.lpfnWndProc, offset WndProc
	mov   wc.cbClsExtra,NULL
	mov   wc.cbWndExtra,NULL
	push  hInstance
	pop   wc.hInstance
	mov   wc.hbrBackground,COLOR_BTNFACE+1
	mov   wc.lpszMenuName,NULL
	mov   wc.lpszClassName,offset ClassName
	invoke LoadIcon,NULL,ID_ICON
	mov   wc.hIcon,eax
	mov   wc.hIconSm,eax
	invoke LoadCursor,hInst,ID_CURSOR
	mov   wc.hCursor,eax
	invoke RegisterClassEx, addr wc
	invoke GetSystemMetrics,SM_CXSCREEN
	sub eax,Frame_Size_X  
	shr eax,1
	push eax
	invoke GetSystemMetrics,SM_CYSCREEN
	sub eax,Frame_Size_Y  
	shr eax,1
	pop ebx
	invoke CreateWindowEx,WS_EX_LAYERED,addr ClassName,addr AppName,WS_POPUP,ebx,eax,Frame_Size_X,Frame_Size_Y,NULL,NULL,hInst,NULL
	mov hWin,eax
	invoke ShowWindow, hWin,SW_SHOWNORMAL
	invoke UpdateWindow, hWin

	.while TRUE
		invoke GetMessage, addr msg,NULL,0,0
		.break .if (!eax)
		invoke TranslateMessage, addr msg
		invoke DispatchMessage, addr msg
	.endw
	mov eax,msg.wParam
	ret
WinMain endp

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	
	.if uMsg==WM_CREATE
	; Load PNGs
		invoke LoadPng,ID_FRAME,addr sizeFrame
		mov bFrame,eax
		
		invoke LoadPng,ID_EXIT,addr sizeButton
		mov bExit,eax
	; Prepare main canvas
		invoke GetDC,0
		mov dcScreen,eax
		invoke CreateDIBSection, dcScreen, addr BIH, DIB_RGB_COLORS, addr pBblank, NULL, NULL
		mov dibMain,eax
		invoke CreateCompatibleDC,dcScreen
		mov dcMem,eax
		invoke CreateDIBSection, dcMem, addr BIH, DIB_RGB_COLORS, addr pBblank, NULL, NULL
		mov dibFrame,eax
		invoke SelectObject,dcMem,dibFrame
		mov hOldBmp,eax
	; Prepare canvas for text
		invoke CreateCompatibleDC,dcScreen
		mov dcTxt,eax
		invoke CreateDIBSection, dcTxt, addr BIH, DIB_RGB_COLORS, addr pBblank, NULL, NULL
		mov dibTxt,eax
		invoke SelectObject,dcTxt,dibTxt
		invoke CreateFontIndirect,addr FontKey
		invoke SelectObject,dcTxt,eax
	; Create and prepare scroller bitmap
		invoke CreateCompatibleDC,dcScreen
		mov dcScroller,eax
		invoke CreateFontIndirect,addr FontKey
		invoke SelectObject,dcScroller,eax
		invoke lstrlen,addr txtScroller
		mov ScrollerTxtSize,eax
		invoke GetTextExtentPoint,dcScroller,addr txtScroller,eax,addr ScrollerSizeX
		push ScrollerSizeX
		pop BIH.biWidth
		add BIH.biWidth,ScrWndWidth*2 ; For empty space in front and after the text
		push ScrollerSizeY
		pop BIH.biHeight
		dec ScrollerSizeY
		invoke CreateDIBSection, dcScroller, addr BIH, DIB_RGB_COLORS, addr pBblank, NULL, NULL
		mov dibScroller,eax
		invoke SelectObject,dcScroller,dibScroller
		invoke GetObject,dibScroller,sizeof bminfoScroller,addr bminfoScroller
		invoke SetBkMode,dcScroller,OPAQUE
		invoke SetBkColor,dcScroller,0
		invoke SetTextColor,dcScroller,022h
		invoke TextOut,dcScroller,ScrWndWidth,0,addr txtScroller,ScrollerTxtSize
		mov eax,bminfoScroller.bmWidth
		mov ecx,bminfoScroller.bmHeight
		mul ecx
		mov edi,bminfoScroller.bmBits
		.while eax > 0
			.if dword ptr [edi] != 0
				or byte ptr [edi+3],0FFh ; Fill Alpha-Bits to opaque, if RGB-Bits are not empty
			.endif
			add edi,4
			dec eax
		.endw
	; Copy frame bitmap into main canvas
		invoke GetObject,bFrame,sizeof bm,addr bm
		mov esi,bm.bmBits
		invoke GetObject,dibMain,sizeof bm,addr bm
		mov edi,bm.bmBits
		mov eax,bm.bmHeight
		mul bm.bmWidth
		mov ebx,eax
	@@:	mov eax,[esi]
		mov [edi],eax
		add esi,4
		add edi,4
		dec ebx
		jnz @B
	

		invoke SetWindowPos,hWnd,0,0,0,Frame_Size_X,Frame_Size_Y,SWP_NOZORDER or SWP_NOMOVE
		invoke ShowWindow,hWnd,SW_SHOW
		invoke uFMOD_PlaySong,addr table,xmSize,XM_MEMORY
		invoke SetTimer,hWnd,777,ScrollerSpeed,NULL
	; Init TRACKMOUSEEVENT
		mov TME.cbSize, sizeof TME
		push hWnd
		pop TME.hwndTrack
		mov TME.dwFlags, TME_LEAVE
	FadeIn:
		add blender.SourceConstantAlpha,5
		invoke UpdateLayeredWindow,hWnd,dcScreen,NULL,offset sizeFrame,dcMem,offset ptZero,0,offset blender,ULW_ALPHA
		invoke Sleep,Fade_Speed
		cmp blender.SourceConstantAlpha,255
		jne FadeIn
	
	
	
	.ELSEIF uMsg == WM_KEYDOWN
		; Following is a simulation of a window editbox:
 		.IF keyTimer == 0 
			mov eax, wParam
			mov keys[eax], 1   
			.IF al == 20h || (al >= 30h && al <= 39h) || (al >= 41h && al <= 5Ah) || ((!keys[VK_SHIFT]) && (al >= 0BBh && al <= 0BFh)) ; " " or "1...9" or "a...z" or "+...?"
				lea edx, txtName
				add edx, lenName
				.IF !keys[VK_SHIFT] && al >= 41h && al <= 5Ah ; "a...z"
					add al, 20h
				.ELSEIF keys[VK_SHIFT] && al >=31h && al <= 39h ; "!...)"
					sub al, 10h
				.ELSEIF !keys[VK_SHIFT] && al >=0BBh && al <= 0BFh ; "+...?"
					sub al, 90h
				.ENDIF

			.ELSEIF ax == [VK_BACK] && lenName > 0
				lea edx, txtName
				sub lenName, 1
				add edx, lenName
				mov ax, word ptr Cursor
				mov word ptr [edx], ax
			.elseif ax == VK_ESCAPE
				invoke PostMessage,hWnd,WM_CLOSE,0,0
			.ELSE
				ret
			.ENDIF

		.ELSE
			;add keyTimer,1


		.ENDIF	
	
	.ELSEIF uMsg == WM_KEYUP
		mov eax, wParam
		mov keys[eax], 0

	.elseif uMsg==WM_LBUTTONDOWN
		.if HOVER_FLAG==H_MAIN || HOVER_FLAG==NULL
			mov MoveDlg,TRUE
			invoke SetCapture,hWnd
			invoke GetCursorPos,addr OldPos
		.else
			mov BTN_FLAG, TRUE
			invoke RefreshFrame
		.endif
		
	.elseif uMsg==WM_MOUSEMOVE
		mov eax,lParam
		and eax,0ffffh
		mov hitpoint.x,eax
		mov eax,lParam
		shr eax,16
		mov hitpoint.y,eax
		.if hitpoint.x >= Gen_Left && hitpoint.x <= Gen_Right && hitpoint.y >= Gen_Top && hitpoint.y <= Gen_Bottom   ; Gen button hovered ?

		.elseif hitpoint.x >= Exit_Left && hitpoint.x <= Exit_Right && hitpoint.y >= Exit_Top && hitpoint.y <= Exit_Bottom   ; Exit button hovered ?
			.if ExitCol == FALSE
				mov GenCol,FALSE
				mov HOVER_FLAG, H_EXIT
				invoke RefreshFrame
				mov ExitCol, TRUE
			.endif
		.elseif MoveDlg==TRUE
			invoke GetWindowRect,hWnd,addr Rect
			invoke GetCursorPos,addr NewPos
			mov eax,NewPos.x
			mov ecx,eax
			sub eax,OldPos.x
			mov OldPos.x,ecx
			add eax,Rect.left
			mov ebx,NewPos.y
			mov ecx,ebx
			sub ebx,OldPos.y
			mov OldPos.y,ecx
			add ebx,Rect.top
			mov ecx,Rect.right
			sub ecx,Rect.left
			mov edx,Rect.bottom
			sub edx,Rect.top
			invoke MoveWindow,hWnd,eax,ebx,ecx,edx,TRUE
		.else
			mov HOVER_FLAG, H_MAIN
			.if GenCol == TRUE
				mov GenCol, FALSE
				invoke RefreshFrame
			.elseif ExitCol == TRUE
				mov ExitCol, FALSE
				invoke RefreshFrame
			.endif
		.endif
		.if MouseInside==FALSE
			mov MouseInside,TRUE
			invoke TrackMouseEvent,addr TME
		.endif
	
	.elseif uMsg==WM_LBUTTONUP
		.if HOVER_FLAG==H_EXIT
			invoke PostMessage,hWnd,WM_CLOSE,0,0
		.else
			mov MoveDlg,FALSE
			invoke ReleaseCapture
		.endif
		mov BTN_FLAG, FALSE
		invoke RefreshFrame

  	.elseif uMsg==WM_RBUTTONDOWN
		invoke ShowWindow,hWnd,SW_MINIMIZE

	.elseif uMsg==WM_MOUSELEAVE
		mov HOVER_FLAG,0
		mov BTN_FLAG,FALSE
		mov MouseInside, FALSE
		.if GenCol == TRUE
			mov GenCol, FALSE
			invoke RefreshFrame
		.elseif ExitCol == TRUE
			mov ExitCol, FALSE
			invoke RefreshFrame
		.endif

	.elseif uMsg==WM_TIMER
		inc CursorTimer
		.if CursorTimer == CursorSpeed
			mov CursorTimer,0
			.IF CursorFlag
				mov al, CursorHide
				mov CursorFlag, FALSE
			.ELSE
				mov al, CursorShow
				mov CursorFlag, TRUE
			.ENDIF
		mov byte ptr Cursor, al
		lea edx, txtName
		add edx, lenName
		mov byte ptr [edx], al
		.endif
		inc ScrActX
		mov eax,bminfoScroller.bmWidth
		sub eax, ScrWndWidth
		.if eax == ScrActX
			mov ScrActX,0
		.endif
		invoke RefreshFrame
		
	.elseif uMsg==WM_CLOSE
	FadeOut:
		invoke UpdateLayeredWindow,hWnd,dcScreen,NULL,offset sizeFrame,dcMem,offset ptZero,0,offset blender,ULW_ALPHA
		invoke Sleep,Fade_Speed
		sub blender.SourceConstantAlpha,5
		cmp blender.SourceConstantAlpha,0
		jne FadeOut
		invoke PostMessage,hWnd,WM_DESTROY,0,0

 	.elseif uMsg==WM_DESTROY
		invoke KillTimer,hWnd,777
		invoke SelectObject,dcMem,hOldBmp
		invoke DeleteDC,dcMem
		invoke ReleaseDC,hWnd,dcScreen
		invoke DeleteObject,bFrame
		invoke uFMOD_PlaySong,0,0,0
		invoke PostQuitMessage,NULL
		
  	.else
		invoke DefWindowProc,hWnd,uMsg,wParam,lParam		
		ret
	.endif
	
	xor eax,eax
	ret
WndProc endp

LoadPng proc ID:DWORD,pSize:DWORD
	LOCAL pngInfo:PNGINFO

	invoke PNG_Init, addr pngInfo
	invoke PNG_LoadResource, addr pngInfo, hInstance, ID
	.if !eax
		xor eax, eax
		jmp @cleanup
	.endif
	invoke PNG_Decode, addr pngInfo
	.if !eax
		xor eax, eax
		jmp @cleanup
	.endif
	invoke PNG_CreateBitmap, addr pngInfo, hWin, PNG_OUTF_AUTO, FALSE
	.if		!eax
		xor eax, eax
		jmp @cleanup
	.endif
	mov edi,pSize
	.if edi!=0
		lea esi,pngInfo
		movsd
		movsd
	.endif
	
@cleanup:
	push eax	
	invoke PNG_Cleanup, addr pngInfo
	
	pop eax
	ret

LoadPng endp

PreMul proc hBmp:DWORD
	LOCAL bminfo:BITMAP
	
	invoke GetObject,hBmp,sizeof bminfo,addr bminfo
	cmp bminfo.bmBitsPixel,32
	jne Abort
	mov esi,bminfo.bmBits
	mov edi,esi
yloop:
	mov ecx,bminfo.bmWidth
xloop:
	mov eax,dword ptr [esi]
	mov edx,eax
	shr eax,24
	mov bl,al
	add esi,4
	mul dl
	shr eax,8
	stosb
	mov al,bl
	shr edx,8
	mul dl
	shr eax,8
	stosb
	mov al,bl
	shr edx,8
	mul dl
	shr eax,8
	stosb
	inc edi
	dec ecx
	jnz xloop
	dec bminfo.bmHeight
	jnz yloop
Abort:
	ret

PreMul endp

AlphaBlend2 proc hSrcBm:DWORD,srcx:DWORD,srcy:DWORD,srcw:DWORD,srch:DWORD,hDstBm:DWORD,dstx:DWORD,dsty:DWORD,Fade:BOOL
	LOCAL bmsrc:BITMAP, bmdst:BITMAP
	LOCAL srci:DWORD, dsti:DWORD
	LOCAL ScrWidth

	invoke GetObject,hSrcBm,sizeof bmsrc,addr bmsrc
	invoke GetObject,hDstBm,sizeof bmdst,addr bmdst
	mov eax,bmsrc.bmWidth
	sub eax,srcw
	shl eax,2
	mov srci,eax
	mov eax,bmdst.bmWidth
	sub eax,srcw
	shl eax,2
	mov dsti,eax
	mov eax,bmdst.bmWidth
	mov edx,bmdst.bmHeight
	sub edx,dsty
	sub edx,srch
	mul edx
	add eax,dstx
	shl eax,2
	add eax,bmdst.bmBits
	mov edx,eax
	push edx
	mov eax,bmsrc.bmWidth
	mov edx,bmsrc.bmHeight
	sub edx,srcy
	sub edx,srch
	mul edx
	add eax,srcx
	shl eax,2
	add eax,bmsrc.bmBits
	pop edx
	shr srcw,1
.data
	__FF000000FF000000	dq 0FF000000FF000000h
	__00FFFFFF00FFFFFF	dq 000FFFFFF00FFFFFFh
	__FADING_MASK		dq 000FFFFFF00FFFFFFh
.code
	
AlphaBlendLoop: ; 13056 ticks for 1000 quads on Athlon. 
	mov ecx,srcw ; number of pixels/2 
	dec ecx 
	pxor mm7,mm7 
	movq mm0,[eax+ecx*8] 
	movq mm1,[edx+ecx*8]
@@:
	.if Fade
		.if ecx >= ( ScrWndWidth / 2 - 12 )
			pand mm0,__FADING_MASK
			add byte ptr __FADING_MASK+3,011h
			add byte ptr __FADING_MASK+7,011h
		.elseif ecx < 12
			sub byte ptr __FADING_MASK+3,011h
			sub byte ptr __FADING_MASK+7,011h
			pand mm0,__FADING_MASK
		.else
			pand mm0,__FADING_MASK
		.endif
	.endif
	movq mm4,mm0
	movq mm6,mm0
	;psrlw mm6,1 ; optional effect
	paddusb mm6,mm1
	pand mm6,__FF000000FF000000
	movq mm2,mm0 
	psrlw mm4,1 
	movq mm3,mm1 
	movq mm5,mm4 
	punpcklbw mm0,mm7 
	punpcklbw mm1,mm7 
	punpckhbw mm2,mm7 
	punpckhbw mm3,mm7 
	psubsw mm0,mm1 
	psubsw mm2,mm3 
	punpcklwd mm4,mm4 
	punpckhwd mm5,mm5 
	punpckhdq mm4,mm4 
	punpckhdq mm5,mm5
	psllw mm0,1 
	psllw mm2,1 
	pmulhw mm0,mm4 
	pmulhw mm2,mm5
	paddsw mm0,mm1 
	paddsw mm2,mm3 
	packuswb mm0,mm2
	pand mm0,__00FFFFFF00FFFFFF
	por mm0,mm6
	; stored alpha = (-dA * sA)/256 + dA (better!?)
	movq [edx+ecx*8],mm0
	dec ecx 
	js @F	; It crashes when I don't add this???
	movq mm0,[eax+ecx*8] 
	movq mm1,[edx+ecx*8] 
	jns @B
@@:
	mov ecx,srcw
	shl ecx,3
	add eax,ecx
	add edx,ecx    
	add eax,srci
	add edx,dsti
	dec srch
	jnz AlphaBlendLoop
    
	ret

AlphaBlend2 endp

PaintText proc hTmpDC:DWORD,hTmpBM:DWORD,hOutDC:DWORD,hOutBM:DWORD,pStr:DWORD,x:DWORD,y:DWORD
	
	LOCAL lStr:DWORD, TxtSize[2]:DWORD, NextLine:DWORD
	LOCAL StartOfs:DWORD, pSrc:DWORD, pDest:DWORD
	LOCAL bminfo:BITMAP
	
	invoke lstrlen, pStr
	.if eax==0
		ret
	.else
		mov lStr,eax
	.endif
	
	invoke GetTextExtentPoint,hTmpDC,pStr,lStr,addr TxtSize
;
	invoke GetObject,hTmpBM,sizeof bminfo,addr bminfo
	mov esi,bminfo.bmBits
	mov pSrc,esi
	invoke GetObject,hOutBM,sizeof bminfo,addr bminfo
	mov edi,bminfo.bmBits
	mov pDest,edi
	mov eax,bminfo.bmWidth
	sub eax,TxtSize
	shl eax,2
	mov NextLine,eax
	mov eax,bminfo.bmWidth
	mov edx,bminfo.bmHeight
	sub edx,y
	sub edx,TxtSize+4
	mul edx
	add eax,x
	shl eax,2
	mov StartOfs,eax

; Correct the alpha values in the destination DC
	invoke SetBkMode,hTmpDC,OPAQUE
	invoke TextOut,hTmpDC,x,y,pStr,lStr
	add esi,StartOfs
	add edi,StartOfs
	add edi,3
	mov ebx,TxtSize+4
yLoop:
	mov ecx,TxtSize
xLoop:
	mov eax,[esi]
	mov edx,eax
	rol edx,16
	ror eax,8
	and eax,0FFFF00FFh
	add dx,ax
	shr edx,24
	add ax,dx
	and eax,0FFFFh
	xor edx,edx
	 push ebx
	mov ebx,3
	div ebx
	 pop ebx
	not al
	.if al>[edi]
		mov [edi],al
	.endif
	add esi,4
	add edi,4
	dec ecx
	jnz xLoop
	add esi,NextLine
	add edi,NextLine
	dec ebx
	jnz yLoop
		
; Paint & copy the text
	invoke BitBlt,hTmpDC,x,y,TxtSize,TxtSize+4,hOutDC,x,y,SRCCOPY
	invoke SetBkMode,hTmpDC,TRANSPARENT
	invoke SetTextColor,hTmpDC,0CCCCEEh
	;invoke TextOut,hTmpDC,x,y,pStr,lStr
	mov esi,pSrc
	mov edi,pDest
	add esi,StartOfs
	add edi,StartOfs
	mov ebx,TxtSize+4
yLoop2:
	mov ecx,TxtSize
xLoop2:
	mov eax,[esi]
	mov edx,[edi]
	and edx,0FF000000h
	or eax,edx
	mov [edi],eax
	add esi,4
	add edi,4
	dec ecx
	jnz xLoop2
	add esi,NextLine
	add edi,NextLine
	dec ebx
	jnz yLoop2	
	
	ret

PaintText endp

RefreshFrame proc

; Restore frame without text/buttons/scroller	
	invoke GetObject,dibMain,sizeof bm,addr bm
	mov esi,bm.bmBits
	invoke GetObject,dibFrame,sizeof bm,addr bm
	mov edi,bm.bmBits
	mov eax,bm.bmHeight
	mul bm.bmWidth
	mov ebx,eax
@@:	mov eax,[esi]
	mov [edi],eax
	add esi,4
	add edi,4
	dec ebx
	jnz @B

; Scroller
	invoke AlphaBlend2,dibScroller,ScrActX,0,ScrWndWidth,ScrollerSizeY,dibFrame,100,136,TRUE
	mov eax,0
	.if HOVER_FLAG==H_EXIT
		.if  BTN_FLAG==TRUE
			mov eax,Exit_Size_Y*2
		.else
			mov eax,Exit_Size_Y
		.endif
	.else
		mov eax,0
	.endif
	invoke AlphaBlend2,bExit,0,eax,Exit_Size_X,Exit_Size_Y,dibFrame,Exit_Left,Exit_Top,FALSE
; Update window	
	invoke PreMul,dibFrame
	invoke UpdateLayeredWindow,hWin,dcScreen,NULL,offset sizeFrame,dcMem,offset ptZero,0,offset blender,ULW_ALPHA
	
	ret

RefreshFrame endp



end start
