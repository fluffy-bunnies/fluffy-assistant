#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <_JXON>
#Include <Gdip_All>
#Include <CreateFormData>
#Include <LC_UriEncode>

;--------------------------------------------------
;--------------------------------------------------
;startup
;--------------------------------------------------
;--------------------------------------------------

OnMessage 0x004A, message_receive ;0x004A is WM_COPYDATA
OnExit shutdown_cleanup
OnError overlay_hide

altar := ComObject("WinHttp.WinHttpRequest.5.1")

client_id := ComObject("Scriptlet.TypeLib").GUID
client_id := LTrim(client_id, "{")
client_id := SubStr(client_id, 1, 36)

;the updown control should have a width of 18 pixels and gets attached at the end of its buddy with an offset
;default width of updown stored in updown_default_w when the first one is created
updown_offset_x := -2

;ideally, this colour should never show up
transparent_bg_colour := "0x181818"

assistant_script := A_IsCompiled ? "comfy.exe" : "comfy.ahk"
horde_assistant_script := A_IsCompiled ? "horde.exe" : "horde.ahk"
libwebp := A_PtrSize = 4 ? "Lib\libwebp32.dll" : "Lib\libwebp64.dll"

pToken := Gdip_Startup()

;--------------------------------------------------
;read settings from settings.ini
;and decide what to do with them
;--------------------------------------------------
background_colour := IniRead("settings.ini", "settings", "background_colour", "0x000000")
background_colour := background_colour = "" ? "0x000000" : background_colour
background_opacity := IniRead("settings.ini", "settings", "background_opacity", 128)
background_opacity := background_opacity = "" ? 128 : background_opacity
control_colour := IniRead("settings.ini", "settings", "control_colour", "0x101010")
control_colour := control_colour = "" ? "0x101010" : control_colour
text_font := IniRead("settings.ini", "settings", "text_font", "Arial")
text_font := text_font = "" ? "Arial" : text_font
text_size := IniRead("settings.ini", "settings", "text_size", 12)
text_size := text_size = "" ? 12 : text_size
text_colour := IniRead("settings.ini", "settings", "text_colour", "0xB0B0B0")
text_colour := text_colour = "" ? "0xB0B0B0" : text_colour
show_labels := IniRead("settings.ini", "settings", "show_labels", 1)
;blank means no, but show if unspecified
label_font := IniRead("settings.ini", "settings", "label_font", "Arial")
label_font := label_font = "" ? "Arial" : label_font
label_size := IniRead("settings.ini", "settings", "label_size", 12)
label_size := label_size = "" ? 12 : label_size
label_colour := IniRead("settings.ini", "settings", "label_colour", "0xE0E0E0")
label_colour := label_colour = "" ? "0xE0E0E0" : label_colour
gap_x := IniRead("settings.ini", "settings", "gap_x", 25)
gap_x := gap_x = "" ? 25 : gap_x
gap_y := IniRead("settings.ini", "settings", "gap_y", 25)
gap_y := gap_y = "" ? 25 : gap_y
screen_border_x := IniRead("settings.ini", "settings", "screen_border_x", 10)
screen_border_x := screen_border_x = "" ? 10 : screen_border_x
screen_border_y := IniRead("settings.ini", "settings", "screen_border_y", 10)
screen_border_y := screen_border_y = "" ? 10 : screen_border_y

server_address := IniRead("settings.ini", "settings", "default_server_address", "")
;blank means "don't autoconnect"
controlnet_preprocessor_nodes := IniRead("settings.ini", "settings", "controlnet_preprocessor_nodes", 1)
;blank means skip, but try if unspecified
IPAdapter_nodes := IniRead("settings.ini", "settings", "IPAdapter_nodes", 1)
;blank means skip, but try if unspecified

horde_address := IniRead("settings.ini", "settings", "horde_default_server_address", "")
;blank means "don't autoconnect"
horde_api_key := IniRead("settings.ini", "settings", "horde_api_key", "0000000000")
horde_api_key := horde_api_key = "" ? "0000000000" : horde_api_key
horde_use_specific_worker := IniRead("settings.ini", "settings", "horde_use_specific_worker", "")
;blank means none
horde_allow_nsfw := IniRead("settings.ini", "settings", "horde_allow_nsfw", 0)
;blank means no
horde_replacement_filter := IniRead("settings.ini", "settings", "horde_replacement_filter", 1)
;blank means no, but leave on if unspecified
horde_allow_untrusted_workers := IniRead("settings.ini", "settings", "horde_allow_untrusted_workers", 1)
;blank means no, but leave on if unspecified
horde_allow_slow_workers := IniRead("settings.ini", "settings", "horde_allow_slow_workers", 1)
;blank means no, but leave on if unspecified
horde_share_with_laion := IniRead("settings.ini", "settings", "horde_share_with_laion", 1)
;blank means no, but leave on if unspecified

input_folder := IniRead("settings.ini", "settings", "input_folder", "images\input\")
input_folder := input_folder = "" ? "images\input\" : input_folder
output_folder := IniRead("settings.ini", "settings", "output_folder", "images\output\")
output_folder := output_folder = "" ? "images\output\" : output_folder
horde_output_folder := IniRead("settings.ini", "settings", "horde_output_folder", "images\horde_output\")
horde_output_folder := horde_output_folder = "" ? "images\horde_output\" : horde_output_folder
save_folder := IniRead("settings.ini", "settings", "save_folder", "save\")
save_folder := save_folder = "" ? "save\" : save_folder

delete_input_files_on_startup := IniRead("settings.ini", "settings", "delete_input_files_on_startup", 0)
;blank means no
delete_output_files_on_startup := IniRead("settings.ini", "settings", "delete_output_files_on_startup", 0)
;blank means no
delete_horde_output_files_on_startup := IniRead("settings.ini", "settings", "delete_horde_output_files_on_startup", 0)
;blank means no

hotkey_toggle_overlay := IniRead("settings.ini", "settings", "hotkey_toggle_overlay", "CapsLock")
;blank means no, but use capslock if unspecified
hotkey_toggle_comfy_overlay := IniRead("settings.ini", "settings", "hotkey_toggle_comfy_overlay", "")
;blank means no
hotkey_generate := IniRead("settings.ini", "settings", "hotkey_generate", "")
;blank means no
hotkey_clipboard_to_source := IniRead("settings.ini", "settings", "hotkey_clipboard_to_source", "")
;blank means no
hotkey_clipboard_to_image_prompt := IniRead("settings.ini", "settings", "hotkey_clipboard_to_image_prompt", "")
;blank means no
hotkey_clipboard_to_mask := IniRead("settings.ini", "settings", "hotkey_clipboard_to_mask", "")
;blank means no
hotkey_clipboard_to_controlnet := IniRead("settings.ini", "settings", "hotkey_clipboard_to_controlnet", "")
;blank means no
hotkey_output_to_clipboard := IniRead("settings.ini", "settings", "hotkey_output_to_clipboard", "")
;blank means no
hotkey_toggle_horde_overlay := IniRead("settings.ini", "settings", "hotkey_toggle_horde_overlay", "")
;blank means no
hotkey_horde_generate := IniRead("settings.ini", "settings", "hotkey_horde_generate", "")
;blank means no
hotkey_horde_clipboard_to_source := IniRead("settings.ini", "settings", "hotkey_horde_clipboard_to_source", "")
;blank means no
hotkey_horde_clipboard_to_mask := IniRead("settings.ini", "settings", "hotkey_horde_clipboard_to_mask", "")
;blank means no
hotkey_horde_output_to_clipboard := IniRead("settings.ini", "settings", "hotkey_horde_output_to_clipboard", "")
;blank means no

use_save_and_load_hotkeys := IniRead("settings.ini", "settings", "use_save_and_load_hotkeys", 1)
;blank means no, but use if unspecified

;--------------------------------------------------
;some global things
;--------------------------------------------------

;populate with list of all available nodes & options from server response
scripture := ""
horde_scripture := ""

;to be filled with the actual gui control objects
preprocessor_controls := Map()

;for connecting the easy name with the actual node name
preprocessor_actual_name := Map()

;for tracking input images
inputs := Map()
preview_images := Map()
horde_inputs := Map()

;images not yet downloaded
images_to_download := Map()
preview_image_to_download := Map()

;prevent certain actions when busy
assistant_status := "idle"

;toggle on hotkey
overlay_visible := 0

;separate overlay "tabs"
overlay_list := ["comfy", "horde"]
overlay_current := overlay_list[1]
;used to cycle overlays with hotkey
overlay_sequence := Map()
for (index, overlay in overlay_list) {
  overlay_sequence[overlay] := index
}
gui_windows := Map()

;to track the displayed output image even if empty item is chosen in the listview
last_selected_output_image:= ""
horde_last_selected_output_image:= ""

;because live previews happen on the spot where the main source image is adjusted
clear_main_preview_image_on_next_dimension_change := 0

;--------------------------------------------------
;--------------------------------------------------
;drawing gui's
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;translucent background
;--------------------------------------------------

overlay_background := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound", "Fluffy Overlay")
overlay_background.Show("Hide x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
WinSetTransparent background_opacity = 255 ? "Off" : background_opacity
overlay_background.BackColor := background_colour

;--------------------------------------------------
;main controls
;--------------------------------------------------

main_controls := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Main Controls")
main_controls.MarginX := 0
main_controls.MarginY := 0
main_controls.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;basic controls
;--------------------------------------------------

batch_size_edit := main_controls.Add("Edit", "x0 y" gap_y " w60 r1 Background" control_colour " Center Number Limit2")
;only used when necessary
batch_size_edit.GetPos(,,,&edit_default_h)

batch_size_updown := main_controls.Add("UpDown", "Range1-64 0x80", 1)
;this is the first updown
batch_size_updown.GetPos(,, &updown_default_w,)

batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
checkpoint_combobox := main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w" A_ScreenWidth / 5 " Background" control_colour, ["None"])

checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
vae_combobox := main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

vae_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
sampler_combobox := main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

sampler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
scheduler_combobox := main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
prompt_positive_edit := main_controls.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 4 " r5 Background" control_colour)

prompt_positive_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
prompt_negative_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 4 " r5 Background" control_colour)

prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
seed_edit := main_controls.Add("Edit", "x" stored_gui_x +stored_gui_w + gap_x " y" stored_gui_y " w200 r1 Background" control_colour " Center Number Limit19", 0)
seed_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2")

;change the font of the entire gui window before creating the control
;instead of changing only the control's font after creation
;reverted for safety after done drawing
seed_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
main_controls.SetFont("c" label_colour " q3", label_font)
random_seed_checkbox := main_controls.Add("CheckBox", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1, "Random")
main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
step_count_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y0 w75 r1 Background" control_colour " Center Number Limit5")
;get specific value
step_count_edit.GetPos(,,, &step_count_edit_h)
step_count_edit.Move(, stored_gui_y + stored_gui_h - step_count_edit_h,,)

step_count_updown := main_controls.Add("UpDown", "Range0-10000 0x80", 20)

step_count_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;to allow for manual input of decimal points, Number is not used in some edit boxes
cfg_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "7.0")
cfg_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2", 0)

cfg_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
denoise_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "1.000")
denoise_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2", 0)

;upscaling
;--------------------------------------------------
prompt_positive_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
upscale_combobox := main_controls.Add("ComboBox", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 5 " Background" control_colour " Choose1", ["None"])

upscale_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
step_count_upscale_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit5 Disabled", 0)

step_count_upscale_updown := main_controls.Add("UpDown", "Range0-10000 0x80 Disabled", 0)

step_count_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
cfg_upscale_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6 Disabled", "7.0")
cfg_upscale_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2 Disabled", 0)

cfg_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
denoise_upscale_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6 Disabled", "1.000")
denoise_upscale_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2 Disabled", 0)

denoise_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
upscale_value_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w100 r1 Background" control_colour " Center Limit8 Disabled", "1.000")
upscale_value_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2 Disabled", 0)

upscale_value_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
main_controls.SetFont("c" label_colour " q3", label_font)
random_seed_upscale_checkbox := main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y0 Disabled", "Random Seed")
main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)
;get specific value
random_seed_upscale_checkbox.GetPos(,,, &random_seed_upscale_checkbox_h)
random_seed_upscale_checkbox.Move(, stored_gui_y + stored_gui_h / 2 - random_seed_upscale_checkbox_h / 2,,)

;refiner
;--------------------------------------------------
upscale_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
refiner_combobox := main_controls.Add("ComboBox", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 5 " Background" control_colour " Choose1", ["None"])

refiner_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
refiner_start_step_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit5 Disabled", 0)

refiner_start_step_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2 Disabled", 0)

refiner_start_step_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
cfg_refiner_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6 Disabled", "7.0")
cfg_refiner_updown := main_controls.Add("UpDown", "Range0-1 0x80 -2 Disabled", 0)

cfg_refiner_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
main_controls.SetFont("c" label_colour " q3", label_font)
random_seed_refiner_checkbox := main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y0 Disabled", "Random Seed")
main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)
;get specific value
random_seed_refiner_checkbox.GetPos(,,, &random_seed_refiner_checkbox_h)
random_seed_refiner_checkbox.Move(, stored_gui_y + stored_gui_h / 2 - random_seed_refiner_checkbox_h / 2,,)

random_seed_refiner_checkbox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
main_controls.SetFont("c" label_colour " q3", label_font)
refiner_conditioning_checkbox := main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " Disabled", "Conditioning")
main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;--------------------------------------------------
;image prompt
;--------------------------------------------------

image_prompt := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Image Prompt")
image_prompt.MarginX := 0
image_prompt.MarginY := 0
image_prompt.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
image_prompt.SetFont("s" text_size " c" text_colour " q0", text_font)

;clip vision
;--------------------------------------------------
clip_vision_combobox := image_prompt.Add("ComboBox", "x0 y" gap_y " w" A_ScreenWidth / 10 " Background" control_colour, ["None"])

;IPAdapter
;--------------------------------------------------
clip_vision_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
IPAdapter_combobox := image_prompt.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour, ["None"])

;image
;--------------------------------------------------
clip_vision_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_picture := image_prompt.Add("Picture", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w150 h150", "stuff\placeholder_pixel.bmp")

;active image prompts
;--------------------------------------------------
image_prompt_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;get specific value
IPAdapter_combobox.GetPos(&IPAdapter_combobox_x,, &IPAdapter_combobox_w,)
image_prompt_active_listview := image_prompt.Add("ListView", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w" IPAdapter_combobox_x + IPAdapter_combobox_w - (stored_gui_x + stored_gui_w + 1) " h" stored_gui_h " Background" control_colour " -Multi", ["Image", "Strength", "Noise"])

image_prompt_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_active_listview.Opt("-Redraw")
Loop 11 {
  image_prompt_active_listview.Add(,"")
}
image_prompt_active_listview.ModifyCol(1, stored_gui_w - 200)
image_prompt_active_listview.ModifyCol(2, 100 " Float")
image_prompt_active_listview.ModifyCol(3, "AutoHdr Float")
image_prompt_active_listview.Delete
image_prompt_active_listview.Opt("+Redraw")
image_prompt_active_listview.Add(,"", "1.000", "0.000")

;strength and noise augmentation
;--------------------------------------------------
image_prompt_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_strength_edit := image_prompt.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" 100 " r1 Background" control_colour " Center Limit6", "1.000")
image_prompt_strength_updown := image_prompt.Add("UpDown", "Range0-1 0x80 -2", 0)

image_prompt_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_noise_augmentation_edit := image_prompt.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w" 100 " r1 Background" control_colour " Center Limit6", "0.000")
image_prompt_noise_augmentation_updown := image_prompt.Add("UpDown", "Range0-1 0x80 -2", 0)

;add/remove buttons
;--------------------------------------------------
image_prompt_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_remove_button := image_prompt.Add("Button", "x0 y" stored_gui_y + stored_gui_h + 1 " h" edit_default_h " Background" background_colour, "Remove")
;get specific value
image_prompt_remove_button.GetPos(&image_prompt_remove_button_x, &image_prompt_remove_button_y, &image_prompt_remove_button_w, &image_prompt_remove_button_h)
image_prompt_remove_button.Move(stored_gui_x + stored_gui_w - image_prompt_remove_button_w,,,)

image_prompt_remove_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_prompt_add_button := image_prompt.Add("Button", "x" stored_gui_x - 1 - stored_gui_w " y" stored_gui_y " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Add")

;--------------------------------------------------
;loras
;--------------------------------------------------

lora_selection := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "LORA")
lora_selection.MarginX := 0
lora_selection.MarginY := 0
lora_selection.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
lora_selection.SetFont("s" text_size " c" text_colour " q0", text_font)

;lora name and strength
;--------------------------------------------------
lora_available_combobox := lora_selection.Add("ComboBox", "x0 y0 w" A_ScreenWidth / 5 - 1 " Background" control_colour " Choose1", ["None"])

lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_strength_edit := lora_selection.Add("Edit", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w" 100 " r1 Background" control_colour " Center Limit6", "1.000")
lora_strength_updown := lora_selection.Add("UpDown", "Range0-1 0x80 -2", 0)

;active loras
;--------------------------------------------------
lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_active_listview := lora_selection.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" A_ScreenWidth / 5 + 100 " r5 Background" control_colour " -Multi", ["LORA", "Strength"])

lora_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
Loop 6 {
  lora_active_listview.Add(,"")
}
lora_active_listview.ModifyCol(1, stored_gui_w - 100)
lora_active_listview.ModifyCol(2, "AutoHdr Float")
lora_active_listview.Delete
lora_active_listview.Add(,"None", "1.000")

;lora add/remove buttons
;--------------------------------------------------
lora_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_remove_button := lora_selection.Add("Button", "x0 y" stored_gui_y + stored_gui_h + 1 " h" edit_default_h " Background" background_colour, "Remove")
;get specific value
lora_remove_button.GetPos(&lora_remove_button_x, &lora_remove_button_y, &lora_remove_button_w, &lora_remove_button_h)
lora_remove_button.Move(stored_gui_x + stored_gui_w - lora_remove_button_w,,,)

lora_remove_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_add_button := lora_selection.Add("Button", "x" stored_gui_x - 1 - stored_gui_w " y" stored_gui_y " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Add")

;--------------------------------------------------
;preview (source image)
;--------------------------------------------------

preview_display := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Image Preview")
preview_display.MarginX := 0
preview_display.MarginY := 0
preview_display.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
preview_display.SetFont("s" text_size " c" text_colour " q0", text_font)

;main preview & dimensions
;--------------------------------------------------
image_width_edit := preview_display.Add("Edit", "x0 y" gap_y " w100 r1 Background" control_colour " Center Number Limit5", "512")
image_width_updown := preview_display.Add("UpDown", "Range0-1 0x80 -2", 0)
image_height_edit := preview_display.Add("Edit", "x0 y" gap_y " w100 r1 Background" control_colour " Center Number Limit5", "512")
image_height_updown := preview_display.Add("UpDown", "Range0-1 0x80 -2", 0)

image_width_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
main_preview_picture := preview_display.Add("Picture", "x0 y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 5 * 2 " h" A_ScreenHeight / 5 * 2, "stuff\placeholder_pixel.bmp")

main_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;get specific value
image_width_edit.GetPos(,, &image_width_edit_w,)
image_width_edit.Move(stored_gui_w / 2 - image_width_edit_w - updown_default_w - updown_offset_x - gap_x,,,)
image_height_edit.Move(stored_gui_w / 2 + gap_x,,,)

;manually reposition updowns
image_width_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_width_updown.Move(stored_gui_x + stored_gui_w + updown_offset_x, stored_gui_y)
image_height_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
image_height_updown.Move(stored_gui_x + stored_gui_w + updown_offset_x, stored_gui_y)

main_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)

generate_button := preview_display.Add("Button", "x" stored_gui_x + stored_gui_w / 2 - 50 " y" stored_gui_y + stored_gui_h + gap_y " w100 Background" background_colour, "Paint")

;--------------------------------------------------
;masking & controlnet
;--------------------------------------------------

mask_and_controlnet := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Additional Input Images")
mask_and_controlnet.MarginX := 0
mask_and_controlnet.MarginY := 0
mask_and_controlnet.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
mask_and_controlnet.SetFont("s" text_size " c" text_colour " q0", text_font)

;mask pictures
;--------------------------------------------------
mask_picture := mask_and_controlnet.Add("Picture", "x0 y" gap_y " w150 h150", "stuff\placeholder_pixel.bmp")

mask_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
mask_preview_picture := mask_and_controlnet.Add("Picture", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w150 h150", "stuff\placeholder_pixel.bmp")

;mask options
;--------------------------------------------------
mask_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;this seems to be broken, replace line if fixed
;mask_pixels_combobox := mask_and_controlnet.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w120 Background" control_colour " Choose1", ["Black", "White"])
mask_pixels_combobox := mask_and_controlnet.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w120 Background" control_colour " Choose1", ["red", "green", "blue"])

mask_pixels_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
mask_grow_edit := mask_and_controlnet.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w75 r1 Background" control_colour " Center Number Limit4", "0")
mask_grow_updown := mask_and_controlnet.Add("UpDown", "Range0-8192 0x80", 0)

mask_grow_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
mask_feather_edit := mask_and_controlnet.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit4", "0")
mask_feather_updown := mask_and_controlnet.Add("UpDown", "Range0-8192 0x80", 0)

mask_grow_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
mask_and_controlnet.SetFont("c" label_colour " q3", label_font)
inpainting_checkpoint_checkbox := mask_and_controlnet.Add("CheckBox", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y, "Inpainting Checkpoint")
mask_and_controlnet.SetFont("s" text_size " c" text_colour " q0", text_font)

;controlnet pictures
;--------------------------------------------------
mask_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_picture := mask_and_controlnet.Add("Picture", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w150 h150", "stuff\placeholder_pixel.bmp")

controlnet_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_preview_picture := mask_and_controlnet.Add("Picture", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w150 h150", "stuff\placeholder_pixel.bmp")

;controlnet model & options
;--------------------------------------------------
controlnet_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_checkpoint_combobox := mask_and_controlnet.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 6 " Background" control_colour " Choose1", ["None"])

controlnet_checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_strength_edit := mask_and_controlnet.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w75 r1 Background" control_colour " Center Limit6", "1.000")
controlnet_strength_updown := mask_and_controlnet.Add("UpDown", "Range0-1 0x80 -2", 0)

controlnet_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_start_edit := mask_and_controlnet.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "0.000")
controlnet_start_updown := mask_and_controlnet.Add("UpDown", "Range0-1 0x80 -2", 0)

controlnet_start_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_end_edit := mask_and_controlnet.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + 1 " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "1.000")
controlnet_end_updown := mask_and_controlnet.Add("UpDown", "Range0-1 0x80 -2", 0)

;controlnet preprocessors
;--------------------------------------------------
controlnet_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_preprocessor_dropdownlist := mask_and_controlnet.Add("DropDownList", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 6 " Background" control_colour " Choose1", ["None"])

;specific preprocessor controls created in a separate gui object
controlnet_preprocessor_options := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "ControlNet Preprocessors")
controlnet_preprocessor_options.MarginX := 0
controlnet_preprocessor_options.MarginY := 0
controlnet_preprocessor_options.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
controlnet_preprocessor_options.SetFont("s" text_size " c" text_colour " q0", text_font)

;for positioning the window
controlnet_checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_preprocessor_options_start_x := stored_gui_x + stored_gui_w + gap_x
controlnet_preprocessor_options_start_y := stored_gui_y - gap_y

;active controlnets
;--------------------------------------------------
controlnet_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_active_listview := mask_and_controlnet.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" A_ScreenWidth / 3 " r5 Background" control_colour " -Multi", ["Image", "Checkpoint", "Strength", "Start", "End", "Preprocessor"])

Loop 6 {
  controlnet_active_listview.Add(,"")
}
controlnet_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_active_listview.ModifyCol(1, "100")
controlnet_active_listview.ModifyCol(2, stored_gui_w / 6 * 2)
controlnet_active_listview.ModifyCol(3, "60 Float")
controlnet_active_listview.ModifyCol(4, "60 Float")
controlnet_active_listview.ModifyCol(5, "60 Float")
controlnet_active_listview.ModifyCol(6, "AutoHdr")
controlnet_active_listview.InsertCol(7, 0, "Preprocessor Options")
controlnet_active_listview.Delete
controlnet_active_listview.Add(, "", "None", "1.000", "0.000", "1.000", "None")

;controlnet add/remove buttons
;--------------------------------------------------
controlnet_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_remove_button := mask_and_controlnet.Add("Button", "x0 y" stored_gui_y + stored_gui_h + 1 " h" edit_default_h " Background" background_colour, "Remove")
;get specific value
controlnet_remove_button.GetPos(&controlnet_remove_button_x, &controlnet_remove_button_y, &controlnet_remove_button_w, &controlnet_remove_button_h)
controlnet_remove_button.Move(stored_gui_x + stored_gui_w - controlnet_remove_button_w,,,)

controlnet_remove_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_add_button := mask_and_controlnet.Add("Button", "x" stored_gui_x - 1 - stored_gui_w " y" stored_gui_y " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Add")

;--------------------------------------------------
;output image viewer
;--------------------------------------------------

output_viewer := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Output Viewer")
output_viewer.MarginX := 0
output_viewer.MarginY := 0
output_viewer.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
output_viewer.SetFont("s" text_size " c" text_colour " q0", text_font)

;output picture & list
;--------------------------------------------------
output_picture := output_viewer.Add("Picture", "x0 y0 w240 h240", "stuff\placeholder_pixel.bmp")

output_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
output_listview := output_viewer.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" stored_gui_w " h" A_ScreenHeight / 3 " Background" control_colour " -Multi SortDesc Count50", ["File Name", "Output Images"])

output_listview.Opt("-Redraw")
Loop 50 {
  output_listview.Add(,"")
}
output_listview.ModifyCol(1, 0)
output_listview.ModifyCol(2, "Integer Left AutoHdr")
output_listview.Delete()
output_listview.Opt("+Redraw")

output_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
clear_outputs_list_button := output_viewer.Add("Button", "x" stored_gui_w / 2 - 60 " y" stored_gui_y + stored_gui_h + 1 " w120 Background" background_colour, "Clear List")

;--------------------------------------------------
;assistant box
;--------------------------------------------------

assistant_box := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Status")
assistant_box.MarginX := 0
assistant_box.MarginY := 0
assistant_box.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
assistant_box.SetFont("s" text_size " c" text_colour " q0", text_font)
if (FileExist("stuff\assistant.png")) {
  status_picture := assistant_box.Add("Picture", "x0 y0 w0 h0", "stuff\assistant.png")
}
else {
  status_picture := assistant_box.Add("Picture", "x0 y0 w100 h100", "stuff\placeholder_pixel.bmp")
}

;--------------------------------------------------
;status box
;--------------------------------------------------

status_box := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Status")
status_box.MarginX := 0
status_box.MarginY := 0
status_box.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
status_box.SetFont("s" text_size " c" text_colour " q0", text_font)

main_controls.Show("Hide")
WinGetPos ,, &main_controls_w, &main_controls_h, main_controls.Hwnd

status_box.SetFont("s" text_size " c" label_colour " q3", label_font)
status_text := status_box.Add("Text", "x0 y0 w" A_ScreenWidth - gap_y - main_controls_w - screen_border_x " r15 Center")
status_box.SetFont("s" text_size " c" text_colour " q0", text_font)

;--------------------------------------------------
;settings window
;--------------------------------------------------

settings_window := Gui("+AlwaysOnTop +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Options")
server_address_label := settings_window.Add("Text", "Section", "ComfyUI Address:")
server_address_edit := settings_window.Add("Edit", "xp w150", server_address)
server_connect_button := settings_window.Add("Button", "yp w100", "Connect")

horde_address_label := settings_window.Add("Text", "xs", "Horde Address:")
horde_address_edit := settings_window.Add("Edit", "xp w150", horde_address)
horde_connect_button := settings_window.Add("Button", "yp w100", "Connect")

horde_api_key_label := settings_window.Add("Text", "xs", "Horde API key:")
horde_api_key_edit := settings_window.Add("Edit", "xp w150 r1 Password", horde_api_key)
horde_api_apply_button := settings_window.Add("Button", "yp w100", "Apply")

horde_use_specific_worker_label := settings_window.Add("Text", "xs", "Use Specific Worker:")
horde_use_specific_worker_edit := settings_window.Add("Edit", "xp w150", horde_use_specific_worker)
horde_use_specific_worker_button := settings_window.Add("Button", "yp w100", "Apply")

horde_allow_nsfw_checkbox := settings_window.Add("Checkbox", "xs Checked" (horde_allow_nsfw ? 1 : 0), "NSFW")
horde_replacement_filter_checkbox := settings_window.Add("Checkbox", "xs Checked" (horde_replacement_filter ? 1 : 0), "Replacement Filter")
horde_allow_untrusted_workers_checkbox := settings_window.Add("Checkbox", "xs Checked" (horde_allow_untrusted_workers ? 1 : 0), "Allow Untrusted Workers")
horde_allow_slow_workers_checkbox := settings_window.Add("Checkbox", "xs Checked" (horde_allow_slow_workers ? 1 : 0), "Allow Slow Workers")
horde_share_with_laion_checkbox := settings_window.Add("Checkbox", "xs Checked" (horde_share_with_laion ? 1 : 0), "Share with LAION to Improve AI")

save_settings_button := settings_window.Add("Button", "xs", "Save Settings")
open_settings_file_button := settings_window.Add("Button", "yp", "Open Settings File")

;--------------------------------------------------
;--------------------------------------------------
;showing/hiding labels
;--------------------------------------------------
;--------------------------------------------------

if (show_labels) {
  ;main controls
  ;--------------------------------------------------
  main_controls.SetFont("s" label_size " c" label_colour " q3", label_font)

  batch_size_label := main_controls.Add("Text", "x0 y0", "Images")
  ;get the height of this label and use for all labels that follow
  batch_size_label.GetPos(,,, &label_h)
  batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  batch_size_label.Move(stored_gui_x, stored_gui_y - label_h)

  checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  checkpoint_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Checkpoint")

  vae_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  vae_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "VAE")

  sampler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  sampler_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Sampler")

  scheduler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  scheduler_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Scheduler")

  prompt_positive_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  prompt_positive_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Prompt (+)")

  prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  prompt_negative_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Prompt (-)")

  seed_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  seed_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Seed")

  step_count_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  step_count_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Steps")

  cfg_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  cfg_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CFG")

  denoise_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  denoise_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Denoising")

  upscale_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  upscale_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Upscale")

  step_count_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  step_count_upscale_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Steps")

  cfg_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  cfg_upscale_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CFG")

  denoise_upscale_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  denoise_upscale_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Denoising")

  upscale_value_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  upscale_method_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Factor")

  refiner_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  refiner_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Refiner")

  refiner_start_step_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  refiner_start_step_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Start Step")

  cfg_refiner_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  cfg_refiner_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CFG")

  ;revert font just in case
  main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;image prompt
  ;--------------------------------------------------
  image_prompt.SetFont("s" label_size " c" label_colour " q3", label_font)

  clip_vision_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  clip_vision_label := image_prompt.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CLIP Vision")

  IPAdapter_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  IPAdapter_label := image_prompt.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "IPAdapter")

  image_prompt.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;preview image (source)
  ;--------------------------------------------------
  preview_display.SetFont("s" label_size " c" label_colour " q3", label_font)

  image_width_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  image_width_label := preview_display.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Width")

  image_height_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  image_height_label := preview_display.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Height")

  preview_display.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;masking & controlnet
  ;--------------------------------------------------
  mask_and_controlnet.SetFont("s" label_size " c" label_colour " q3", label_font)

  mask_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  mask_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Mask")

  mask_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  mask_preview_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Mask Preview")

  mask_pixels_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  mask_pixels_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Color")

  mask_grow_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  mask_grow_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Grow")

  mask_feather_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  mask_feather_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Feather")

  controlnet_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "ControlNet")

  controlnet_preview_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_preview_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "ControlNet Preview")

  controlnet_checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_checkpoint_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Checkpoint")

  controlnet_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_strength_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Strength")

  controlnet_start_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_start_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Start")

  controlnet_end_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_end_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "End")

  controlnet_preprocessor_dropdownlist.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  controlnet_preprocessor_label := mask_and_controlnet.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Preprocessor")

  mask_and_controlnet.SetFont("s" text_size " c" text_colour " q0", text_font)
}

;--------------------------------------------------
;--------------------------------------------------
;menus and picture frames
;--------------------------------------------------
;--------------------------------------------------

;submenus
;--------------------------------------------------
inputs_existing_images_menu := Menu()
outputs_existing_images_menu := Menu()
input_destination_menu := Menu()
horde_outputs_existing_images_menu := Menu()

;main preview
;--------------------------------------------------
main_preview_picture_menu := Menu()
main_preview_picture_menu.Add("Inputs", inputs_existing_images_menu)
main_preview_picture_menu.Add("Outputs", outputs_existing_images_menu)
main_preview_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
main_preview_picture_menu.Add("Clipboard", main_preview_picture_menu_clipboard)
main_preview_picture_menu.Add()
main_preview_picture_menu.Add("Remove", main_preview_picture_menu_remove)

;image prompt
;--------------------------------------------------
image_prompt_picture_menu := Menu()
image_prompt_picture_menu.Add("Inputs", inputs_existing_images_menu)
image_prompt_picture_menu.Add("Outputs", outputs_existing_images_menu)
image_prompt_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
image_prompt_picture_menu.Add("Clipboard", image_prompt_picture_menu_clipboard)
image_prompt_picture_menu.Add()
image_prompt_picture_menu.Add("Remove", image_prompt_picture_menu_remove)

;mask
;--------------------------------------------------
mask_picture_menu := Menu()
mask_picture_menu.Add("Inputs", inputs_existing_images_menu)
mask_picture_menu.Add("Outputs", outputs_existing_images_menu)
mask_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
mask_picture_menu.Add("Clipboard", mask_picture_menu_clipboard)
mask_picture_menu.Add()
mask_picture_menu.Add("Preview", mask_picture_menu_preview)
mask_picture_menu.Add("Remove", mask_picture_menu_remove)

;controlnet
;--------------------------------------------------
controlnet_picture_menu := Menu()
controlnet_picture_menu.Add("Inputs", inputs_existing_images_menu)
controlnet_picture_menu.Add("Outputs", outputs_existing_images_menu)
controlnet_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
controlnet_picture_menu.Add("Clipboard", controlnet_picture_menu_clipboard)
controlnet_picture_menu.Add()
controlnet_picture_menu.Add("Preview", controlnet_picture_menu_preview)
controlnet_picture_menu.Add("Remove", controlnet_picture_menu_remove)

