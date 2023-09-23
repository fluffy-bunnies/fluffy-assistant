#SingleInstance Force
#Include <_JXON>
#Include <WebSocket>

;A_Args[1] - A_ScriptName
;A_Args[2] - server_address
;A_Args[3] - client_id
;A_Args[4] - job_type
;A_Args[5] - prompt_id

try {
  main_script := A_Args[1] " ahk_class AutoHotkey"
}
catch {
  Msgbox "This script is not intended to be run manually."
  return
}
DetectHiddenWindows True
SetTitleMatchMode 2

try {
  temple := WebSocket("ws://" A_Args[2] "/ws?clientId=" A_Args[3],
  ;{open: (*) => FileAppend("[" A_Now "]`nOPEN" "`n", "log", "utf-8"), data:(self, data) => FileAppend("[" A_Now "]`nDATA: " data "`n", "log", "utf-8"), message: (self, data) => FileAppend("[" A_Now "]`nMESSAGE: " data "`n", "log", "utf-8"), close: (self, status, reason) => FileAppend("[" A_Now "]`nCLOSE:`n" status " | " reason "`n", "log", "utf-8")}
  ,false)
}
catch Error as what_went_wrong {
  FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
  send_something_forward("something went wrong")
  Exit
}

loop {
  try {
    grace := temple.receive()
  }
  catch Error as what_went_wrong {
    FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
    send_something_forward("something went wrong")
    Exit
  }
  send_something_forward(grace)
  if (Type(grace) = "String") {
    revelation := Jxon_load(&grace)
    if (revelation["type"] = "executing") {
      if ((revelation["data"]["node"] = "") and (revelation["data"]["prompt_id"] = A_Args[5])) {
        break
      }
    }
    else if (revelation["type"] = "status") {
      if (revelation["data"]["status"]["exec_info"]["queue_remaining"] = 0) {
        break
      }
    }
  }
}

send_something_forward(A_Args[4])

return


send_something_forward(something) {
  con_struct_ion := Buffer(A_PtrSize * 3)
  if (Type(something) = "String") {
    something := "comfy" something
    NumPut("Ptr", ((StrLen(something) + 1) * 2), con_struct_ion, A_PtrSize)
    NumPut("Ptr",  StrPtr(something), con_struct_ion, A_ptrSize * 2)
  }
  else {
    NumPut("Ptr", something.Size, "Ptr", something.Ptr, con_struct_ion, A_PtrSize)
  }
  try {
    response_value := SendMessage(0x004A, 0, con_struct_ion,, main_script)
  }
  catch Error as what_went_wrong {
    FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
    Exit
  }
}
