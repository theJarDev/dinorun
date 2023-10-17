.386
.model flat, stdcall
.stack 10448576
option casemap:none

; ========== LIBRERIAS =============
include masm32\include\windows.inc 
include masm32\include\kernel32.inc
include masm32\include\user32.inc
includelib masm32\lib\kernel32.lib
includelib masm32\lib\user32.lib
include masm32\include\gdi32.inc
includelib masm32\lib\Gdi32.lib
include masm32\include\msimg32.inc
includelib masm32\lib\msimg32.lib
include masm32\include\winmm.inc
includelib masm32\lib\winmm.lib
include masm32\include\msvcrt.inc
includelib masm32\lib\msvcrt.lib

; ================ PROTOTIPOS ======================================
; Delcaramos los prototipos que no están declarados en las librerias
; (Son funciones que nosotros hicimos)
main			proto
credits			proto	:DWORD
playMusic		proto
joystickError	proto
WinMain			proto	:DWORD, :DWORD, :DWORD, :DWORD

; =========================================== DECLARACION DE VARIABLES =====================================================
.data
; ==========================================================================================================================
; =============================== VARIABLES QUE NORMALMENTE NO VAN A TENER QUE CAMBIAR =====================================
; ==========================================================================================================================
className				db			"ProyectoEnsamblador",0		; Se usa para declarar el nombre del "estilo" de la ventana.
windowHandler			dword		?							; Un HWND auxiliar
windowClass				WNDCLASSEX	<>							; Aqui es en donde registramos la "clase" de la ventana.
windowMessage			MSG			<>							; Sirve pare el ciclo de mensajes (los del WHILE infinito)
clientRect				RECT		<>							; Un RECT auxilar, representa el área usable de la ventana
windowContext			HDC			?							; El contexto de la ventana
layer					HBITMAP		?							; El lienzo, donde dibujaremos cosas
layerContext			HDC			?							; El contexto del lienzo
auxiliarLayer			HBITMAP		?							; Un lienzo auxiliar
auxiliarLayerContext	HBITMAP		?							; El contexto del lienzo auxiliar
clearColor				HBRUSH		?							; El color de limpiado de pantalla
windowPaintstruct		PAINTSTRUCT	<>							; El paintstruct de la ventana.
joystickInfo			JOYINFO		<>							; Información sobre el joystick
; Mensajes de error:
errorTitle				byte		'Error',0
joystickErrorText		byte		'No se pudo inicializar el joystick',0
; ==========================================================================================================================
; ========================================== VARIABLES QUE PROBABLEMENTE QUIERAN CAMBIAR ===================================
; ==========================================================================================================================
; El título de la ventana
windowTitle				db			"DinoRun",0
; El ancho de la venata CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
windowWidth				DWORD		1734	
; El alto de la ventana CON TODO Y LA BARRA DE TITULO Y LOS MARGENES
windowHeight			DWORD		840							
; Un string, se usa como título del messagebox NOTESE QUE TRAS ESCRIBIR EL STRING, SE LE CONCATENA UN 0
messageBoxTitle			byte		'Plantilla ensamblador: Créditos',0	
; Se usa como texto de un mensaje, el 10 es para hacer un salto de linea
; (Ya que 10 es el valor ascii de \n)
messageBoxText			byte		'Programación: Edgar Abraham Santos Cervantes',10,'Arte: Estúdio Vaca Roxa',10,'https://bakudas.itch.io/generic-rpg-pack',0
; El nombre de la música a reproducir.
; Asegúrense de que sea .wav
musicFilename			byte		'AthleticTheme.wav',0  ;'FlowerGarden.wav',0
; El manejador de la imagen a manuplar, pueden agregar tantos como necesiten.
image					HBITMAP		?
; El nombre de la imagen a cargar
imageFilename			byte		'atlas.bmp',0

x sdword 0
y sdword 0

xFondo sdword 363

xSuelo sdword 381
ySuelo sdword 343

xWasd dword 143
yWasd dword 100

xTeclaP dword 145
yTeclaP dword 50