;output images
;--------------------------------------------------
output_picture_menu := Menu()
output_picture_menu.Add("Send to Source", output_picture_menu_to_source)
output_picture_menu.Add("Send to Image Prompt", output_picture_menu_to_image_prompt)
output_picture_menu.Add("Send to Mask", output_picture_menu_to_mask)
output_picture_menu.Add("Send to ControlNet", output_picture_menu_to_controlnet)
output_picture_menu.Add()
output_picture_menu.Add("Send to Source (Horde)", output_picture_menu_to_horde_source)
output_picture_menu.Add("Send to Mask (Horde)", output_picture_menu_to_horde_mask)
output_picture_menu.Add()
output_picture_menu.Add("Copy", output_picture_menu_copy)


;status box
;--------------------------------------------------
status_picture_menu := Menu()
status_picture_menu.Add("Connect", connect_menu)
status_picture_menu.Add("Settings", show_settings)
status_picture_menu.Add()
status_picture_menu.Add("ComfyUI", switch_tab_menu)
status_picture_menu.Add("Horde", switch_tab_menu)
status_picture_menu.Add()
status_picture_menu.Add("Restart", restart_everything)
status_picture_menu.Add("Exit", exit_everything)


;picture frames
;--------------------------------------------------
main_preview_picture_frame := create_picture_frame("source", main_preview_picture)
image_prompt_picture_frame := create_picture_frame("", image_prompt_picture)
mask_picture_frame := create_picture_frame("mask", mask_picture)
mask_preview_picture_frame := create_picture_frame("mask_preview", mask_preview_picture)
controlnet_picture_frame := create_picture_frame("", controlnet_picture)
controlnet_preview_picture_frame := create_picture_frame("", controlnet_preview_picture)
output_picture_frame := create_picture_frame("output", output_picture)

;--------------------------------------------------
;--------------------------------------------------
;gui controls
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;main controls
;--------------------------------------------------

;image count
;--------------------------------------------------
batch_size_edit.OnEvent("LoseFocus", batch_size_edit_losefocus)
batch_size_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(1, 1, 64, GuiCtrlObj)
}

;seed
;--------------------------------------------------
seed_updown.OnEvent("Change", seed_updown_change)
seed_updown_change(GuiCtrlObj, Info) {
  ;-8446744073709551617 is 9999999999999999999 after wrapping around to a negative number
  if (IsNumber(seed_edit.Value) and (seed_edit.Value <= -8446744073709551617 or (Info and seed_edit.Value = 0x7FFFFFFFFFFFFFFF))) {
    seed_edit.Value := 0x7FFFFFFFFFFFFFFF
  }
  else {
    number_update(0, 0, 0x7FFFFFFFFFFFFFFF, 1, 0, seed_edit, Info)
  }
}

seed_edit.OnEvent("LoseFocus", seed_edit_losefocus)
seed_edit_losefocus(GuiCtrlObj, Info) {
  if (IsNumber(seed_edit.Value) and seed_edit.Value <= -8446744073709551617) {
    seed_edit.Value := 0x7FFFFFFFFFFFFFFF
  }
  else {
    number_cleanup(0, 0, 0x7FFFFFFFFFFFFFFF, GuiCtrlObj)
  }
}

random_seed_checkbox.OnEvent("Click", random_seed_checkbox_click)
random_seed_checkbox_click(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Value){
    seed_edit.Opt("+ReadOnly")
    seed_updown.Enabled := 0
    seed_edit.SetFont("c" control_colour)
  }
  else {
    seed_edit.Opt("-ReadOnly")
    seed_updown.Enabled := 1
    seed_edit.SetFont("c" text_colour)
  }
}

;steps
;--------------------------------------------------
step_count_updown.OnEvent("Change", step_count_updown_change)
step_count_updown_change(GuiCtrlObj, Info) {
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

step_count_edit.OnEvent("LoseFocus", step_count_edit_losefocus)
step_count_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(20, 0, 10000, GuiCtrlObj)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;cfg
;--------------------------------------------------
cfg_updown.OnEvent("Change", cfg_updown_change)
cfg_updown_change(GuiCtrlObj, Info) {
  number_update(7, 0, 100, 0.1, 1, cfg_edit, Info)
}

cfg_edit.OnEvent("LoseFocus", cfg_edit_losefocus)
cfg_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("7.0", "0.0", "100.0", GuiCtrlObj)
}


;denoise
;--------------------------------------------------
denoise_updown.OnEvent("Change", denoise_updown_change)
denoise_updown_change(GuiCtrlObj, Info) {
  number_update(1, 0, 1, 0.01, 3, denoise_edit, Info)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

denoise_edit.OnEvent("LoseFocus", denoise_edit_losefocus)
denoise_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("1.000", "0.000", "1.000", GuiCtrlObj)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;--------------------------------------------------
;upscaling
;--------------------------------------------------

;upscaling model
;--------------------------------------------------
upscale_combobox.OnEvent("Change", upscale_combobox_change)
upscale_combobox_change(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Text = "None" or !GuiCtrlObj.Text) {
    step_count_upscale_edit.Enabled := 0
    step_count_upscale_updown.Enabled := 0
    cfg_upscale_edit.Enabled := 0
    cfg_upscale_updown.Enabled := 0
    denoise_upscale_edit.Enabled := 0
    denoise_upscale_updown.Enabled := 0
    upscale_value_edit.Enabled := 0
    upscale_value_updown.Enabled := 0
    random_seed_upscale_checkbox.Enabled := 0
  }
  else {
    step_count_upscale_edit.Enabled := 1
    step_count_upscale_updown.Enabled := 1
    cfg_upscale_edit.Enabled := 1
    cfg_upscale_updown.Enabled := 1
    denoise_upscale_edit.Enabled := 1
    denoise_upscale_updown.Enabled := 1
    upscale_value_edit.Enabled := 1
    upscale_value_updown.Enabled := 1
    random_seed_upscale_checkbox.Enabled := 1
  }
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;upscale steps
;--------------------------------------------------
step_count_upscale_updown.OnEvent("Change", step_count_upscale_updown_change)
step_count_upscale_updown_change(GuiCtrlObj, Info) {
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

step_count_upscale_edit.OnEvent("LoseFocus", step_count_upscale_edit_losefocus)
step_count_upscale_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(0, 0, 10000, GuiCtrlObj)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;upscale cfg
;--------------------------------------------------
cfg_upscale_updown.OnEvent("Change", cfg_upscale_updown_change)
cfg_upscale_updown_change(GuiCtrlObj, Info) {
  number_update(7, 0, 100, 0.1, 1, cfg_upscale_edit, Info)
}

cfg_upscale_edit.OnEvent("LoseFocus", cfg_upscale_edit_losefocus)
cfg_upscale_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("7.0", "0.0", "100.0", GuiCtrlObj)
}


;upscale denoise
;--------------------------------------------------
denoise_upscale_updown.OnEvent("Change", denoise_upscale_updown_change)
denoise_upscale_updown_change(GuiCtrlObj, Info) {
  number_update(1, 0, 1, 0.01, 3, denoise_upscale_edit, Info)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

denoise_upscale_edit.OnEvent("LoseFocus", denoise_upscale_edit_losefocus)
denoise_upscale_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("1.000", "0.000", "1.000", GuiCtrlObj)
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;upscale target
;--------------------------------------------------
upscale_value_updown.OnEvent("Change", upscale_value_updown_change)
upscale_value_updown_change(GuiCtrlObj, Info) {
  number_update(1, 0, 100, 0.01, 3, upscale_value_edit, Info)
}

upscale_value_edit.OnEvent("LoseFocus", upscale_value_edit_losefocus)
upscale_value_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("1.000", "0.000", "100.000", GuiCtrlObj)
}

;--------------------------------------------------
;refiner
;--------------------------------------------------

;refiner model
;--------------------------------------------------

refiner_combobox.OnEvent("Change", refiner_combobox_change)
refiner_combobox_change(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Text = "None" or !GuiCtrlObj.Text) {
    refiner_start_step_edit.Enabled := 0
    refiner_start_step_updown.Enabled := 0
    cfg_refiner_edit.Enabled := 0
    cfg_refiner_updown.Enabled := 0
    random_seed_refiner_checkbox.Enabled := 0
    refiner_conditioning_checkbox.Enabled := 0
  }
  else {
    refiner_start_step_edit.Enabled := 1
    refiner_start_step_updown.Enabled := 1
    cfg_refiner_edit.Enabled := 1
    cfg_refiner_updown.Enabled := 1
    random_seed_refiner_checkbox.Enabled := 1
    refiner_conditioning_checkbox.Enabled := 1
    refiner_start_step_edit_losefocus(refiner_start_step_edit, "")
  }
}

;refiner steps
;--------------------------------------------------
refiner_start_step_updown.OnEvent("Change", refiner_start_step_updown_change)
refiner_start_step_updown_change(GuiCtrlObj, Info) {
  if (upscale_combobox.Text and upscale_combobox.Text != "None") {
    number_update(step_count_upscale_edit.Value, Round(step_count_upscale_edit.Value - (denoise_upscale_edit.Value * step_count_upscale_edit.Value)), step_count_upscale_edit.Value, 1, 0, refiner_start_step_edit, Info)
  }
  else {
    number_update(step_count_edit.Value, Round(step_count_edit.Value - (denoise_edit.Value * step_count_edit.Value)), step_count_edit.Value, 1, 0, refiner_start_step_edit, Info)
  }
}

refiner_start_step_edit.OnEvent("LoseFocus", refiner_start_step_edit_losefocus)
refiner_start_step_edit_losefocus(GuiCtrlObj, Info) {
  if (upscale_combobox.Text and upscale_combobox.Text != "None") {
    number_cleanup(step_count_upscale_edit.Value, Round(step_count_upscale_edit.Value - (denoise_upscale_edit.Value * step_count_upscale_edit.Value)), step_count_upscale_edit.Value, GuiCtrlObj)
  }
  else {
    number_cleanup(step_count_edit.Value, Round(step_count_edit.Value - (denoise_edit.Value * step_count_edit.Value)), step_count_edit.Value, GuiCtrlObj)
  }
}

;refiner cfg
;--------------------------------------------------
cfg_refiner_updown.OnEvent("Change", cfg_refiner_updown_change)
cfg_refiner_updown_change(GuiCtrlObj, Info) {
  number_update(7, 0, 100, 0.1, 1, cfg_refiner_edit, Info)
}

cfg_refiner_edit.OnEvent("LoseFocus", cfg_refiner_edit_losefocus)
cfg_refiner_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup("7.0", "0.0", "100.0", GuiCtrlObj)
}

;--------------------------------------------------
;image prompt
;--------------------------------------------------

;active image prompts
;--------------------------------------------------
image_prompt_active_listview.OnEvent("ItemSelect", image_prompt_active_listview_itemselect)
image_prompt_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  image_prompt_current := GuiCtrlObj.GetCount() = 1 ? 1 : GuiCtrlObj.GetNext()
  if (image_prompt_current) {
    image_prompt_picture_frame["name"] := GuiCtrlObj.GetText(image_prompt_current, 1)
    if (inputs.Has(image_prompt_picture_frame["name"])) {
      image_load_and_fit_wthout_change(inputs[image_prompt_picture_frame["name"]], image_prompt_picture_frame)
    }
    else {
      image_prompt_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(image_prompt_picture_frame["w"], image_prompt_picture_frame["h"], image_prompt_picture_frame)
    }
    image_prompt_strength_edit.Value := GuiCtrlObj.GetText(image_prompt_current, 2)
    image_prompt_noise_augmentation_edit.Value := GuiCtrlObj.GetText(image_prompt_current, 3)
  }
  else {
    image_prompt_picture_frame["name"] := ""
    ;use blank image
    image_prompt_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    picture_fit_to_frame(image_prompt_picture_frame["w"], image_prompt_picture_frame["h"], image_prompt_picture_frame)
    image_prompt_strength_edit.Value := "1.000"
    image_prompt_noise_augmentation_edit.Value := "0.000"
  }
}

image_prompt_active_listview.OnEvent("DoubleClick", image_prompt_remove_button_click)

;strength
;--------------------------------------------------
image_prompt_strength_updown.OnEvent("Change", image_prompt_strength_updown_change)
image_prompt_strength_updown_change(GuiCtrlObj, Info) {
  number_update(1, -10, 10, 0.01, 3, image_prompt_strength_edit, Info)
  image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
  if (image_prompt_current) {
    image_prompt_active_listview.Modify(image_prompt_current, "Vis",, image_prompt_strength_edit.Value)
  }
}

image_prompt_strength_edit.OnEvent("LoseFocus", image_prompt_strength_edit_losefocus)
image_prompt_strength_edit_losefocus(GuiCtrlObj, Info) {
  image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
  if (image_prompt_current) {
    number_cleanup(image_prompt_active_listview.GetText(image_prompt_current, 2), "-10.000", "10.000", GuiCtrlObj)
    image_prompt_active_listview.Modify(image_prompt_current,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("1.000", "-10.000", "10.000", GuiCtrlObj)
  }
}

;noise augmentation
;--------------------------------------------------
image_prompt_noise_augmentation_updown.OnEvent("Change", image_prompt_noise_augmentation_updown_change)
image_prompt_noise_augmentation_updown_change(GuiCtrlObj, Info) {
  number_update(0, 0, 1, 0.01, 3, image_prompt_noise_augmentation_edit, Info)
  image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
  if (image_prompt_current) {
    image_prompt_active_listview.Modify(image_prompt_current, "Vis",,, image_prompt_noise_augmentation_edit.Value)
  }
}

image_prompt_noise_augmentation_edit.OnEvent("LoseFocus", image_prompt_noise_augmentation_edit_losefocus)
image_prompt_noise_augmentation_edit_losefocus(GuiCtrlObj, Info) {
  image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
  if (image_prompt_current) {
    number_cleanup(image_prompt_active_listview.GetText(image_prompt_current, 3), "0.000", "1.000", GuiCtrlObj)
    image_prompt_active_listview.Modify(image_prompt_current,,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("0.000", "0.000", "1.000", GuiCtrlObj)
  }
}

;add image prompt button
;--------------------------------------------------
image_prompt_add_button.OnEvent("Click", image_prompt_add_button_click)
image_prompt_add_button_click(GuiCtrlObj, Info) {
  if (image_prompt_active_listview.GetNext() or image_prompt_active_listview.GetCount() <= 1) {
    image_prompt_active_listview.Add("Select", "", "1.000", "0.000")
    image_prompt_active_listview.Modify(image_prompt_active_listview.GetCount(), "Vis")
    image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
  }
  else {
    ;if an image is selected without a row being active, a row should be automatically created
    ;it should act as if the "Add" button gets pressed automatically
    image_prompt_active_listview.Add("Select", image_prompt_picture_frame["name"], image_prompt_strength_edit.Value, image_prompt_noise_augmentation_edit.Value)
    image_prompt_active_listview.Modify(image_prompt_active_listview.GetCount(), "Vis")
    image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
  }
}

;remove image prompt button
;--------------------------------------------------
image_prompt_remove_button.OnEvent("Click", image_prompt_remove_button_click)
image_prompt_remove_button_click(GuiCtrlObj, Info) {
  ;if an image has been selected, it should always be deleted when "Remove" is clicked
  if (inputs.Has(image_prompt_picture_frame["name"])) {
    inputs.Delete(image_prompt_picture_frame["name"])
  }
  if (image_prompt_active_listview.GetCount() <= 1) {
    ;"remove" is a "reset" button when there's only one row
    image_prompt_picture_frame["name"] := ""
    image_prompt_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    picture_fit_to_frame(image_prompt_picture_frame["w"], image_prompt_picture_frame["h"], image_prompt_picture_frame)
    image_prompt_strength_edit.Value := "1.000"
    image_prompt_noise_augmentation_edit.Value := "0.000"
    image_prompt_active_listview.Delete()
    image_prompt_active_listview.Add(, "", "1.000", "0.000")
  }
  else {
    image_prompt_to_remove := image_prompt_active_listview.GetNext()
    if (image_prompt_to_remove) {
      image_prompt_active_listview.Delete(image_prompt_active_listview.GetNext())
      if (image_prompt_to_remove > image_prompt_active_listview.GetCount()) {
        image_prompt_active_listview.Modify(image_prompt_active_listview.GetCount(), "Select Vis")
      }
      else {
        image_prompt_active_listview.Modify(image_prompt_to_remove, "Select Vis")
      }
      ;takes care of cleanup
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
  }
}

;--------------------------------------------------
;loras
;--------------------------------------------------

;lora name
;--------------------------------------------------
lora_available_combobox.OnEvent("Change", lora_available_combobox_change)
lora_available_combobox_change(GuiCtrlObj, Info) {
  lora_current := lora_active_listview.GetCount() = 1 ? 1 : lora_active_listview.GetNext()
  if (lora_current) {
    lora_active_listview.Modify(lora_current, "Vis", GuiCtrlObj.Text)
  }
}

;lora strength
;--------------------------------------------------
lora_strength_updown.OnEvent("Change", lora_strength_updown_change)
lora_strength_updown_change(GuiCtrlObj, Info) {
  number_update(1, 0, 1, 0.01, 3, lora_strength_edit, Info)
  lora_current := lora_active_listview.GetCount() = 1 ? 1 : lora_active_listview.GetNext()
  if (lora_current) {
    lora_active_listview.Modify(lora_current, "Vis",, lora_strength_edit.Value)
  }
}

lora_strength_edit.OnEvent("LoseFocus", lora_strength_edit_losefocus)
lora_strength_edit_losefocus(GuiCtrlObj, Info) {
  lora_current := lora_active_listview.GetCount() = 1 ? 1 : lora_active_listview.GetNext()
  if (lora_current) {
    number_cleanup(lora_active_listview.GetText(lora_current, 2), "0.000", "1.000", GuiCtrlObj)
    lora_active_listview.Modify(lora_current,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("1.000", "0.000", "1.000", GuiCtrlObj)
  }
}

;active loras
;--------------------------------------------------
lora_active_listview.OnEvent("ItemSelect", lora_active_listview_itemselect)
;unsure how Item and Selected work
;get selected row manually
lora_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  lora_current := GuiCtrlObj.GetCount() = 1 ? 1 : GuiCtrlObj.GetNext()
  if (lora_current) {
    lora_available_combobox.Text := GuiCtrlObj.GetText(lora_current,1)
    lora_strength_edit.Value := GuiCtrlObj.GetText(lora_current,2)
  }
  else {
    lora_available_combobox.Text := "None"
    lora_strength_edit.Value := "1.000"
  }
}

lora_active_listview.OnEvent("DoubleClick", lora_remove_button_click)

;add lora button
;--------------------------------------------------
lora_add_button.OnEvent("Click", lora_add_button_click)
lora_add_button_click(GuiCtrlObj, Info) {
  if (lora_active_listview.GetNext() or lora_active_listview.GetCount() <= 1) {
    lora_active_listview.Add("Select", "None", "1.000")
    lora_active_listview.Modify(lora_active_listview.GetCount(), "Vis")
    lora_active_listview_itemselect(lora_active_listview, "", "")
    lora_available_combobox.Focus()
  }
  else {
    lora_active_listview.Add("Select", lora_available_combobox.Text, lora_strength_edit.Value)
    lora_active_listview.Modify(lora_active_listview.GetCount(), "Vis")
    ;not actually necessary here?
    ;lora_active_listview_itemselect(lora_active_listview, "", "")
  }
}

;remove lora button
;--------------------------------------------------
lora_remove_button.OnEvent("Click", lora_remove_button_click)
lora_remove_button_click(GuiCtrlObj, Info) {
  if (lora_active_listview.GetCount() <= 1) {
    ;works like a reset button
    lora_available_combobox.Text := "None"
    lora_strength_edit.Value := "1.000"
    lora_active_listview.Delete()
    lora_active_listview.Add(, "None", "1.000")
  }
  else {
    lora_to_remove := lora_active_listview.GetNext()
    if (lora_to_remove) {
      lora_active_listview.Delete(lora_active_listview.GetNext())
      if (lora_to_remove > lora_active_listview.GetCount()) {
        lora_active_listview.Modify(lora_active_listview.GetCount(), "Select Vis")
      }
      else {
        lora_active_listview.Modify(lora_to_remove, "Select Vis")
      }
      ;should take care of cleaning up
      lora_active_listview_itemselect(lora_active_listview, "", "")
    }
  }
}

;--------------------------------------------------
;preview (source image)
;--------------------------------------------------

;width
;--------------------------------------------------
image_width_updown.OnEvent("Change", image_width_updown_change)
image_width_updown_change(GuiCtrlObj, Info) {
  number_update(512, 8, 8192, 8, 0, image_width_edit, Info)
  picture_fit_to_frame(image_width_edit.Value, image_height_edit.Value, main_preview_picture_frame)
  global clear_main_preview_image_on_next_dimension_change
  if (clear_main_preview_image_on_next_dimension_change) {
    main_preview_picture.Value := "stuff\placeholder_pixel.bmp"
    clear_main_preview_image_on_next_dimension_change := 0
  }
}

image_width_edit.OnEvent("LoseFocus", image_width_edit_losefocus)
image_width_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(512, 8, 8192, GuiCtrlObj)
  picture_fit_to_frame(image_width_edit.Value, image_height_edit.Value, main_preview_picture_frame)
  global clear_main_preview_image_on_next_dimension_change
  if (clear_main_preview_image_on_next_dimension_change) {
    main_preview_picture.Value := "stuff\placeholder_pixel.bmp"
    clear_main_preview_image_on_next_dimension_change := 0
  }
}

;height
;--------------------------------------------------
image_height_updown.OnEvent("Change", image_height_updown_change)
image_height_updown_change(GuiCtrlObj, Info) {
  number_update(512, 8, 8192, 8, 0, image_height_edit, Info)
  picture_fit_to_frame(image_width_edit.Value, image_height_edit.Value, main_preview_picture_frame)
  global clear_main_preview_image_on_next_dimension_change
  if (clear_main_preview_image_on_next_dimension_change) {
    main_preview_picture.Value := "stuff\placeholder_pixel.bmp"
    clear_main_preview_image_on_next_dimension_change := 0
  }
}

image_height_edit.OnEvent("LoseFocus", image_height_edit_losefocus)
image_height_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(512, 8, 8192, GuiCtrlObj)
  picture_fit_to_frame(image_width_edit.Value, image_height_edit.Value, main_preview_picture_frame)
  global clear_main_preview_image_on_next_dimension_change
  if (clear_main_preview_image_on_next_dimension_change) {
    main_preview_picture.Value := "stuff\placeholder_pixel.bmp"
    clear_main_preview_image_on_next_dimension_change := 0
  }
}

;generate button
;--------------------------------------------------
generate_button.OnEvent("Click", generate_button_click)
generate_button_click(GuiCtrlObj, Info) {
  if (assistant_status = "idle") {
    diffusion_time()
  }
  else if (assistant_status = "painting") {
    cancel_painting()
  }
}

;--------------------------------------------------
;masking & controlnet
;--------------------------------------------------

;mask grow
;--------------------------------------------------
mask_grow_edit.OnEvent("LoseFocus", mask_grow_edit_losefocus)
mask_grow_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(0, 0, 8192, GuiCtrlObj)
}

;mask feather
;--------------------------------------------------
mask_feather_edit.OnEvent("LoseFocus", mask_feather_edit_losefocus)
mask_feather_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(0, 0, 8192, GuiCtrlObj)
}

;controlnet model
;--------------------------------------------------
controlnet_checkpoint_combobox.OnEvent("Change", controlnet_checkpoint_combobox_change)
controlnet_checkpoint_combobox_change(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis",, GuiCtrlObj.Text)
  }
}

;controlnet strength
;--------------------------------------------------
controlnet_strength_updown.OnEvent("Change", controlnet_strength_updown_change)
controlnet_strength_updown_change(GuiCtrlObj, Info) {
  number_update(1, 0, 1, 0.01, 3, controlnet_strength_edit, Info)
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis",,, controlnet_strength_edit.Value)
  }
}

controlnet_strength_edit.OnEvent("LoseFocus", controlnet_strength_edit_losefocus)
controlnet_strength_edit_losefocus(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (controlnet_current) {
    number_cleanup(controlnet_active_listview.GetText(controlnet_current, 3), "0.000", "1.000", GuiCtrlObj)
    controlnet_active_listview.Modify(controlnet_current, "Vis",,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("1.000", "0.000", "1.000", GuiCtrlObj)
  }
}

;controlnet start
;--------------------------------------------------
controlnet_start_updown.OnEvent("Change", controlnet_start_updown_change)
controlnet_start_updown_change(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (!IsNumber(controlnet_end_edit.Value)) {
    if (controlnet_current) {
      controlnet_end_edit.Value := controlnet_active_listview.GetText(controlnet_current, 5)
    }
    else {
      controlnet_end_edit.Value := "1.000"
    }
  }
  number_update(0, 0, Round(controlnet_end_edit.Value - 0.01, 3), 0.01, 3, controlnet_start_edit, Info)

  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,, controlnet_start_edit.Value)
  }
}

controlnet_start_edit.OnEvent("LoseFocus", controlnet_start_edit_losefocus)
controlnet_start_edit_losefocus(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (!IsNumber(controlnet_end_edit.Value)) {
    if (controlnet_current) {
      controlnet_end_edit.Value := controlnet_active_listview.GetText(controlnet_current, 5)
    }
    else {
      controlnet_end_edit.Value := "1.000"
    }
  }
  if (controlnet_current) {
    number_cleanup(controlnet_active_listview.GetText(controlnet_current, 4), "0.000", Round(controlnet_end_edit.Value - 0.001, 3), GuiCtrlObj)
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("0.000", "0.000", "1.000", GuiCtrlObj)
  }
}

;controlnet end
;--------------------------------------------------
controlnet_end_updown.OnEvent("Change", controlnet_end_updown_change)
controlnet_end_updown_change(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (!IsNumber(controlnet_start_edit.Value)) {
    if (controlnet_current) {
      controlnet_start_edit.Value := controlnet_active_listview.GetText(controlnet_current, 4)
    }
    else {
      controlnet_start_edit.Value := "0.000"
    }
  }
  number_update(1, Round(controlnet_start_edit.Value + 0.01, 3), 1, 0.01, 3, controlnet_end_edit, Info)

  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,,, controlnet_end_edit.Value)
  }
}

controlnet_end_edit.OnEvent("LoseFocus", controlnet_end_edit_losefocus)
controlnet_end_edit_losefocus(GuiCtrlObj, Info) {
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (!IsNumber(controlnet_start_edit.Value)) {
    if (controlnet_current) {
      controlnet_start_edit.Value := controlnet_active_listview.GetText(controlnet_current, 4)
    }
    else {
      controlnet_start_edit.Value := "0.000"
    }
  }
  if (controlnet_current) {
    number_cleanup(controlnet_active_listview.GetText(controlnet_current, 5), Round(controlnet_start_edit.Value + 0.001, 3), "1.000", GuiCtrlObj)
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup("1.000", "0.000", "1.000", GuiCtrlObj)
  }
}

;controlnet preprocessor node
;--------------------------------------------------
controlnet_preprocessor_dropdownlist.OnEvent("Change", controlnet_preprocessor_dropdownlist_change)
controlnet_preprocessor_dropdownlist_change(GuiCtrlObj, Info) {
  controlnet_preprocessor_hide()
  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (GuiCtrlObj.Value = 1) {
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,,, "")
    }
  }
  else if (preprocessor_actual_name.Has(GuiCtrlObj.Text)) {
    actual_name := preprocessor_actual_name[GuiCtrlObj.Text]
    if (preprocessor_controls.Has(actual_name)) {
      ;update the listview
      pp_value_string := ""
      for(opt in preprocessor_controls[actual_name]) {
        pp_value_string .= opt ":" preprocessor_controls[actual_name][opt][1].Text
        if (A_Index < preprocessor_controls[actual_name].Count) {
          pp_value_string .= ","
        }
        for (control in preprocessor_controls[actual_name][opt]) {
          control.Visible := 1
        }
      }
      if (controlnet_current) {
        controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,,, pp_value_string)
      }
    }
  }
  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,, GuiCtrlObj.Text)
  }
}

controlnet_preprocessor_hide() {
  for (node in preprocessor_controls) {
    for (opt in preprocessor_controls[node]) {
      for (control in preprocessor_controls[node][opt]) {
      control.Visible := 0
      }
    }
  }
}

controlnet_preprocessor_reset_values() {
  ;refer to the object values received from server to determine defaults
  for (node in preprocessor_controls) {
    for (opt in preprocessor_controls[node]) {
      for (optionality in scripture[node]["input"]) {
        if (scripture[node]["input"][optionality].Has(opt)) {
          if (scripture[node]["input"][optionality][opt].Has(2) and (scripture[node]["input"][optionality][opt][2].Has("default"))) {
            preprocessor_controls[node][opt][1].Text := scripture[node]["input"][optionality][opt][2]["default"]
          }
          else if (Type(scripture[node]["input"][optionality][opt][1]) = "Array") {
            preprocessor_controls[node][opt][1].Text := scripture[node]["input"][optionality][opt][1][1]
          }
        }
      }
    }
  }
}

;active controlnets
;--------------------------------------------------
controlnet_active_listview.OnEvent("ItemSelect", controlnet_active_listview_itemselect)
controlnet_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  controlnet_current := GuiCtrlObj.GetCount() = 1 ? 1 : GuiCtrlObj.GetNext()
  if (controlnet_current) {
    controlnet_picture_frame["name"] := GuiCtrlObj.GetText(controlnet_current, 1)
    if (inputs.Has(controlnet_picture_frame["name"])) {
      image_load_and_fit_wthout_change(inputs[controlnet_picture_frame["name"]], controlnet_picture_frame)
      if (preview_images.Has(controlnet_picture_frame["name"])) {
        image_load_and_fit_wthout_change(preview_images[controlnet_picture_frame["name"]], controlnet_preview_picture_frame)
      }
      else {
        controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
        picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
      }
    }
    else {
      controlnet_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(controlnet_picture_frame["w"], controlnet_picture_frame["h"], controlnet_picture_frame)
      controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
    }
    controlnet_checkpoint_combobox.Text := GuiCtrlObj.GetText(controlnet_current, 2)
    controlnet_strength_edit.Value := GuiCtrlObj.GetText(controlnet_current, 3)
    controlnet_start_edit.Value := GuiCtrlObj.GetText(controlnet_current, 4)
    controlnet_end_edit.Value := GuiCtrlObj.GetText(controlnet_current, 5)
    try {
      controlnet_preprocessor_dropdownlist.Text := GuiCtrlObj.GetText(controlnet_current, 6)
    }

    controlnet_preprocessor_reset_values()
    ;and then load the value from the listview string
    if preprocessor_actual_name.Has(GuiCtrlObj.GetText(controlnet_current, 6)) {
      actual_name := preprocessor_actual_name[GuiCtrlObj.GetText(controlnet_current, 6)]
      if (preprocessor_controls.Has(actual_name)) {
        if (GuiCtrlObj.GetText(controlnet_current, 7) != "") {
          Loop Parse controlnet_active_listview.GetText(controlnet_current, 7), "," {
            option_pair := StrSplit(A_LoopField, ":")
            preprocessor_controls[actual_name][option_pair[1]][1].Text := option_pair[2]
          }
        }
      }
    }

    controlnet_preprocessor_dropdownlist_change(controlnet_preprocessor_dropdownlist, "")
  }
  else {
    controlnet_picture_frame["name"] := ""
    ;use blank image
    controlnet_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    picture_fit_to_frame(controlnet_picture_frame["w"], controlnet_picture_frame["h"], controlnet_picture_frame)
    controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
    controlnet_checkpoint_combobox.Text := "None"
    controlnet_strength_edit.Value := "1.000"
    controlnet_start_edit.Value := "0.000"
    controlnet_end_edit.Value := "1.000"
    controlnet_preprocessor_dropdownlist.Value := 1
    controlnet_preprocessor_reset_values()
    controlnet_preprocessor_dropdownlist_change(controlnet_preprocessor_dropdownlist, "")
  }
}

controlnet_active_listview.OnEvent("DoubleClick", controlnet_remove_button_click)


;add controlnet button
;--------------------------------------------------
controlnet_add_button.OnEvent("Click", controlnet_add_button_click)
controlnet_add_button_click(GuiCtrlObj, Info) {
  if (controlnet_active_listview.GetNext() or controlnet_active_listview.GetCount() <= 1) {
    controlnet_active_listview.Add("Select", "", "None", "1.000", "0.000", "1.000", "None", "")
    controlnet_active_listview.Modify(controlnet_active_listview.GetCount(), "Vis")
    controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    controlnet_checkpoint_combobox.Focus()
  }
  else {
    ;if an image is selected without a row being active, a row should be automatically created
    ;it should act as if the "Add" button gets pressed automatically
    controlnet_active_listview.Add("Select", controlnet_picture_frame["name"], controlnet_checkpoint_combobox.Text, controlnet_strength_edit.Value, controlnet_start_edit.Value, controlnet_end_edit.Value, controlnet_preprocessor_dropdownlist.Text, "")
    ;this should also update the new entry's preprocessor options
    controlnet_preprocessor_dropdownlist_change(controlnet_preprocessor_dropdownlist, "")
    controlnet_active_listview.Modify(controlnet_active_listview.GetCount(), "Vis")
    ;takes care of preview image
    controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
  }
}

;remove controlnet button
;--------------------------------------------------
controlnet_remove_button.OnEvent("Click", controlnet_remove_button_click)
controlnet_remove_button_click(GuiCtrlObj, Info) {
  ;if an image has been selected, it should always be deleted when "Remove" is clicked
  if (inputs.Has(controlnet_picture_frame["name"])) {
    inputs.Delete(controlnet_picture_frame["name"])
    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
      controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
    }
  }
  if (controlnet_active_listview.GetCount() <= 1) {
    ;"remove" is a "reset" button when there's only one row
    controlnet_picture_frame["name"] := ""
    controlnet_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
    picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
    picture_fit_to_frame(controlnet_picture_frame["w"], controlnet_picture_frame["h"], controlnet_picture_frame)
    controlnet_checkpoint_combobox.Text := "None"
    controlnet_strength_edit.Value := "1.000"
    controlnet_start_edit.Value := "0.000"
    controlnet_end_edit.Value := "1.000"
    controlnet_preprocessor_dropdownlist.Value := 1
    controlnet_preprocessor_reset_values()
    controlnet_preprocessor_dropdownlist_change(controlnet_preprocessor_dropdownlist, "")
    controlnet_active_listview.Delete()
    controlnet_active_listview.Add(, "", "None", "1.000", "0.000", "1.000", "None", "")
  }
  else {
    controlnet_to_remove := controlnet_active_listview.GetNext()
    if (controlnet_to_remove) {
      controlnet_active_listview.Delete(controlnet_active_listview.GetNext())
      if (controlnet_to_remove > controlnet_active_listview.GetCount()) {
        controlnet_active_listview.Modify(controlnet_active_listview.GetCount(), "Select Vis")
      }
      else {
        controlnet_active_listview.Modify(controlnet_to_remove, "Select Vis")
      }
      ;takes care of cleanup
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
  }
}

