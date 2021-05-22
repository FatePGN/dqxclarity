﻿#SingleInstance force
#Include <classMemory>
#Include <convertHex>
#Include <memWrite>
#Include <JSON>

if (_ClassMemory.__Class != "_ClassMemory") {
  msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
  ExitApp
}

dqx := new _ClassMemory("ahk_exe DQXGame.exe", "", hProcessCopy)
Global dqx

if !isObject(dqx)
{
  msgbox Please open Dragon Quest X before running dqxclarity.
  ExitApp
  if (hProcessCopy = 0)
  {
    msgbox The program isn't running (not found) or you passed an incorrect program identifier parameter.
    ExitApp
  }
  else if (hProcessCopy = "")
  {
    msgbox OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin. Consult A_LastError for more information.
    ExitApp
  }
}

Gui, +AlwaysOnTop +E0x08000000
Gui, Font, s12
Gui, Add, Edit, vNotes w500 r10 +ReadOnly -WantCtrlA -WantReturn,
Gui, Show, Autosize

;; Mark FileRead operations as UTF-8
FileEncoding UTF-8

;; Start timer
startTime := A_TickCount

;; Loop through all files in json directory
Loop, Files, json\*.json, F
{
  FileRead, jsonData, %A_ScriptDir%\%A_LoopFileFullPath%
  GuiControl,, Notes, Loading %A_LoopFileFullPath% ...
  data := JSON.Load(jsonData)
  textHex := dqx.hexStringToPattern(data.1.hex_start)  ;; Start of TEXT block
  footAOB := [0, 0, 0, 0, 70, 79, 79, 84]  ;; End of TEXT block (FOOT)

  startAddr := dqx.processPatternScan(,,textHex*)
  endAddr := dqx.processPatternScan(startAddr,, footAOB*)

  ;; Iterate over all json objects in strings[]
  for i, obj in data.1.strings
  {

    ;; If en_string is blank, skip it
    if (obj.en_string == "")
      Continue

    ;; Convert utf-8 strings to hex
    jp := 00 . convertStrToHex(obj.jp_string) . 00
    jp := RegExReplace(jp, "\r\n", "")
    jp_raw := obj.jp_string
    jp_len := StrLen(jp)

    ;; For other languages, we want to make the length of our JP hex
    ;; string the same as what we're inputting.
    en := 00 . convertStrToHex(obj.en_string) . 00
    en := RegExReplace(en, "\r\n", "")
    en_raw := obj.en_string
    en_len := StrLen(en)

    ;; Whether the string has line break characters we need to account for.
    line_break := obj.line_break

    GuiControl,, Notes, Reading %A_LoopFileFullPath%`n`nOn this text:`n`nJP: %jp_raw%`nEN:%en_raw%

    ;; If the string length doesn't match, add null terms until it does.
    if (jp_len != en_len)
    {
      ;; Remove the last 00 we added earlier as we aren't ready
      ;; to 'terminate' the string yet. 
      en := SubStr(en, 1, (en_len - 2))
      Loop
      {
        en .= 00
        new_len := StrLen(en)
      }
      Until ((jp_len - new_len) == 0)

      ;; Some sentences can scale multiple lines, so instead of a null terminator,
      ;; we want to replace the spaces with the line break code '0a'. 
      if (line_break != "")
      {
        jp := StrReplace(jp, "20", "0a")
        en := StrReplace(en, "7c", "0a")
      }
    }
    memWrite(jp, en, jp_raw, en_raw, startAddr, endAddr)
  }
}

elapsedTime := A_TickCount - startTime
GuiControl,, Notes, Done.`n`nElapsed time: %elapsedTime%ms
FileAppend, Last run time: %elapsedTime%ms`n, times.txt
Sleep 3000
ExitApp

GuiEscape:
GuiClose:
  ExitApp