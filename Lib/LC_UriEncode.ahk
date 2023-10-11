;adapted from https://github.com/ahkscript/libcrypt.ahk

LC_UriEncode(Uri, RE:="[0-9A-Za-z]") {
	Res := ""
	Var := Buffer(StrPut(Uri, "UTF-8"), 0), StrPut(Uri, Var, "UTF-8")
	While Code := NumGet(Var, A_Index - 1, "UChar")
		Res .= (Char:=Chr(Code)) ~= RE ? Char : Format("%{:02X}", Code)
	Return Res
}