;--------------------------------------------------
;output image viewer
;--------------------------------------------------

;output image list
;--------------------------------------------------
output_listview.OnEvent("ItemSelect", output_listview_itemselect)
output_listview_itemselect(GuiCtrlObj, Item, Selected) {
  if (GuiCtrlObj.GetNext()) {
    global last_selected_output_image := output_folder GuiCtrlObj.GetText(GuiCtrlObj.GetNext(), 1)
    try {
      image_load_and_fit_wthout_change(last_selected_output_image, output_picture_frame)
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
    }
  }
}

output_listview.OnEvent("DoubleClick", output_listview_doubleclick)
output_listview_doubleclick(GuiCtrlObj, Info) {
  if (last_selected_output_image) {
    Run last_selected_output_image
    overlay_hide()
  }
}

clear_outputs_list_button.OnEvent("Click", clear_outputs_list_button_click)
clear_outputs_list_button_click(GuiCtrlObj, Info) {
  output_listview.Delete()
  global last_selected_output_image := ""
  image_load_and_fit_wthout_change("stuff\placeholder_pixel.bmp", output_picture_frame)
}

;--------------------------------------------------
;--------------------------------------------------
;picture frames, context menus, drop files
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;main preview
;--------------------------------------------------
main_preview_picture.OnEvent("ContextMenu", main_preview_picture_contextmenu)
main_preview_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  if (assistant_status = "painting") {
    return
  }

  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, main_preview_picture_menu_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, main_preview_picture_menu_horde_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), main_preview_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), main_preview_picture_menu_horde_output_file)
  }
  main_preview_picture_menu.Show()
}

;main preview - input file
;--------------------------------------------------
main_preview_picture_menu_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(inputs[ItemName], main_preview_picture_frame)) {
    inputs[main_preview_picture_frame["name"]] := valid_file
    main_preview_picture_update(0)
  }
}

;main preview - output file
;--------------------------------------------------
main_preview_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(output_folder ItemName, main_preview_picture_frame)) {
    inputs[main_preview_picture_frame["name"]] := valid_file
    main_preview_picture_update(0)
  }
}

;main preview - clipboard
;--------------------------------------------------
main_preview_picture_menu_clipboard(*) {
  if (valid_file := image_load_and_fit_clipboard(main_preview_picture_frame)) {
    inputs[main_preview_picture_frame["name"]] := valid_file
    main_preview_picture_update(0)
  }
}

;main preview - remove
;--------------------------------------------------
main_preview_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (inputs.Has(main_preview_picture_frame["name"])) {
    inputs.Delete(main_preview_picture_frame["name"])
  }
  main_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  main_preview_picture_update(1)
}

;main preview - horde input file
;--------------------------------------------------
main_preview_picture_menu_horde_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], main_preview_picture_frame)) {
    inputs[main_preview_picture_frame["name"]] := valid_file
    main_preview_picture_update(0)
  }
}

;main preview - horde output file
;--------------------------------------------------
main_preview_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, main_preview_picture_frame)) {
    inputs[main_preview_picture_frame["name"]] := valid_file
    main_preview_picture_update(0)
  }
}

;main preview - drop
;--------------------------------------------------
preview_display.OnEvent("DropFiles", preview_display_dropfiles)
preview_display_dropfiles(GuiObj, GuiCtrlObj, FileArray, X, Y) {
  if (assistant_status = "painting") {
    return
  }

  if (GuiCtrlObj = main_preview_picture) {
    if (valid_file := image_load_and_fit(FileArray[1], main_preview_picture_frame)) {
      inputs[main_preview_picture_frame["name"]] := valid_file
      main_preview_picture_update(0)
    }
  }
}

;main preview - misc
;--------------------------------------------------
main_preview_picture_update(on_off) {
  if (on_off) {
    image_width_edit.Enabled := 1
    image_width_updown.Enabled := 1
    image_height_edit.Enabled := 1
    image_height_updown.Enabled := 1
  }
  else {
    image_width_edit.Enabled := 0
    image_width_updown.Enabled := 0
    image_width_edit.Value := main_preview_picture_frame["actual_w"]
    image_height_edit.Enabled := 0
    image_height_updown.Enabled := 0
    image_height_edit.Value := main_preview_picture_frame["actual_h"]
  }
}

;--------------------------------------------------
;image prompt
;--------------------------------------------------

image_prompt_picture.OnEvent("ContextMenu", image_prompt_picture_contextmenu)
image_prompt_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, image_prompt_picture_menu_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, image_prompt_picture_menu_horde_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), image_prompt_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), image_prompt_picture_menu_horde_output_file)
  }

  image_prompt_picture_menu.Show()
}

;image_prompt - input file
;--------------------------------------------------
image_prompt_picture_menu_file(ItemName, ItemPos, MyMenu) {
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(inputs[ItemName], image_prompt_picture_frame)) {
    inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;image_prompt - output file
;--------------------------------------------------
image_prompt_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(output_folder ItemName, image_prompt_picture_frame)) {
	inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;image_prompt - clipboard
;--------------------------------------------------
image_prompt_picture_menu_clipboard(*) {
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit_clipboard(image_prompt_picture_frame)) {
    inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      ;automatically create a new row
      image_prompt_add_button_click("", "")
    }
  }
}

;image_prompt - remove
;--------------------------------------------------
image_prompt_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (inputs.Has(image_prompt_picture_frame["name"])) {
    inputs.Delete(image_prompt_picture_frame["name"])
  }

  image_prompt_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  picture_fit_to_frame(image_prompt_picture_frame["w"], image_prompt_picture_frame["h"], image_prompt_picture_frame)

  image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
  if (image_prompt_current) {
    image_prompt_active_listview.Modify(image_prompt_current, "Vis", "")
  }
}

;image_prompt - horde input file
;--------------------------------------------------
image_prompt_picture_menu_horde_file(ItemName, ItemPos, MyMenu) {
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], image_prompt_picture_frame)) {
    inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;image_prompt - horde output file
;--------------------------------------------------
image_prompt_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, image_prompt_picture_frame)) {
	inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;image_prompt - drop
;--------------------------------------------------
image_prompt.OnEvent("DropFiles", image_prompt_dropfiles)
image_prompt_dropfiles(GuiObj, GuiCtrlObj, FileArray, X, Y) {
  if (GuiCtrlObj = image_prompt_picture) {
    if (image_prompt_picture_frame["name"] = "") {
      image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
    }
    if (valid_file := image_load_and_fit(FileArray[1], image_prompt_picture_frame)) {
      inputs[image_prompt_picture_frame["name"]] := valid_file

      image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
      if (image_prompt_current) {
        image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
        image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
      }
      else {
        image_prompt_add_button_click("", "")
      }
    }
  }
}

;image_prompt - misc
;--------------------------------------------------
image_prompt_check_for_free_index() {
  loop {
    if (inputs.Has("image_prompt_" A_Index)) {
      continue
    }
    else {
      return "image_prompt_" A_Index
    }
  }
}

;--------------------------------------------------
;mask
;--------------------------------------------------
mask_picture.OnEvent("ContextMenu", mask_picture_contextmenu)
mask_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, mask_picture_menu_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, mask_picture_menu_horde_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), mask_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), mask_picture_menu_horde_output_file)
  }

  mask_picture_menu.Show()
}

;mask - input file
;--------------------------------------------------
mask_picture_menu_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(inputs[ItemName], mask_picture_frame)) {
    inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;mask - output file
;--------------------------------------------------
mask_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(output_folder ItemName, mask_picture_frame)) {
	inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;mask - clipboard
;--------------------------------------------------
mask_picture_menu_clipboard(*) {
  if (valid_file := image_load_and_fit_clipboard(mask_picture_frame)) {
    inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;mask - preview
;--------------------------------------------------
mask_picture_menu_preview(ItemName, ItemPos, MyMenu) {
  preview_sidejob(mask_picture_frame)
}

;mask - remove
;--------------------------------------------------
mask_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (inputs.Has(mask_picture_frame["name"])) {
    inputs.Delete(mask_picture_frame["name"])
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
  mask_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  picture_fit_to_frame(mask_picture_frame["w"], mask_picture_frame["h"], mask_picture_frame)
}

;mask - horde input file
;--------------------------------------------------
mask_picture_menu_horde_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], mask_picture_frame)) {
    inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;mask - horde output file
;--------------------------------------------------
mask_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, mask_picture_frame)) {
	inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;--------------------------------------------------
;controlnet
;--------------------------------------------------

;for controlnet, picture frame's "name" is changed as needed
;ie. it becomes "controlnet_1" when the first image is selected
controlnet_picture.OnEvent("ContextMenu", controlnet_picture_contextmenu)
controlnet_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, controlnet_picture_menu_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, controlnet_picture_menu_horde_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), controlnet_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), controlnet_picture_menu_horde_output_file)
  }

  controlnet_picture_menu.Show()
}

;controlnet - input file
;--------------------------------------------------
controlnet_picture_menu_file(ItemName, ItemPos, MyMenu) {
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(inputs[ItemName], controlnet_picture_frame)) {
    inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;controlnet - output file
;--------------------------------------------------
controlnet_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(output_folder ItemName, controlnet_picture_frame)) {
	inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;controlnet - clipboard
;--------------------------------------------------
controlnet_picture_menu_clipboard(*) {
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit_clipboard(controlnet_picture_frame)) {
    inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      ;automatically create a new row
      controlnet_add_button_click("", "")
    }
  }
}

;controlnet - horde output file
;--------------------------------------------------
controlnet_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, controlnet_picture_frame)) {
	inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;controlnet - preview
;--------------------------------------------------
controlnet_picture_menu_preview(ItemName, ItemPos, MyMenu) {
  preview_sidejob(controlnet_picture_frame)
}

;controlnet - remove
;--------------------------------------------------
controlnet_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (inputs.Has(controlnet_picture_frame["name"])) {
    inputs.Delete(controlnet_picture_frame["name"])
    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
      controlnet_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(controlnet_preview_picture_frame["w"], controlnet_preview_picture_frame["h"], controlnet_preview_picture_frame)
    }
  }

  controlnet_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  picture_fit_to_frame(controlnet_picture_frame["w"], controlnet_picture_frame["h"], controlnet_picture_frame)

  controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
  if (controlnet_current) {
    controlnet_active_listview.Modify(controlnet_current, "Vis", "")
  }
}

;controlnet - horde input file
;--------------------------------------------------
controlnet_picture_menu_horde_file(ItemName, ItemPos, MyMenu) {
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], controlnet_picture_frame)) {
    inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;controlnet (& mask) - drop
;--------------------------------------------------
mask_and_controlnet.OnEvent("DropFiles", mask_and_controlnet_dropfiles)
mask_and_controlnet_dropfiles(GuiObj, GuiCtrlObj, FileArray, X, Y) {
  switch GuiCtrlObj {
    case mask_picture:
      if (valid_file := image_load_and_fit(FileArray[1], mask_picture_frame)) {
        inputs[mask_picture_frame["name"]] := valid_file
        if (preview_images.Has("mask")) {
          preview_images.Delete("mask")
          mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
          picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
        }
      }
    case controlnet_picture:
      if (controlnet_picture_frame["name"] = "") {
        controlnet_picture_frame["name"] := controlnet_check_for_free_index()
      }
      if (valid_file := image_load_and_fit(FileArray[1], controlnet_picture_frame)) {
        inputs[controlnet_picture_frame["name"]] := valid_file

        if (preview_images.Has(controlnet_picture_frame["name"])) {
          preview_images.Delete(controlnet_picture_frame["name"])
        }

        controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
        if (controlnet_current) {
          controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
          controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
        }
        else {
          controlnet_add_button_click("", "")
        }
      }
    ;default:
  }
}

;controlnet - misc
;--------------------------------------------------
controlnet_check_for_free_index() {
  loop {
    if (inputs.Has("controlnet_" A_Index)) {
      continue
    }
    else {
      return "controlnet_" A_Index
    }
  }
}

;--------------------------------------------------
;output images
;--------------------------------------------------
output_picture.OnEvent("ContextMenu", output_picture_menu_contextmenu)
output_picture_menu_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  output_picture_menu.Show()
}

output_listview.OnEvent("ContextMenu", output_picture_menu_contextmenu)

;output images - to source
;--------------------------------------------------
output_picture_menu_to_source(ItemName, ItemPos, MyMenu) {
  if (assistant_status = "painting" or !last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(last_selected_output_image, main_preview_picture_frame)) {
      inputs[main_preview_picture_frame["name"]] := valid_file
      main_preview_picture_update(0)
    }
  }
}

;output images - to image prompt
;--------------------------------------------------
output_picture_menu_to_image_prompt(ItemName, ItemPos, MyMenu) {
  if (!last_selected_output_image) {
    return
  }
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(last_selected_output_image, image_prompt_picture_frame)) {
    inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;output images - to mask
;--------------------------------------------------
output_picture_menu_to_mask(ItemName, ItemPos, MyMenu) {
  if (!last_selected_output_image) {
    return
  }
  else if (valid_file := image_load_and_fit(last_selected_output_image, mask_picture_frame)) {
    inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;output images - to controlnet
;--------------------------------------------------
output_picture_menu_to_controlnet(ItemName, ItemPos, MyMenu) {
  if (!last_selected_output_image) {
    return
  }
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(last_selected_output_image, controlnet_picture_frame)) {
    inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;output images - to horde source
;--------------------------------------------------
output_picture_menu_to_horde_source(ItemName, ItemPos, MyMenu) {
  if (!last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(last_selected_output_image, horde_source_picture_frame)) {
      horde_inputs[horde_source_picture_frame["name"]] := valid_file
      horde_source_picture_update(0)
    }
  }
}

;output images - to horde mask
;--------------------------------------------------
output_picture_menu_to_horde_mask(ItemName, ItemPos, MyMenu) {
  if (!last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(last_selected_output_image, horde_mask_picture_frame)) {
      horde_inputs[horde_mask_picture_frame["name"]] := valid_file
    }
  }
}

;output images - copy
;--------------------------------------------------
output_picture_menu_copy(*) {
  try {
    Gdip_SetBitmapToClipboard(pBitmap := Gdip_CreateBitmapFromFile(last_selected_output_image))
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
  finally {
    if (IsSet(pBitmap)) {
      try {
        Gdip_DisposeImage(pBitmap)
      }
    }
  }
}

;--------------------------------------------------
;status box
;--------------------------------------------------
status_picture.OnEvent("ContextMenu", status_picture_contextmenu)
status_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  status_picture_menu.Show()
}

connect_menu(ItemName, ItemPos, MyMenu) {
  if (server_address = "" and horde_address = "") {
    status_text.Text := "No Servers Selected"
  }
  if (server_address != "") {
    connect_to_server()
  }
  if (horde_address != "") {
    connect_to_horde()
  }
}

show_settings(*) {
  settings_window.Show("w300 x" A_ScreenWidth - 600 " y" A_ScreenHeight - 400)
}

switch_tab_menu(ItemName, ItemPos, MyMenu) {
  switch ItemName {
    case "ComfyUI":
      overlay_tab_change("comfy")
    case "Horde":
      overlay_tab_change("horde")
  }
}

;--------------------------------------------------
;settings window
;--------------------------------------------------

server_connect_button.OnEvent("Click", server_connect_button_click)
server_connect_button_click(GuiCtrlObj, Info) {
  global server_address := server_address_edit.Text
  connect_to_server()
}

horde_connect_button.OnEvent("Click", horde_connect_button_click)
horde_connect_button_click(GuiCtrlObj, Info) {
  global horde_address := horde_address_edit.Text
  connect_to_horde()
}

horde_api_apply_button.OnEvent("Click", horde_api_apply_button_click)
horde_api_apply_button_click(GuiCtrlObj, Info) {
  global horde_api_key := horde_api_key_edit.Value = "" ? "0000000000" : horde_api_key_edit.Value
}

horde_use_specific_worker_button.OnEvent("Click", horde_use_specific_worker_button_click)
horde_use_specific_worker_button_click(GuiCtrlObj, Info) {
  global horde_use_specific_worker := horde_use_specific_worker_edit.Value
}

save_settings_button.OnEvent("Click", save_settings_button_click)
save_settings_button_click(GuiCtrlObj, Info) {
  try {
    if (!FileExist("settings.ini")) {
      FileCopy("settings.ini.example", "settings.ini")
    }
    IniWrite(server_address_edit.Text, "settings.ini", "settings", "default_server_address")
    IniWrite(horde_address_edit.Text, "settings.ini", "settings", "horde_default_server_address")
    IniWrite(horde_api_key_edit.Text, "settings.ini", "settings", "horde_api_key")
    IniWrite(horde_use_specific_worker_edit.Text, "settings.ini", "settings", "horde_use_specific_worker")
    IniWrite(horde_allow_nsfw_checkbox.Value, "settings.ini", "settings", "horde_allow_nsfw")
    IniWrite(horde_replacement_filter_checkbox.Value, "settings.ini", "settings", "horde_replacement_filter")
    IniWrite(horde_allow_untrusted_workers_checkbox.Value, "settings.ini", "settings", "horde_allow_untrusted_workers")
    IniWrite(horde_allow_slow_workers_checkbox.Value, "settings.ini", "settings", "horde_allow_slow_workers")
    IniWrite(horde_share_with_laion_checkbox.Value, "settings.ini", "settings", "horde_share_with_laion")
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

open_settings_file_button.OnEvent("Click", open_settings_file_button_click)
open_settings_file_button_click(GuiCtrlObj, Info) {
  overlay_hide()
  try {
    if (!FileExist("settings.ini")) {
      FileCopy("settings.ini.example", "settings.ini")
    }
    Run "Notepad settings.ini"
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;--------------------------------------------------
;--------------------------------------------------
;horde
;--------------------------------------------------
;--------------------------------------------------

;fallback defaults
horde_batch_size_values := Map(
  "default", 1
  ,"minimum", 1
  ,"maximum", 20
)

horde_clip_skip_values := Map(
  "default", 1
  ,"minimum", 1
  ,"maximum", 12
)

horde_step_count_values := Map(
  "default", 30
  ,"minimum", 1
  ,"maximum", 500
)

horde_cfg_values := Map(
  "default", "7.5"
  ,"minimum", "0.0"
  ,"maximum", "100.0"
  ,"multipleOf", 0.5
  ,"dp", 1
)

horde_image_width_values := Map(
  "default", 512
  ,"minimum", 64
  ,"maximum", 3072
  ,"multipleOf", 64
  ,"dp", 0
)

horde_image_height_values := Map(
  "default", 512
  ,"minimum", 64
  ,"maximum", 3072
  ,"multipleOf", 64
  ,"dp", 0
)

horde_denoise_values := Map(
  "default", "1.00"
  ,"minimum", "0.01"
  ,"maximum", "1.00"
  ,"multipleOf", 0.01
  ,"dp", 2
)

horde_seed_variation_values := Map(
  "default", 1
  ,"minimum", 1
  ,"maximum", 1000
)

horde_facefixer_strength_values := Map(
  "default", "0.75"
  ,"minimum", "0.00"
  ,"maximum", "1.00"
  ,"multipleOf", 0.01
  ,"dp", 2
)

horde_lora_strength_values := Map(
  "default", "1.00"
  ,"minimum", "-5.00"
  ,"maximum", "5.00"
  ,"multipleOf", 0.01
  ,"dp", 2
)

horde_lora_inject_trigger_values := Map(
  "maxLength", "30"
)

horde_textual_inversion_strength_values := Map(
  "default", "1.00"
  ,"minimum", "-5.00"
  ,"maximum", "5.00"
  ,"multipleOf", 0.01
  ,"dp", 2
)

;--------------------------------------------------
;--------------------------------------------------
;horde gui's
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;horde main controls
;--------------------------------------------------

horde_main_controls := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Main Controls (Horde)")
horde_main_controls.MarginX := 0
horde_main_controls.MarginY := 0
horde_main_controls.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde image count
horde_batch_size_edit := horde_main_controls.Add("Edit", "x0 y" gap_y " w60 r1 Background" control_colour " Center Number Limit2")
horde_batch_size_updown := horde_main_controls.Add("UpDown", "Range0-" horde_batch_size_values["maximum"] " 0x80", 0)

;horde checkpoint
horde_batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_checkpoint_combobox := horde_main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w" A_ScreenWidth / 5 " Background" control_colour)

;horde sampler
horde_checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_sampler_combobox := horde_main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

;horde clip skip
horde_sampler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_clip_skip_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit2")
horde_clip_skip_updown := horde_main_controls.Add("UpDown", "Range0-" horde_clip_skip_values["maximum"] " 0x80", 0)

;horde karras
horde_clip_skip_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_main_controls.SetFont("c" label_colour " q3", label_font)
horde_karras_checkbox := horde_main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y0 Checked", "Karras")
horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)
;get specific value
horde_karras_checkbox.GetPos(,,, &horde_karras_checkbox_h)
horde_karras_checkbox.Move(, stored_gui_y + stored_gui_h / 2 - horde_karras_checkbox_h / 2,,)

;horde hires fix
horde_karras_checkbox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_main_controls.SetFont("c" label_colour " q3", label_font)
horde_hires_fix_checkbox := horde_main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y, "Hires Fix")
horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde tiling
horde_hires_fix_checkbox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_main_controls.SetFont("c" label_colour " q3", label_font)
horde_tiling_checkbox := horde_main_controls.Add("CheckBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " Disabled", "Tiling")
horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde prompt (positive)
horde_batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_prompt_positive_edit := horde_main_controls.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenWidth / 4 " r5 Background" control_colour)

;horde prompt (negative)
horde_prompt_positive_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_prompt_negative_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_y " y" stored_gui_y " w" A_ScreenWidth / 4 " r5 Background" control_colour)

;horde seed
horde_prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_seed_edit := horde_main_controls.Add("Edit", "x" stored_gui_x +stored_gui_w + gap_x " y" stored_gui_y " w200 r1 Background" control_colour " Center", 0)
horde_seed_updown := horde_main_controls.Add("UpDown", "Range0-1 0x80 -2")

;horde random seed
horde_seed_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_main_controls.SetFont("c" label_colour " q3", label_font)
horde_random_seed_checkbox := horde_main_controls.Add("CheckBox", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1, "Random")
horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde seed variation
horde_seed_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_seed_variation_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + 1 " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit5 Hidden")
horde_seed_variation_updown := horde_main_controls.Add("UpDown", "Range0-" horde_seed_variation_values["maximum"] " 0x80 Hidden", 0)

;horde steps
horde_prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_step_count_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + gap_x " y0 w75 r1 Background" control_colour " Center Number Limit5")
;get specific value
horde_step_count_edit.GetPos(,,, &horde_step_count_edit_h)
horde_step_count_edit.Move(, stored_gui_y + stored_gui_h - horde_step_count_edit_h,,)
horde_step_count_updown := horde_main_controls.Add("UpDown", "Range0-" horde_step_count_values["maximum"] " 0x80", 0)

;horde cfg
horde_step_count_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_cfg_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "0.0")
horde_cfg_updown := horde_main_controls.Add("UpDown", "Range0-1 0x80 -2", 0)

;horde denoise
horde_cfg_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_denoise_edit := horde_main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w75 r1 Background" control_colour " Center Limit6", "0.00")
horde_denoise_updown := horde_main_controls.Add("UpDown", "Range0-1 0x80 -2", 0)

;--------------------------------------------------
;horde input images
;--------------------------------------------------

horde_image_input := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Image Inputs (Horde)")
horde_image_input.MarginX := 0
horde_image_input.MarginY := 0
horde_image_input.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_image_input.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde controlnet
horde_controlnet_type_combobox := horde_image_input.Add("ComboBox", "x0 y" gap_y " w" A_ScreenWidth / 10 " Background" control_colour " Hidden")

horde_controlnet_type_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_controlnet_option_dropdownlist := horde_image_input.Add("DropDownList", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w200 Background" control_colour " Choose1 Disabled Hidden", ["Image to ControlNet", "Image as ControlNet", "Return Control as Output"])

;source & mask pictures
horde_controlnet_type_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_source_picture := horde_image_input.Add("Picture", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w240 h240", "stuff\placeholder_pixel.bmp")

horde_source_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_mask_picture := horde_image_input.Add("Picture", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w240 h240", "stuff\placeholder_pixel.bmp")

;horde image width & height
horde_source_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_image_width_edit := horde_image_input.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w75 r1 Background" control_colour " Center Number Limit4", "512")
horde_image_width_updown := horde_image_input.Add("UpDown", "Range0-1 0x80 -2", 0)

horde_image_width_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_image_height_edit := horde_image_input.Add("Edit", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + 1 " y" stored_gui_y " w75 r1 Background" control_colour " Center Number Limit4", "512")
horde_image_height_updown := horde_image_input.Add("UpDown", "Range0-1 0x80 -2", 0)

;horde source image dimensions button
horde_image_height_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_copy_source_dimensions_button := horde_image_input.Add("Button", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_y  " y" stored_gui_y " h" stored_gui_h " Background" background_colour " Hidden", "Source Dimensions")

;--------------------------------------------------
;horde post-processing
;--------------------------------------------------

horde_post_processing := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Post-Processing (Horde)")
horde_post_processing.MarginX := 0
horde_post_processing.MarginY := 0
horde_post_processing.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_post_processing.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde post-processing list
horde_post_process_active_listview := horde_post_processing.Add("ListView", "x0 y" gap_y " w" A_ScreenWidth / 5 " r8 Background" control_colour " Checked -Multi -Hdr", ["Post-Processing"])
horde_post_process_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
Loop 9 {
  horde_post_process_active_listview.Add(,"")
}
horde_post_process_active_listview.ModifyCol(1, "AutoHdr")
horde_post_process_active_listview.Delete

horde_post_process_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_post_process_order_updown := horde_post_processing.Add("UpDown", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " h" stored_gui_h " Range0-1 0x80 -16", 0)

;horde facefixer strength
horde_post_process_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_facefixer_strength_edit := horde_post_processing.Add("Edit", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + gap_y " w75 r1 Background" control_colour " Center Limit6 Hidden", "0.00")
horde_facefixer_strength_updown := horde_post_processing.Add("UpDown", "Range0-1 0x80 -2 Hidden", 0)

;--------------------------------------------------
;horde loras
;--------------------------------------------------

horde_lora_selection := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "LORAs (Horde)")
horde_lora_selection.MarginX := 0
horde_lora_selection.MarginY := 0
horde_lora_selection.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_lora_selection.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde lora name
;--------------------------------------------------
horde_lora_available_combobox := horde_lora_selection.Add("ComboBox", "x0 y0 w" A_ScreenWidth / 5 - 1 " Background" control_colour " Choose1", ["None"])

;horde lora strength
horde_lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_lora_strength_edit := horde_lora_selection.Add("Edit", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w" 100 " r1 Background" control_colour " Center Limit6", horde_lora_strength_values["default"])
horde_lora_strength_updown := horde_lora_selection.Add("UpDown", "Range0-1 0x80 -2", 0)

;horde active loras
;--------------------------------------------------
horde_lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_lora_active_listview := horde_lora_selection.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" A_ScreenWidth / 5 + 100 " r5 Background" control_colour " -Multi", ["LORA", "Strength"])

horde_lora_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
Loop 6 {
  horde_lora_active_listview.Add(,"")
}
horde_lora_active_listview.ModifyCol(1, stored_gui_w - 100)
horde_lora_active_listview.ModifyCol(2, "AutoHdr Float")
horde_lora_active_listview.InsertCol(3, 0, "Inject Trigger")
horde_lora_active_listview.Delete
horde_lora_active_listview.Add(,"None", horde_lora_strength_values["default"])

;horde lora add/remove buttons
;--------------------------------------------------
horde_lora_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_lora_remove_button := horde_lora_selection.Add("Button", "x0 y" stored_gui_y + stored_gui_h + 1 " h" edit_default_h " Background" background_colour, "Remove")
;get specific value
horde_lora_remove_button.GetPos(&horde_lora_remove_button_x, &horde_lora_remove_button_y, &horde_lora_remove_button_w, &horde_lora_remove_button_h)
horde_lora_remove_button.Move(stored_gui_x + stored_gui_w - horde_lora_remove_button_w,,,)

horde_lora_remove_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_lora_add_button := horde_lora_selection.Add("Button", "x" stored_gui_x - 1 - stored_gui_w " y" stored_gui_y " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Add")

;horde lora inject trigger
;--------------------------------------------------
horde_lora_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;reuse remove button's location
horde_lora_inject_trigger_edit := horde_lora_selection.Add("Edit", "x" stored_gui_x " y" horde_lora_remove_button_y + horde_lora_remove_button_h + 1 " w" stored_gui_w " r1 Background" control_colour " Limit" horde_lora_inject_trigger_values["maxLength"])

;--------------------------------------------------
;horde textual inversions
;--------------------------------------------------

horde_textual_inversion_selection := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Textual Inversions (Horde)")
horde_textual_inversion_selection.MarginX := 0
horde_textual_inversion_selection.MarginY := 0
horde_textual_inversion_selection.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_textual_inversion_selection.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde ti name
;--------------------------------------------------
horde_textual_inversion_available_combobox := horde_textual_inversion_selection.Add("ComboBox", "x0 y0 w" A_ScreenWidth / 5 - 102 " Background" control_colour " Choose1", ["None"])

;horde ti inject field
;--------------------------------------------------
horde_textual_inversion_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_textual_inversion_inject_field_dropdownlist := horde_textual_inversion_selection.Add("DropDownList", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w100 Background" control_colour " Choose1", ["Positive", "Negative", "Manual"])

;horde ti strength
horde_textual_inversion_inject_field_dropdownlist.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_textual_inversion_strength_edit := horde_textual_inversion_selection.Add("Edit", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w100 r1 Background" control_colour " Center Limit6", horde_textual_inversion_strength_values["default"])
horde_textual_inversion_strength_updown := horde_textual_inversion_selection.Add("UpDown", "Range0-1 0x80 -2", 0)

;horde active tis
;--------------------------------------------------
horde_textual_inversion_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_textual_inversion_active_listview := horde_textual_inversion_selection.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" A_ScreenWidth / 5 + 100 " r5 Background" control_colour " -Multi", ["Textual Inversion", "Field", "Strength"])

horde_textual_inversion_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
Loop 6 {
  horde_textual_inversion_active_listview.Add(,"")
}
horde_textual_inversion_active_listview.ModifyCol(1, stored_gui_w - 202)
horde_textual_inversion_active_listview.ModifyCol(2, 101)
horde_textual_inversion_active_listview.ModifyCol(3, "Float AutoHdr")

horde_textual_inversion_active_listview.Delete
horde_textual_inversion_active_listview.Add(,"None", "Positive", horde_textual_inversion_strength_values["default"])

;horde ti add/remove buttons
;--------------------------------------------------
horde_textual_inversion_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_textual_inversion_remove_button := horde_textual_inversion_selection.Add("Button", "x0 y" stored_gui_y + stored_gui_h + 1 " h" edit_default_h " Background" background_colour, "Remove")
;get specific value
horde_textual_inversion_remove_button.GetPos(&horde_textual_inversion_remove_button_x, &horde_textual_inversion_remove_button_y, &horde_textual_inversion_remove_button_w, &horde_textual_inversion_remove_button_h)
horde_textual_inversion_remove_button.Move(stored_gui_x + stored_gui_w - horde_textual_inversion_remove_button_w,,,)

horde_textual_inversion_remove_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_textual_inversion_add_button := horde_textual_inversion_selection.Add("Button", "x" stored_gui_x - 1 - stored_gui_w " y" stored_gui_y " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Add")

;--------------------------------------------------
;horde generations
;--------------------------------------------------

horde_generate := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "Generation (Horde)")
horde_generate.MarginX := 0
horde_generate.MarginY := 0
horde_generate.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_generate.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde job list
;--------------------------------------------------
horde_generation_status_listview := horde_generate.Add("ListView", "x0 y0 w" A_ScreenWidth / 5 * 2 " r20 Background" control_colour " -Multi", ["ID", "Finished", "Processing", "Restarted", "Waiting", "Done", "Faulted", "ETA", "Queue", "Kudos", "Possible", "Status"])

horde_generation_status_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
Loop 21 {
  horde_generation_status_listview.Add(,"")
}
horde_generation_status_listview.ModifyCol(1, A_ScreenWidth / 5)
horde_generation_status_listview.ModifyCol(2, "0  Integer")
horde_generation_status_listview.ModifyCol(3, "0 Integer")
horde_generation_status_listview.ModifyCol(4, "0 Integer")
horde_generation_status_listview.ModifyCol(5, "0 Integer")
horde_generation_status_listview.ModifyCol(6, "0 Integer")
horde_generation_status_listview.ModifyCol(7, "0 Integer")
horde_generation_status_listview.ModifyCol(8, "75 Integer")
horde_generation_status_listview.ModifyCol(9, "75 Integer")
horde_generation_status_listview.ModifyCol(10, "0 Integer")
horde_generation_status_listview.ModifyCol(11, "0 Integer")
horde_generation_status_listview.ModifyCol(12, "AutoHdr")
horde_generation_status_listview.Delete

horde_generate.SetFont("s" label_size " c" label_colour " q3", label_font)
kudos_text := horde_generate.Add("Text", "x" stored_gui_x + stored_gui_w * 3 / 4 " y" stored_gui_y + stored_gui_h + 1 " w" stored_gui_w / 4 " r5 Right")
horde_generate.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde generate button
;--------------------------------------------------
horde_generation_status_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_generate_button := horde_generate.Add("Button", "x" stored_gui_x + stored_gui_w / 2 - 50 " y" stored_gui_y + stored_gui_h + gap_y " w100 Background" background_colour, "Paint")

;--------------------------------------------------
;horde output images
;--------------------------------------------------

horde_output_viewer := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "horde_output Viewer")
horde_output_viewer.MarginX := 0
horde_output_viewer.MarginY := 0
horde_output_viewer.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
horde_output_viewer.SetFont("s" text_size " c" text_colour " q0", text_font)

;horde output picture
;--------------------------------------------------
horde_output_picture := horde_output_viewer.Add("Picture", "x0 y0 w240 h240", "stuff\placeholder_pixel.bmp")

;horde output list
;--------------------------------------------------
horde_output_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
horde_output_listview := horde_output_viewer.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" stored_gui_w " h" A_ScreenHeight / 3 " Background" control_colour " -Multi SortDesc Count50", ["File Name", "Output Images"])

horde_output_listview.Opt("-Redraw")
Loop 50 {
  horde_output_listview.Add(,"")
}
horde_output_listview.ModifyCol(1, 0)
horde_output_listview.ModifyCol(2, "Integer Left AutoHdr")
horde_output_listview.Delete()
horde_output_listview.Opt("+Redraw")

;horde output clear list button
;--------------------------------------------------
horde_output_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
clear_horde_outputs_list_button := horde_output_viewer.Add("Button", "x" stored_gui_w / 2 - 60 " y" stored_gui_y + stored_gui_h + 1 " w120 Background" background_colour, "Clear List")

;--------------------------------------------------
;horde labels
;--------------------------------------------------

if (show_labels) {
  ;horde main controls
  ;--------------------------------------------------
  horde_main_controls.SetFont("s" label_size " c" label_colour " q3", label_font)

  horde_batch_size_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_batch_size_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Images")

  horde_checkpoint_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_checkpoint_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Checkpoint")

  horde_sampler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_sampler_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Sampler")

  horde_clip_skip_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_clip_skip_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CLIP Skip")

  horde_prompt_positive_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_prompt_positive_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Prompt (+)")

  horde_prompt_negative_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_prompt_negative_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Prompt (-)")

  horde_seed_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_seed_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Seed")

  ;horde_seed_variation_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  ;horde_seed_variation_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Variation")

  horde_step_count_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_step_count_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Steps")

  horde_cfg_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_cfg_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CFG")

  horde_denoise_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_denoise_label := horde_main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Denoising")

  horde_main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;horde input images
  ;--------------------------------------------------
  horde_image_input.SetFont("s" label_size " c" label_colour " q3", label_font)

  horde_controlnet_type_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_controlnet_type_label := horde_image_input.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h " Hidden", "ControlNet")

  horde_source_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_source_label := horde_image_input.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Source Image")

  horde_mask_picture.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_mask_label := horde_image_input.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Mask")

  horde_image_width_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_image_width_label := horde_image_input.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Width")

  horde_image_height_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_image_height_label := horde_image_input.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Height")

  horde_image_input.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;horde post-processing
  ;--------------------------------------------------
  horde_post_processing.SetFont("s" label_size " c" label_colour " q3", label_font)

  horde_post_process_active_listview.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_post_process_active_label := horde_post_processing.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Post-Processing")

  horde_facefixer_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_facefixer_strength_label := horde_post_processing.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h " Hidden", "Facefixer Strength")

  horde_post_processing.SetFont("s" text_size " c" text_colour " q0", text_font)

  ;horde loras
  ;--------------------------------------------------
  horde_lora_selection.SetFont("s" label_size " c" label_colour " q3", label_font)

  horde_lora_inject_trigger_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  horde_lora_inject_trigger_label := horde_lora_selection.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Inject Trigger")

  horde_lora_selection.SetFont("s" text_size " c" text_colour " q0", text_font)
}

;--------------------------------------------------
;--------------------------------------------------
;horde menus and picture frames
;--------------------------------------------------
;--------------------------------------------------

;the submenu horde_outputs_existing_images_menu is created with the non-horde menus
;horde_outputs_existing_images_menu := Menu()

;horde source
;--------------------------------------------------
horde_source_picture_menu := Menu()
horde_source_picture_menu.Add("Inputs", inputs_existing_images_menu)
horde_source_picture_menu.Add("Outputs", outputs_existing_images_menu)
horde_source_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
horde_source_picture_menu.Add("Clipboard", horde_source_picture_menu_clipboard)
horde_source_picture_menu.Add()
horde_source_picture_menu.Add("Remove", horde_source_picture_menu_remove)

;horde mask
;--------------------------------------------------
horde_mask_picture_menu := Menu()
horde_mask_picture_menu.Add("Inputs", inputs_existing_images_menu)
horde_mask_picture_menu.Add("Outputs", outputs_existing_images_menu)
horde_mask_picture_menu.Add("Outputs (Horde)", horde_outputs_existing_images_menu)
horde_mask_picture_menu.Add("Clipboard", horde_mask_picture_menu_clipboard)
horde_mask_picture_menu.Add()
horde_mask_picture_menu.Add("Remove", horde_mask_picture_menu_remove)

;horde output images
;--------------------------------------------------
horde_output_picture_menu := Menu()
horde_output_picture_menu.Add("Send to Source", horde_output_picture_menu_to_source)
horde_output_picture_menu.Add("Send to Image Prompt", horde_output_picture_menu_to_image_prompt)
horde_output_picture_menu.Add("Send to Mask", horde_output_picture_menu_to_mask)
horde_output_picture_menu.Add("Send to ControlNet", horde_output_picture_menu_to_controlnet)
horde_output_picture_menu.Add()
horde_output_picture_menu.Add("Send to Source (Horde)", horde_output_picture_menu_to_horde_source)
horde_output_picture_menu.Add("Send to Mask (Horde)", horde_output_picture_menu_to_horde_mask)
horde_output_picture_menu.Add()
horde_output_picture_menu.Add("Copy", horde_output_picture_menu_copy)

;horde job list
;--------------------------------------------------
horde_generation_status_listview_menu := Menu()
horde_generation_status_listview_menu.Add("Salvage", horde_generation_status_listview_menu_salvage_job)
horde_generation_status_listview_menu.Add("Cancel", horde_generation_status_listview_menu_cancel_job)
horde_generation_status_listview_menu.Add()
horde_generation_status_listview_menu.Add("Clear Finished Jobs", horde_generation_status_listview_menu_clear_finished_jobs)

;horde picture frames
;--------------------------------------------------
horde_source_picture_frame := create_picture_frame("horde_source", horde_source_picture)
horde_mask_picture_frame := create_picture_frame("horde_mask", horde_mask_picture)
horde_output_picture_frame := create_picture_frame("horde_output", horde_output_picture)

;--------------------------------------------------
;--------------------------------------------------
;horde gui controls
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;horde main controls
;--------------------------------------------------

;horde image count
horde_batch_size_edit.OnEvent("LoseFocus", horde_batch_size_edit_losefocus)
horde_batch_size_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_batch_size_values["default"], horde_batch_size_values["minimum"], horde_batch_size_values["maximum"], GuiCtrlObj)
}

