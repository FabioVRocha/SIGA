#define INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY 4

#define REQ_STATE_UNINITIALIZED 0 && open()has not been called yet.
#define REQ_STATE_LOADING       1 && send()has not been called yet.
#define REQ_STATE_LOADED        2 && send() has been called, and headers and status are available.
#define REQ_STATE_INTERACTIVE   3 && Downloading; responseText holds partial data.
#define REQ_STATE_COMPLETED     4 && The operation is complete.

DEFINE CLASS HttpClientRequest As Custom
  readystate=REQ_STATE_UNINITIALIZED
  Protocol=NULL
  Url=NULL
  requestBody=NULL
  responseBody=NULL

  PROCEDURE Open(tcProtocol, tcUrl)
    IF this.readystate != REQ_STATE_UNINITIALIZED
      ERROR "HttpClientRequest is already opened."
    ENDIF
    IF VARTYPE(m.tcProtocol)!="C" OR VARTYPE(m.tcUrl)!="C" 
      ERROR "Invalid type or count of parameters."
    ENDIF
    IF NOT INLIST(m.tcProtocol,"GET")
      ERROR "Unsupported or currently not implemented protocol type."
    ENDIF
    this.Protocol = m.tcProtocol
    this.Url = m.tcUrl
    this.readystate = REQ_STATE_LOADING
  ENDPROC

  PROCEDURE Send(tcBody)
    IF this.readystate != REQ_STATE_LOADING
      ERROR "HttpClientRequest is not in initialized state."
    ENDIF
    IF PCOUNT()=0
      m.tcBody=NULL
    ENDIF
    IF this.Protocol=="GET" AND (NOT ISNULL(m.tcBody))
      ERROR "Invalid type or count of parameters."
    ENDIF
    this.requestBody = m.tcBody
    this.readystate = REQ_STATE_LOADED


    DECLARE integer InternetOpen IN "wininet.dll" ;
      string @ lpszAgent, ;
      integer dwAccessType, ;
      string @ lpszProxyName, ;
      string @ lpszProxyBypass, ;
      integer dwFlags
    DECLARE integer InternetCloseHandle IN "wininet.dll" ;
      integer hInternet
    DECLARE integer InternetCanonicalizeUrl IN "wininet.dll" ;
      string @ lpszUrl, ;
      string @ lpszBuffer, ;
      integer @ lpdwBufferLength, ;
      integer dwFlags
    DECLARE integer InternetOpenUrl IN "wininet.dll" ;
      integer hInternet, ;
      string @ lpszUrl, ;
      string @ lpszHeaders, ;
      integer dwHeadersLength, ;
      integer dwFlags, ;
      integer dwContext
    DECLARE integer InternetReadFile IN "wininet.dll" ;
      integer hFile, ;
      string @ lpBuffer, ;
      integer dwNumberOfBytesToRead, ;
      integer @ lpdwNumberOfBytesRead

    LOCAL m.hInternet,lcUrl,lnUrlLen,m.hInternetFile,lcBuffer,lnBufferLen,lnReaded
    m.hInternet = InternetOpen("a.k.d. HttpClientRequest for Visual FoxPro", ;
                               INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY, ;
                               NULL, NULL, 0)
    this.responseBody = ""
    IF m.hInternet != 0
      m.lnUrlLen = LEN(this.Url)*8
      m.lcUrl = REPLICATE(CHR(0),m.lnUrlLen)
      InternetCanonicalizeUrl(this.Url, @lcUrl, @lnUrlLen, 0)
      m.hInternetFile = InternetOpenUrl(m.hInternet, @lcUrl, NULL, -1, 0, 0)
      IF m.hInternetFile != 0
        m.lnBufferLen = 10240
        DO WHILE .T.
           m.lcBuffer = REPLICATE(CHR(0),m.lnBufferLen)
           m.lnReaded = 0
           IF NOT (0!=InternetReadFile(m.hInternetFile, @lcBuffer, m.lnBufferLen, @lnReaded) AND m.lnReaded>0)
             EXIT
           ENDIF
          this.responseBody = this.responseBody + LEFT(m.lcBuffer,m.lnReaded)
          this.readystate = REQ_STATE_INTERACTIVE
        ENDDO
        InternetCloseHandle(m.hInternetFile)
      ENDIF
      InternetCloseHandle(m.hInternet)
    ENDIF
    this.readystate = REQ_STATE_COMPLETED
  ENDPROC
ENDDEFINE