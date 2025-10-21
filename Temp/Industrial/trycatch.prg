* TRYCATCH.PRG
* Implementacion de bloques TRY-CATCH para VFP6
*
* Autor: Victor Espina
* Fecha: Mayo 2014
*

PROCEDURE TRY
 IF VARTYPE(gcTRYOnError)="U"
  PUBLIC gcTRYOnError,goTRYEx,goTRYNestingLevel
  goTRYNestingLevel = 0
 ENDIF
 gcTRYOnError = ON("ERROR")
 goTRYEx = NULL
 goTRYNestingLevel = goTRYNestingLevel + 1
 IF goTRYNestingLevel = 1
  ON ERROR tryCatch(ERROR(), MESSAGE(), MESSAGE(1), PROGRAM(), LINENO())
 ENDIF
ENDPROC

PROCEDURE CATCH(poEx)
 IF PCOUNT() = 1
  poEx = goTRYEx
 ENDIF
 RETURN !ISNULL(goTRYEx)
ENDPROC

PROCEDURE ENDTRY
 gnTRYNestingLevel = gnTRYNestingLevel - 1
 goTRYEx = NULL
 IF gnTRYNestingLevel = 0 
  IF !EMPTY(gcTRYOnError)
   ON ERROR &gcTRYOnError
  ELSE
   ON ERROR
  ENDIF
 ENDIF
ENDPROC

FUNCTION NOEX()
 RETURN ISNULL(goTRYEx)
ENDFUNC

PROCEDURE tryCatch(pnErrorNo, pcMessage, pcSource, pcProcedure, pnLineNo)
 goTRYEx = CREATE("Exception")
 WITH goTRYEx
  .errorNo = pnErrorNo
  .Message = pcMessage
  .Source = pcSource
  .Procedure = pcProcedure
  .lineNo = pnLineNo
 ENDWITH
ENDPROC

DEFINE CLASS Exception AS Custom
 errorNo = 0
 Message = ""
 Source = ""
 Procedure = ""
 lineNo = 0 
ENDDEFINE