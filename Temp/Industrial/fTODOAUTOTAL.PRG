PARAMETERS nHan, aTexto, nLL

PRIVATE nLen, nL, cT
If Empty( nLL)
	nLen = ALEN( aTexto, 1)
Else
	nLen = nLL
Endif

nL = nLen
Do While nL >= 1
	If EMPTY( aTexto[nL])
		nLen = nLen -1
	Else
		Exit
	Endif
	nL = nL -1
Enddo

For nL = 1 to nLen
	
	cT = aTexto[nL]
        do 'fLINHATOTAL' with cT
	
	If nL = 1 .AND. Len(cT) = 0
	    cT = Space(10)
	Endif	
	    
	If nL < nLen
		Do 'fPOEM' with nHan, cT
	Else
		&& cT = cT + cHr(12)
		Do 'fPOESAU' with nHan, cT
	Endif
Next
cT = Space(0)
Do 'fPOEM' with nHan, cT
Return