;horde clip skip
horde_clip_skip_edit.OnEvent("LoseFocus", horde_clip_skip_edit_losefocus)
horde_clip_skip_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_clip_skip_values["default"], horde_clip_skip_values["minimum"], horde_clip_skip_values["maximum"], GuiCtrlObj)
}

;horde seed
horde_seed_updown.OnEvent("Change", horde_seed_updown_change)
horde_seed_updown_change(GuiCtrlObj, Info) {
  number_update(0, 0, 4294967295, 1, 0, horde_seed_edit, Info)
}

;horde random seed
horde_random_seed_checkbox.OnEvent("Click", horde_random_seed_checkbox_click)
horde_random_seed_checkbox_click(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Value){
    horde_seed_edit.Opt("+ReadOnly")
    horde_seed_updown.Enabled := 0
    horde_seed_edit.SetFont("c" control_colour)
  }
  else {
    horde_seed_edit.Opt("-ReadOnly")
    horde_seed_updown.Enabled := 1
    horde_seed_edit.SetFont("c" text_colour)
  }
}

;horde seed variation
horde_seed_variation_edit.OnEvent("LoseFocus", horde_seed_variation_edit_losefocus)
horde_seed_variation_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_seed_variation_values["default"], horde_seed_variation_values["minimum"], horde_seed_variation_values["maximum"], GuiCtrlObj)
}

;horde steps
horde_step_count_edit.OnEvent("LoseFocus", horde_step_count_edit_losefocus)
horde_step_count_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_step_count_values["default"], horde_step_count_values["minimum"], horde_step_count_values["maximum"], GuiCtrlObj)
}

;horde cfg
horde_cfg_updown.OnEvent("Change", horde_cfg_updown_change)
horde_cfg_updown_change(GuiCtrlObj, Info) {
  number_update(horde_cfg_values["default"], horde_cfg_values["minimum"], horde_cfg_values["maximum"], horde_cfg_values["multipleOf"], horde_cfg_values["dp"], horde_cfg_edit, Info)
}

horde_cfg_edit.OnEvent("LoseFocus", horde_cfg_edit_losefocus)
horde_cfg_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_cfg_values["default"], horde_cfg_values["minimum"], horde_cfg_values["maximum"], GuiCtrlObj)
}

;horde denoise
horde_denoise_updown.OnEvent("Change", horde_denoise_updown_change)
horde_denoise_updown_change(GuiCtrlObj, Info) {
  number_update(horde_denoise_values["default"], horde_denoise_values["minimum"], horde_denoise_values["maximum"], horde_denoise_values["multipleOf"], horde_denoise_values["dp"], horde_denoise_edit, Info)
}

horde_denoise_edit.OnEvent("LoseFocus", horde_denoise_edit_losefocus)
horde_denoise_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_denoise_values["default"], horde_denoise_values["minimum"], horde_denoise_values["maximum"], GuiCtrlObj)
}

;--------------------------------------------------
;horde input images
;--------------------------------------------------

;horde controlnet
horde_controlnet_type_combobox.OnEvent("Change", horde_controlnet_type_combobox_change)
horde_controlnet_type_combobox_change(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Text = "" or GuiCtrlObj.Text = "None") {
    horde_controlnet_option_dropdownlist.Enabled := 0
  }
  else {
    horde_controlnet_option_dropdownlist.Enabled := 1
  }
}

;horde image width
horde_image_width_updown.OnEvent("Change", horde_image_width_updown_change)
horde_image_width_updown_change(GuiCtrlObj, Info) {
  number_update(horde_image_width_values["default"], horde_image_width_values["minimum"], horde_image_width_values["maximum"], horde_image_width_values["multipleOf"], horde_image_width_values["dp"], horde_image_width_edit, Info)
}

horde_image_width_edit.OnEvent("LoseFocus", horde_image_width_edit_losefocus)
horde_image_width_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_image_width_values["default"], horde_image_width_values["minimum"], horde_image_width_values["maximum"], GuiCtrlObj)
  horde_image_width_edit.Value := integer_round(horde_image_width_edit.Value, horde_image_width_values["multipleOf"])
}

;horde image height
horde_image_height_updown.OnEvent("Change", horde_image_height_updown_change)
horde_image_height_updown_change(GuiCtrlObj, Info) {
  number_update(horde_image_height_values["default"], horde_image_height_values["minimum"], horde_image_height_values["maximum"], horde_image_height_values["multipleOf"], horde_image_height_values["dp"], horde_image_height_edit, Info)
}

horde_image_height_edit.OnEvent("LoseFocus", horde_image_height_edit_losefocus)
horde_image_height_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_image_height_values["default"], horde_image_height_values["minimum"], horde_image_height_values["maximum"], GuiCtrlObj)
  horde_image_height_edit.Value := integer_round(horde_image_height_edit.Value, horde_image_height_values["multipleOf"])
}

;horde source image dimensions button
horde_copy_source_dimensions_button.OnEvent("Click", horde_copy_source_dimensions_button_click)
horde_copy_source_dimensions_button_click(GuiCtrlObj, Info) {
  horde_image_width_edit.Value := integer_round(horde_source_picture_frame["actual_w"], horde_image_width_values["multipleOf"])
  horde_image_height_edit.Value := integer_round(horde_source_picture_frame["actual_h"], horde_image_height_values["multipleOf"])
}

;--------------------------------------------------
;horde post-processing
;--------------------------------------------------

;horde post-processing list
horde_post_process_active_listview.OnEvent("ItemSelect", horde_post_process_active_listview_itemselect)
horde_post_process_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  if (GuiCtrlObj.GetNext() and (GuiCtrlObj.GetText(GuiCtrlObj.GetNext()) = "GFPGAN" or GuiCtrlObj.GetText(GuiCtrlObj.GetNext()) = "CodeFormers")) {
    horde_facefixer_strength_edit.Visible := 1
    horde_facefixer_strength_updown.Visible := 1
    if (show_labels) {
      horde_facefixer_strength_label.Visible := 1
    }
  }
  else {
    horde_facefixer_strength_edit.Visible := 0
    horde_facefixer_strength_updown.Visible := 0
    if (show_labels) {
      horde_facefixer_strength_label.Visible := 0
    }
  }
}

horde_post_process_order_updown.OnEvent("Change", horde_post_process_order_updown_change)
horde_post_process_order_updown_change(GuiCtrlObj, Info) {
  if(horde_post_process_active_listview.GetNext()) {
    original_position := horde_post_process_active_listview.GetNext()
    original_value := horde_post_process_active_listview.GetText(original_position)
    original_checked := SendMessage(0x102C, original_position - 1, 0xF000, horde_post_process_active_listview) = 0x2000 ? "+Check" : "-Check"
    if (Info and original_position > 1 ) {
      horde_post_process_active_listview.Modify(original_position, SendMessage(0x102C, original_position - 2, 0xF000, horde_post_process_active_listview) = 0x2000 ? "+Check" : "-Check", horde_post_process_active_listview.GetText(original_position - 1))
      horde_post_process_active_listview.Modify(original_position - 1, "Select Vis " original_checked, original_value)
    }
    else if (!Info and original_position < horde_post_process_active_listview.GetCount()) {
      horde_post_process_active_listview.Modify(original_position, SendMessage(0x102C, original_position, 0xF000, horde_post_process_active_listview) = 0x2000 ? "+Check" : "-Check", horde_post_process_active_listview.GetText(original_position + 1))
      horde_post_process_active_listview.Modify(original_position + 1, "Select Vis " original_checked, original_value)
    }
  }
}

;horde facefixer strength
horde_facefixer_strength_updown.OnEvent("Change", horde_facefixer_strength_updown_change)
horde_facefixer_strength_updown_change(GuiCtrlObj, Info) {
  number_update(horde_facefixer_strength_values["default"], horde_facefixer_strength_values["minimum"], horde_facefixer_strength_values["maximum"], horde_facefixer_strength_values["multipleOf"], horde_facefixer_strength_values["dp"], horde_facefixer_strength_edit, Info)
}

horde_facefixer_strength_edit.OnEvent("LoseFocus", horde_facefixer_strength_edit_losefocus)
horde_facefixer_strength_edit_losefocus(GuiCtrlObj, Info) {
  number_cleanup(horde_facefixer_strength_values["default"], horde_facefixer_strength_values["minimum"], horde_facefixer_strength_values["maximum"], GuiCtrlObj)
}

;--------------------------------------------------
;horde loras
;--------------------------------------------------

;horde lora name
;--------------------------------------------------
horde_lora_available_combobox.OnEvent("Change", horde_lora_available_combobox_change)
horde_lora_available_combobox_change(GuiCtrlObj, Info) {
  horde_lora_current := horde_lora_active_listview.GetCount() = 1 ? 1 : horde_lora_active_listview.GetNext()
  if (horde_lora_current) {
    horde_lora_active_listview.Modify(horde_lora_current, "Vis", GuiCtrlObj.Text)
  }
}

;horde lora strength
;--------------------------------------------------
horde_lora_strength_updown.OnEvent("Change", horde_lora_strength_updown_change)
horde_lora_strength_updown_change(GuiCtrlObj, Info) {
  number_update(horde_lora_strength_values["default"], horde_lora_strength_values["minimum"], horde_lora_strength_values["maximum"], horde_lora_strength_values["multipleOf"], horde_lora_strength_values["dp"], horde_lora_strength_edit, Info)
  horde_lora_current := horde_lora_active_listview.GetCount() = 1 ? 1 : horde_lora_active_listview.GetNext()
  if (horde_lora_current) {
    horde_lora_active_listview.Modify(horde_lora_current, "Vis",, horde_lora_strength_edit.Value)
  }
}

horde_lora_strength_edit.OnEvent("LoseFocus", horde_lora_strength_edit_losefocus)
horde_lora_strength_edit_losefocus(GuiCtrlObj, Info) {
  horde_lora_current := horde_lora_active_listview.GetCount() = 1 ? 1 : horde_lora_active_listview.GetNext()
  if (horde_lora_current) {
    number_cleanup(horde_lora_active_listview.GetText(horde_lora_current, 2), horde_lora_strength_values["minimum"], horde_lora_strength_values["maximum"], GuiCtrlObj)
    horde_lora_active_listview.Modify(horde_lora_current,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup(horde_lora_strength_values["default"], horde_lora_strength_values["minimum"], horde_lora_strength_values["maximum"], GuiCtrlObj)
  }
}

;horde active loras
;--------------------------------------------------
horde_lora_active_listview.OnEvent("ItemSelect", horde_lora_active_listview_itemselect)
horde_lora_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  horde_lora_current := GuiCtrlObj.GetCount() = 1 ? 1 : GuiCtrlObj.GetNext()
  if (horde_lora_current) {
    horde_lora_available_combobox.Text := GuiCtrlObj.GetText(horde_lora_current,1)
    horde_lora_strength_edit.Value := GuiCtrlObj.GetText(horde_lora_current,2)
    horde_lora_inject_trigger_edit.Value := GuiCtrlObj.GetText(horde_lora_current,3)
  }
  else {
    horde_lora_available_combobox.Text := "None"
    horde_lora_strength_edit.Value := horde_lora_strength_values["default"]
    horde_lora_inject_trigger_edit.Value := ""
  }
}

horde_lora_active_listview.OnEvent("DoubleClick", horde_lora_remove_button_click)

;horde lora add button
;--------------------------------------------------
horde_lora_add_button.OnEvent("Click", horde_lora_add_button_click)
horde_lora_add_button_click(GuiCtrlObj, Info) {
  if (horde_lora_active_listview.GetNext() or horde_lora_active_listview.GetCount() <= 1) {
    horde_lora_active_listview.Add("Select", "None", horde_lora_strength_values["default"], "")
    horde_lora_active_listview.Modify(horde_lora_active_listview.GetCount(), "Vis")
    horde_lora_active_listview_itemselect(horde_lora_active_listview, "", "")
    horde_lora_available_combobox.Focus()
  }
  else {
    horde_lora_active_listview.Add("Select", horde_lora_available_combobox.Text, horde_lora_strength_edit.Value, horde_lora_inject_trigger_edit.Value)
    horde_lora_active_listview.Modify(horde_lora_active_listview.GetCount(), "Vis")
    ;horde_lora_active_listview_itemselect(horde_lora_active_listview, "", "")
  }
}

;;horde lora remove button
;--------------------------------------------------
horde_lora_remove_button.OnEvent("Click", horde_lora_remove_button_click)
horde_lora_remove_button_click(GuiCtrlObj, Info) {
  if (horde_lora_active_listview.GetCount() <= 1) {
    horde_lora_available_combobox.Text := "None"
    horde_lora_strength_edit.Value := horde_lora_strength_values["default"]
    horde_lora_inject_trigger_edit.Value := ""
    horde_lora_active_listview.Delete()
    horde_lora_active_listview.Add(, "None", horde_lora_strength_values["default"])
  }
  else {
    horde_lora_to_remove := horde_lora_active_listview.GetNext()
    if (horde_lora_to_remove) {
      horde_lora_active_listview.Delete(horde_lora_active_listview.GetNext())
      if (horde_lora_to_remove > horde_lora_active_listview.GetCount()) {
        horde_lora_active_listview.Modify(horde_lora_active_listview.GetCount(), "Select Vis")
      }
      else {
        horde_lora_active_listview.Modify(horde_lora_to_remove, "Select Vis")
      }
      horde_lora_active_listview_itemselect(horde_lora_active_listview, "", "")
    }
  }
}

;horde lora inject trigger
;--------------------------------------------------
horde_lora_inject_trigger_edit.OnEvent("Change", horde_lora_inject_trigger_edit_change)
horde_lora_inject_trigger_edit_change(GuiCtrlObj, Info) {
  horde_lora_current := horde_lora_active_listview.GetCount() = 1 ? 1 : horde_lora_active_listview.GetNext()
  if (horde_lora_current) {
    horde_lora_active_listview.Modify(horde_lora_current, "Vis",,, GuiCtrlObj.Value)
  }
}

;--------------------------------------------------
;horde textual inversions
;--------------------------------------------------

;horde ti inject field
;--------------------------------------------------
horde_textual_inversion_inject_field_dropdownlist.OnEvent("Change", horde_textual_inversion_inject_field_dropdownlist_change)
horde_textual_inversion_inject_field_dropdownlist_change(GuiCtrlObj, Info) {
  if (GuiCtrlObj.Value = 3) {
    horde_textual_inversion_strength_edit.Enabled := 0
    horde_textual_inversion_strength_updown.Enabled := 0
  }
  else {
    horde_textual_inversion_strength_edit.Enabled := 1
    horde_textual_inversion_strength_updown.Enabled := 1
  }
  horde_textual_inversion_current := horde_textual_inversion_active_listview.GetCount() = 1 ? 1 : horde_textual_inversion_active_listview.GetNext()
  if (horde_textual_inversion_current) {
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current, "Vis",, GuiCtrlObj.Text)
    if (GuiCtrlObj.Value = 3) {
      horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current, "Vis",,, "")
    }
    else {
      horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current, "Vis",,, horde_textual_inversion_strength_edit.Value)
    }
  }
}

;horde ti strength
;--------------------------------------------------
horde_textual_inversion_strength_updown.OnEvent("Change", horde_textual_inversion_strength_updown_change)
horde_textual_inversion_strength_updown_change(GuiCtrlObj, Info) {
  number_update(horde_textual_inversion_strength_values["default"], horde_textual_inversion_strength_values["minimum"], horde_textual_inversion_strength_values["maximum"], horde_textual_inversion_strength_values["multipleOf"], horde_textual_inversion_strength_values["dp"], horde_textual_inversion_strength_edit, Info)
  horde_textual_inversion_current := horde_textual_inversion_active_listview.GetCount() = 1 ? 1 : horde_textual_inversion_active_listview.GetNext()
  if (horde_textual_inversion_current) {
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current, "Vis",,, horde_textual_inversion_strength_edit.Value)
  }
}

horde_textual_inversion_strength_edit.OnEvent("LoseFocus", horde_textual_inversion_strength_edit_losefocus)
horde_textual_inversion_strength_edit_losefocus(GuiCtrlObj, Info) {
  horde_textual_inversion_current := horde_textual_inversion_active_listview.GetCount() = 1 ? 1 : horde_textual_inversion_active_listview.GetNext()
  if (horde_textual_inversion_current) {
    number_cleanup(horde_textual_inversion_active_listview.GetText(horde_textual_inversion_current, 3), horde_textual_inversion_strength_values["minimum"], horde_textual_inversion_strength_values["maximum"], GuiCtrlObj)
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current,,,, GuiCtrlObj.Value)
  }
  else {
    number_cleanup(horde_textual_inversion_strength_values["default"], horde_textual_inversion_strength_values["minimum"], horde_textual_inversion_strength_values["maximum"], GuiCtrlObj)
  }
}

;horde ti name
;--------------------------------------------------
horde_textual_inversion_available_combobox.OnEvent("Change", horde_textual_inversion_available_combobox_change)
horde_textual_inversion_available_combobox_change(GuiCtrlObj, Info) {
  horde_textual_inversion_current := horde_textual_inversion_active_listview.GetCount() = 1 ? 1 : horde_textual_inversion_active_listview.GetNext()
  if (horde_textual_inversion_current) {
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_current, "Vis", GuiCtrlObj.Text)
  }
}

;horde active tis
;--------------------------------------------------
horde_textual_inversion_active_listview.OnEvent("ItemSelect", horde_textual_inversion_active_listview_itemselect)
horde_textual_inversion_active_listview_itemselect(GuiCtrlObj, Item, Selected) {
  horde_textual_inversion_current := GuiCtrlObj.GetCount() = 1 ? 1 : GuiCtrlObj.GetNext()
  if (horde_textual_inversion_current) {
    horde_textual_inversion_available_combobox.Text := GuiCtrlObj.GetText(horde_textual_inversion_current, 1)
    horde_textual_inversion_inject_field_dropdownlist.Text := GuiCtrlObj.GetText(horde_textual_inversion_current, 2)
    if (horde_textual_inversion_inject_field_dropdownlist.Value != 3) {
      horde_textual_inversion_strength_edit.Value := GuiCtrlObj.GetText(horde_textual_inversion_current,3)
      horde_textual_inversion_strength_edit.Enabled := 1
      horde_textual_inversion_strength_updown.Enabled := 1
    }
    else {
      horde_textual_inversion_strength_edit.Value := horde_textual_inversion_strength_values["default"]
      horde_textual_inversion_strength_edit.Enabled := 0
      horde_textual_inversion_strength_updown.Enabled := 0
    }
  }
  else {
    horde_textual_inversion_available_combobox.Text := "None"
    horde_textual_inversion_inject_field_dropdownlist.Value := 1
    horde_textual_inversion_strength_edit.Value := horde_textual_inversion_strength_values["default"]
    horde_textual_inversion_strength_edit.Enabled := 1
    horde_textual_inversion_strength_updown.Enabled := 1
  }
}

horde_textual_inversion_active_listview.OnEvent("DoubleClick", horde_textual_inversion_remove_button_click)

;horde add ti button
;--------------------------------------------------
horde_textual_inversion_add_button.OnEvent("Click", horde_textual_inversion_add_button_click)
horde_textual_inversion_add_button_click(GuiCtrlObj, Info) {
  if (horde_textual_inversion_active_listview.GetNext() or horde_textual_inversion_active_listview.GetCount() <= 1) {
    horde_textual_inversion_active_listview.Add("Select", "None", "Positive", horde_textual_inversion_strength_values["default"])
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_active_listview.GetCount(), "Vis")
    horde_textual_inversion_active_listview_itemselect(horde_textual_inversion_active_listview, "", "")
    horde_textual_inversion_available_combobox.Focus()
  }
  else {
    if (horde_textual_inversion_inject_field_dropdownlist.Value != 3) {
      horde_textual_inversion_active_listview.Add("Select", horde_textual_inversion_available_combobox.Text, horde_textual_inversion_inject_field_dropdownlist.Text, horde_textual_inversion_strength_edit.Value)
    }
    else {
      horde_textual_inversion_active_listview.Add("Select", horde_textual_inversion_available_combobox.Text, horde_textual_inversion_inject_field_dropdownlist.Text, "")
    }
    horde_textual_inversion_active_listview.Modify(horde_textual_inversion_active_listview.GetCount(), "Vis")
    ;horde_textual_inversion_active_listview_itemselect(horde_textual_inversion_active_listview, "", "")
  }
}

;horde remove ti button
;--------------------------------------------------
horde_textual_inversion_remove_button.OnEvent("Click", horde_textual_inversion_remove_button_click)
horde_textual_inversion_remove_button_click(GuiCtrlObj, Info) {
  if (horde_textual_inversion_active_listview.GetCount() <= 1) {
    horde_textual_inversion_available_combobox.Text := "None"
    horde_textual_inversion_inject_field_dropdownlist.Text := "Positive"
    horde_textual_inversion_strength_edit.Value := horde_textual_inversion_strength_values["default"]
    horde_textual_inversion_active_listview.Delete()
    horde_textual_inversion_active_listview.Add(, "None", "Positive", horde_textual_inversion_strength_values["default"])
    horde_textual_inversion_strength_edit.Enabled := 1
    horde_textual_inversion_strength_updown.Enabled := 1
  }
  else {
    horde_textual_inversion_to_remove := horde_textual_inversion_active_listview.GetNext()
    if (horde_textual_inversion_to_remove) {
      horde_textual_inversion_active_listview.Delete(horde_textual_inversion_active_listview.GetNext())
      if (horde_textual_inversion_to_remove > horde_textual_inversion_active_listview.GetCount()) {
        horde_textual_inversion_active_listview.Modify(horde_textual_inversion_active_listview.GetCount(), "Select Vis")
      }
      else {
        horde_textual_inversion_active_listview.Modify(horde_textual_inversion_to_remove, "Select Vis")
      }
      horde_textual_inversion_active_listview_itemselect(horde_textual_inversion_active_listview, "", "")
    }
  }
}

;--------------------------------------------------
;horde generations
;--------------------------------------------------

;horde output clear list button
;--------------------------------------------------
clear_horde_outputs_list_button.OnEvent("Click", clear_horde_outputs_list_button_click)
clear_horde_outputs_list_button_click(GuiCtrlObj, Info) {
  horde_output_listview.Delete()
  global horde_last_selected_output_image := ""
  image_load_and_fit_wthout_change("stuff\placeholder_pixel.bmp", horde_output_picture_frame)
}

;horde generate button
;--------------------------------------------------
horde_generate_button.OnEvent("Click", horde_generate_button_click)
horde_generate_button_click(GuiCtrlObj, Info) {
  summon_the_horde()
}

;--------------------------------------------------
;horde output images
;--------------------------------------------------

;horde output list
;--------------------------------------------------
horde_output_listview.OnEvent("ItemSelect", horde_output_listview_itemselect)
horde_output_listview_itemselect(GuiCtrlObj, Item, Selected) {
  if (GuiCtrlObj.GetNext()) {
    global horde_last_selected_output_image := horde_output_folder GuiCtrlObj.GetText(GuiCtrlObj.GetNext(), 1)
    try {
      image_load_and_fit_wthout_change(horde_last_selected_output_image, horde_output_picture_frame)
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
    }
  }
}

horde_output_listview.OnEvent("DoubleClick", horde_output_listview_doubleclick)
horde_output_listview_doubleclick(GuiCtrlObj, Info) {
  if (horde_last_selected_output_image) {
    Run horde_last_selected_output_image
    overlay_hide()
  }
}

;--------------------------------------------------
;--------------------------------------------------
;horde picture frames, context menus, drop files
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;horde source
;--------------------------------------------------

horde_source_picture.OnEvent("ContextMenu", horde_source_picture_contextmenu)
horde_source_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, horde_source_picture_menu_input_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, horde_source_picture_menu_horde_input_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), horde_source_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), horde_source_picture_menu_horde_output_file)
  }

  horde_source_picture_menu.Show()
}

;input file
;--------------------------------------------------
horde_source_picture_menu_input_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(inputs[ItemName], horde_source_picture_frame)) {
    horde_inputs[horde_source_picture_frame["name"]] := valid_file
    horde_source_picture_update(0)
  }
}

;output file
;--------------------------------------------------
horde_source_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(output_folder ItemName, horde_source_picture_frame)) {
    horde_inputs[horde_source_picture_frame["name"]] := valid_file
    horde_source_picture_update(0)
  }
}


;clipboard
;--------------------------------------------------
horde_source_picture_menu_clipboard(*) {
  if (valid_file := image_load_and_fit_clipboard(horde_source_picture_frame)) {
    horde_inputs[horde_source_picture_frame["name"]] := valid_file
    horde_source_picture_update(0)
  }
}

;remove
;--------------------------------------------------
horde_source_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (horde_inputs.Has(horde_source_picture_frame["name"])) {
    horde_inputs.Delete(horde_source_picture_frame["name"])
  }
  horde_source_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  picture_fit_to_frame(horde_source_picture_frame["w"], horde_source_picture_frame["h"], horde_source_picture_frame)
  horde_source_picture_update(1)
}

;horde input file
;--------------------------------------------------
horde_source_picture_menu_horde_input_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], horde_source_picture_frame)) {
    horde_inputs[horde_source_picture_frame["name"]] := valid_file
    horde_source_picture_update(0)
  }
}

;horde output file
;--------------------------------------------------
horde_source_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, horde_source_picture_frame)) {
    horde_inputs[horde_source_picture_frame["name"]] := valid_file
    horde_source_picture_update(0)
  }
}

;misc
;--------------------------------------------------
horde_source_picture_update(on_off) {
  if (on_off) {
    horde_controlnet_type_combobox.Visible := 0
    horde_controlnet_option_dropdownlist.Visible := 0
    horde_copy_source_dimensions_button.Visible := 0
    if (show_labels) {
      horde_controlnet_type_label.Visible := 0
    }
  }
  else {
    horde_controlnet_type_combobox.Visible := 1
    horde_controlnet_option_dropdownlist.Visible := 1
    horde_copy_source_dimensions_button.Visible := 1
    if (show_labels) {
      horde_controlnet_type_label.Visible := 1
    }
  }
}

;--------------------------------------------------
;horde mask
;--------------------------------------------------

horde_mask_picture.OnEvent("ContextMenu", horde_mask_picture_contextmenu)
horde_mask_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()
  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, horde_mask_picture_menu_file)
  }
  for (existing_image in horde_inputs) {
    inputs_existing_images_menu.Add(existing_image, horde_mask_picture_menu_horde_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), horde_mask_picture_menu_output_file)
  }
  horde_outputs_existing_images_menu.Delete()
  while (A_Index <= horde_output_listview.GetCount()) {
    horde_outputs_existing_images_menu.Add(horde_output_listview.GetText(A_Index), horde_mask_picture_menu_horde_output_file)
  }

  horde_mask_picture_menu.Show()
}

;input file
;--------------------------------------------------
horde_mask_picture_menu_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(inputs[ItemName], horde_mask_picture_frame)) {
    horde_inputs[horde_mask_picture_frame["name"]] := valid_file
  }
}

;output file
;--------------------------------------------------
horde_mask_picture_menu_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(output_folder ItemName, horde_mask_picture_frame)) {
    horde_inputs[horde_mask_picture_frame["name"]] := valid_file
  }
}

;clipboard
;--------------------------------------------------
horde_mask_picture_menu_clipboard(*) {
  if (valid_file := image_load_and_fit_clipboard(horde_mask_picture_frame)) {
    horde_inputs[horde_mask_picture_frame["name"]] := valid_file
  }
}

;remove
;--------------------------------------------------
horde_mask_picture_menu_remove(ItemName, ItemPos, MyMenu) {
  if (horde_inputs.Has(horde_mask_picture_frame["name"])) {
    horde_inputs.Delete(horde_mask_picture_frame["name"])
  }
  horde_mask_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
  picture_fit_to_frame(horde_mask_picture_frame["w"], horde_mask_picture_frame["h"], horde_mask_picture_frame)
}

;horde input file
;--------------------------------------------------
horde_mask_picture_menu_horde_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_inputs[ItemName], horde_mask_picture_frame)) {
    horde_inputs[horde_mask_picture_frame["name"]] := valid_file
  }
}

;horde output file
;--------------------------------------------------
horde_mask_picture_menu_horde_output_file(ItemName, ItemPos, MyMenu) {
  if (valid_file := image_load_and_fit(horde_output_folder ItemName, horde_mask_picture_frame)) {
    horde_inputs[horde_mask_picture_frame["name"]] := valid_file
  }
}

