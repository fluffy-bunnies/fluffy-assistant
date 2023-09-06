;https://www.autohotkey.com/boards/viewtopic.php?f=82&t=112741
;Chr to Char
;and error with empty string
LC_UriEncode(Uri, RE := "[0-9A-Za-z]")
{
    Var := Buffer(StrPut(Uri, "UTF-8"), 0)
    StrPut(Uri, Var, "UTF-8")
	Res := ""
    While Code := NumGet(Var, A_Index - 1, "UChar")
    {
        if RegExMatch(Char := Chr(Code), RE)
        {
            Res .= Char
        }
        else
        {
            Res .= Format("%{:02X}", Code)
        }
    }
    return Res
}