xPantalla dword 1720
yPantalla dword 800

xPausa dword 0
yPausa dword 0

xMuerte dword 0
yMuerte dword 0

xOrigenDino sdword 100
yOrigenDino sdword 4

xOrigenMoneda sdword 589
yOrigenMoneda sdword 75

vida dword 164

rectanguloColision RECT <>
rectanguloDino RECT <>
rectanguloCactus RECT <>
rectanguloCactus2 RECT <>
rectanguloCactus3 RECT <>
rectanguloCactus4 RECT <>
rectanguloCactus5 RECT <>
rectanguloCactus6 RECT <>
rectanguloMoneda RECT <>

booleano dword 1

mts byte 12 dup (0)
puntuacion dword 0
mejorPuntuacion dword 0
xPuntuacion dword 500
velocidadCactus dword 20
velocidadSuelo dword 20
velocidadFondo dword 1
velocidadMoneda dword 20


; =============== MACROS ===================
RGB MACRO red, green, blue
	exitm % blue shl 16 + green shl 8 + red
endm 

.code

main proc
	invoke crt_time, 0
	invoke crt_srand, eax
	; El programa comienza aquí.
	; Le pedimos a un hilo que reprodusca la música
	invoke	CreateThread, 0, 0, playMusic, 0, 0, 0
	; Obtenemos nuestro HINSTANCE.
	; NOTA IMPORTANTE: Las funciones de WinAPI normalmente ponen el resultado de sus funciones en el registro EAX
	invoke	GetModuleHandleA, NULL   
	; Mandamos a llamar a WinMain
	; Noten que, como GetModuleHandleA nos regresa nuestro HINSTANCE y los resultados de las funciones de WinAPI
	; suelen estar en EAX, entonces puedo pasar a EAX como el HINSTANCE
	invoke	WinMain, eax, NULL, NULL, SW_SHOWDEFAULT
	; Cierra el programa
	invoke ExitProcess,0
main endp

; Este es el WinMain, donde se crea la ventana y se hace el ciclo de mensajes.
WinMain proc hInstance:dword, hPrevInst:dword, cmdLine:dword, cmdShow:DWORD
	; ============== INICIALIZACION DE LA CLASE ====================
	; Establecemos nuestro callback procedure, que en este caso se llama WindowCallback
	mov		windowClass.lpfnWndProc, OFFSET WindowCallback
	; Tenemos que decir el tamaño de nuestra estructura, si no se lo dicen no se podrá crear la ventana.
	mov		windowClass.cbSize, SIZEOF WNDCLASSEX
	; Le asignamos nuestro HINSTANCE
	mov		eax, hInstance
	mov		windowClass.hInstance, eax
	; Asignamos el nombre de nuestra "clase"
	mov		windowClass.lpszClassName, OFFSET className
	; Registramos la clase
	invoke RegisterClassExA, addr windowClass                      
    
	; ========== CREACIÓN DE LA VENATANA =============
	; Creamos la ventana.
	; Le asignamos los estilos para que se pueda crear pero que NO se pueda alterar su tamaño, maximizar ni minimizar
	xor		ebx, ebx
	mov		ebx, WS_OVERLAPPED
	or		ebx, WS_CAPTION
	or		ebx, WS_SYSMENU
	invoke CreateWindowExA, NULL, ADDR className, ADDR windowTitle, ebx, CW_USEDEFAULT, CW_USEDEFAULT, windowWidth, windowHeight, NULL, NULL, hInstance, NULL
    ; Guardamos el resultado en una variable auxilar y mostramos la ventana.
	mov		windowHandler, eax
    invoke ShowWindow, windowHandler,cmdShow               
    invoke UpdateWindow, windowHandler                    

	; ============= EL CICLO DE MENSAJES =======================
    invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
	.WHILE eax != 0                                  
        invoke	TranslateMessage, ADDR windowMessage
        invoke	DispatchMessageA, ADDR windowMessage
		invoke	GetMessageA, ADDR windowMessage, NULL, 0, 0
   .ENDW
    mov eax, windowMessage.wParam
	ret
