#SingleInstance Force
#Include <_JXON>
OnMessage 0x004A, message_receive

;A_Args[1] - A_ScriptName
;A_Args[2] - server_address
;A_Args[3] - job_type
;A_Args[4] - prompt_id

try {
  A_Args[1]
}
catch {
  Msgbox "This script is not intended to be run manually."
  return
}
DetectHiddenWindows True
SetTitleMatchMode 2

job_queue := Map()
job_queue[A_Args[4]] :=  Map(
  "script", A_Args[1]
  ,"server_address", A_Args[2]
  ,"job_type", A_Args[3]
)

try {
  shrine := ComObject("WinHttp.WinHttpRequest.5.1")
}
catch Error as what_went_wrong {
  FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
  send_something_forward("something went wrong", job_details["script"] " ahk_class AutoHotkey")
  Exit
}

while (job_queue.Count) {
  for (prompt_id, job_details in job_queue) {
    try {
      shrine.Open("GET", "https://" job_details["server_address"] "/api/v2/generate/check/" prompt_id, false)
      shrine.Send()
      grace := shrine.ResponseText
      if (!shrine.Status = 200) {
        FileAppend("[" A_Now "]`nhttps://" job_details["server_address"] "/api/v2/generate/check/" prompt_id "`n" shrine.Status ": " shrine.StatusText "`n" grace "`n", "log", "utf-8")
        send_something_forward("something went wrong", job_details["script"] " ahk_class AutoHotkey")
        job_queue.Delete(prompt_id)
        continue
      }
      else {
        ;make a json to send as a status update
        send_something_forward('horde_progress{"prompt_id": "' prompt_id '", "actual_server_response": ' grace ' }', job_details["script"] " ahk_class AutoHotkey")

        revelation := Jxon_load(&grace)
        if (revelation["done"] = true) {
          send_something_forward(job_details["job_type"] prompt_id, job_details["script"] " ahk_class AutoHotkey")
          job_queue.Delete(prompt_id)
        }
      }
    }
    catch Error as what_went_wrong {
      FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
      send_something_forward("something went wrong", job_details["script"] " ahk_class AutoHotkey")
      job_queue.Delete(prompt_id)
    }
    Sleep 1000
  }
}

return


send_something_forward(something, target_script) {
  con_struct_ion := Buffer(A_PtrSize * 3)
  if (Type(something) = "String") {
    something := "horde" something
    NumPut("Ptr", ((StrLen(something) + 1) * 2), con_struct_ion, A_PtrSize)
    NumPut("Ptr",  StrPtr(something), con_struct_ion, A_ptrSize * 2)
  }
  else {
    NumPut("Ptr", something.Size, "Ptr", something.Ptr, con_struct_ion, A_PtrSize)
  }
  try {
    response_value := SendMessage(0x004A, 0, con_struct_ion,, target_script)
  }
  catch Error as what_went_wrong {
    FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
    Exit
  }
}

message_receive(wParam, lParam, msg, hwnd) {
  try {
    out_ptr := NumGet(lParam, A_PtrSize * 2, "Ptr")
    possible_string := StrGet(out_ptr)
    ;job_queue.Push(Jxon_load(&possible_string))
    new_job := Jxon_load(&possible_string)
    job_queue[new_job[4]] := Map(
      "script", new_job[1]
      ,"server_address", new_job[2]
      ,"job_type", new_job[3]
    )
  }
  catch Error as what_went_wrong {
    FileAppend("[" A_Now "]`n" what_went_wrong.Message "`n" what_went_wrong.Extra "`n" what_went_wrong.File "`n" what_went_wrong.Line "`n" what_went_wrong.Stack "`n", "log", "utf-8")
  }
}