;horde source/mask drop files
;--------------------------------------------------
horde_image_input.OnEvent("DropFiles", horde_image_input_dropfiles)
horde_image_input_dropfiles(GuiObj, GuiCtrlObj, FileArray, X, Y) {
  switch GuiCtrlObj {
    case horde_source_picture:
      if (valid_file := image_load_and_fit(FileArray[1], horde_source_picture_frame)) {
        horde_inputs[horde_source_picture_frame["name"]] := valid_file
        horde_source_picture_update(0)
      }
    case horde_mask_picture:
      if (valid_file := image_load_and_fit(FileArray[1], horde_mask_picture_frame)) {
        horde_inputs[horde_mask_picture_frame["name"]] := valid_file
      }
    ;default:
  }
}

;--------------------------------------------------
;horde job list
;--------------------------------------------------

horde_generation_status_listview.OnEvent("ContextMenu", horde_generation_status_listview_contextmenu)
horde_generation_status_listview_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  horde_generation_status_listview_menu.Show()
}

;horde salvage job
;--------------------------------------------------
horde_generation_status_listview_menu_salvage_job(ItemName, ItemPos, MyMenu) {
  if (horde_generation_status_listview.GetNext()) {
    prompt_id := horde_generation_status_listview.GetText(horde_generation_status_listview.GetNext(), 1)
    try {
      DetectHiddenWindows True
      if (!WinExist(horde_assistant_script " ahk_class AutoHotkey")) {
        Run horde_assistant_script " " A_ScriptName " " horde_address " horde_job " prompt_id
      }
      else {
        con_struct_ion := string_to_message(Jxon_dump([A_ScriptName, horde_address, "horde_job", prompt_id]))
        response_value := SendMessage(0x004A, 0, con_struct_ion)
      }
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
    }
    finally {
      DetectHiddenWindows False
    }
  }
}

;horde cancel job
;--------------------------------------------------
horde_generation_status_listview_menu_cancel_job(ItemName, ItemPos, MyMenu) {
  if (horde_generation_status_listview.GetNext()) {
    prompt_id := horde_generation_status_listview.GetText(horde_generation_status_listview.GetNext(), 1)
    try {
      altar.Open("DELETE", "https://" horde_address "/api/v2/generate/status/" prompt_id, false)
      altar.SetRequestHeader("accept", "application/json")
      altar.Send()

      response := altar.ResponseText
      horde_forgiveness := Jxon_load(&response)

      message_to_display := FormatTime() "`nhttps://" horde_address "/api/v2/generate/status/`n" prompt_id "`n" altar.Status ": " altar.StatusText
      if (horde_forgiveness.Has("message")) {
        message_to_display .= "`n" horde_forgiveness["message"]
      }
      status_text.Text := message_to_display

      if (altar.Status != 200) {
        FileAppend("[" A_Now "]`nhttps://" horde_address "/api/v2/generate/status/" prompt_id "`n" altar.Status ": " altar.StatusText "`n" response "`n", "log", "utf-8")
      }
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
    }
  }
}

;horde clear finished jobs
;--------------------------------------------------
horde_generation_status_listview_menu_clear_finished_jobs(ItemName, ItemPos, MyMenu) {
  while (A_Index <= horde_generation_status_listview.GetCount()) {
    if (horde_generation_status_listview.GetText(A_Index, 6) = 1 or horde_generation_status_listview.GetText(A_Index, 12) = "Not Found") {
      horde_generation_status_listview.Delete(A_Index)
      A_Index -= 1
    }
  }
}

;--------------------------------------------------
;horde outputs
;--------------------------------------------------

horde_output_picture.OnEvent("ContextMenu", horde_output_picture_menu_contextmenu)
horde_output_picture_menu_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  horde_output_picture_menu.Show()
}

horde_output_listview.OnEvent("ContextMenu", horde_output_picture_menu_contextmenu)

;horde output images - to source
;--------------------------------------------------
horde_output_picture_menu_to_source(ItemName, ItemPos, MyMenu) {
  if (assistant_status = "painting" or !horde_last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(horde_last_selected_output_image, main_preview_picture_frame)) {
      inputs[main_preview_picture_frame["name"]] := valid_file
      main_preview_picture_update(0)
    }
  }
}

;horde output images - to image prompt
;--------------------------------------------------
horde_output_picture_menu_to_image_prompt(ItemName, ItemPos, MyMenu) {
  if (!horde_last_selected_output_image) {
    return
  }
  if (image_prompt_picture_frame["name"] = "") {
    image_prompt_picture_frame["name"] := image_prompt_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_last_selected_output_image, image_prompt_picture_frame)) {
    inputs[image_prompt_picture_frame["name"]] := valid_file

    image_prompt_current := image_prompt_active_listview.GetCount() = 1 ? 1 : image_prompt_active_listview.GetNext()
    if (image_prompt_current) {
      image_prompt_active_listview.Modify(image_prompt_current, "Vis", image_prompt_picture_frame["name"])
      image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
    }
    else {
      image_prompt_add_button_click("", "")
    }
  }
}

;horde output images - to mask
;--------------------------------------------------
horde_output_picture_menu_to_mask(ItemName, ItemPos, MyMenu) {
  if (!horde_last_selected_output_image) {
    return
  }
  else if (valid_file := image_load_and_fit(horde_last_selected_output_image, mask_picture_frame)) {
    inputs[mask_picture_frame["name"]] := valid_file
    if (preview_images.Has("mask")) {
      preview_images.Delete("mask")
      mask_preview_picture_frame["GuiCtrlObj"].Value := "stuff\placeholder_pixel.bmp"
      picture_fit_to_frame(mask_preview_picture_frame["w"], mask_preview_picture_frame["h"], mask_preview_picture_frame)
    }
  }
}

;horde output images - to controlnet
;--------------------------------------------------
horde_output_picture_menu_to_controlnet(ItemName, ItemPos, MyMenu) {
  if (!horde_last_selected_output_image) {
    return
  }
  if (controlnet_picture_frame["name"] = "") {
    controlnet_picture_frame["name"] := controlnet_check_for_free_index()
  }
  if (valid_file := image_load_and_fit(horde_last_selected_output_image, controlnet_picture_frame)) {
    inputs[controlnet_picture_frame["name"]] := valid_file

    if (preview_images.Has(controlnet_picture_frame["name"])) {
      preview_images.Delete(controlnet_picture_frame["name"])
    }

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      controlnet_active_listview.Modify(controlnet_current, "Vis", controlnet_picture_frame["name"])
      controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
    }
    else {
      controlnet_add_button_click("", "")
    }
  }
}

;horde output images - to horde source
;--------------------------------------------------
horde_output_picture_menu_to_horde_source(ItemName, ItemPos, MyMenu) {
  if (!horde_last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(horde_last_selected_output_image, horde_source_picture_frame)) {
      horde_inputs[horde_source_picture_frame["name"]] := valid_file
      horde_source_picture_update(0)
    }
  }
}

;horde output images - to horde mask
;--------------------------------------------------
horde_output_picture_menu_to_horde_mask(ItemName, ItemPos, MyMenu) {
  if (!horde_last_selected_output_image) {
    return
  }
  else {
    if (valid_file := image_load_and_fit(horde_last_selected_output_image, horde_mask_picture_frame)) {
      horde_inputs[horde_mask_picture_frame["name"]] := valid_file
    }
  }
}

;horde output images - copy
;--------------------------------------------------
horde_output_picture_menu_copy(*) {
  try {
    SplitPath horde_last_selected_output_image,,, &original_file_extension
    if (StrLower(original_file_extension) = "webp") {
      file_object := FileOpen(horde_last_selected_output_image, "r")
      file_object.RawRead(buffer_object := Buffer(file_object.Length))
      file_object.Close()
      pointy_bits := DllCall(libwebp "\WebPDecodeBGRA", "Ptr", buffer_object.Ptr, "Ptr", buffer_object.Size, "IntP", &width := 0, "IntP", &height := 0, "Cdecl Ptr")

      bpp := (0x26200A & 0xFF00) >> 8
      stride := ((width * bpp + 31) & ~31) >> 3
      DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width, "Int", height, "Int", stride, "Int", 0x26200A, "Ptr", pointy_bits, "Ptr*", &pBitmap := 0)
    }
    else {
      pBitmap := Gdip_CreateBitmapFromFile(horde_last_selected_output_image)
    }
    Gdip_SetBitmapToClipboard(pBitmap)
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
  finally {
    if (IsSet(pBitmap)) {
      try {
        Gdip_DisposeImage(pBitmap)
      }
    }
    if (IsSet(pointy_bits)) {
      try {
        DllCall(libwebp "\WebPFree", "Ptr", pointy_bits)
      }
    }
  }
}

;--------------------------------------------------
;--------------------------------------------------
;gui window positioning
;--------------------------------------------------
;--------------------------------------------------

;common
overlay_background.Show("Hide")
WinGetPos ,, &overlay_background_w, &overlay_background_h, overlay_background.Hwnd
assistant_box.Show("Hide")
WinGetPos ,, &assistant_box_w, &assistant_box_h, assistant_box.Hwnd
status_box.Show("Hide")
WinGetPos ,, &status_box_w, &status_box_h, status_box.Hwnd

overlay_background.Show("x0 y0 Hide")
assistant_box.Show("x" A_ScreenWidth - assistant_box_w " y" A_ScreenHeight - assistant_box_h " Hide")
status_box.Show("x" A_ScreenWidth - status_box_w " y" A_ScreenHeight - status_box_h " Hide")

;comfy
main_controls.Show("Hide")
WinGetPos ,, &main_controls_w, &main_controls_h, main_controls.Hwnd
image_prompt.Show("Hide")
WinGetPos ,, &image_prompt_w, &image_prompt_h, image_prompt.Hwnd
lora_selection.Show("Hide")
WinGetPos ,, &lora_selection_w, &lora_selection_h, lora_selection.Hwnd
preview_display.Show("Hide")
WinGetPos ,, &preview_display_w, &preview_display_h, preview_display.Hwnd
mask_and_controlnet.Show("Hide")
WinGetPos ,, &mask_and_controlnet_w, &mask_and_controlnet_h, mask_and_controlnet.Hwnd
;controlnet preprocessor options behave in a special way because the gui object gets recreated when connecting to server
;controlnet_preprocessor_options.Show("Hide")
;WinGetPos ,, &controlnet_preprocessor_options_w, &controlnet_preprocessor_options_h, controlnet_preprocessor_options.Hwnd
output_viewer.Show("Hide")
WinGetPos ,, &output_viewer_w, &output_viewer_h, output_viewer.Hwnd

gui_windows["comfy"] := Map(
  "main_controls", Map(
    "gui_window", main_controls
    ,"x", screen_border_x
    ,"y", A_ScreenHeight - screen_border_y - main_controls_h
  )
  ,"image_prompt", Map(
    "gui_window", image_prompt
    ,"x", screen_border_x
    ,"y", A_ScreenHeight - screen_border_y - main_controls_h - image_prompt_h
  )
  ,"lora_selection", Map(
    "gui_window", lora_selection
    ,"x", screen_border_x + image_prompt_w + gap_x
    ,"y", A_ScreenHeight - screen_border_y - main_controls_h - lora_selection_h
  )
  ,"preview_display", Map(
    "gui_window", preview_display
    ,"x", A_ScreenWidth - screen_border_x - output_viewer_w - gap_y - preview_display_w
    ,"y", screen_border_y
  )
  ,"mask_and_controlnet", Map(
    "gui_window", mask_and_controlnet
    ,"x", screen_border_x
    ,"y", screen_border_y
  )
  ,"controlnet_preprocessor_options", Map(
    "gui_window", controlnet_preprocessor_options
    ,"x", screen_border_x + controlnet_preprocessor_options_start_x
    ,"y", screen_border_y + controlnet_preprocessor_options_start_y
  )
  ,"output_viewer", Map(
    "gui_window", output_viewer
    ,"x", A_ScreenWidth - screen_border_x - output_viewer_w
    ,"y", screen_border_y
  )
)

for (, gui_window_map in gui_windows["comfy"]) {
  gui_window_map["gui_window"].Show("x" gui_window_map["x"] " y" gui_window_map["y"] " Hide")
}

;horde
horde_main_controls.Show("Hide")
WinGetPos ,, &horde_main_controls_w, &horde_main_controls_h, horde_main_controls.Hwnd
horde_image_input.Show("Hide")
WinGetPos ,, &horde_image_input_w, &horde_image_input_h, horde_image_input.Hwnd
horde_post_processing.Show("Hide")
WinGetPos ,, &horde_post_processing_w, &horde_post_processing_h, horde_post_processing.Hwnd
horde_lora_selection.Show("Hide")
WinGetPos ,, &horde_lora_selection_w, &horde_lora_selection_h, horde_lora_selection.Hwnd
horde_textual_inversion_selection.Show("Hide")
WinGetPos ,, &horde_textual_inversion_selection_w, &horde_textual_inversion_selection_h, horde_textual_inversion_selection.Hwnd
horde_generate.Show("Hide")
WinGetPos ,, &horde_generate_w, &horde_generate_h, horde_generate.Hwnd
horde_output_viewer.Show("Hide")
WinGetPos ,, &horde_output_viewer_w, &horde_output_viewer_h, horde_output_viewer.Hwnd

gui_windows["horde"] := Map(
  "horde_main_controls", Map(
    "gui_window", horde_main_controls
    ,"x", screen_border_x
    ,"y", A_ScreenHeight - screen_border_y - horde_main_controls_h
  )
  ,"horde_image_input", Map(
    "gui_window", horde_image_input
    ,"x", screen_border_x
    ,"y", A_ScreenHeight - screen_border_y - horde_main_controls_h - horde_image_input_h
  )
  ,"horde_post_processing", Map(
    "gui_window", horde_post_processing
    ,"x", screen_border_x + horde_image_input_w + gap_x
    ,"y", A_ScreenHeight - screen_border_y - horde_main_controls_h - horde_post_processing_h
  )
  ,"horde_lora_selection", Map(
    "gui_window", horde_lora_selection
    ,"x", screen_border_x
    ,"y", screen_border_y
  )
  ,"horde_textual_inversion_selection", Map(
    "gui_window", horde_textual_inversion_selection
    ,"x", screen_border_x
    ,"y", screen_border_y + horde_lora_selection_h + gap_y
  )
  ,"horde_generate", Map(
    "gui_window", horde_generate
    ,"x", ((screen_border_x + horde_lora_selection_w + gap_x) + (A_ScreenWidth - screen_border_x - horde_output_viewer_w - gap_x - horde_generate_w)) / 2
    ,"y", screen_border_y
  )
  ,"horde_output_viewer", Map(
    "gui_window", horde_output_viewer
    ,"x", A_ScreenWidth - screen_border_x - horde_output_viewer_w
    ,"y", screen_border_y
  )
)

for (, gui_window_map in gui_windows["horde"]) {
  gui_window_map["gui_window"].Show("x" gui_window_map["x"] " y" gui_window_map["y"] " Hide")
}

;--------------------------------------------------
;--------------------------------------------------
;final preparations
;--------------------------------------------------
;--------------------------------------------------

;in case it's not square
picture_fit_to_frame(image_width_edit.Value, image_height_edit.Value, main_preview_picture_frame)