WinMain endp


; El callback de la ventana.
; La mayoria de la lógica de su proyecto se encontrará aquí.
; (O desde aquí se mandarán a llamar a otras funciones)
WindowCallback proc handler:dword, message:dword, wParam:dword, lParam:dword
	.IF message == WM_CREATE
		; Lo que sucede al crearse la ventana.
		; Normalmente se usa para inicializar variables.
		; Obtiene las dimenciones del área de trabajo de la ventana.
		invoke	GetClientRect, handler, addr clientRect
		; Obtenemos el contexto de la ventana.
		invoke	GetDC, handler
		mov		windowContext, eax
		; Creamos un bitmap del tamaño del área de trabajo de nuestra ventana.
		invoke	CreateCompatibleBitmap, windowContext, clientRect.right, clientRect.bottom
		mov		layer, eax
		; Y le creamos un contexto
		invoke	CreateCompatibleDC, windowContext
		mov		layerContext, eax
		; Liberamos windowContext para poder trabajar con lo demás
		invoke	ReleaseDC, handler, windowContext
		; Le decimos que el contexto layerContext le pertenece a layer
		invoke	SelectObject, layerContext, layer
		invoke	DeleteObject, layer
		; Asignamos un color de limpiado de pantalla
		invoke	CreateSolidBrush, RGB(0,0,0)
		mov		clearColor, eax
		;Cargamos la imagen
		invoke	LoadImage, NULL, addr imageFilename, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE
		mov		image, eax
		; Habilitamos el joystick
		invoke	joyGetNumDevs
		.IF eax == 0
			invoke joystickError	
		.ELSE
			invoke	joyGetPos, JOYSTICKID1, addr joystickInfo
			.IF eax != JOYERR_NOERROR
				;invoke joystickError
			.ELSE
				invoke	joySetCapture, handler, JOYSTICKID1, NULL, FALSE
				.IF eax != 0
					;invoke joystickError
				.ENDIF
			.ENDIF
		.ENDIF
		; Habilita el timer
		;invoke	SetTimer, handler, 100, 100, NULL

		mov rectanguloCactus.left, 1720
		mov rectanguloCactus.top, 553
		mov rectanguloCactus.right, 1720+93
		mov rectanguloCactus.bottom, 553+110

		mov rectanguloCactus2.left, 2006
		mov rectanguloCactus2.top, 553
		mov rectanguloCactus2.right, 2006+93
		mov rectanguloCactus2.bottom, 553+110

		mov rectanguloCactus3.left, 2293
		mov rectanguloCactus3.top, 553
		mov rectanguloCactus3.right, 2293+93
		mov rectanguloCactus3.bottom, 553+110

		mov rectanguloCactus4.left, 2866
		mov rectanguloCactus4.top, 553
		mov rectanguloCactus4.right, 2866+93
		mov rectanguloCactus4.bottom, 553+110

		mov rectanguloCactus5.left, 3152 
		mov rectanguloCactus5.top, 553
		mov rectanguloCactus5.right, 3152+93
		mov rectanguloCactus5.bottom, 553+110

		mov rectanguloCactus6.left, 3438
		mov rectanguloCactus6.top, 553
		mov rectanguloCactus6.right, 3438+93
		mov rectanguloCactus6.bottom, 553+110

		mov rectanguloMoneda.left, 1900
		mov rectanguloMoneda.top, 599
		mov rectanguloMoneda.right, 1900+42
		mov rectanguloMoneda.bottom, 599+48

		mov rectanguloDino.left, 100
		mov rectanguloDino.top, 583
		mov rectanguloDino.right, 100+75
		mov rectanguloDino.bottom, 583+80


	.ELSEIF message == WM_PAINT
		
		; El proceso de dibujado
		; Iniciamos nuestro windowContext
		invoke	BeginPaint, handler, addr windowPaintstruct
		mov		windowContext, eax
		; Creamos un bitmap auxilar. Esto es, para evitar el efecto de parpadeo
		invoke	CreateCompatibleBitmap, layerContext, clientRect.right, clientRect.bottom
		mov		auxiliarLayer, eax
		; Le creamos su contetxo
		invoke	CreateCompatibleDC, layerContext
		mov		auxiliarLayerContext, eax
		; Lo asociamos
		invoke	SelectObject, auxiliarLayerContext, auxiliarLayer
		invoke	DeleteObject, auxiliarLayer
		; Llenamos nuestro auxiliar con nuestro color de borrado, sirve para limpiar la pantalla
		invoke	FillRect, auxiliarLayerContext, addr clientRect, clearColor
		; Elegimos la imagen
		invoke	SelectObject, layerContext, image

		; Aquí pueden poner las cosas que deseen dibujar
		invoke TransparentBlt, auxiliarLayerContext, 0, 0, 1720, 800, layerContext, xFondo, 183, 273, 155, 00000FF00h ;fondo
		mov edx, velocidadFondo
		add xFondo, edx  ;ANIMACION DEL FONDO EN MOVIMIENTO
		.IF xFondo >= 363 + 546
			mov xFondo, 363
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, 6, 6, vida, 68, layerContext, 986, 4, vida, 68, 00000FF00h ;vida

		invoke TransparentBlt, auxiliarLayerContext, 0, 389, 1720, 137, layerContext, xSuelo, ySuelo, 572, 47, 00000FF00h ;suelo3
		invoke TransparentBlt, auxiliarLayerContext, 0, 526, 1720, 137, layerContext, xSuelo, ySuelo, 572, 47, 00000FF00h ;suelo2
		invoke TransparentBlt, auxiliarLayerContext, 0, 663, 1720, 137, layerContext, xSuelo, ySuelo, 572, 47, 00000FF00h ;suelo1
		mov edx, velocidadSuelo
		add xSuelo, edx   ;ANIMACION DEL SUELO EN MOVIMIENTO
		.IF xSuelo >= 381 + 572
			mov xSuelo, 381
		.ENDIF	

		invoke TransparentBlt, auxiliarLayerContext, rectanguloDino.left, rectanguloDino.top, 75, 80, layerContext, xOrigenDino, yOrigenDino, 15, 16, 00000FF00h ;dinosaurio
		add xOrigenDino, 24    ;ANIMACION DEL DINOSAURIO EN MOVIMIENTO
		.IF yOrigenDino == 50
			.IF xOrigenDino >= 102+144
				mov xOrigenDino, 102
			.ENDIF
		.ELSEIF yOrigenDino != 50
			.IF xOrigenDino >= 100+144
				mov xOrigenDino, 100
			.ENDIF
		.ENDIF

		mov eax, rectanguloDino.left
		add eax, 75
		mov rectanguloDino.right, eax
		                                          ;SE CALCULA LA POSICION DEL DINOSAURIO, SI SE MOVIÓ DE LUGAR, LA COLISION SE MUEVE TAMBIEN
		mov eax, rectanguloDino.top
		add eax, 80
		mov rectanguloDino.bottom, eax

		;MONEDA

		mov edx, rectanguloMoneda.left
		mov y, edx
		.IF y == 1900
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloMoneda.top, 599
				mov rectanguloMoneda.bottom, 599+48
			.ELSEIF edx == 1
				mov rectanguloMoneda.top, 462
				mov rectanguloMoneda.bottom, 462+48
			.ELSEIF edx == 2
				mov rectanguloMoneda.top, 325
				mov rectanguloMoneda.bottom, 325+48
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloMoneda.left, rectanguloMoneda.top, 42, 48, layerContext, xOrigenMoneda, yOrigenMoneda, 14, 16, 00000FF00h ;moneda
		add xOrigenMoneda, 16    ;ANIMACION DE LA MONEDA GIRANDO
		.IF xOrigenMoneda >= 589+80
			mov xOrigenMoneda, 589
		.ENDIF
		mov edx, velocidadMoneda
		sub rectanguloMoneda.left, edx     ;MONEDA AVANZA A LA IZQUIERDA
		sub rectanguloMoneda.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON LA MONEDA
		mov edx, rectanguloMoneda.right
		mov y, edx
		.IF y <= 0
			mov rectanguloMoneda.left, 1900      ;REGRESA A LA MONEDA A SU POSICIÓN ORIGINAL
			mov rectanguloMoneda.right, 1900+42
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloMoneda
		.IF eax != 0
			add puntuacion, 100
			mov rectanguloMoneda.left, 1900      ;REGRESA A LA MONEDA A SU POSICIÓN ORIGINAL
			mov rectanguloMoneda.right, 1900+42
		.ENDIF

		;CACTUS1

		mov edx, rectanguloCactus.left
		mov y, edx
		.IF y == 1720
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus.top, 553
				mov rectanguloCactus.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus.top, 418
				mov rectanguloCactus.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus.top, 283
				mov rectanguloCactus.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus.left, rectanguloCactus.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus1
		mov edx, velocidadCactus
		sub rectanguloCactus.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus.left, 1720      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus.right, 1720+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		;CACTUS2

		mov edx, rectanguloCactus2.left
		mov y, edx
		.IF y == 2006
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus2.top, 553
				mov rectanguloCactus2.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus2.top, 418
				mov rectanguloCactus2.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus2.top, 283
				mov rectanguloCactus2.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus2.left, rectanguloCactus2.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus2
		mov edx, velocidadCactus
		sub rectanguloCactus2.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus2.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus2.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus2.left, 2006      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus2.right, 2006+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus2
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		
		;CACTUS3

		mov edx, rectanguloCactus3.left
		mov y, edx
		.IF y == 2293
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus3.top, 553
				mov rectanguloCactus3.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus3.top, 418
				mov rectanguloCactus3.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus3.top, 283
				mov rectanguloCactus3.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus3.left, rectanguloCactus3.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus3
		mov edx, velocidadCactus
		sub rectanguloCactus3.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus3.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus3.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus3.left, 2293      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus3.right, 2293+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus3
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		;CACTUS4

		mov edx, rectanguloCactus4.left
		mov y, edx
		.IF y == 2866
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus4.top, 553
				mov rectanguloCactus4.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus4.top, 418
				mov rectanguloCactus4.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus4.top, 283
				mov rectanguloCactus4.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus4.left, rectanguloCactus4.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus4
		mov edx, velocidadCactus
		sub rectanguloCactus4.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus4.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus4.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus4.left, 2866      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus4.right, 2866+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus4
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		;CACTUS5

		mov edx, rectanguloCactus5.left
		mov y, edx
		.IF y == 3152
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus5.top, 553
				mov rectanguloCactus5.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus5.top, 418
				mov rectanguloCactus5.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus5.top, 283
				mov rectanguloCactus5.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus5.left, rectanguloCactus5.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus5
		mov edx, velocidadCactus
		sub rectanguloCactus5.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus5.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus5.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus5.left, 3152      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus5.right, 3152+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus5
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		;CACTUS6

		mov edx, rectanguloCactus6.left
		mov y, edx
		.IF y == 3438
			xor eax, eax
			xor ebx, ebx
			invoke crt_rand
			mov ebx, 3
			xor edx, edx
			div bx
			.IF edx == 0
				mov rectanguloCactus6.top, 553
				mov rectanguloCactus6.bottom, 553+110
			.ELSEIF edx == 1
				mov rectanguloCactus6.top, 418
				mov rectanguloCactus6.bottom, 418+110
			.ELSEIF edx == 2
				mov rectanguloCactus6.top, 283
				mov rectanguloCactus6.bottom, 283+110
			.ENDIF
		.ENDIF

		invoke TransparentBlt, auxiliarLayerContext, rectanguloCactus6.left, rectanguloCactus6.top, 93, 110, layerContext, 5, 355, 372, 442, 00000FF00h ;cactus6
		mov edx, velocidadCactus
		sub rectanguloCactus6.left, edx     ;CACTUS AVANZA A LA IZQUIERDA
		sub rectanguloCactus6.right, edx    ;SE RESTA PARA QUE LA COLISION AVANCE JUNTO CON EL CACTUS
		mov edx, rectanguloCactus6.right
		mov y, edx
		.IF y <= 0
			mov rectanguloCactus6.left, 3438      ;REGRESA AL CACTUS A SU POSICIÓN ORIGINAL
			mov rectanguloCactus6.right, 3438+93
		.ENDIF
	
		invoke IntersectRect, addr rectanguloColision, addr rectanguloDino, addr rectanguloCactus6
		.IF eax != 0
			sub vida, 82
			.IF vida == 0
				mov xMuerte, 1720      ;SI LA VIDA LLEGA A CERO, SE ACTIVA LA PANTALLA DE MUERTE 
				mov yMuerte, 800
			.ENDIF
			add rectanguloDino.left, 170
			;mov rectanguloDino.top, 583
		.ENDIF

		;CACTUS7

		invoke TransparentBlt, auxiliarLayerContext, 0, 700, 143, 100, layerContext, 678, 76, xWasd, yWasd, 00000FF00h ;TECLAS WASD
		invoke TransparentBlt, auxiliarLayerContext, 1550, 750, 145, 50, layerContext, 849, 126, xTeclaP, yTeclaP, 00000FF00h ;TUTORIAL PAUSA

		invoke TransparentBlt, auxiliarLayerContext, 0, 0, 1720, 800, layerContext, 0, 800, xPantalla, yPantalla, 00000FF00h ;PANTALLA DE TITULO

		

		invoke TransparentBlt, auxiliarLayerContext, 0, 0, 1720, 800, layerContext, 1720, 800, xMuerte, yMuerte, 00000FF00h ;PANTALLA DE MUERTE
		.IF xPantalla == 0      ;LA PUNTUACION EMPIEZA A CONTAR DESDE QUE LA PANTALLA DE TITULO DESAPAREZCA, ES DECIR QUE SEA == 0
		add puntuacion, 1
		invoke crt__itoa, puntuacion, addr mts, 10
		invoke TextOutA, auxiliarLayerContext, 1632, 0, addr mts, 12

		mov edx, puntuacion
		.IF mejorPuntuacion <= edx
			mov mejorPuntuacion, edx
		.ENDIF

		.ENDIF
		.IF xMuerte == 1720
				invoke crt__itoa, mejorPuntuacion, addr mts, 10
				invoke TextOutA, auxiliarLayerContext, 1632, 34, addr mts, 12
				invoke KillTimer, handler, 100    ;SI ESTÁ MOSTRANDO LA PANTALLA DE MUERTE, SE DESACTIVA EL TIMER. SOLO SE MUESTRA LA PANTALLA DE MUERTE CUANDO NO QUEDAN VIDAS
		.ENDIF
		invoke TransparentBlt, auxiliarLayerContext, 360, 50, 1000, 700, layerContext, 2440, 100, xPausa, yPausa, 00000FF00h ;PANTALLA DE PAUSA
		.IF xPausa == 1000
				invoke KillTimer, handler, 100
		.ENDIF


		

		mov edx, xPuntuacion
		.IF puntuacion >= edx
			add velocidadFondo, 1
			add velocidadSuelo, 5
			add velocidadCactus, 5
			add velocidadMoneda, 5
			
			add xPuntuacion, 500
		.ENDIF
		xor edx, edx

		.IF puntuacion >= 500
			mov xWasd, 0
			mov yWasd, 0
			mov xTeclaP, 0
			mov yTeclaP, 0
		.ENDIF

		; Ya que terminamos de dibujarlas, las mostramos en pantalla
		invoke	BitBlt, windowContext, 0, 0, clientRect.right, clientRect.bottom, auxiliarLayerContext, 0, 0, SRCCOPY
		invoke  EndPaint, handler, addr windowPaintstruct
		; Es MUY importante liberar los recursos al terminar de usuarlos, si no se liberan la aplicación se quedará trabada con el tiempo
		invoke	DeleteDC, windowContext
		invoke	DeleteDC, auxiliarLayerContext
	.ELSEIF message == WM_KEYDOWN
		
		
		; Lo que hace cuando una tecla se presiona
		; Deben especificar las teclas de acuerdo a su código ASCII
		; Pueden consultarlo aquí: https://elcodigoascii.com.ar/
		; Movemos wParam a EAX para que AL contenga el valor ASCII de la tecla presionada.
		mov	eax, wParam
		; Esto es un ejemplo: Si presionamos la tecla P mostrará los créditos
		
		.IF al == 80 ;P    PAUSA
			.IF booleano == 0
				mov xPausa, 0
				mov yPausa, 0
				invoke SetTimer, handler, 100, 100, NULL
				mov booleano, 1
			.ELSEIF booleano == 1
				mov xPausa, 1000
				mov yPausa, 700
				mov booleano, 0
			.ENDIF
				
			
		.ELSEIF al == 65 ;A    IZQUIERDA
			sub rectanguloDino.left, 8
			mov edx, rectanguloDino.left
			mov x, edx
			.IF x <= 0
				mov rectanguloDino.left, 0
			.ENDIF

		.ELSEIF al == 68 ;D    DERECHA
			add rectanguloDino.left, 8
			mov edx, rectanguloDino.left
			mov x, edx
			.IF x >= 1632
				mov rectanguloDino.left, 1632
			.ENDIF

		.ELSEIF al == 87 ;W    ARRIBA
			sub rectanguloDino.top, 137
			.IF rectanguloDino.top <= 309
				mov rectanguloDino.top, 309
			.ENDIF
		
		.ELSEIF al == 83 ;S     ABAJO
			add rectanguloDino.top, 137
			.IF rectanguloDino.top >= 583
				mov rectanguloDino.top, 583
			.ENDIF

		.ELSEIF al == 13 ;ESPACIO    INICIAR JUEGO
			mov xPantalla, 0
			mov yPantalla, 0
			invoke SetTimer, handler, 100, 100, NULL

		.ELSEIF al == 86 ;V    VOLVER A JUGAR
			mov vida, 164
			mov xWasd, 143
			mov yWasd, 100
			mov xTeclaP, 145
			mov yTeclaP, 50
			mov xPuntuacion, 500
			mov velocidadFondo, 1
			mov velocidadSuelo, 20
			mov velocidadCactus, 20
			mov velocidadMoneda, 20

			mov rectanguloCactus.left, 1720
			mov rectanguloCactus.right, 1720+93

			mov rectanguloCactus2.left, 2006
			mov rectanguloCactus2.right, 2006+93

			mov rectanguloCactus3.left, 2293
			mov rectanguloCactus3.right, 2293+93

			mov rectanguloCactus4.left, 2866
			mov rectanguloCactus4.right, 2866+93

			mov rectanguloCactus5.left, 3152
			mov rectanguloCactus5.right, 3152+93

			mov rectanguloCactus6.left, 3438
			mov rectanguloCactus6.right, 3438+93

			mov rectanguloMoneda.left, 1900
			mov rectanguloMoneda.right, 1900+42

			mov rectanguloDino.left, 100
			mov rectanguloDino.top, 583
			mov rectanguloDino.right, 100+75
			mov rectanguloDino.bottom, 583+80
			mov xMuerte, 0
			mov yMuerte, 0
			mov puntuacion, 0
			invoke SetTimer, handler, 100, 100, NULL

		.ELSEIF al == 71 ;G    GREEN
			mov yOrigenDino, 4
			mov xOrigenDino, 100
		.ELSEIF al == 66 ;B    BLUE
			mov yOrigenDino, 27
			mov xOrigenDino, 100
		.ELSEIF al == 89 ;Y    YELLOW
			mov yOrigenDino, 73
			mov xOrigenDino, 100
		.ELSEIF al == 82 ;R    RED
			mov yOrigenDino, 50
			mov xOrigenDino, 102

		.ELSEIF al == 78 ;N    PISO NORMAL
			mov ySuelo, 343
		.ELSEIF al == 79 ;O    PISO NARANJA
			mov ySuelo, 392
		.ELSEIF al == 70 ;F    PISO ROSA 
			mov ySuelo, 441
		.ENDIF
	.ELSEIF message == MM_JOY1MOVE
		; Lo que pasa cuando mueves la palanca del joystick
		xor	ebx, ebx
		xor edx, edx
		mov	edx, lParam
		mov bx, dx
		and	dx, 0
		ror edx, 16
		; En este punto, BX contiene la coordenada de la palanca en x
		; Y DX la coordenada y
		; Las coordenadas se dan relativas al la esquina superior izquierda de la palanca.
		; En escala del 0 a 0FFFFh
		; Lo que significa que si la palanca está en medio, la coordenada en X será 07FFFh
		; Y la coordenada Y también.
		; Lo máximo hacia arriba es 0 en Y
		; Lo máximo hacia abajo en FFFF en Y
		; Lo máximo hacia la derecha es FFFF en X
		; Lo máximo hacia la izquierda es 0 en X
		; Si la palanca no está en ningún extremo, será un valor intermedio
		; Este es un ejemplo: Si la palanca está al máximo a la derecha, mostrará los créditos
		.IF bx == 0FFFFh
			invoke credits, handler
		.ENDIF 
	.ELSEIF message == MM_JOY1BUTTONDOWN
		; Lo que hace cuando presionas un botón del joystick
		; Pueden comparar que botón se presionó haciendo un AND
		xor	ebx, ebx
		mov	ebx, wParam
		and	ebx, JOY_BUTTON1
		; Esto es un ejemplo, si presionamos el botón 1 del joystick, mostrará los créditos
		.IF	ebx != 0
			invoke credits, handler
		.ENDIF
	.ELSEIF message == WM_TIMER
		; Lo que hace cada tick (cada vez que se ejecute el timer)
		invoke	InvalidateRect, handler, NULL, FALSE
	.ELSEIF message == WM_DESTROY
		; Lo que debe suceder al intentar cerrar la ventana.   
        invoke PostQuitMessage, NULL
    .ENDIF
	; Este es un fallback.
	; NOTA IMPORTANTE: Normalmente WinAPI espera que se le regrese ciertos valores dependiendo del mensaje que se esté procesando.
	; Como varia mucho entre mensaje y mensaje, entonces DefWindowProcA se encarga de regresar el mensaje predeterminado como si las cosas
	; fueran con normalidad. Pero en realidad pueden devolver otras cosas y el comportamiento de WinAPI cambiará.
	; (Por ejemplo, si regresan -1 en EAX al procesar WM_CREATE, la ventana no se creará)
    invoke DefWindowProcA, handler, message, wParam, lParam      
    ret
WindowCallback endp

; Reproduce la música
playMusic proc
	xor		ebx, ebx
	mov		ebx, SND_FILENAME
	or		ebx, SND_LOOP
	or		ebx, SND_ASYNC
	invoke	PlaySound, addr musicFilename, NULL, ebx
	ret
playMusic endp

; Muestra el error del joystick
joystickError proc
	xor		ebx, ebx
	mov		ebx, MB_OK
	or		ebx, MB_ICONERROR
	invoke	MessageBoxA, NULL, addr joystickErrorText, addr errorTitle, ebx
	ret
joystickError endp

; Muestra los créditos
credits	proc handler:DWORD
	; Estoy matando al timer para que no haya problemas al mostrar el Messagebox.
	; Veanlo como un sistema de pausa
	invoke KillTimer, handler, 100
	xor ebx, ebx
	mov ebx, MB_OK
	or	ebx, MB_ICONINFORMATION
	invoke	MessageBoxA, handler, addr messageBoxText, addr messageBoxTitle, ebx
	; Volvemos a habilitar el timer
	invoke SetTimer, handler, 100, 100, NULL
	ret
credits endp

end main