if (delete_input_files_on_startup = "DELETEINPUTFILES") {
  try {
    DirDelete input_folder, 1
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

if (delete_output_files_on_startup = "DELETEOUTPUTFILES") {
  try {
    DirDelete output_folder, 1
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

if (delete_horde_output_files_on_startup = "DELETEHORDEOUTPUTFILES") {
  try {
    DirDelete horde_output_folder, 1
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

try {
  DirCreate input_folder
  DirCreate output_folder
  DirCreate horde_output_folder
}
catch Error as what_went_wrong {
  oh_no(what_went_wrong)
}

if (server_address) {
  connect_to_server()
}

if (horde_address) {
  connect_to_horde()
}

;--------------------------------------------------
;hotkeys
;--------------------------------------------------

;toggle overlay (whichever was used last)
if (hotkey_toggle_overlay != "") {
  Hotkey hotkey_toggle_overlay, overlay_toggle, "On"
}

;comfy specific
;--------------------------------------------------
;toggle overlay (switch to comfy if not already)
if (hotkey_toggle_comfy_overlay != "") {
  Hotkey hotkey_toggle_comfy_overlay, overlay_toggle_comfy, "On"
}

;generate
if (hotkey_generate != "") {
  Hotkey hotkey_generate, diffusion_time, "On"
}

;clipboard to source
if (hotkey_clipboard_to_source != "") {
  Hotkey hotkey_clipboard_to_source, main_preview_picture_menu_clipboard, "On"
}

;clipboard to image prompt
if (hotkey_clipboard_to_image_prompt != "") {
  Hotkey hotkey_clipboard_to_image_prompt, image_prompt_picture_menu_clipboard, "On"
}

;clipboard to mask
if (hotkey_clipboard_to_mask != "") {
  Hotkey hotkey_clipboard_to_mask, mask_picture_menu_clipboard, "On"
}

;clipboard to controlnet
if (hotkey_clipboard_to_controlnet != "") {
  Hotkey hotkey_clipboard_to_controlnet, controlnet_picture_menu_clipboard, "On"
}

;output to clipboard
if (hotkey_output_to_clipboard != "") {
  Hotkey hotkey_output_to_clipboard, output_picture_menu_copy, "On"
}

;horde specific
;--------------------------------------------------
;toggle overlay (switch to horde if not already)
if (hotkey_toggle_horde_overlay != "") {
  Hotkey hotkey_toggle_horde_overlay, overlay_toggle_horde, "On"
}

;horde generate
if (hotkey_horde_generate != "") {
  Hotkey hotkey_horde_generate, summon_the_horde, "On"
}

;horde clipboard to source
if (hotkey_horde_clipboard_to_source != "") {
  Hotkey hotkey_horde_clipboard_to_source, horde_source_picture_menu_clipboard, "On"
}

;horde clipboard to mask
if (hotkey_horde_clipboard_to_mask != "") {
  Hotkey hotkey_horde_clipboard_to_mask, horde_mask_picture_menu_clipboard, "On"
}

;horde output to clipboard
if (hotkey_horde_output_to_clipboard != "") {
  Hotkey hotkey_horde_output_to_clipboard, horde_output_picture_menu_copy, "On"
}


#HotIf overlay_visible
~*Esc::overlay_hide()
;~*LWin Up::overlay_hide()
;~*RWin Up::overlay_hide()
~*!Tab::overlay_hide()
^Tab::overlay_tab_change_next()
^+Tab::overlay_tab_change_previous()
#HotIf

HotIf "overlay_visible"

if (use_save_and_load_hotkeys) {
  loop 12 {
    Hotkey "F" A_Index, load_f_hotkey, "On"
    Hotkey "+F" A_Index, save_f_hotkey, "On"
  }
}

HotIf

load_f_hotkey(f_key) {
  load_state(SubStr(f_key, 2))
}

save_f_hotkey(f_key) {
  save_state(SubStr(f_key, 3))
}

return

;end of auto-execute

;--------------------------------------------------
;--------------------------------------------------
;other functions
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;dealing with numbers
;--------------------------------------------------

;how to update numbers using updown controls
;--------------------------------------------------
number_update(default_value, limit_lower, limit_upper, step_size, decimal_places, GuiCtrlObj, Info) {
  original_value := GuiCtrlObj.Value
  format_string := decimal_places ? "{:." decimal_places "f}" : "{:u}"
  if (!IsNumber(original_value) or limit_lower > limit_upper) {
    new_value := Format(format_string, default_value)
  }
  else {
    effective_limit_lower := Format(format_string, limit_lower)
    effective_limit_upper := Format(format_string, limit_upper)
    effective_step := Format(format_string, step_size)
    gap := Format(format_string, Mod(original_value, effective_step))

    if (Info) {
      if (gap = 0 or gap = effective_step or gap = - effective_step) {
        new_value := original_value + effective_step
      }
      else if (gap > 0) {
        new_value := original_value + effective_step - gap
      }
      else if (gap < 0) {
        new_value := original_value - gap
      }
    }
    else {
      if (gap = 0 or gap = effective_step or gap = - effective_step) {
          new_value := original_value - effective_step
      }
      else if (gap > 0) {
          new_value := original_value - gap
      }
      else if (gap < 0) {
          new_value := original_value - effective_step - gap
      }
    }

    if (new_value > effective_limit_upper) {
      new_value := effective_limit_upper
    }
    else if (new_value < effective_limit_lower) {
      new_value := effective_limit_lower
    }

    if (decimal_places) {
      new_value := Format(format_string, new_value)
    }
  }
  GuiCtrlObj.Value := new_value
}

;clean up numbers on losefocus
;pass params as strings to choose how the number shows up
;--------------------------------------------------
number_cleanup(default_value, limit_lower, limit_upper, GuiCtrlObj) {
  if (!IsNumber(GuiCtrlObj.Value) or limit_lower > limit_upper) {
    GuiCtrlObj.Value := default_value
  }
  else if (GuiCtrlObj.Value > limit_upper) {
    GuiCtrlObj.Value := limit_upper
  }
  else if (GuiCtrlObj.Value < limit_lower) {
    GuiCtrlObj.Value := limit_lower
  }
}

;rounding, only intended for integers
;--------------------------------------------------
integer_round(starting_number, to_nearest) {
  remainder := Mod(starting_number, to_nearest)
  switch {
    case remainder = 0:
      return starting_number
    case remainder >= to_nearest / 2:
      return starting_number + to_nearest - remainder
    default:
      return starting_number - remainder
  }
}

;--------------------------------------------------
;dealing with pictures
;--------------------------------------------------

;create a picture frame - used to for fitting images into specific "slots"
;--------------------------------------------------
create_picture_frame(name, GuiCtrlObj) {
  GuiCtrlObj.GetPos(&x, &y, &w, &h)
  return Map("name", name, "x", x, "y", y, "w", w, "h", h, "GuiCtrlObj", GuiCtrlObj)
}

;centre and "scale to fit" an image into a picture frame
;--------------------------------------------------
picture_fit_to_frame(new_w, new_h, frame) {
  ;if (new_w = new_h) {
  if (Float(new_w) / Float(new_h) = Float(frame["w"]) / Float(frame["h"])) {
    frame["GuiCtrlObj"].Move(frame["x"], frame["y"], frame["w"], frame["h"])
  }
  ;else if (new_w > new_h) {
  else if (Float(new_w) / Float(new_h) > Float(frame["w"]) / Float(frame["h"])) {
    frame["GuiCtrlObj"].Move(frame["x"], frame["y"] + (frame["h"] / 2) - (new_h / (new_w / frame["w"])) / 2, frame["w"], new_h / (new_w / frame["w"]))
  }
  ;else if (new_w < new_h) {
  else if (Float(new_w) / Float(new_h) < Float(frame["w"]) / Float(frame["h"])) {
    frame["GuiCtrlObj"].Move(frame["x"] + (frame["w"] / 2) - (new_w / (new_h / frame["h"])) / 2, frame["y"], new_w / (new_h / frame["h"]), frame["h"])
  }
  ;frame["GuiCtrlObj"].Redraw()
  frame["actual_w"] := new_w
  frame["actual_h"] := new_h
}

;save an image from a file path and fit into a picture frame
;--------------------------------------------------
image_load_and_fit(image, frame) {
  try {
    SplitPath image,,, &original_file_extension

    try {
      FileCopy image, input_folder frame["name"] ".*" , 1
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
      if (!FileExist(input_folder frame["name"] original_file_extension)) {
        return ""
      }
    }

    if (StrLower(original_file_extension) = "webp") {
      image := "HBITMAP:" webp_decode(image)
    }

    frame["GuiCtrlObj"].Visible := 0
    frame["GuiCtrlObj"].Value := "*w0 *h0 " image
    frame["GuiCtrlObj"].GetPos(,, &w, &h)
    picture_fit_to_frame(w, h, frame)
    frame["GuiCtrlObj"].Redraw()
    frame["GuiCtrlObj"].Visible := 1

    ;delete files with different extensions
    loop files input_folder frame["name"] ".*" {
      if (A_LoopFileName != frame["name"] "." original_file_extension)
        FileDelete(A_LoopFilePath)
    }
    ;in case of files with no file extension
    if (original_file_extension and FileExist(input_folder frame["name"])) {
      FileDelete(input_folder frame["name"])
    }

    return input_folder frame["name"] "." original_file_extension
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return ""
  }
}

;fit image into a frame without moving files around
;--------------------------------------------------
image_load_and_fit_wthout_change(image, frame) {
  try {
    SplitPath image,,, &original_file_extension
    if (StrLower(original_file_extension) = "webp") {
      image := "HBITMAP:" webp_decode(image)
    }
    frame["GuiCtrlObj"].Visible := 0
    frame["GuiCtrlObj"].Value := "*w0 *h0 " image
    frame["GuiCtrlObj"].GetPos(,, &w, &h)
    picture_fit_to_frame(w, h, frame)
    frame["GuiCtrlObj"].Redraw()
    frame["GuiCtrlObj"].Visible := 1

    return 1
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return ""
  }
}

;save clipboard and fit to picture frame
;--------------------------------------------------
image_load_and_fit_clipboard(frame) {
  try {
    pBitmap := Gdip_CreateBitmapFromClipboard()
    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    frame["GuiCtrlObj"].Visible := 0
    frame["GuiCtrlObj"].Value := "*w0 *h0 HBITMAP:" hBitmap
    frame["GuiCtrlObj"].GetPos(,, &w, &h)
    picture_fit_to_frame(w, h, frame)
    frame["GuiCtrlObj"].Redraw()
    frame["GuiCtrlObj"].Visible := 1

    Gdip_SaveBitmapToFile(pBitmap, input_folder frame["name"] ".png")

    ;delete files with different extensions
    loop files input_folder frame["name"] ".*" {
      if (A_LoopFileName != frame["name"] ".png")
        FileDelete(A_LoopFilePath)
    }
    ;in case of files with no file extension
    if (FileExist(input_folder frame["name"])) {
      FileDelete(input_folder frame["name"])
    }

    return input_folder frame["name"] ".png"
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return ""
  }
  finally {
    if (IsSet(pBitmap)) {
      try {
        Gdip_DisposeImage(pBitmap)
      }
    }
  }
}

;webp files
;--------------------------------------------------
webp_decode(webp_file) {
  try {
    file_object := FileOpen(webp_file, "r")
    file_object.RawRead(buffer_object := Buffer(file_object.Length))
    file_object.Close()
    pointy_bits := DllCall(libwebp "\WebPDecodeBGRA", "Ptr", buffer_object.Ptr, "Ptr", buffer_object.Size, "IntP", &width := 0, "IntP", &height := 0, "Cdecl Ptr")

    bpp := (0x26200A & 0xFF00) >> 8
    stride := ((width * bpp + 31) & ~31) >> 3
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width, "Int", height, "Int", stride, "Int", 0x26200A, "Ptr", pointy_bits, "Ptr*", &pBitmap := 0)
    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)

    return hBitmap
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return ""
  }
  finally {
    if (IsSet(pBitmap)) {
      try {
        Gdip_DisposeImage(pBitmap)
      }
    }
    if (IsSet(pointy_bits)) {
      try {
        DllCall(libwebp "\WebPFree", "Ptr", pointy_bits)
      }
    }
  }
}

;file to base64 string
;--------------------------------------------------
encode_image_file_to_base64(image) {
  try {
    SplitPath image,,, &original_file_extension
    if (StrLower(original_file_extension) = "webp") {
      file_object := FileOpen(image, "r")
      file_object.RawRead(buffer_object := Buffer(file_object.Length))
      file_object.Close()
      pointy_bits := DllCall(libwebp "\WebPDecodeBGRA", "Ptr", buffer_object.Ptr, "Ptr", buffer_object.Size, "IntP", &width := 0, "IntP", &height := 0, "Cdecl Ptr")

      bpp := (0x26200A & 0xFF00) >> 8
      stride := ((width * bpp + 31) & ~31) >> 3
      DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width, "Int", height, "Int", stride, "Int", 0x26200A, "Ptr", pointy_bits, "Ptr*", &pBitmap := 0)
    }
    else {
      pBitmap := Gdip_CreateBitmapFromFile(image)
    }
    encoded_image := Gdip_EncodeBitmapTo64string(pBitmap)
    return encoded_image
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return ""
  }
  finally {
    if (IsSet(pBitmap)) {
      try {
        Gdip_DisposeImage(pBitmap)
      }
    }
    if (IsSet(pointy_bits)) {
      try {
        DllCall(libwebp "\WebPFree", "Ptr", pointy_bits)
      }
    }
  }
}

;--------------------------------------------------
;communication
;--------------------------------------------------

;this function attempts to query the server to
;populate all the model lists & controlnet preprocessor options
;--------------------------------------------------
connect_to_server(*) {
  try {
    altar.Open("GET", "http://" server_address "/object_info", false)
    altar.Send()
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttp://" server_address "/object_info`n" altar.Status ": " altar.StatusText
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return
  }
  global scripture := Jxon_load(&response)

  selected_option := checkpoint_combobox.Text
  checkpoint_combobox.Delete()
  checkpoint_combobox.Add(["None"])
  checkpoint_combobox.Add(scripture["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][1])
  if (selected_option) {
    checkpoint_combobox.Text := selected_option
  }
  else {
    checkpoint_combobox.Value := 1
  }

  selected_option := vae_combobox.Text
  vae_combobox.Delete()
  vae_combobox.Add(["Default"])
  vae_combobox.Add(scripture["VAELoader"]["input"]["required"]["vae_name"][1])
  if (selected_option) {
    vae_combobox.Text := selected_option
  }
  else {
    vae_combobox.Value := 1
  }

  selected_option := sampler_combobox.Text
  sampler_combobox.Delete()
  sampler_combobox.Add(scripture["KSampler"]["input"]["required"]["sampler_name"][1])
  if (selected_option) {
    sampler_combobox.Text := selected_option
  }
  else {
    sampler_combobox.Value := 1
  }

  selected_option := scheduler_combobox.Text
  scheduler_combobox.Delete()
  scheduler_combobox.Add(scripture["KSampler"]["input"]["required"]["scheduler"][1])
  if (selected_option) {
    scheduler_combobox.Text := selected_option
  }
  else {
    scheduler_combobox.Value := 1
  }

  selected_option := upscale_combobox.Text
  upscale_combobox.Delete()
  upscale_combobox.Add(["None"])
  upscale_combobox.Add(scripture["ImageScale"]["input"]["required"]["upscale_method"][1])
  upscale_combobox.Add(scripture["UpscaleModelLoader"]["input"]["required"]["model_name"][1])
  if (selected_option) {
    upscale_combobox.Text := selected_option
  }
  else {
    upscale_combobox.Value := 1
  }

  selected_option := refiner_combobox.Text
  refiner_combobox.Delete()
  refiner_combobox.Add(["None"])
  refiner_combobox.Add(scripture["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][1])
  if (selected_option) {
    refiner_combobox.Text := selected_option
  }
  else {
    refiner_combobox.Value := 1
  }

  selected_option := clip_vision_combobox.Text
  clip_vision_combobox.Delete()
  clip_vision_combobox.Add(["None"])
  clip_vision_combobox.Add(scripture["CLIPVisionLoader"]["input"]["required"]["clip_name"][1])
  if (selected_option) {
    clip_vision_combobox.Text := selected_option
  }
  else {
    clip_vision_combobox.Value := 1
  }

  selected_option := IPAdapter_combobox.Text
  IPAdapter_combobox.Delete()
  IPAdapter_combobox.Add(["None"])
  ;IPAdapter_nodes is exposed as an option in the settings file
  if (IPAdapter_nodes and scripture.Has("IPAdapterModelLoader")) {
    IPAdapter_combobox.Add(scripture["IPAdapterModelLoader"]["input"]["required"]["ipadapter_file"][1])
  }
  if (selected_option) {
    IPAdapter_combobox.Text := selected_option
  }
  else {
    IPAdapter_combobox.Value := 1
  }

  ;with listviews (loras and controlnet), refresh selected option using itemselect instead
  lora_available_combobox.Delete()
  lora_available_combobox.Add(["None"])
  lora_available_combobox.Add(scripture["LoraLoader"]["input"]["required"]["lora_name"][1])
  lora_active_listview_itemselect(lora_active_listview, "", "")

  controlnet_checkpoint_combobox.Delete()
  controlnet_checkpoint_combobox.Add(["None"])
  controlnet_checkpoint_combobox.Add(scripture["DiffControlNetLoader"]["input"]["required"]["control_net_name"][1])

  controlnet_preprocessor_dropdownlist.Delete()
  controlnet_preprocessor_dropdownlist.Add(["None"])
  preprocessor_controls.Clear()
  preprocessor_actual_name.Clear()

  remake_controlnet_preprocessor_gui()
  for (node in scripture) {
    ;find every node which belongs to the specific node category, as well as the default Canny
    ;controlnet_preprocessor_nodes is exposed as an option in the settings file
    if (node = "Canny" or (controlnet_preprocessor_nodes and InStr(scripture[node]["category"], "ControlNet Preprocessors/") = 1)) {
      controlnet_preprocessor_dropdownlist.Add([scripture[node]["display_name"]])
      ;this mapping makes some things slightly easier
      preprocessor_actual_name[scripture[node]["display_name"]] := node

      ;after this, an array of controls lives at the bottom of preprocessor_controls
      ;preprocessor_controls["Canny"]["low_threshold"] would be an array containing the
      ;edit and updown used for low_threshold, in addition to the label if labels are visible
      preprocessor_controls[node] := Map()
      preprocessor_controls_created := 0

      ;determine what kind of values are being dealt with
      for (optionality in scripture[node]["input"]) {
        for (opt, value_properties in scripture[node]["input"][optionality]) {
          controlnet_preprocessor_option_next_y := gap_y + (edit_default_h + gap_y) * Mod(preprocessor_controls_created, 3)
          controlnet_preprocessor_option_next_x := (preprocessor_controls_created // 3) * (100 + gap_x)
          if (Type(value_properties) = "Array") {
            switch {
              ;this should be an array with "enable" and "disable" but should hopefully be fine with other values too
              case Type(value_properties[1]) = "Array":
                if (value_properties[1].Length) {
                  if (value_properties.Has(2) and value_properties[2].Has("default")) {
                    preprocessor_controls[node][opt] := create_a_choice(controlnet_preprocessor_option_next_x, controlnet_preprocessor_option_next_y, node, opt, value_properties[1], value_properties[2]["default"])
                  }
                  else {
                    preprocessor_controls[node][opt] := create_a_choice(controlnet_preprocessor_option_next_x, controlnet_preprocessor_option_next_y, node, opt, value_properties[1], value_properties[1][1])
                  }
                  preprocessor_controls_created += 1
                }
              ;number to be represented using an edit and updown
              case value_properties[1] = "INT" or value_properties[1] = "FLOAT":
                ;ignore resolution here
                if (opt = "resolution") {
                  continue
                }
                if (value_properties[2].Has("step")) {
                  step_value_to_use := value_properties[2]["step"]
                }
                else {
                  step_value_to_use := value_properties[1] = "FLOAT" ? 0.1 : 1
                }
                preprocessor_controls[node][opt] := create_a_number_box(controlnet_preprocessor_option_next_x, controlnet_preprocessor_option_next_y, node, opt, value_properties[2]["default"], value_properties[2]["min"], value_properties[2]["max"], step_value_to_use)
                preprocessor_controls_created += 1
              ;default:
            }
          }
        }
      }
    }
  }

  controlnet_active_listview_itemselect(controlnet_active_listview, "", "")

  controlnet_preprocessor_options.Show("x" gui_windows["comfy"]["controlnet_preprocessor_options"]["x"] " y" gui_windows["comfy"]["controlnet_preprocessor_options"]["y"] " Hide")
  if (overlay_visible and overlay_current = "comfy") {
    controlnet_preprocessor_options.Show("NoActivate")
  }
}

;used by connect_to_server to recreate the specific gui for controlnet preprocessors
;so that controls can be destroyed efficiently
;--------------------------------------------------
remake_controlnet_preprocessor_gui() {
  global controlnet_preprocessor_options
  controlnet_preprocessor_options.Destroy()
  controlnet_preprocessor_options := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay_background.Hwnd " +LastFound", "ControlNet Preprocessors")
  controlnet_preprocessor_options.MarginX := 0
  controlnet_preprocessor_options.MarginY := 0
  controlnet_preprocessor_options.BackColor := transparent_bg_colour
  WinSetTransColor transparent_bg_colour
  controlnet_preprocessor_options.SetFont("s" text_size " c" text_colour " q0", text_font)

  gui_windows["comfy"]["controlnet_preprocessor_options"]["gui_window"] := controlnet_preprocessor_options
}

;used by connect_to_server to create gui controls for specific perprocessors which have integer and float inputs
;--------------------------------------------------
create_a_number_box(x, y, node, opt, v_default, v_min, v_max, v_step) {
  ;determine how many useful decimal places to use, up to 3 based on the step size
  if IsFloat(v_step) {
    ;format as float with 3 dp and remove trailing 0's
    decimal_places := RTrim(Format("{:.3f}", v_step), "0")
    ;(length of string) minus (length of string up to decimal point)
    decimal_places := Strlen(decimal_places) - (InStr(decimal_places, "."))
    format_string := "{:." decimal_places "f}"
  }
  else {
    decimal_places := 0
    format_string := "{:u}"
  }
  effective_default := Format(format_string, v_default)
  effective_limit_lower := Format(format_string, v_min)
  effective_limit_upper := Format(format_string, v_max)
  effective_step := Format(format_string, v_step)

  control_edit := controlnet_preprocessor_options.Add("Edit", "x" x " y" y " w100 r1 Background" control_colour " Center", effective_default)
  if IsInteger(v_step) {
    control_edit.Opt("Number")
  }
  control_updown := controlnet_preprocessor_options.Add("UpDown", "Range0-1 0x80 -2", 0)

  control_updown.OnEvent("Change", control_updown_change)
  control_edit.OnEvent("LoseFocus", control_edit_losefocus)

  control_updown_change(GuiCtrlObj, Info) {
    number_update(effective_default, effective_limit_lower, effective_limit_upper, effective_step, decimal_places, control_edit, Info)

    ;update the listview with all the values for the current option using a map-as-a-string
    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      for (each_opt in preprocessor_controls[node]) {
        pp_value_string .= each_opt ":" preprocessor_controls[node][each_opt][1].Text
        if (A_Index < preprocessor_controls[node].Count) {
          pp_value_string .= ","
        }
      }
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,,, pp_value_string)
    }
  }

  control_edit_losefocus(GuiCtrlObj, Info) {
    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current and preprocessor_actual_name[controlnet_active_listview.GetText(controlnet_current, 6)] = node) {
      ;get values from listview's controlnet preprocessor column
      last_value := effective_default
      Loop Parse controlnet_active_listview.GetText(controlnet_current, 7), "," {
        option_pair := StrSplit(A_LoopField, ":")
        if (option_pair[1] = opt) {
          last_value := option_pair[2]
        }
      }
      number_cleanup(last_value, effective_limit_lower, effective_limit_upper, GuiCtrlObj)
      for (each_opt in preprocessor_controls[node]) {
        pp_value_string .= each_opt ":" preprocessor_controls[node][each_opt][1].Text
        if (A_Index < preprocessor_controls[node].Count) {
          pp_value_string .= ","
        }
      }
      controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,,, pp_value_string)
    }
    else {
      number_cleanup(effective_default, effective_limit_lower, effective_limit_upper, GuiCtrlObj)
    }
  }

  if (show_labels) {
    controlnet_preprocessor_options.SetFont("s" label_size " c" label_colour " q3", label_font)
    control_label := controlnet_preprocessor_options.Add("Text", "x" x " y" y - label_h , opt)
    controlnet_preprocessor_options.SetFont("s" text_size " c" text_colour " q0", text_font)
    return [control_edit, control_updown, control_label]
  }
  else {
    return [control_edit, control_updown]
  }
}

;same as above except for dropdownlist (multiple choice questions)
;--------------------------------------------------
create_a_choice(x, y, node, opt, choices, v_default) {
  control_dropdownlist := controlnet_preprocessor_options.Add("DropDownList", "x" x " y" y " w100 Background" control_colour, choices)
  control_dropdownlist.Text := v_default

  control_dropdownlist.OnEvent("Change", control_dropdownlist_change)

  control_dropdownlist_change(GuiCtrlObj, Info) {

    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_current) {
      for (controls in preprocessor_controls[node]) {
        pp_value_string .= controls ":" preprocessor_controls[node][controls][1].Text
        if (A_Index < preprocessor_controls[node].Count) {
          pp_value_string .= ","
        }
      }
    controlnet_active_listview.Modify(controlnet_current, "Vis",,,,,,, pp_value_string)
    }
  }

  if (show_labels) {
    controlnet_preprocessor_options.SetFont("s" label_size " c" label_colour " q3", label_font)
    control_label := controlnet_preprocessor_options.Add("Text", "x" x " y" y - label_h , opt)
    controlnet_preprocessor_options.SetFont("s" text_size " c" text_colour " q0", text_font)
    return [control_dropdownlist, control_label]
  }
  else {
    return [control_dropdownlist]
  }
}

;--------------------------------------------------
;painting
;--------------------------------------------------

;create a ((((masterpiece))))
;--------------------------------------------------
diffusion_time(*) {
  change_status("painting")

  ;upload all input images first
  server_image_files := Map()
  try {
    for (picture, image_file in inputs) {
      altar.Open("POST", "http://" server_address "/upload/image", false)
      objParam := {overwrite: "true", image: [image_file], subfolder: "fluff"}
      CreateFormData(&offering, &hdr_ContentType, objParam)
      altar.SetRequestHeader("Content-Type", hdr_ContentType)
      altar.Send(offering)
      response := altar.ResponseText
      status_text.Text := FormatTime() "`nhttp://" server_address "/upload/image`n" altar.Status ": " altar.StatusText

      inspiration := Jxon_load(&response)
      if (inspiration.Has("subfolder") and inspiration.Has("name")) {
        server_image_files[picture] := inspiration["subfolder"] "\" inspiration["name"]
      }
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return
  }

  dream := FileRead("workflows\main_api.json")
  thought := Jxon_load(&dream)

  ;values are roughly dealt with in order of gui appearance for default workflow
  ;try to avoid using node properties in conditionals

  ;temporary bandaid node - if the ImageColorToMask works, delete this
  ;ctrl+f "mask_from_image" and switch the relevant lines with the commented ones further down (3 times)
  thought["mask_from_image"]["class_type"] := "ImageToMask"
  thought["mask_from_image"]["inputs"].Delete("color")

  ;checkpoint
  thought["checkpoint_loader"]["inputs"]["ckpt_name"] := checkpoint_combobox.Text

  ;vae
  if (vae_combobox.Text = "Default") {
    vae_node := ["checkpoint_loader", 2]
  }
  else {
    thought["vae_loader"]["inputs"]["vae_name"] := vae_combobox.Text
    vae_node := ["vae_loader", 0]
  }
  thought["main_vae_decode"]["inputs"]["vae"] := vae_node
  thought["source_vae_encode"]["inputs"]["vae"] := vae_node
  thought["inpaint_specific"]["inputs"]["vae"] := vae_node
  thought["upscale_vae_encode"]["inputs"]["vae"] := vae_node
  thought["upscale_vae_decode"]["inputs"]["vae"] := vae_node
  thought["upscale_inpaint_specific"]["inputs"]["vae"] := vae_node

  ;sampler
  thought["main_sampler"]["inputs"]["sampler_name"] := sampler_combobox.Text

  ;scheduler
  thought["main_sampler"]["inputs"]["scheduler"] := scheduler_combobox.Text

  ;text prompts
  if (prompt_positive_edit.Text = "00") {
    thought["main_prompt_positive_zero_out"]["inputs"]["conditioning"] := ["main_prompt_positive", 0]
    thought["main_sampler"]["inputs"]["positive"] := ["main_prompt_positive_zero_out", 0]
  }
  else {
    thought["main_prompt_positive"]["inputs"]["text"] := prompt_positive_edit.Text
    thought["main_sampler"]["inputs"]["positive"] := ["main_prompt_positive", 0]
  }
  if (prompt_negative_edit.Text = "00") {
    thought["main_prompt_negative_zero_out"]["inputs"]["conditioning"] := ["main_prompt_negative", 0]
    thought["main_sampler"]["inputs"]["negative"] := ["main_prompt_negative_zero_out", 0]
  }
  else {
    thought["main_prompt_negative"]["inputs"]["text"] := prompt_negative_edit.Text
    thought["main_sampler"]["inputs"]["negative"] := ["main_prompt_negative", 0]
  }

  ;seed
  if (random_seed_checkbox.Value) {
    thought["main_sampler"]["inputs"]["seed"] := seed_edit.Value := Random(0x7FFFFFFFFFFFFFFF)
  }
  else {
    thought["main_sampler"]["inputs"]["seed"] := seed_edit.Value
  }

  ;steps, cfg, denoise
  thought["main_sampler"]["inputs"]["steps"] := step_count_edit.Value
  thought["main_sampler"]["inputs"]["cfg"] := cfg_edit.Value
  thought["main_sampler"]["inputs"]["denoise"] := denoise_edit.Value

  ;source image
  if (inputs.Has("source")) {
    thought["source_image_loader"]["inputs"]["image"] := server_image_files["source"]
    ;image count
    if (batch_size_edit.Value > 1) {
      image_batcher_node_count := 1
      thought["source_image_batcher_1"]["inputs"]["image1"] := ["source_image_loader", 0]
      thought["source_image_batcher_1"]["inputs"]["image2"] := ["source_image_loader", 0]
      while (image_batcher_node_count + 1 < batch_size_edit.Value) {
        image_batcher_node_count += 1
        thought["source_image_batcher_" image_batcher_node_count] := Map(
          "inputs", Map(
            "image1", ["source_image_batcher_" image_batcher_node_count - 1, 0]
            ,"image2", ["source_image_loader", 0]
          ),
          "class_type", "ImageBatch"
        )
      }
      thought["source_vae_encode"]["inputs"]["pixels"] := ["source_image_batcher_" image_batcher_node_count, 0]
      thought["inpaint_specific"]["inputs"]["pixels"] := ["source_image_batcher_" image_batcher_node_count, 0]
    }
    else {
      thought["source_vae_encode"]["inputs"]["pixels"] := ["source_image_loader", 0]
      thought["inpaint_specific"]["inputs"]["pixels"] := ["source_image_loader", 0]
    }
    if (inputs.Has("mask")) {
      thought["mask_image_loader"]["inputs"]["image"] := server_image_files["mask"]
      ;this is broken
      ;thought["mask_from_image"]["inputs"]["color"] := (mask_pixels_combobox.Text = "Black") ? 0 : (mask_pixels_combobox.Text = "White") ? 16777215 : mask_pixels_combobox.Text
      thought["mask_from_image"]["inputs"]["channel"] := mask_pixels_combobox.Text
      thought["mask_grow"]["inputs"]["expand"] := mask_grow_edit.Value
      thought["mask_feather"]["inputs"]["left"] := thought["mask_feather"]["inputs"]["top"] := thought["mask_feather"]["inputs"]["right"] := thought["mask_feather"]["inputs"]["bottom"] := mask_feather_edit.Value
      if (inpainting_checkpoint_checkbox.Value) {
        thought["main_sampler"]["inputs"]["latent_image"] := ["inpaint_specific", 0]
      }
      else {
        thought["main_sampler"]["inputs"]["latent_image"] := ["inpaint_simple", 0]
      }
    }
    else {
      thought["main_sampler"]["inputs"]["latent_image"] := ["source_vae_encode", 0]
    }
  }
  else {
    thought["main_sampler"]["inputs"]["latent_image"] := ["empty_latent", 0]
    ;dimensions
    thought["empty_latent"]["inputs"]["width"] := image_width_edit.Value
    thought["empty_latent"]["inputs"]["height"] := image_height_edit.Value
    ;image count
    thought["empty_latent"]["inputs"]["batch_size"] := batch_size_edit.Value
    if (inputs.Has("mask")) {
      ;this should usually be pointless but the user should be allowed to
      ;inpaint a blank source image if they want to
      thought["mask_image_loader"]["inputs"]["image"] := server_image_files["mask"]
      ;this is broken
      ;thought["mask_from_image"]["inputs"]["color"] := (mask_pixels_combobox.Text = "Black") ? 0 : (mask_pixels_combobox.Text = "White") ? 16777215 : mask_pixels_combobox.Text
      thought["mask_from_image"]["inputs"]["channel"] := mask_pixels_combobox.Text
      thought["mask_grow"]["inputs"]["expand"] := mask_grow_edit.Value
      thought["mask_feather"]["inputs"]["left"] := thought["mask_feather"]["inputs"]["top"] := thought["mask_feather"]["inputs"]["right"] := thought["mask_feather"]["inputs"]["bottom"] := mask_feather_edit.Value
      if (inpainting_checkpoint_checkbox.Value) {
        ;generate a node to vae decode
        thought["empty_latent_vae_decode"] := Map("inputs", Map("samples", ["empty_latent", 0], "vae", vae_node), "class_type", "VAEDecode")
        thought["inpaint_specific"]["inputs"]["pixels"] := ["empty_latent_vae_decode", 0]
        thought["main_sampler"]["inputs"]["latent_image"] := ["inpaint_specific", 0]
      }
      else {
        thought["main_sampler"]["inputs"]["latent_image"] := ["inpaint_simple", 0]
        thought["inpaint_simple"]["inputs"]["samples"] := ["empty_latent", 0]
      }
    }
  }
  ;thought["main_vae_decode"]["inputs"]["samples"] := ["main_sampler", 0]

  ;upscale
  if (upscale_combobox.Text and upscale_combobox.Text != "None") {
    ;only using non-latent upscaling
    ;determine whether using model to upscale or not by checking the name of upscale method
    upscale_using_model := 1
    for (upscaler in scripture["ImageScale"]["input"]["required"]["upscale_method"][1]) {
      if (upscale_combobox.Text = upscaler) {
        thought["upscale_resize"]["inputs"]["upscale_method"] := upscale_combobox.Text
        thought["upscale_resize"]["inputs"]["image"] := ["main_vae_decode", 0]
        upscale_using_model := 0
        break
      }
    }
    if (upscale_using_model) {
      thought["upscale_model_loader"]["inputs"]["model_name"] := upscale_combobox.Text
      thought["upscale_with_model"]["inputs"]["image"] := ["main_vae_decode", 0]
      thought["upscale_resize"]["inputs"]["image"] := ["upscale_with_model", 0]
    }

    thought["upscale_resize"]["inputs"]["width"] := image_width_edit.Value * upscale_value_edit.Value
    thought["upscale_resize"]["inputs"]["width"] := thought["upscale_resize"]["inputs"]["width"] > 8192 ? 8192 : Round(thought["upscale_resize"]["inputs"]["width"])
    thought["upscale_resize"]["inputs"]["height"] := image_height_edit.Value * upscale_value_edit.Value
    thought["upscale_resize"]["inputs"]["height"] := thought["upscale_resize"]["inputs"]["height"] > 8192 ? 8192 : Round(thought["upscale_resize"]["inputs"]["height"])

    ;reapply mask if inpainting
    if (inputs.Has("mask")) {
      if (inpainting_checkpoint_checkbox.Value) {
        thought["upscale_inpaint_specific"]["inputs"]["pixels"] := ["upscale_resize", 0]
        thought["upscale_sampler"]["inputs"]["latent_image"] := ["upscale_inpaint_specific", 0]
      }
      else {
        thought["upscale_inpaint_simple"]["inputs"]["samples"] := ["upscale_vae_encode", 0]
        thought["upscale_sampler"]["inputs"]["latent_image"] := ["upscale_inpaint_simple", 0]
      }
    }
    else {
      thought["upscale_sampler"]["inputs"]["latent_image"] := ["upscale_vae_encode", 0]
    }

    ;upscale sampler options
    if (random_seed_upscale_checkbox.Value) {
      thought["upscale_sampler"]["inputs"]["seed"] := Random(0x7FFFFFFFFFFFFFFF)
    }
    else {
      thought["upscale_sampler"]["inputs"]["seed"] := thought["main_sampler"]["inputs"]["seed"]
    }
    thought["upscale_sampler"]["inputs"]["sampler_name"] := thought["main_sampler"]["inputs"]["sampler_name"]
    thought["upscale_sampler"]["inputs"]["scheduler"] := thought["main_sampler"]["inputs"]["scheduler"]
    thought["upscale_sampler"]["inputs"]["steps"] := step_count_upscale_edit.Value
    thought["upscale_sampler"]["inputs"]["cfg"] := cfg_upscale_edit.Value
    thought["upscale_sampler"]["inputs"]["denoise"] := denoise_upscale_edit.Value

    ;thought["upscale_vae_decode"]["inputs"]["samples"] := ["upscale_sampler", 0]
    thought["save_image"]["inputs"]["images"] := ["upscale_vae_decode", 0]
  }
  else {
    thought["save_image"]["inputs"]["images"] := ["main_vae_decode", 0]
  }

  ;refiner
  if (refiner_combobox.Text and refiner_combobox.Text != "None") {
    ;decide which KSampler node to convert into KSamplerAdvanced
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      node_to_convert := "upscale_sampler"
      thought["upscale_vae_decode"]["inputs"]["samples"] := ["refiner_sampler", 0]
    }
    else {
      node_to_convert := "main_sampler"
      thought["main_vae_decode"]["inputs"]["samples"] := ["refiner_sampler", 0]
    }

    ;overwrite the node
    thought[node_to_convert] := Map(
      "inputs", Map(
        "add_noise", "enable"
        ,"noise_seed", thought[node_to_convert]["inputs"]["seed"]
        ,"steps", thought[node_to_convert]["inputs"]["steps"]
        ,"cfg", thought[node_to_convert]["inputs"]["cfg"]
        ,"sampler_name", thought[node_to_convert]["inputs"]["sampler_name"]
        ,"scheduler", thought[node_to_convert]["inputs"]["scheduler"]
        ,"start_at_step", Round(thought[node_to_convert]["inputs"]["steps"] - (thought[node_to_convert]["inputs"]["denoise"] * thought[node_to_convert]["inputs"]["steps"]))
        ,"end_at_step", refiner_start_step_edit.Value
        ,"return_with_leftover_noise", "enable"
        ,"model", thought[node_to_convert]["inputs"]["model"]
        ,"positive", thought[node_to_convert]["inputs"]["positive"]
        ,"negative", thought[node_to_convert]["inputs"]["negative"]
        ,"latent_image", thought[node_to_convert]["inputs"]["latent_image"]
      ),
      "class_type", "KSamplerAdvanced"
    )

    ;adjust the refiner node
    thought["refiner_sampler"]["inputs"]["add_noise"] := "disable"
    thought["refiner_sampler"]["inputs"]["noise_seed"] := random_seed_refiner_checkbox.Value ? Random(0x7FFFFFFFFFFFFFFF) : thought[node_to_convert]["inputs"]["noise_seed"]
    thought["refiner_sampler"]["inputs"]["steps"] := thought[node_to_convert]["inputs"]["steps"]
    thought["refiner_sampler"]["inputs"]["cfg"] := cfg_refiner_edit.Value
    thought["refiner_sampler"]["inputs"]["sampler_name"] := thought[node_to_convert]["inputs"]["sampler_name"]
    thought["refiner_sampler"]["inputs"]["scheduler"] := thought[node_to_convert]["inputs"]["scheduler"]
    thought["refiner_sampler"]["inputs"]["start_at_step"] := thought[node_to_convert]["inputs"]["end_at_step"]
    thought["refiner_sampler"]["inputs"]["end_at_step"] := 10000
    thought["refiner_sampler"]["inputs"]["return_with_leftover_noise"] := "disable"

    ;other refinement related nodes
    thought["refiner_model_loader"]["inputs"]["ckpt_name"] := refiner_combobox.Text

    if (prompt_positive_edit.Text = "00") {
      thought["refiner_prompt_positive_zero_out"]["inputs"]["conditioning"] := ["refiner_prompt_positive", 0]
      thought["refiner_sampler"]["inputs"]["positive"] := ["refiner_prompt_positive_zero_out", 0]
    }
    else {
      thought["refiner_prompt_positive"]["inputs"]["text"] := thought["main_prompt_positive"]["inputs"]["text"]
      thought["refiner_sampler"]["inputs"]["positive"] := ["refiner_prompt_positive", 0]
    }
    if (prompt_negative_edit.Text = "00") {
      thought["refiner_prompt_negative_zero_out"]["inputs"]["conditioning"] := ["refiner_prompt_negative", 0]
      thought["refiner_sampler"]["inputs"]["negative"] := ["refiner_prompt_negative_zero_out", 0]
    }
    else {
      thought["refiner_prompt_negative"]["inputs"]["text"] := thought["main_prompt_negative"]["inputs"]["text"]
      thought["refiner_sampler"]["inputs"]["negative"] := ["refiner_prompt_negative", 0]
    }

    /*this doesn't work
    ;inpainting
    if (inputs.Has("mask")) {
      thought["refiner_inpaint"]["inputs"]["samples"] := [node_to_convert, 0]
      thought["refiner_sampler"]["inputs"]["latent_image"] := ["refiner_inpaint", 0]
    }
    else {
      thought["refiner_sampler"]["inputs"]["latent_image"] := [node_to_convert, 0]
    }
    */

    thought["refiner_sampler"]["inputs"]["latent_image"] := [node_to_convert, 0]
  }

  ;image prompt
  actual_image_prompt_count := 0
  if (clip_vision_combobox.Text and clip_vision_combobox.Text != "None") {
    if (IPAdapter_combobox.Text and IPAdapter_combobox.Text != "None") {
      while (A_Index <= image_prompt_active_listview.GetCount()) {
        if (image_prompt_active_listview.GetText(A_Index, 1) and image_prompt_active_listview.GetText(A_Index, 1) != "None") {
          actual_image_prompt_count += 1
          thought["image_prompt_image_loader_" actual_image_prompt_count] := Map(
            "inputs", Map(
              "image", server_image_files[image_prompt_active_listview.GetText(A_Index, 1)]
              ,"choose file to upload", "image"
            ),
            "class_type", "LoadImage"
          )
          ;use the IPAdapterApply custom node
          thought["IPAdapter_apply_" actual_image_prompt_count] := Map(
            "inputs", Map(
              "weight", image_prompt_active_listview.GetText(A_Index, 2) > 3 ? 3 : image_prompt_active_listview.GetText(A_Index, 2) < -1 ? -1 : image_prompt_active_listview.GetText(A_Index, 2)
              ,"noise", image_prompt_active_listview.GetText(A_Index, 3)
              ,"ipadapter", ["IPAdapter_loader", 0]
              ,"clip_vision", ["clip_vision_loader", 0]
              ,"image", ["image_prompt_image_loader_" actual_image_prompt_count, 0]
              ,"model", ["IPAdapter_apply_" actual_image_prompt_count - 1, 0]
            ),
            "class_type", "IPAdapterApply"
          )

          ;refiner
          if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
            thought["refiner_IPAdapter_apply_" actual_image_prompt_count] := Map(
              "inputs", Map(
                "weight", thought["IPAdapter_apply_" actual_image_prompt_count]["inputs"]["weight"]
                ,"noise", thought["IPAdapter_apply_" actual_image_prompt_count]["inputs"]["noise"]
                ,"ipadapter", thought["IPAdapter_apply_" actual_image_prompt_count]["inputs"]["ipadapter"]
                ,"clip_vision", thought["IPAdapter_apply_" actual_image_prompt_count]["inputs"]["clip_vision"]
                ,"image", thought["IPAdapter_apply_" actual_image_prompt_count]["inputs"]["image"]
                ,"model", ["refiner_IPAdapter_apply_" actual_image_prompt_count - 1, 0]
              ),
              "class_type", "IPAdapterApply"
            )
          }
        }
      }
      if (actual_image_prompt_count) {
        thought["clip_vision_loader"]["inputs"]["clip_name"] := clip_vision_combobox.Text
        thought["IPAdapter_loader"]["inputs"]["ipadapter_file"] := IPAdapter_combobox.Text
        thought["IPAdapter_apply_1"]["inputs"]["model"] := ["checkpoint_loader", 0]
        thought["main_sampler"]["inputs"]["model"] := ["IPAdapter_apply_" actual_image_prompt_count, 0]
        if (upscale_combobox.Text and upscale_combobox.Text != "None") {
          thought["upscale_sampler"]["inputs"]["model"] := ["IPAdapter_apply_" actual_image_prompt_count, 0]
        }
        if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
          thought["refiner_IPAdapter_apply_1"]["inputs"]["model"] := ["refiner_model_loader", 0]
          thought["refiner_sampler"]["inputs"]["model"] := ["refiner_IPAdapter_apply_" actual_image_prompt_count, 0]
        }
      }
    }
    else {
      while (A_Index <= image_prompt_active_listview.GetCount()) {
        if (image_prompt_active_listview.GetText(A_Index, 1) and image_prompt_active_listview.GetText(A_Index, 1) != "None") {
          actual_image_prompt_count += 1
          thought["image_prompt_image_loader_" actual_image_prompt_count] := Map(
            "inputs", Map(
              "image", server_image_files[image_prompt_active_listview.GetText(A_Index, 1)]
              ,"choose file to upload", "image"
            ),
            "class_type", "LoadImage"
          )
          ;use "clip vision encode" and "unclip conditioning" nodes
          thought["clip_vision_encode_" actual_image_prompt_count] := Map(
            "inputs", Map(
              "clip_vision", ["clip_vision_loader", 0]
              ,"image", ["image_prompt_image_loader_" actual_image_prompt_count, 0]
            ),
            "class_type", "CLIPVisionEncode"
          )
          thought["unclip_conditioning_" actual_image_prompt_count] := Map(
            "inputs", Map(
              "strength", image_prompt_active_listview.GetText(A_Index, 2)
              ,"noise_augmentation", image_prompt_active_listview.GetText(A_Index, 3)
              ,"conditioning", ["unclip_conditioning_" actual_image_prompt_count - 1, 0]
              ,"clip_vision_output", ["clip_vision_encode_" actual_image_prompt_count, 0]
            ),
            "class_type", "unCLIPConditioning"
          )

          ;refiner
          if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
            thought["refiner_unclip_conditioning_" actual_image_prompt_count] := Map(
              "inputs", Map(
                "strength", thought["unclip_conditioning_" actual_image_prompt_count]["inputs"]["strength"]
                ,"noise_augmentation", thought["unclip_conditioning_" actual_image_prompt_count]["inputs"]["noise_augmentation"]
                ,"conditioning", ["refiner_unclip_conditioning_" actual_image_prompt_count - 1, 0]
                ,"clip_vision_output", thought["unclip_conditioning_" actual_image_prompt_count]["inputs"]["clip_vision_output"]
              ),
              "class_type", "unCLIPConditioning"
            )
          }
        }
      }
      if (actual_image_prompt_count) {
        thought["clip_vision_loader"]["inputs"]["clip_name"] := clip_vision_combobox.Text
        thought["unclip_conditioning_1"]["inputs"]["conditioning"] := prompt_positive_edit.Text = "00" ? ["main_prompt_positive_zero_out", 0] : ["main_prompt_positive", 0]
        thought["main_sampler"]["inputs"]["positive"] := ["unclip_conditioning_" actual_image_prompt_count, 0]
        if (upscale_combobox.Text and upscale_combobox.Text != "None") {
          thought["upscale_sampler"]["inputs"]["positive"] := ["unclip_conditioning_" actual_image_prompt_count, 0]
        }
        if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
          thought["refiner_unclip_conditioning_1"]["inputs"]["conditioning"] := prompt_positive_edit.Text = "00" ? ["refiner_prompt_positive_zero_out", 0] : ["refiner_prompt_positive", 0]
          thought["refiner_sampler"]["inputs"]["positive"] := ["refiner_unclip_conditioning_" actual_image_prompt_count, 0]
        }
      }
    }
  }

  ;lora
  actual_lora_count := 0
  while (A_Index <= lora_active_listview.GetCount()) {
    if (lora_active_listview.GetText(A_Index, 1) and lora_active_listview.GetText(A_Index, 1) != "None") {
      actual_lora_count += 1
      thought["lora_" actual_lora_count] := Map(
        "inputs", Map(
          "lora_name", lora_active_listview.GetText(A_Index, 1)
          ,"strength_model", lora_active_listview.GetText(A_Index, 2)
          ,"strength_clip", lora_active_listview.GetText(A_Index, 2)
          ,"model", ["lora_" actual_lora_count - 1, 0]
          ,"clip", ["lora_" actual_lora_count - 1, 1]
        ),
        "class_type", "LoraLoader"
      )

      ;refiner
      if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
        thought["refiner_lora_" actual_lora_count] := Map(
          "inputs", Map(
            "lora_name", thought["lora_" actual_lora_count]["inputs"]["lora_name"]
            ,"strength_model", thought["lora_" actual_lora_count]["inputs"]["strength_model"]
            ,"strength_clip", thought["lora_" actual_lora_count]["inputs"]["strength_clip"]
            ,"model", ["refiner_lora_" actual_lora_count - 1, 0]
            ,"clip", ["refiner_lora_" actual_lora_count - 1, 1]
          ),
          "class_type", "LoraLoader"
        )
      }
    }
  }
  if (actual_lora_count) {
    if (actual_image_prompt_count and IPAdapter_combobox.Text and IPAdapter_combobox.Text != "None") {
      thought["lora_1"]["inputs"]["model"] := ["IPAdapter_apply_" actual_image_prompt_count, 0]
    }
    else {
      thought["lora_1"]["inputs"]["model"] := ["checkpoint_loader", 0]
    }
    thought["lora_1"]["inputs"]["clip"] := ["checkpoint_loader", 1]
    thought["main_prompt_positive"]["inputs"]["clip"] := ["lora_" actual_lora_count, 1]
    thought["main_prompt_negative"]["inputs"]["clip"] := ["lora_" actual_lora_count, 1]
    thought["main_sampler"]["inputs"]["model"] := ["lora_" actual_lora_count, 0]
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      thought["upscale_sampler"]["inputs"]["model"] := ["lora_" actual_lora_count, 0]
    }
    if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
      if (actual_image_prompt_count and IPAdapter_combobox.Text and IPAdapter_combobox.Text != "None") {
        thought["refiner_lora_1"]["inputs"]["model"] := ["refiner_IPAdapter_apply_" actual_image_prompt_count, 0]
      }
      else {
        thought["refiner_lora_1"]["inputs"]["model"] := ["refiner_model_loader", 0]
      }
      thought["refiner_lora_1"]["inputs"]["clip"] := ["refiner_model_loader", 1]
      thought["refiner_prompt_positive"]["inputs"]["clip"] := ["refiner_lora_" actual_lora_count, 1]
      thought["refiner_prompt_negative"]["inputs"]["clip"] := ["refiner_lora_" actual_lora_count, 1]
      thought["refiner_sampler"]["inputs"]["model"] := ["refiner_lora_" actual_lora_count, 0]
    }
  }

  ;controlnet
  actual_controlnet_count := 0
  while (A_Index <= controlnet_active_listview.GetCount()) {
    ;only add controlnet rows which have a valid checkpoint and image selected
    if (controlnet_active_listview.GetText(A_Index, 1) and controlnet_active_listview.GetText(A_Index, 2) and controlnet_active_listview.GetText(A_Index, 2) != "None") {
      actual_controlnet_count += 1

      ;model loader node
      thought["controlnet_model_loader_" actual_controlnet_count] := Map(
        "inputs", Map(
          "control_net_name", controlnet_active_listview.GetText(A_Index, 2)
          ,"model", ["checkpoint_loader", 0]
        ),
        "class_type", "DiffControlNetLoader"
      )

      ;image loader node
      thought["controlnet_image_loader_" actual_controlnet_count] := Map(
        "inputs", Map(
          "image", server_image_files[controlnet_active_listview.GetText(A_Index, 1)]
          ,"choose file to upload", "image"
        ),
        "class_type", "LoadImage"
      )

      ;apply controlnet node
      ;the image input will come straight from the loader unless there's a preprocessor,
      ;in which case the input will get replaced further down
      thought["controlnet_apply_" actual_controlnet_count] := Map(
        "inputs", Map(
          "strength", controlnet_active_listview.GetText(A_Index, 3)
          ,"start_percent", controlnet_active_listview.GetText(A_Index, 4)
          ,"end_percent", controlnet_active_listview.GetText(A_Index, 5)
          ,"positive", ["controlnet_apply_" actual_controlnet_count - 1, 0]
          ,"negative", ["controlnet_apply_" actual_controlnet_count - 1, 1]
          ,"control_net", ["controlnet_model_loader_" actual_controlnet_count, 0]
          ,"image", ["controlnet_image_loader_" actual_controlnet_count, 0]
        ),
        "class_type", "ControlNetApplyAdvanced"
      )

      ;preprocessor
      ;if present, adjust noodle path
      if (controlnet_active_listview.GetText(A_Index, 6) and controlnet_active_listview.GetText(A_Index, 6) != "None") {
        actual_name := preprocessor_actual_name[controlnet_active_listview.GetText(A_Index, 6)]
        ;fill out bare minimum node for preprocessor
        thought["controlnet_preprocessor_" actual_controlnet_count] := Map(
          "inputs", Map(
            "image", ["controlnet_image_loader_" actual_controlnet_count, 0]
          )
          ,"class_type", actual_name
        )
        ;untangle the string
        if (controlnet_active_listview.GetText(A_Index, 7) != "") {
          Loop Parse controlnet_active_listview.GetText(A_Index, 7), "," {
            option_pair := StrSplit(A_LoopField, ":")
            thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"][option_pair[1]] := IsNumber(option_pair[2]) ? option_pair[2] + 0 : option_pair[2]
          }
        }

        ;check if the preprocessor needs a mask (inpainting) or resolution input
        if (scripture.Has(actual_name)) {
          for (optionality in scripture[actual_name]["input"]) {
            for (opt, value_properties in scripture[actual_name]["input"][optionality]) {
              if (opt = "resolution") {
                thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["resolution"] := image_width_edit.Value >= image_height_edit.Value ? image_width_edit.Value : image_height_edit.Value
                if (upscale_combobox.Text and upscale_combobox.Text != "None") {
                  thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["resolution"] := Round(thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["resolution"] * upscale_value_edit.Value)
                }
                else {
                  thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["resolution"] := Round(thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["resolution"])
                }
              }
              if (value_properties[1] = "MASK") {
                ;hijack the mask and re-noodle it
                if (inputs.Has("mask")) {
                  thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"][opt] := ["mask_feather", 0]
                  if (inputs.Has("source")) {
                    thought["main_sampler"]["inputs"]["latent_image"] := ["source_vae_encode", 0]
                  }
                  else {
                    thought["main_sampler"]["inputs"]["latent_image"] := ["empty_latent", 0]
                  }
                  if (upscale_combobox.Text and upscale_combobox.Text != "None") {
                    thought["upscale_sampler"]["inputs"]["latent_image"] := ["upscale_vae_encode", 0]
                    thought["upscale_vae_encode"]["inputs"]["pixels"] := ["upscale_resize", 0]
                  }
                }
                ;if no mask selected, allow it to fail
              }
            }
          }
        }
      }

      ;calculate which image noodle gets attached to controlnet_apply_# here for clarity
      if (controlnet_active_listview.GetText(A_Index, 6) and controlnet_active_listview.GetText(A_Index, 6) != "None") {
        ;if preprocessor
        thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_preprocessor_" actual_controlnet_count, 0]
      }
      else {
        ;no preprocessor
        thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_image_loader_" actual_controlnet_count, 0]
      }

      ;refiner
      if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
        thought["refiner_controlnet_apply_" actual_controlnet_count] := Map(
          "inputs", Map(
            "strength", thought["controlnet_apply_" actual_controlnet_count]["inputs"]["strength"]
            ,"start_percent", thought["controlnet_apply_" actual_controlnet_count]["inputs"]["start_percent"]
            ,"end_percent", thought["controlnet_apply_" actual_controlnet_count]["inputs"]["end_percent"]
            ,"positive", ["refiner_controlnet_apply_" actual_controlnet_count - 1, 0]
            ,"negative", ["refiner_controlnet_apply_" actual_controlnet_count - 1, 1]
            ,"control_net", thought["controlnet_apply_" actual_controlnet_count]["inputs"]["control_net"]
            ,"image", thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"]
          ),
          "class_type", "ControlNetApplyAdvanced"
        )
      }
    }
  }
  if (actual_controlnet_count) {
    if (actual_image_prompt_count and (!IPAdapter_combobox.Text or IPAdapter_combobox.Text = "None")) {
      thought["controlnet_apply_1"]["inputs"]["positive"] := ["unclip_conditioning_" actual_image_prompt_count, 0]
    }
    else {
      thought["controlnet_apply_1"]["inputs"]["positive"] := prompt_positive_edit.Text = "00" ? ["main_prompt_positive_zero_out", 0] : ["main_prompt_positive", 0]
    }
    thought["controlnet_apply_1"]["inputs"]["negative"] := prompt_negative_edit.Text = "00" ? ["main_prompt_negative_zero_out", 0] : ["main_prompt_negative", 0]
    thought["main_sampler"]["inputs"]["positive"] := ["controlnet_apply_" actual_controlnet_count, 0]
    thought["main_sampler"]["inputs"]["negative"] := ["controlnet_apply_" actual_controlnet_count, 1]
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      thought["upscale_sampler"]["inputs"]["positive"] := ["controlnet_apply_" actual_controlnet_count, 0]
      thought["upscale_sampler"]["inputs"]["negative"] := ["controlnet_apply_" actual_controlnet_count, 1]
    }
    if (refiner_combobox.Text and refiner_combobox.Text != "None" and refiner_conditioning_checkbox.Value) {
      if (actual_image_prompt_count and (!IPAdapter_combobox.Text or IPAdapter_combobox.Text = "None")) {
        thought["refiner_controlnet_apply_1"]["inputs"]["positive"] := ["refiner_unclip_conditioning_" actual_image_prompt_count, 0]
      }
      else {
        thought["refiner_controlnet_apply_1"]["inputs"]["positive"] := prompt_positive_edit.Text = "00" ? ["refiner_prompt_positive_zero_out", 0] : ["refiner_prompt_positive", 0]
      }
      thought["refiner_controlnet_apply_1"]["inputs"]["negative"] := prompt_negative_edit.Text = "00" ? ["refiner_prompt_negative_zero_out", 0] : ["refiner_prompt_negative", 0]
      thought["refiner_sampler"]["inputs"]["positive"] := ["refiner_controlnet_apply_" actual_controlnet_count, 0]
      thought["refiner_sampler"]["inputs"]["negative"] := ["refiner_controlnet_apply_" actual_controlnet_count, 1]
    }
  }

  ;adjust noodles if upscaling without sampling
  if (step_count_edit.Value = 0) {
    ;bypass the main sampling node
    thought["main_vae_decode"]["inputs"]["samples"] := thought["main_sampler"]["inputs"]["latent_image"]
    ;further bypass vae encode/decode if using a source image
    ;generally, this should only *not* happen if the user wishes to upscale an empty latent
    if (inputs.Has("source")) {
      source_image_exit_node := batch_size_edit.Value > 1 ? ["source_image_batcher_" image_batcher_node_count, 0] : ["source_image_loader", 0]
      if (upscale_combobox.Text and upscale_combobox.Text != "None") {
        if (upscale_using_model) {
          thought["upscale_with_model"]["inputs"]["image"] := source_image_exit_node
        }
        else {
          thought["upscale_resize"]["inputs"]["image"] := source_image_exit_node
        }
      }
      else {
        ;no main sampler and no upscale means the source image goes straight to output
        thought["save_image"]["inputs"]["images"] := source_image_exit_node
      }
    }
  }
  ;for upscaling and then not sampling,
  ;send the image directly to the saving node
  if (step_count_upscale_edit.Value = 0) {
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      thought["save_image"]["inputs"]["images"] := ["upscale_resize", 0]
    }
  }

  ;saving
  generation_time := thought["save_image"]["inputs"]["filename_prefix"] := A_Now

  prayer := Jxon_dump(Map("prompt", thought, "client_id", client_id))

  try {
    altar.Open("POST", "http://" server_address "/prompt", false)
    altar.Send(prayer)
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttp://" server_address "/prompt`n" altar.Status ": " altar.StatusText "`n" altar.ResponseText
    if (altar.Status = 200) {
      vision := Jxon_load(&response)
      images_to_download[generation_time] := vision["prompt_id"]
      Run assistant_script " " A_ScriptName " " server_address " " client_id " normal_job " vision["prompt_id"]
    }
    else {
      change_status("idle")
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    change_status("idle")
    return
  }
}

;send a simple job for previewing effects of masks and controlnet preprocessors
;--------------------------------------------------
preview_sidejob(picture_frame) {
  change_status("painting")

  dream := FileRead("workflows\preview_sidejob_api.json")
  thought := Jxon_load(&dream)

  preview_pictures_to_upload := Map()

  ;adjust nodes first because it's necessary to
  ;determine which images need to be uploaded
  ;...controlnet first because it may also need mask
  if (InStr(picture_frame["name"], "controlnet") = 1) {
    controlnet_current := controlnet_active_listview.GetCount() = 1 ? 1 : controlnet_active_listview.GetNext()
    if (controlnet_active_listview.GetText(controlnet_current, 6) and controlnet_active_listview.GetText(controlnet_current, 6) != "None" and inputs.Has(picture_frame["name"])) {
      actual_name := preprocessor_actual_name[controlnet_active_listview.GetText(controlnet_current, 6)]

      preview_pictures_to_upload["controlnet"] := inputs[picture_frame["name"]]

      ;same as dealing with preprocessors in a proper job
      ;fill out bare minimum node for preprocessor
      thought["controlnet_preprocessor"] := Map(
        "inputs", Map(
          "image", ["controlnet_image_loader", 0]
        )
        ,"class_type", actual_name
      )
      ;untangle the string
      if (controlnet_active_listview.GetText(controlnet_current, 7) != "") {
        Loop Parse controlnet_active_listview.GetText(controlnet_current, 7), "," {
          option_pair := StrSplit(A_LoopField, ":")
          thought["controlnet_preprocessor"]["inputs"][option_pair[1]] := IsNumber(option_pair[2]) ? option_pair[2] + 0 : option_pair[2]
        }
      }

      ;check if preprocessor needs mask
      if (scripture.Has(actual_name)) {
        for (optionality in scripture[actual_name]["input"]) {
          for (opt, value_properties in scripture[actual_name]["input"][optionality]) {
            if (opt = "resolution") {
              thought["controlnet_preprocessor"]["inputs"]["resolution"] := image_width_edit.Value >= image_height_edit.Value ? image_width_edit.Value : image_height_edit.Value
              if (upscale_combobox.Text and upscale_combobox.Text != "None") {
                thought["controlnet_preprocessor"]["inputs"]["resolution"] := Round(thought["controlnet_preprocessor"]["inputs"]["resolution"] * upscale_value_edit.Value)
              }
              else {
                thought["controlnet_preprocessor"]["inputs"]["resolution"] := Round(thought["controlnet_preprocessor"]["inputs"]["resolution"])
              }
            }
            if (value_properties[1] = "MASK") {
              if (inputs.Has("mask")) {
                preview_pictures_to_upload["mask"] := inputs["mask"]
                thought["controlnet_preprocessor"]["inputs"][opt] := ["mask_feather", 0]
              }
            }
          }
        }
      }
      thought["save_image"]["inputs"]["images"] := ["controlnet_preprocessor", 0]
    }
  }
  else if (picture_frame["name"] = "mask") {
    if (inputs.Has("mask")) {
      thought["save_image"]["inputs"]["images"] := ["mask_to_image", 0]
      preview_pictures_to_upload["mask"] := inputs["mask"]
    }
  }
  if (preview_pictures_to_upload.Has("mask")) {
    ;this is broken
    ;thought["mask_from_image"]["inputs"]["color"] := (mask_pixels_combobox.Text = "Black") ? 0 : (mask_pixels_combobox.Text = "White") ? 16777215 : mask_pixels_combobox.Text
    thought["mask_from_image"]["class_type"] := "ImageToMask"
    thought["mask_from_image"]["inputs"]["channel"] := mask_pixels_combobox.Text
    thought["mask_grow"]["inputs"]["expand"] := mask_grow_edit.Value
    thought["mask_feather"]["inputs"]["left"] := thought["mask_feather"]["inputs"]["top"] := thought["mask_feather"]["inputs"]["right"] := thought["mask_feather"]["inputs"]["bottom"] := mask_feather_edit.Value
  }

  ;upload image
  server_image_files := Map()
  if (preview_pictures_to_upload.Count) {
    for (picture, image_file in preview_pictures_to_upload) {
      try {
        altar.Open("POST", "http://" server_address "/upload/image", false)
        objParam := {overwrite: "true", image: [image_file], subfolder: "fluff"}
        CreateFormData(&offering, &hdr_ContentType, objParam)
        altar.SetRequestHeader("Content-Type", hdr_ContentType)
        altar.Send(offering)

        response := altar.ResponseText
        status_text.Text := FormatTime() "`nhttp://" server_address "/upload/image`n" altar.Status ": " altar.StatusText
        inspiration := Jxon_load(&response)
        if (inspiration.Has("subfolder") and inspiration.Has("name")) {
          server_image_files[picture "_preview"] := inspiration["subfolder"] "\" inspiration["name"]
        }
      }
      catch Error as what_went_wrong {
        oh_no(what_went_wrong)
        return
      }
    }
  }

  if (server_image_files.Has("mask_preview")) {
    thought["mask_image_loader"]["inputs"]["image"] := server_image_files["mask_preview"]
    thought["save_image"]["inputs"]["filename_prefix"] := "mask_preview"
  }
  if (server_image_files.Has("controlnet_preview")) {
    thought["controlnet_image_loader"]["inputs"]["image"] := server_image_files["controlnet_preview"]
    thought["save_image"]["inputs"]["filename_prefix"] := "controlnet_preview"
  }

  prayer := Jxon_dump(Map("prompt", thought, "client_id", client_id))
  try {
    altar.Open("POST", "http://" server_address "/prompt", false)
    altar.Send(prayer)
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttp://" server_address "/prompt`n" altar.Status ": " altar.StatusText "`n" altar.ResponseText
    if (altar.Status = 200) {
      vision := Jxon_load(&response)
      ;only dealing with a single image
      preview_image_to_download[picture_frame["name"]] := vision["prompt_id"]
      Run assistant_script " " A_ScriptName " " server_address " " client_id " preview_job " vision["prompt_id"]
    }
    else {
      change_status("idle")
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    change_status("idle")
  }
}

;attempt to download all images for which a download hasn't been attempted yet
;should only happen after generation is finished or failed
;--------------------------------------------------
download_images() {
  for (time, prompt_id in images_to_download) {
    try {
      altar.Open("GET", "http://" server_address "/history/" prompt_id, false)
      altar.Send()
      response := altar.ResponseText
      status_text.Text := FormatTime() "`nhttp://" server_address "/history/`n" prompt_id "`n" altar.Status ": " altar.StatusText
      history := Jxon_load(&response)
      if (history[prompt_id]["outputs"]["save_image"].Has("images")) {
        output_listview.Opt("-Redraw")
        for (output_image in history[prompt_id]["outputs"]["save_image"]["images"]) {
          url_values := "filename=" LC_UriEncode(output_image["filename"]) "&subfolder=" LC_UriEncode(output_image["subfolder"]) "&type=" LC_UriEncode(output_image["type"])
          Download "http://" server_address "/view?" url_values, output_folder output_image["filename"]
          output_listview.Add(,output_image["filename"], FormatTime(time, "[HH:mm:ss]") " " Format("{:05u}", A_Index))
        }
        output_listview.Opt("+Redraw")
        if (output_listview.GetCount()) {
          output_listview.Modify(1 ,"Select Vis")
          output_listview_itemselect(output_listview, "", "")
        }
      }
      images_to_download.Delete(time)
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
      if (images_to_download.Has(time)) {
        images_to_download.Delete(time)
      }
    }
  }
}

;similar to download_images
;should only ever get one image
;--------------------------------------------------
download_preview_images() {
  for (name, prompt_id in preview_image_to_download) {
    try {
      altar.Open("GET", "http://" server_address "/history/" prompt_id, false)
      altar.Send()
      response := altar.ResponseText
      status_text.Text := FormatTime() "`nhttp://" server_address "/history/`n" prompt_id "`n" altar.Status ": " altar.StatusText
      history := Jxon_load(&response)
      output_image := history[prompt_id]["outputs"]["save_image"]["images"][1]
      url_values := "filename=" LC_UriEncode(output_image["filename"]) "&subfolder=" LC_UriEncode(output_image["subfolder"]) "&type=" LC_UriEncode(output_image["type"])
      Download "http://" server_address "/view?" url_values, input_folder name "_preview.png"
      preview_image_to_download.Delete(name)

      preview_images[name] := input_folder name "_preview.png"
      ;change preview image directly here for mask
      if (name = "mask") {
        image_load_and_fit_wthout_change(input_folder name "_preview.png", mask_preview_picture_frame)
      }
      ;but for controlnet, refresh the listview to update to the "stored" image
      else {
        controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
      }
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
      if (preview_image_to_download.Has(name)) {
        preview_image_to_download.Delete(name)
      }
    }
  }
}

;interrupt current generation (if ongoing) and attempt to kill the assistant
;--------------------------------------------------
cancel_painting(*) {
  try {
    altar.Open("POST", "http://" server_address "/interrupt", false)
    altar.Send()
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttp://" server_address "/interrupt`n" altar.Status ": " altar.StatusText
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
  ;attempt salvage
  download_images()
  DetectHiddenWindows True
  if (WinExist(assistant_script " ahk_class AutoHotkey")) {
    WinKill
    if (WinExist(assistant_script " ahk_class AutoHotkey")) {
      status_text.Text := FormatTime() "`nAttempted to kill assistant but assistant is still alive."
    }
  }
  DetectHiddenWindows False
  change_status("idle")
}

;--------------------------------------------------
;horde communication
;--------------------------------------------------

;horde connect
;--------------------------------------------------
connect_to_horde(*) {
  try {
    altar.Open("GET", "https://" horde_address "/api/swagger.json", false)
    altar.Send()
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttps://" horde_address "/api/swagger.json`n" altar.Status ": " altar.StatusText
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return
  }
  global horde_scripture := Jxon_load(&response)

  ;image count
  horde_value_range(horde_batch_size_values, horde_scripture["definitions"]["ModelGenerationInputStable"]["allOf"][2]["properties"]["n"])
  horde_batch_size_updown.Opt("Range" horde_batch_size_values["minimum"] "-" horde_batch_size_values["maximum"])
  if (horde_batch_size_edit.Value) {
    number_cleanup(horde_batch_size_values["default"], horde_batch_size_values["minimum"], horde_batch_size_values["maximum"], horde_batch_size_edit)
  }
  else {
    horde_batch_size_edit.Value := horde_batch_size_values["default"]
  }

  ;samplers
  selected_option := horde_sampler_combobox.Text
  horde_sampler_combobox.Delete()
  horde_sampler_combobox.Add(horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["sampler_name"]["enum"])
  horde_sampler_combobox.Text := selected_option ? selected_option : horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["sampler_name"]["default"]

  ;clip skip
  horde_value_range(horde_clip_skip_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["clip_skip"])
  horde_clip_skip_updown.Opt("Range" horde_clip_skip_values["minimum"] "-" horde_clip_skip_values["maximum"])
  if (horde_clip_skip_edit.Value) {
    number_cleanup(horde_clip_skip_values["default"], horde_clip_skip_values["minimum"], horde_clip_skip_values["maximum"], horde_clip_skip_edit)
  }
  else {
    horde_clip_skip_edit.Value := horde_clip_skip_values["default"]
  }

  ;seed variation
  horde_value_range(horde_seed_variation_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["seed_variation"])
  horde_seed_variation_updown.Opt("Range" horde_seed_variation_values["minimum"] "-" horde_seed_variation_values["maximum"])
  if (horde_seed_variation_edit.Value) {
    number_cleanup(horde_seed_variation_values["default"], horde_seed_variation_values["minimum"], horde_seed_variation_values["maximum"], horde_seed_variation_edit)
  }
  else {
    horde_seed_variation_edit.Value := horde_seed_variation_values["default"]
  }

  ;steps
  horde_value_range(horde_step_count_values, horde_scripture["definitions"]["ModelGenerationInputStable"]["allOf"][2]["properties"]["steps"])
  horde_step_count_updown.Opt("Range" horde_step_count_values["minimum"] "-" horde_step_count_values["maximum"])
  if (horde_step_count_edit.Value) {
    number_cleanup(horde_step_count_values["default"], horde_step_count_values["minimum"], horde_step_count_values["maximum"], horde_step_count_edit)
  }
  else {
    horde_step_count_edit.Value := horde_step_count_values["default"]
  }

  ;cfg
  horde_value_range(horde_cfg_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["cfg_scale"])
  if (horde_cfg_edit.Value) {
    number_cleanup(horde_cfg_values["default"], horde_cfg_values["minimum"], horde_cfg_values["maximum"], horde_cfg_edit)
  }
  else {
    horde_cfg_edit.Value := horde_cfg_values["default"]
  }

  ;denoise
  horde_value_range(horde_denoise_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["denoising_strength"])
  if (horde_denoise_edit.Value) {
    number_cleanup(horde_denoise_values["default"], horde_denoise_values["minimum"], horde_denoise_values["maximum"], horde_denoise_edit)
  }
  else {
    horde_denoise_edit.Value := horde_denoise_values["default"]
  }

  ;width & height
  horde_value_range(horde_image_width_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["width"])
  horde_value_range(horde_image_height_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["height"])
  if (!horde_inputs.Has("horde_source")) {
    number_cleanup(horde_image_width_values["default"], horde_image_width_values["minimum"], horde_image_width_values["maximum"], horde_image_width_edit)
    number_cleanup(horde_image_height_values["default"], horde_image_height_values["minimum"], horde_image_height_values["maximum"], horde_image_height_edit)
    horde_image_width_edit_losefocus(horde_image_width_edit, "")
  }

  ;controlnet
  selected_option := horde_controlnet_type_combobox.Text
  horde_controlnet_type_combobox.Delete()
  horde_controlnet_type_combobox.Add(["None"])
  horde_controlnet_type_combobox.Add(horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["control_type"]["enum"])
  horde_controlnet_type_combobox.Text := selected_option ? selected_option : "None"

  ;post-processing
  horde_post_process_active_listview.Delete()
  for (,post_processing_option in horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["post_processing"]["items"]["enum"]) {
    horde_post_process_active_listview.Add(,post_processing_option)
  }

  ;facefixer strength
  horde_value_range(horde_facefixer_strength_values, horde_scripture["definitions"]["ModelPayloadRootStable"]["properties"]["denoising_strength"])
  if (horde_facefixer_strength_edit.Value) {
    number_cleanup(horde_facefixer_strength_values["default"], horde_facefixer_strength_values["minimum"], horde_facefixer_strength_values["maximum"], horde_facefixer_strength_edit)
  }
  else {
    horde_facefixer_strength_edit.Value := horde_facefixer_strength_values["default"]
  }

  ;lora strength
  horde_value_range(horde_lora_strength_values, horde_scripture["definitions"]["ModelPayloadLorasStable"]["properties"]["model"])
  if (horde_lora_strength_edit.Value) {
    number_cleanup(horde_lora_strength_values["default"], horde_lora_strength_values["minimum"], horde_lora_strength_values["maximum"], horde_lora_strength_edit)
  }
  else {
    horde_lora_strength_edit.Value := horde_lora_strength_values["default"]
  }

  ;lora inject trigger
  horde_value_range(horde_lora_inject_trigger_values, horde_scripture["definitions"]["ModelPayloadLorasStable"]["properties"]["inject_trigger"])
  horde_lora_inject_trigger_edit.Opt("Limit" horde_lora_inject_trigger_values["maxLength"])

  ;textual inversion strength
  horde_value_range(horde_textual_inversion_strength_values, horde_scripture["definitions"]["ModelPayloadTextualInversionsStable"]["properties"]["strength"])
  if (horde_textual_inversion_strength_edit.Value) {
    number_cleanup(horde_textual_inversion_strength_values["default"], horde_textual_inversion_strength_values["minimum"], horde_textual_inversion_strength_values["maximum"], horde_textual_inversion_strength_edit)
  }
  else {
    horde_textual_inversion_strength_edit.Value := horde_textual_inversion_strength_values["default"]
  }

  ;models
  if (horde_models := horde_update_models()) {
    selected_option := horde_checkpoint_combobox.Text
    horde_checkpoint_combobox.Delete()
    horde_checkpoint_combobox.Opt("-Redraw")
    horde_models_count := 0
    for (,model in horde_models) {
      horde_checkpoint_combobox.Add([model["name"] " (" model["count"] ")"])
      horde_models_count += 1
    }
    horde_checkpoint_combobox.Opt("+Redraw")
    if (selected_option!= "") {
      horde_checkpoint_combobox.Text := selected_option
    }
    else {
      horde_checkpoint_combobox.Value := Random(1, horde_models_count)
    }
  }

  update_kudos()
}

;horde update models
;--------------------------------------------------
horde_update_models(*) {
  try {
    altar.Open("GET", "https://" horde_address "/api/v2/status/models?type=image", false)
    altar.Send()
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttps://" horde_address "/api/v2/status/models?type=image`n" altar.Status ": " altar.StatusText
    return Jxon_load(&response)
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;horde value range
;--------------------------------------------------
horde_value_range(value_map, map_location) {
  if (map_location.Has("default")) {
    value_map["default"] := map_location["default"]
  }
  if (map_location.Has("minimum")) {
    value_map["minimum"] := map_location["minimum"]
  }
  if (map_location.Has("maximum")) {
    value_map["maximum"] := map_location["maximum"]
  }
  if (map_location.Has("multipleOf")) {
    value_map["multipleOf"] := map_location["multipleOf"]
    value_map["dp"] := InStr(value_map["multipleOf"], ".") ? Strlen(value_map["multipleOf"]) - (InStr(value_map["multipleOf"], ".")) : 0
  }
  if (value_map.Has("dp")) {
    value_map["default"] := Format("{:." value_map["dp"] "f}", value_map["default"])
    value_map["minimum"] := Format("{:." value_map["dp"] "f}", value_map["minimum"])
    value_map["maximum"] := Format("{:." value_map["dp"] "f}", value_map["maximum"])
  }
  if (map_location.Has("maxLength")) {
    value_map["maxLength"] := map_location["maxLength"]
  }
}

;horde update kudos
;--------------------------------------------------
update_kudos(*) {
  try {
    altar.Open("GET", "https://" horde_address "/api/v2/find_user", false)
    altar.SetRequestHeader("accept", "application/json")
    altar.SetRequestHeader("apikey", horde_api_key)
    altar.Send()

    response := altar.ResponseText
    horde_worth := Jxon_load(&response)

    if (horde_worth.Has("message")) {
      status_text.Text := FormatTime() "`nhttps://" horde_address "/api/v2/find_user`n" altar.Status ": " altar.StatusText "`n" horde_worth["message"]
    }

    if (altar.Status = 200) {
      kudos_text.Text := Round(horde_worth["kudos"]) " Kudos"
    }
    else {
      FileAppend("[" A_Now "]`nhttps://" horde_address "/api/v2/find_user`n" altar.Status ": " altar.StatusText "`n" response "`n", "log", "utf-8")
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;--------------------------------------------------
;horde painting
;--------------------------------------------------

;horde generate
;--------------------------------------------------
summon_the_horde(*) {
  try {
    horde_thought := Map()
    if (horde_prompt_positive_edit.Text or horde_prompt_negative_edit.Text) {
      horde_thought["prompt"] := horde_prompt_positive_edit.Text "###" horde_prompt_negative_edit.Text
    }

    horde_thought["params"] := Map()
    horde_thought["params"]["sampler_name"] := horde_sampler_combobox.Text
    horde_thought["params"]["cfg_scale"] := horde_cfg_edit.Value + 0
    horde_thought["params"]["denoising_strength"] := horde_denoise_edit.Value + 0
    ;if (horde_random_seed_checkbox.Value) {
    ;  horde_seed_edit.Text := horde_thought["params"]["seed"] := Random(0x7FFFFFFFFFFFFFFF) ""
    ;}
    ;else {
    ;  horde_thought["params"]["seed"] := horde_seed_edit.Text ""
    ;}
    horde_thought["params"]["height"] := horde_image_height_edit.Value + 0
    horde_thought["params"]["width"] := horde_image_width_edit.Value + 0
    ;horde_thought["params"]["seed_variation"] := horde_seed_variation_edit.Value + 0
    if (next_post := horde_post_process_active_listview.GetNext(0, "C")) {
      horde_thought["params"]["post_processing"] := [horde_post_process_active_listview.GetText(next_post, 1)]
      while (next_post := horde_post_process_active_listview.GetNext(next_post, "C")) {
        horde_thought["params"]["post_processing"].Push(horde_post_process_active_listview.GetText(next_post, 1))
      }
    }
    horde_thought["params"]["karras"] := horde_karras_checkbox.Value ? "true" : "false"
    horde_thought["params"]["tiling"] := horde_tiling_checkbox.Value ? "true" : "false"
    horde_thought["params"]["hires_fix"] := horde_hires_fix_checkbox.Value ? "true" : "false"
    horde_thought["params"]["clip_skip"] := horde_clip_skip_edit.Value + 0
    if (horde_inputs.Has("horde_source") and horde_controlnet_type_combobox.Text and horde_controlnet_type_combobox.Text != "None") {
      horde_thought["params"]["control_type"] := horde_controlnet_type_combobox.Text
      horde_thought["params"]["image_is_control"] := horde_controlnet_option_dropdownlist.Value = 2 ? "true" : "false"
      horde_thought["params"]["return_control_map"] := horde_controlnet_option_dropdownlist.Value = 3 ? "true" : "false"
    }
    horde_thought["params"]["facefixer_strength"] := horde_facefixer_strength_edit.Value + 0

    actual_lora_array := Array()
    while (A_Index <= horde_lora_active_listview.GetCount()) {
      lora_name := horde_lora_active_listview.GetText(A_Index, 1)
      if (lora_name and lora_name != "None") {
        actual_lora_array.Push(
          Map(
            "name", lora_name
            ,"model", horde_lora_active_listview.GetText(A_Index, 2) + 0
            ,"clip", horde_lora_active_listview.GetText(A_Index, 2) + 0
          )
        )
        if (horde_lora_active_listview.GetText(A_Index, 3)) {
          actual_lora_array[-1]["inject_trigger"] := horde_lora_active_listview.GetText(A_Index, 3)
        }
      }
    }
    if (actual_lora_array.Length) {
      horde_thought["params"]["loras"] := actual_lora_array
    }

    actual_ti_array := Array()
    while (A_Index <= horde_textual_inversion_active_listview.GetCount()) {
      ti_name := horde_textual_inversion_active_listview.GetText(A_Index, 1)
      if (ti_name and ti_name != "None") {
        actual_ti_array.Push(
          Map(
            "name", ti_name
          )
        )
        if (horde_textual_inversion_active_listview.GetText(A_Index, 2) != "Manual") {
          actual_ti_array[-1]["inject_ti"] := horde_textual_inversion_active_listview.GetText(A_Index, 2) = "Negative" ? "negprompt" : "prompt"
          actual_ti_array[-1]["strength"] := horde_textual_inversion_active_listview.GetText(A_Index, 3) + 0
        }
      }
    }
    if (actual_ti_array.Length) {
      horde_thought["params"]["tis"] := actual_ti_array
    }

    horde_thought["params"]["steps"] := horde_step_count_edit.Value + 0
    ;horde_thought["params"]["n"] := horde_batch_size_edit.Value + 0
    horde_thought["params"]["n"] := 1


    horde_thought["nsfw"] := horde_allow_nsfw_checkbox.Value ? "true" : "false"
    horde_thought["trusted_workers"] := horde_allow_untrusted_workers_checkbox.Value ? "false" : "true"
    horde_thought["slow_workers"] := horde_allow_slow_workers_checkbox.Value ? "true" : "false"
    horde_thought["censor_nsfw"] := horde_allow_nsfw_checkbox.Value ? "false" : "true"
    if (horde_use_specific_worker != "") {
      horde_thought["workers"] :=  [horde_use_specific_worker]
    }
    ;not implemented
    ;horde_thought["worker_blacklist"] := "false"

    if (InStr(horde_checkpoint_combobox.Text, ")",, -1, -1) = StrLen(horde_checkpoint_combobox.Text)) {
      horde_thought["models"] := [SubStr(horde_checkpoint_combobox.Text, 1, InStr(horde_checkpoint_combobox.Text, "(",, -1) - 2)]
    }
    else {
      horde_thought["models"] := [horde_checkpoint_combobox.Text]
    }

    if (horde_inputs.Has("horde_source")) {
      horde_thought["source_image"] := encode_image_file_to_base64(horde_inputs["horde_source"])
      if (horde_inputs.Has("horde_mask")) {
        horde_thought["source_mask"] := encode_image_file_to_base64(horde_inputs["horde_mask"])
        horde_thought["source_processing"] := "inpainting"
      }
      else {
        horde_thought["source_processing"] := "img2img"
      }
    }

    horde_thought["r2"] := "true"
    horde_thought["shared"] := horde_share_with_laion_checkbox.Value ? "true" : "false"
    horde_thought["replacement_filter"] := horde_replacement_filter_checkbox.Value ? "true" : "false"
    horde_thought["dry_run"] := "false"

    ;sidestep issues with seed variation and n
    ;using a loop to send batches of 1
    if (IsInteger(horde_seed_edit.Text) and horde_seed_edit.Text >= 0 and horde_seed_edit.Text + horde_batch_size_edit.Value - 1 <= 4294967295) {
      seed_treatment := "int"
    }
    else {
      seed_treatment := "str"
    }
    loop horde_batch_size_edit.Value {
      if (horde_random_seed_checkbox.Value) {
        horde_seed_edit.Text := horde_thought["params"]["seed"] := Random(4294967295) ""
      }
      else {
        if (A_Index = 1) {
          base_seed := horde_thought["params"]["seed"] := horde_seed_edit.Text
        }
        else {
          if (seed_treatment = "int") {
            horde_thought["params"]["seed"] := base_seed + A_Index - 1 . ""
          }
          else if (seed_treatment = "str") {
            horde_thought["params"]["seed"] := base_seed " " A_Index - 1
          }
        }
      }
      horde_prayer := Jxon_dump(horde_thought)
      altar.Open("POST", "https://" horde_address "/api/v2/generate/async", false)
      altar.SetRequestHeader("accept", "application/json")
      altar.SetRequestHeader("apikey", horde_api_key)
      altar.SetRequestHeader("Content-Type", "application/json")
      altar.Send(horde_prayer)

      response := altar.ResponseText
      horde_vision := Jxon_load(&response)
      message_to_display := FormatTime() "`nhttps://" horde_address "/api/v2/generate/async`n" altar.Status ": " altar.StatusText
      if (altar.Status = 202) {
        message_to_display .= "`n" horde_vision["id"]
        try {
          DetectHiddenWindows True
          if (!WinExist(horde_assistant_script " ahk_class AutoHotkey")) {
            Run horde_assistant_script " " A_ScriptName " " horde_address " horde_job " horde_vision["id"]
          }
          else {
            con_struct_ion := string_to_message(Jxon_dump([A_ScriptName, horde_address, "horde_job", horde_vision["id"]]))
            response_value := SendMessage(0x004A, 0, con_struct_ion)
          }
          horde_generation_status_listview.Add(,horde_vision["id"],,,,,,,,,,, "Request Received")
          ;remove image files in order to save history
          horde_thought_for_history :=  horde_thought.Clone()
          if (horde_thought_for_history.Has("source_image")) {
            horde_thought_for_history["source_image"] := "redacted for brevity"
            if (horde_thought_for_history.Has("source_mask")) {
              horde_thought_for_history["source_mask"] := "redacted for brevity"
            }
          }
          IniWrite(Jxon_dump(horde_thought_for_history), horde_output_folder "history.ini", horde_vision["id"], "Request")
        }
        catch Error as what_went_wrong {
          oh_no(what_went_wrong)
        }
        finally {
          DetectHiddenWindows False
        }
      }
      else if (altar.Status != 200) {
        FileAppend("[" A_Now "]`nhttps://" horde_address "/api/v2/generate/async`n" altar.Status ": " altar.StatusText "`n" response "`n", "log", "utf-8")
      }
      if (horde_vision.Has("message")) {
        message_to_display .= "`n" horde_vision["message"]
      }
      status_text.Text := message_to_display
    }
    update_kudos()
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;horde download image
;--------------------------------------------------
horde_download_image(prompt_id) {
  try {
    altar.Open("GET", "https://" horde_address "/api/v2/generate/status/" prompt_id, false)
    altar.Send()
    response := altar.ResponseText
    status_text.Text := FormatTime() "`nhttps://" horde_address "/api/v2/generate/status/`n" prompt_id "`n" altar.Status ": " altar.StatusText
    history := Jxon_load(&response)
    if (history.Has("generations")) {
      time := A_Now
      horde_output_listview.Opt("-Redraw")
      for (output_image in history["generations"]) {
        destination_file_name := time "_" Format("{:05u}", A_Index) "_.webp"
        Download output_image["img"], horde_output_folder destination_file_name
        horde_output_listview.Add(, destination_file_name, FormatTime(time, "[HH:mm:ss]") " " Format("{:05u}", A_Index))
        IniWrite(output_image["id"] " - Worker: " output_image["worker_name"] " (" output_image["worker_id"] ")", horde_output_folder "history.ini", prompt_id, destination_file_name " ")
      }
      horde_output_listview.Opt("+Redraw")
      if (horde_output_listview.GetCount()) {
        horde_output_listview.Modify(1 ,"Select Vis")
        horde_output_listview_itemselect(horde_output_listview, "", "")
      }
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;--------------------------------------------------
;save states
;--------------------------------------------------

save_state(slot_id) {
  if (!DirExist(save_folder)) {
    try {
      DirCreate save_folder
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
      return
    }
  }

  save_name := overlay_current "_" slot_id
  try {
    if (overlay_current = "comfy") {
      string_of_pairs := (
        "batch_size=" batch_size_edit.Value
        "`ncheckpoint=" checkpoint_combobox.Text
        "`nvae=" vae_combobox.Text
        "`nsampler=" sampler_combobox.Text
        "`nscheduler=" scheduler_combobox.Text
        "`nprompt_positive=" prompt_positive_edit.Text
        "`nprompt_negative=" prompt_negative_edit.Text
        "`nseed=" seed_edit.Value
        "`nrandom_seed=" random_seed_checkbox.Value
        "`nstep_count=" step_count_edit.Value
        "`ncfg=" cfg_edit.Value
        "`ndenoise=" denoise_edit.Value
        "`nupscale=" upscale_combobox.Text
        "`nstep_count_upscale=" step_count_upscale_edit.Value
        "`ncfg_upscale=" cfg_upscale_edit.Value
        "`ndenoise_upscale=" denoise_upscale_edit.Value
        "`nupscale_value=" upscale_value_edit.Value
        "`nrandom_seed_upscale=" random_seed_upscale_checkbox.Value
        "`nrefiner=" refiner_combobox.Text
        "`nrefiner_start_step=" refiner_start_step_edit.Value
        "`ncfg_refiner=" cfg_refiner_edit.Value
        "`nrandom_seed_refiner=" random_seed_refiner_checkbox.Value
        "`nrefiner_conditioning=" refiner_conditioning_checkbox.Value
      )

      string_of_pairs .= (
        "`nsource_image=" (inputs.Has("source") ? "source" : "")
        "`nimage_width=" image_width_edit.Value
        "`nimage_height=" image_height_edit.Value
      )

      string_of_pairs .= (
        "`nclip_vision=" clip_vision_combobox.Text
        "`nIPAdapter=" IPAdapter_combobox.Text
      )

      while (A_Index <= image_prompt_active_listview.GetCount()) {
        string_of_pairs .= (
        "`nimage_prompt_" A_Index "_image=" image_prompt_active_listview.GetText(A_Index, 1)
        "`nimage_prompt_" A_Index "_strength=" image_prompt_active_listview.GetText(A_Index, 2)
        "`nimage_prompt_" A_Index "_noise=" image_prompt_active_listview.GetText(A_Index, 3)
        )
      }

      while (A_Index <= lora_active_listview.GetCount()) {
        string_of_pairs .= (
        "`nlora_" A_Index "_name=" lora_active_listview.GetText(A_Index, 1)
        "`nlora_" A_Index "_strength=" lora_active_listview.GetText(A_Index, 2)
        )
      }

      string_of_pairs .= (
        "`nmask_image=" (inputs.Has("mask") ? "mask" : "")
        "`nmask_pixels=" mask_pixels_combobox.Text
        "`nmask_grow=" mask_grow_edit.Value
        "`nmask_feather=" mask_feather_edit.Value
        "`ninpainting_checkpoint=" inpainting_checkpoint_checkbox.Value
      )

      while (A_Index <= controlnet_active_listview.GetCount()) {
        string_of_pairs .= (
        "`ncontrolnet_" A_Index "_image=" controlnet_active_listview.GetText(A_Index, 1)
        "`ncontrolnet_" A_Index "_checkpoint=" controlnet_active_listview.GetText(A_Index, 2)
        "`ncontrolnet_" A_Index "_strength=" controlnet_active_listview.GetText(A_Index, 3)
        "`ncontrolnet_" A_Index "_start=" controlnet_active_listview.GetText(A_Index, 4)
        "`ncontrolnet_" A_Index "_end=" controlnet_active_listview.GetText(A_Index, 5)
        "`ncontrolnet_" A_Index "_preprocessor=" controlnet_active_listview.GetText(A_Index, 6)
        "`ncontrolnet_" A_Index "_preprocessor_options=" controlnet_active_listview.GetText(A_Index, 7)
        )
      }

      IniWrite(string_of_pairs, save_folder save_name ".ini", "save")

      FileDelete(save_folder save_name "_*.*")
      for (existing_image, image_file in inputs) {
        SplitPath image_file, &original_file_name
        FileCopy(image_file, save_folder save_name "_" original_file_name, 1)
        IniWrite(save_name "_" original_file_name, save_folder save_name ".ini", "save", "inputs_" existing_image)
      }
    }
    else if (overlay_current = "horde") {
      string_of_pairs := (
        "horde_batch_size=" horde_batch_size_edit.Value
        "`nhorde_checkpoint=" horde_checkpoint_combobox.Text
        "`nhorde_sampler=" horde_sampler_combobox.Text
        "`nhorde_clip_skip=" horde_clip_skip_edit.Value
        "`nhorde_karras=" horde_karras_checkbox.Value
        "`nhorde_hires_fix=" horde_hires_fix_checkbox.Value
        "`nhorde_tiling=" horde_tiling_checkbox.Value
        "`nhorde_prompt_positive=" horde_prompt_positive_edit.Text
        "`nhorde_prompt_negative=" horde_prompt_negative_edit.Text
        "`nhorde_seed=" horde_seed_edit.Text
        "`nhorde_random_seed=" horde_random_seed_checkbox.Value
        "`nhorde_seed_variation=" horde_seed_variation_edit.Value
        "`nhorde_step_count=" horde_step_count_edit.Value
        "`nhorde_cfg=" horde_cfg_edit.Value
        "`nhorde_denoise=" horde_denoise_edit.Value
      )

      string_of_pairs .= (
        "`nhorde_controlnet_type=" horde_controlnet_type_combobox.Text
        "`nhorde_controlnet_option=" horde_controlnet_option_dropdownlist.Value
        "`nhorde_source_image=" (horde_inputs.Has("horde_source") ? "horde_source" : "")
        "`nhorde_mask_image=" (horde_inputs.Has("horde_mask") ? "horde_mask" : "")
        "`nhorde_image_width=" horde_image_width_edit.Value
        "`nhorde_image_height=" horde_image_height_edit.Value
      )

      if (next_post := horde_post_process_active_listview.GetNext(0, "C")) {
        string_of_pairs .= "`nhorde_post_processing_1=" horde_post_process_active_listview.GetText(next_post, 1)
        while (next_post := horde_post_process_active_listview.GetNext(next_post, "C")) {
          string_of_pairs .= "`nhorde_post_processing_" A_Index + 1 "=" horde_post_process_active_listview.GetText(next_post, 1)
        }
      }
      else {
        string_of_pairs .= "`nhorde_post_processing_1="
      }

      string_of_pairs .= "`nhorde_facefixer_strength=" horde_facefixer_strength_edit.Value

      while (A_Index <= horde_lora_active_listview.GetCount()) {
        string_of_pairs .= (
        "`nhorde_lora_" A_Index "_name=" horde_lora_active_listview.GetText(A_Index, 1)
        "`nhorde_lora_" A_Index "_strength=" horde_lora_active_listview.GetText(A_Index, 2)
        "`nhorde_lora_" A_Index "_inject_trigger=" horde_lora_active_listview.GetText(A_Index, 3)
        )
      }

      while (A_Index <= horde_textual_inversion_active_listview.GetCount()) {
        string_of_pairs .= (
        "`nhorde_textual_inversion_" A_Index "_name=" horde_textual_inversion_active_listview.GetText(A_Index, 1)
        "`nhorde_textual_inversion_" A_Index "_inject_field=" horde_textual_inversion_active_listview.GetText(A_Index, 2)
        "`nhorde_textual_inversion_" A_Index "_strength=" horde_textual_inversion_active_listview.GetText(A_Index, 3)
        )
      }

      IniWrite(string_of_pairs, save_folder save_name ".ini", "save")

      FileDelete(save_folder save_name "_*.*")
      for (existing_image, image_file in horde_inputs) {
        SplitPath image_file, &original_file_name
        FileCopy(image_file, save_folder save_name "_" original_file_name, 1)
        IniWrite(save_name "_" original_file_name, save_folder save_name ".ini", "save", "horde_inputs_" existing_image)
      }
    }
    status_text.Text := FormatTime() "`nSaved`n" save_name
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

load_state(slot_id) {
  save_name := overlay_current "_" slot_id
  try {
    if (overlay_current = "comfy" and assistant_status = "idle") {
      batch_size_edit.Value := IniRead(save_folder save_name ".ini", "save", "batch_size", batch_size_edit.Value)
      checkpoint_combobox.Text := IniRead(save_folder save_name ".ini", "save", "checkpoint", checkpoint_combobox.Text)
      vae_combobox.Text := IniRead(save_folder save_name ".ini", "save", "vae", vae_combobox.Text)
      sampler_combobox.Text := IniRead(save_folder save_name ".ini", "save", "sampler", sampler_combobox.Text)
      scheduler_combobox.Text := IniRead(save_folder save_name ".ini", "save", "scheduler", scheduler_combobox.Text)
      prompt_positive_edit.Text := IniRead(save_folder save_name ".ini", "save", "prompt_positive", prompt_positive_edit.Text)
      prompt_negative_edit.Text := IniRead(save_folder save_name ".ini", "save", "prompt_negative", prompt_negative_edit.Text)
      seed_edit.Value := IniRead(save_folder save_name ".ini", "save", "seed", seed_edit.Value)
      random_seed_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "random_seed", random_seed_checkbox.Value)
      random_seed_checkbox_click(random_seed_checkbox, "")
      step_count_edit.Value := IniRead(save_folder save_name ".ini", "save", "step_count", step_count_edit.Value)
      cfg_edit.Value := IniRead(save_folder save_name ".ini", "save", "cfg", cfg_edit.Value)
      denoise_edit.Value := IniRead(save_folder save_name ".ini", "save", "denoise", denoise_edit.Value)
      upscale_combobox.Text := IniRead(save_folder save_name ".ini", "save", "upscale", upscale_combobox.Text)
      upscale_combobox_change(upscale_combobox, "")
      step_count_upscale_edit.Value := IniRead(save_folder save_name ".ini", "save", "step_count_upscale", step_count_upscale_edit.Value)
      cfg_upscale_edit.Value := IniRead(save_folder save_name ".ini", "save", "cfg_upscale", cfg_upscale_edit.Value)
      denoise_upscale_edit.Value := IniRead(save_folder save_name ".ini", "save", "denoise_upscale", denoise_upscale_edit.Value)
      upscale_value_edit.Value := IniRead(save_folder save_name ".ini", "save", "upscale_value", upscale_value_edit.Value)
      random_seed_upscale_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "random_seed_upscale", random_seed_upscale_checkbox.Value)
      refiner_combobox.Text := IniRead(save_folder save_name ".ini", "save", "refiner", refiner_combobox.Text)
      refiner_combobox_change(refiner_combobox, "")
      refiner_start_step_edit.Value := IniRead(save_folder save_name ".ini", "save", "refiner_start_step", refiner_start_step_edit.Value)
      cfg_refiner_edit.Value := IniRead(save_folder save_name ".ini", "save", "cfg_refiner", cfg_refiner_edit.Value)
      random_seed_refiner_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "random_seed_refiner", random_seed_refiner_checkbox.Value)
      refiner_conditioning_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "refiner_conditioning", refiner_conditioning_checkbox.Value)

      if(IniRead(save_folder save_name ".ini", "save", "source_image", "option_not_found") != "option_not_found") {
        main_preview_picture_menu_remove("", "", "")
        if (inputs.Has("source")) {
          inputs.Delete("source")
        }
        if (source_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "inputs_source", "")) {
          if (valid_file := image_load_and_fit(save_folder source_input_file_to_load, main_preview_picture_frame)) {
            inputs["source"] := valid_file
            main_preview_picture_update(0)
          }
        }
        else {
          image_width_edit.Value := IniRead(save_folder save_name ".ini", "save", "image_width", image_width_edit.Value)
          image_height_edit.Value := IniRead(save_folder save_name ".ini", "save", "image_height", image_height_edit.Value)
          image_width_edit_losefocus(image_width_edit, "")
          image_height_edit_losefocus(image_height_edit, "")
        }
      }

      clip_vision_combobox.Text := IniRead(save_folder save_name ".ini", "save", "clip_vision", clip_vision_combobox.Text)
      IPAdapter_combobox.Text := IniRead(save_folder save_name ".ini", "save", "IPAdapter", IPAdapter_combobox.Text)

      ;this just checks for the first row in the saved listview
      ;"option_not_found" means that there's no value in the save file
      ;as opposed to the value existing, but being empty
      if (IniRead(save_folder save_name ".ini", "save", "image_prompt_1_image", "option_not_found") != "option_not_found") {
        while (A_Index <= image_prompt_active_listview.GetCount()) {
          if (inputs.Has(image_prompt_image_to_clear := image_prompt_active_listview.GetText(A_Index, 1))) {
            inputs.Delete(image_prompt_image_to_clear)
          }
        }
        image_prompt_active_listview.Delete()
        while ((image_prompt_image := IniRead(save_folder save_name ".ini", "save", "image_prompt_" A_Index "_image", "option_not_found")) != "option_not_found") {
          if ((image_prompt_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "inputs_" image_prompt_image, "")) and FileExist(save_folder image_prompt_input_file_to_load)) {
            SplitPath image_prompt_input_file_to_load,,, &original_file_extension
            FileCopy(save_folder image_prompt_input_file_to_load, input_folder image_prompt_image "." original_file_extension, 1)
            inputs[image_prompt_image] := input_folder image_prompt_image "." original_file_extension
          }
          image_prompt_active_listview.Add(, inputs.Has(image_prompt_image) ? image_prompt_image : "", IniRead(save_folder save_name ".ini", "save", "image_prompt_" A_Index "_strength", ""), IniRead(save_folder save_name ".ini", "save", "image_prompt_" A_Index "_noise", ""))
        }
        image_prompt_active_listview.Modify(1 ,"Select Vis")
        image_prompt_active_listview_itemselect(image_prompt_active_listview, "", "")
      }

      if (IniRead(save_folder save_name ".ini", "save", "lora_1_name", "option_not_found") != "option_not_found") {
        lora_active_listview.Delete()
        while ((lora_name := IniRead(save_folder save_name ".ini", "save", "lora_" A_Index "_name", "option_not_found")) != "option_not_found") {
          lora_active_listview.Add(, lora_name, IniRead(save_folder save_name ".ini", "save", "lora_" A_Index "_strength", ""))
        }
        lora_active_listview.Modify(1 ,"Select Vis")
        lora_active_listview_itemselect(lora_active_listview, "", "")
      }

      mask_pixels_combobox.Text := IniRead(save_folder save_name ".ini", "save", "mask_pixels", mask_pixels_combobox.Text)
      mask_grow_edit.Value := IniRead(save_folder save_name ".ini", "save", "mask_grow", mask_grow_edit.Value)
      mask_feather_edit.Value := IniRead(save_folder save_name ".ini", "save", "mask_feather", mask_feather_edit.Value)
      inpainting_checkpoint_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "inpainting_checkpoint", inpainting_checkpoint_checkbox.Value)

      if(IniRead(save_folder save_name ".ini", "save", "mask_image", "option_not_found") != "option_not_found") {
        mask_picture_menu_remove("", "", "")
        if (mask_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "inputs_mask", "")) {
          if (inputs.Has("mask")) {
            inputs.Delete("mask")
          }
          if (valid_file := image_load_and_fit(save_folder mask_input_file_to_load, mask_picture_frame)) {
            inputs["mask"] := valid_file
          }
        }
      }

      if (IniRead(save_folder save_name ".ini", "save", "controlnet_1_image", "option_not_found") != "option_not_found") {
        while (A_Index <= controlnet_active_listview.GetCount()) {
          if (inputs.Has(controlnet_image_to_clear := controlnet_active_listview.GetText(A_Index, 1))) {
            inputs.Delete(controlnet_image_to_clear)
            if (preview_images.Has(controlnet_image_to_clear)) {
              preview_images.Delete(controlnet_image_to_clear)
            }
          }
        }
        controlnet_active_listview.Delete()
        while ((controlnet_image := IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_image", "option_not_found")) != "option_not_found") {
          if ((controlnet_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "inputs_" controlnet_image, "")) and FileExist(save_folder controlnet_input_file_to_load)) {
            SplitPath controlnet_input_file_to_load,,, &original_file_extension
            FileCopy(save_folder controlnet_input_file_to_load, input_folder controlnet_image "." original_file_extension, 1)
            inputs[controlnet_image] := input_folder controlnet_image "." original_file_extension
          }
          controlnet_active_listview.Add(, inputs.Has(controlnet_image) ? controlnet_image : "", IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_checkpoint", ""), IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_strength", ""), IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_start", ""), IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_end", ""), IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_preprocessor", ""), IniRead(save_folder save_name ".ini", "save", "controlnet_" A_Index "_preprocessor_options", ""))
        }
        controlnet_active_listview.Modify(1 ,"Select Vis")
        controlnet_active_listview_itemselect(controlnet_active_listview, "", "")
      }

    }
    else if (overlay_current = "horde") {
      horde_batch_size_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_batch_size", horde_batch_size_edit.Value)
      horde_checkpoint_combobox.Text := IniRead(save_folder save_name ".ini", "save", "horde_checkpoint", horde_checkpoint_combobox.Text)
      horde_sampler_combobox.Text := IniRead(save_folder save_name ".ini", "save", "horde_sampler", horde_sampler_combobox.Text)
      horde_clip_skip_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_clip_skip", horde_clip_skip_edit.Value)
      horde_karras_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "horde_karras", horde_karras_checkbox.Value)
      horde_hires_fix_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "horde_hires_fix", horde_hires_fix_checkbox.Value)
      horde_tiling_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "horde_tiling", horde_tiling_checkbox.Value)
      horde_prompt_positive_edit.Text := IniRead(save_folder save_name ".ini", "save", "horde_prompt_positive", horde_prompt_positive_edit.Text)
      horde_prompt_negative_edit.Text := IniRead(save_folder save_name ".ini", "save", "horde_prompt_negative", horde_prompt_negative_edit.Text)
      horde_seed_edit.Text := IniRead(save_folder save_name ".ini", "save", "horde_seed", horde_seed_edit.Text)
      horde_random_seed_checkbox.Value := IniRead(save_folder save_name ".ini", "save", "horde_random_seed", horde_random_seed_checkbox.Value)
      horde_random_seed_checkbox_click(horde_random_seed_checkbox, "")
      horde_seed_variation_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_seed_variation", horde_seed_variation_edit.Value)
      horde_step_count_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_step_count", horde_step_count_edit.Value)
      horde_cfg_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_cfg", horde_cfg_edit.Value)
      horde_denoise_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_denoise", horde_denoise_edit.Value)

      horde_controlnet_type_combobox.Text := IniRead(save_folder save_name ".ini", "save", "horde_controlnet_type", horde_controlnet_type_combobox.Text)
      horde_controlnet_option_dropdownlist.Value := IniRead(save_folder save_name ".ini", "save", "horde_controlnet_option", horde_controlnet_option_dropdownlist.Value)

      if(IniRead(save_folder save_name ".ini", "save", "horde_source_image", "option_not_found") != "option_not_found") {
        horde_source_picture_menu_remove("", "", "")
        if (horde_inputs.Has("horde_source")) {
          horde_inputs.Delete("horde_source")
        }
        if (horde_source_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "horde_inputs_horde_source", "")) {
          if (valid_file := image_load_and_fit(save_folder horde_source_input_file_to_load, horde_source_picture_frame)) {
            horde_inputs["horde_source"] := valid_file
            horde_source_picture_update(0)
          }
        }
      }

      if(IniRead(save_folder save_name ".ini", "save", "horde_mask_image", "option_not_found") != "option_not_found") {
        horde_mask_picture_menu_remove("", "", "")
        if (horde_inputs.Has("horde_mask")) {
          horde_inputs.Delete("horde_mask")
        }
        if (horde_mask_input_file_to_load := IniRead(save_folder save_name ".ini", "save", "horde_inputs_horde_mask", "")) {
          if (valid_file := image_load_and_fit(save_folder horde_mask_input_file_to_load, horde_mask_picture_frame)) {
            horde_inputs["horde_mask"] := valid_file
          }
        }
      }

      horde_image_width_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_image_width", horde_image_width_edit.Value)
      horde_image_height_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_image_height", horde_image_height_edit.Value)

      if(IniRead(save_folder save_name ".ini", "save", "horde_post_processing_1", "option_not_found") != "option_not_found") {
        while (A_Index <= horde_post_process_active_listview.GetCount()) {
          horde_post_process_active_listview.Modify(A_Index, "-Check")
        }
        while (horde_post_processing_name := IniRead(save_folder save_name ".ini", "save", "horde_post_processing_" A_Index, "")) {
          if (existing_horde_post_processing_entry := listview_search(horde_post_process_active_listview, horde_post_processing_name)) {
            horde_post_process_active_listview.Delete(existing_horde_post_processing_entry)
          }
          horde_post_process_active_listview.Insert(A_Index, "Check", horde_post_processing_name)
        }
        horde_post_process_active_listview_itemselect(horde_post_process_active_listview, "", "")
      }

      horde_facefixer_strength_edit.Value := IniRead(save_folder save_name ".ini", "save", "horde_facefixer_strength", horde_facefixer_strength_edit.Value)

      if (IniRead(save_folder save_name ".ini", "save", "horde_lora_1_name", "option_not_found") != "option_not_found") {
        horde_lora_active_listview.Delete()
        while ((horde_lora_name := IniRead(save_folder save_name ".ini", "save", "horde_lora_" A_Index "_name", "option_not_found")) != "option_not_found") {
          horde_lora_active_listview.Add(, horde_lora_name, IniRead(save_folder save_name ".ini", "save", "horde_lora_" A_Index "_strength", ""), IniRead(save_folder save_name ".ini", "save", "horde_lora_" A_Index "_inject_trigger"))
        }
        horde_lora_active_listview.Modify(1 ,"Select Vis")
        horde_lora_active_listview_itemselect(horde_lora_active_listview, "", "")
      }

      if (IniRead(save_folder save_name ".ini", "save", "horde_textual_inversion_1_name", "option_not_found") != "option_not_found") {
        horde_textual_inversion_active_listview.Delete()
        while ((horde_textual_inversion_name := IniRead(save_folder save_name ".ini", "save", "horde_textual_inversion_" A_Index "_name", "option_not_found")) != "option_not_found") {
          horde_textual_inversion_active_listview.Add(, horde_textual_inversion_name, IniRead(save_folder save_name ".ini", "save", "horde_textual_inversion_" A_Index "_inject_field", ""), IniRead(save_folder save_name ".ini", "save", "horde_textual_inversion_" A_Index "_strength"))
        }
        horde_textual_inversion_active_listview.Modify(1 ,"Select Vis")
        horde_textual_inversion_active_listview_itemselect(horde_textual_inversion_active_listview, "", "")
      }
    }
    status_text.Text := FormatTime() "`nLoaded`n" save_name
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}

;--------------------------------------------------
;other
;--------------------------------------------------

;handling in-progress previews and status updates sent from the assistant scripts
;--------------------------------------------------
message_receive(wParam, lParam, msg, hwnd) {
  out_size := NumGet(lParam, A_PtrSize * 1, "Ptr")
  out_ptr := NumGet(lParam, A_PtrSize * 2, "Ptr")
  possible_string := StrGet(out_ptr)
  switch {
    ;message from comfy script
    case (Instr(possible_string, "comfy") = 1):
      comfy_string := SubStr(possible_string, 6)
      switch {
        case comfy_string = "something went wrong":
          status_text.Text := FormatTime() "`nSomething went wrong."
          ;also sets status back to idle
          cancel_painting()
          return 1
        case comfy_string = "normal_job":
          download_images()
          change_status("idle")
          return 1
        case comfy_string = "preview_job":
          download_preview_images()
          change_status("idle")
          return 1
        ;default:
        case (Instr(comfy_string, "{") = 1):
          ;lazy check for json
          status_text.Text := FormatTime() "`n" comfy_string
          return 1
      }

    ;message from horde script
    case (Instr(possible_string, "horde") = 1):
      horde_string := SubStr(possible_string, 6)
      switch {
        case (Instr(horde_string, "horde_job") = 1):
          horde_download_image(SubStr(horde_string, 10))
          return 1
        case (horde_string = "something went wrong"):
          status_text.Text := FormatTime() "`nSomething went wrong."
          return 1
        case (Instr(horde_string, "prompt_id_not_found") = 1):
          not_found_prompt_id := SubStr(horde_string, 20)
          status_text.Text := FormatTime() "`n" not_found_prompt_id "`nPrompt ID not found or expired."
          if (existing_job_entry := listview_search(horde_generation_status_listview, not_found_prompt_id)) {
            horde_generation_status_listview.Modify(existing_job_entry,,,,,,,,,,,,, "Not Found")
          }
          return 1
        case (Instr(horde_string, "horde_progress") = 1):
          horde_progress_update := (SubStr(horde_string, 15))
          horde_progress_update := Jxon_load(&horde_progress_update)
          if (horde_progress_update["actual_server_response"]["faulted"]) {
            simple_status_readout := "Error"
          }
          else if (horde_progress_update["actual_server_response"]["done"]) {
            simple_status_readout := "Done"
          }
          else if (!horde_progress_update["actual_server_response"]["is_possible"]) {
            simple_status_readout := "No Available Workers"
          }
          else {
            simple_status_readout := "OK"
          }
          if (existing_job_entry := listview_search(horde_generation_status_listview, horde_progress_update["prompt_id"])) {
            horde_generation_status_listview.Modify(existing_job_entry,,, horde_progress_update["actual_server_response"]["finished"], horde_progress_update["actual_server_response"]["processing"], horde_progress_update["actual_server_response"]["restarted"], horde_progress_update["actual_server_response"]["waiting"], horde_progress_update["actual_server_response"]["done"], horde_progress_update["actual_server_response"]["faulted"], horde_progress_update["actual_server_response"]["wait_time"], horde_progress_update["actual_server_response"]["queue_position"], horde_progress_update["actual_server_response"]["kudos"], horde_progress_update["actual_server_response"]["is_possible"], simple_status_readout)
          }
          else {
            horde_generation_status_listview.Add(,horde_progress_update["prompt_id"], horde_progress_update["actual_server_response"]["finished"], horde_progress_update["actual_server_response"]["processing"], horde_progress_update["actual_server_response"]["restarted"], horde_progress_update["actual_server_response"]["waiting"], horde_progress_update["actual_server_response"]["done"], horde_progress_update["actual_server_response"]["faulted"], horde_progress_update["actual_server_response"]["wait_time"], horde_progress_update["actual_server_response"]["queue_position"], horde_progress_update["actual_server_response"]["kudos"], horde_progress_update["actual_server_response"]["is_possible"], simple_status_readout)
          }
          return 1
        ;default:
      }

    default:
      try {
        pStream := DllCall("Shlwapi\SHCreateMemStream", "Ptr", out_ptr + 8, "UInt", out_size - 8, "Ptr")
        DllCall("Gdiplus\GdipCreateBitmapFromStream", "Ptr", pStream, "PtrP", &pBitmap := 0)
        DllCall("Gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "PtrP", &hBitmap := 0, "UInt", 0)
        DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        ObjRelease(pStream)
        main_preview_picture.Value := "HBITMAP:" hBitmap
      }
      catch Error as what_went_wrong {
        oh_no(what_went_wrong)
      }
      finally {
        if (IsSet(pBitmap)) {
          try {
            Gdip_DisposeImage(pBitmap)
          }
        }
      }
      return 1

  }
}

;prepare a string to be sent using SendMessage 0x004A
;--------------------------------------------------
string_to_message(str) {
  con_struct_ion := Buffer(A_PtrSize * 3)
  NumPut("Ptr", ((StrLen(str) + 1) * 2), con_struct_ion, A_PtrSize)
  NumPut("Ptr",  StrPtr(str), con_struct_ion, A_ptrSize * 2)
  return con_struct_ion
}

;keep track of task and prevent some interruptions
;--------------------------------------------------
change_status(status) {
  global assistant_status := status
  switch status {
    case "idle":
      generate_button.Text := "Paint"
      if (!inputs.Has(main_preview_picture_frame["name"])) {
        image_width_edit.Enabled := 1
        image_width_updown.Enabled := 1
        image_height_edit.Enabled := 1
        image_height_updown.Enabled := 1
      }
    case "painting":
      generate_button.Text := "Cancel"
      image_width_edit.Enabled := 0
      image_width_updown.Enabled := 0
      image_height_edit.Enabled := 0
      image_height_updown.Enabled := 0
      global clear_main_preview_image_on_next_dimension_change := 1
    ;default:
  }
}

;exit and restart, appear in context menu
;--------------------------------------------------
exit_everything(*) {
  ExitApp
}

restart_everything(*) {
  Reload
}

shutdown_cleanup(*) {
  if (WinExist(assistant_script " ahk_class AutoHotkey")) {
    WinKill
  }
  if (WinExist(horde_assistant_script " ahk_class AutoHotkey")) {
    WinKill
  }
  if (IsSet(pToken)) {
    try {
      Gdip_Shutdown(pToken)
    }
  }
}

;search listview
;--------------------------------------------------
listview_search(listview_object, str) {
  static buffer_size := A_PtrSize = 8 ? 36 : 24
  LVFINDINFO := Buffer(buffer_size, 0)
  NumPut("UInt", 0x0002, LVFINDINFO)
  NumPut("Ptr", StrPtr(str), LVFINDINFO, A_PtrSize)
  return (SendMessage(0x1053, -1, LVFINDINFO, listview_object.Hwnd) + 1)
}

;generic error
;--------------------------------------------------
oh_no(error_message) {
  status_text.Text := FormatTime() "`n" error_message.Message "`n" error_message.Extra
  FileAppend("[" A_Now "]`n" error_message.Message "`n" error_message.Extra "`n" error_message.File "`n" error_message.Line "`n" error_message.Stack "`n", "log", "utf-8")
}

;--------------------------------------------------
;overlay
;--------------------------------------------------

overlay_show(*) {
  Critical
  overlay_background.Show()
  for (, gui_window_map in gui_windows[overlay_current]) {
    gui_window_map["gui_window"].Show("NoActivate")
  }
  assistant_box.Show("NoActivate")
  status_box.Show("NoActivate")
  global overlay_visible := 1
}

overlay_hide(*) {
  Critical
  for (, gui_window_map in gui_windows[overlay_current]) {
    gui_window_map["gui_window"].Hide()
  }
  settings_window.Hide()
  assistant_box.Hide()
  status_box.Hide()
  overlay_background.Hide()
  global overlay_visible := 0
}

overlay_tab_change_next(*) {
  Critical
  for (, gui_window_map in gui_windows[overlay_current]) {
    gui_window_map["gui_window"].Hide()
  }
  global overlay_current := overlay_sequence[overlay_current] >= overlay_list.Length ? overlay_list[1] : overlay_list[overlay_sequence[overlay_current] + 1]
  if (overlay_visible) {
    overlay_show()
  }
}

overlay_tab_change_previous(*) {
  Critical
  for (, gui_window_map in gui_windows[overlay_current]) {
    gui_window_map["gui_window"].Hide()
  }
  global overlay_current := overlay_sequence[overlay_current] <= 1 ? overlay_list[-1] : overlay_list[overlay_sequence[overlay_current] - 1]
  if (overlay_visible) {
    overlay_show()
  }
}

overlay_tab_change(overlay_name) {
  Critical
  for (, gui_window_map in gui_windows[overlay_current]) {
    gui_window_map["gui_window"].Hide()
  }
  global overlay_current := overlay_name
  if (overlay_visible) {
    overlay_show()
  }
}

overlay_toggle(*) {
  Critical
  if (!overlay_visible) {
    overlay_show()
  }
  else {
    overlay_hide()
  }
}

overlay_toggle_comfy(*) {
  Critical
  if (overlay_current != "comfy") {
    overlay_tab_change("comfy")
    overlay_show()
  }
  else {
    overlay_toggle()
  }
}

overlay_toggle_horde(*) {
  Critical
  if (overlay_current != "horde") {
    overlay_tab_change("horde")
    overlay_show()
  }
  else {
    overlay_toggle()
  }
}
