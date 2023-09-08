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
transparent_bg_colour := "0xAAAAAA"

assistant_script := A_IsCompiled ? "assistant-assistant.exe" : "assistant-assistant.ahk"

;--------------------------------------------------
;read settings from fluffy-settings.ini
;and decide what to do with them
;--------------------------------------------------
background_colour := IniRead("fluffy-settings.ini", "settings", "background_colour", "0x000000")
background_colour := background_colour = "" ? "0x000000" : background_colour
background_opacity := IniRead("fluffy-settings.ini", "settings", "background_opacity", 128)
background_opacity := background_opacity = "" ? 128 : background_opacity
control_colour := IniRead("fluffy-settings.ini", "settings", "control_colour", "0x101010")
control_colour := control_colour = "" ? "0x101010" : control_colour
text_font := IniRead("fluffy-settings.ini", "settings", "text_font", "Arial")
text_font := text_font = "" ? "Arial" : text_font
text_size := IniRead("fluffy-settings.ini", "settings", "text_size", 12)
text_size := text_size = "" ? 12 : text_size
text_colour := IniRead("fluffy-settings.ini", "settings", "text_colour", "0xB0B0B0")
text_colour := text_colour = "" ? "0xB0B0B0" : text_colour
show_labels := IniRead("fluffy-settings.ini", "settings", "show_labels", 1)
;blank means no
label_font := IniRead("fluffy-settings.ini", "settings", "label_font", "Arial")
label_font := label_font = "" ? "Arial" : label_font
label_size := IniRead("fluffy-settings.ini", "settings", "label_size", 12)
label_size := label_size = "" ? 12 : label_size
label_colour := IniRead("fluffy-settings.ini", "settings", "label_colour", "0xE0E0E0")
label_colour := label_colour = "" ? "0xE0E0E0" : label_colour
gap_x := IniRead("fluffy-settings.ini", "settings", "gap_x", 25)
gap_x := gap_x = "" ? 25 : gap_x
gap_y := IniRead("fluffy-settings.ini", "settings", "gap_y", 25)
gap_y := gap_y = "" ? 25 : gap_y
screen_border_x := IniRead("fluffy-settings.ini", "settings", "screen_border_x", 10)
screen_border_x := screen_border_x = "" ? 10 : screen_border_x
screen_border_y := IniRead("fluffy-settings.ini", "settings", "screen_border_y", 10)
screen_border_y := screen_border_y = "" ? 10 : screen_border_y
server_address := IniRead("fluffy-settings.ini", "settings", "default_server_address", "127.0.0.1:8188")
;blank means "don't autoconnect"
input_folder := IniRead("fluffy-settings.ini", "settings", "input_folder", "images\input\")
input_folder := input_folder = "" ? "images\input\" : input_folder
output_folder := IniRead("fluffy-settings.ini", "settings", "output_folder", "images\output\")
output_folder := output_folder = "" ? "images\output\" : output_folder
preprocessor_category_name := IniRead("fluffy-settings.ini", "settings", "preprocessor_category_name", "ControlNet Preprocessors/")
preprocessor_category_name := preprocessor_category_name = "" ? "ControlNet Preprocessors/" : preprocessor_category_name
delete_files_on_startup := IniRead("fluffy-settings.ini", "settings", "delete_files_on_startup", 0)
;blank means no

;--------------------------------------------------
;some global things
;--------------------------------------------------

;populate with list of all available nodes & options from server response
scripture := Map()

;to be filled with the actual gui control objects
preprocessor_controls := Map()

;for connecting the easy name with the actual node name
preprocessor_actual_name := Map()

;for tracking input images
inputs := Map()
preview_images := Map()

;images not yet downloaded
images_to_download := Map()
preview_image_to_download := Map()

;prevent certain actions when busy
assistant_status := "idle"

;toggle on hotkey
overlay_visible := 0

;to track the displayed output image even if empty item is chosen in the listview
last_selected_output_image:= ""

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

overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound", "Fluffy Overlay")
overlay.Show("Hide x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
WinSetTransparent background_opacity = 255 ? "Off" : background_opacity
overlay.BackColor := background_colour

;--------------------------------------------------
;main controls
;--------------------------------------------------

main_controls := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Main Controls")
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
vae_combobox :=  main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

vae_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
sampler_combobox :=  main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

sampler_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
scheduler_combobox :=  main_controls.Add("ComboBox", "x" stored_gui_x + stored_gui_w + gap_x " y" stored_gui_y " w" A_ScreenWidth / 10 " Background" control_colour)

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
upscale_target_option_dropdownlist := main_controls.Add("DropDownList", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + gap_x " y" stored_gui_y " w80 Background" control_colour " Center Limit6 Choose1 Disabled", ["Factor", "Pixels"])

upscale_target_option_dropdownlist.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
upscale_value_edit := main_controls.Add("Edit", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w120 r1 Background" control_colour " Center Limit8 Disabled", "1.000")

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

;--------------------------------------------------
;loras
;--------------------------------------------------

lora_selection := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "LORA")
lora_selection.MarginX := 0
lora_selection.MarginY := 0
lora_selection.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
lora_selection.SetFont("s" text_size " c" text_colour " q0", text_font)


;lora name and strength
;--------------------------------------------------
lora_available_combobox := lora_selection.Add("ComboBox", "x0 y0 w" A_ScreenWidth / 5 - 1 " Background" control_colour " Choose1", ["None"])

lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_strength_edit := lora_selection.Add("Edit", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " w" A_ScreenWidth / 25 " r1 Background" control_colour " Center Limit6", "1.000")
lora_strength_updown := lora_selection.Add("UpDown", "Range0-1 0x80 -2", 0)

;active loras
;--------------------------------------------------
lora_available_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_active_listview := lora_selection.Add("ListView", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" A_ScreenWidth / 25 * 6 " r5 Background" control_colour " -Multi", ["LORA", "Strength"])

Loop 6 {
  lora_active_listview.Add(,"")
}
lora_active_listview.ModifyCol(1, A_ScreenWidth / 5)
lora_active_listview.ModifyCol(2, "AutoHdr Float")
lora_active_listview.Delete
lora_active_listview.Add(,"None", "1.000")

;lora add/remove buttons
;--------------------------------------------------
lora_strength_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
;autofit width to longer "Remove" button before changing back to "Add"
lora_add_button := lora_selection.Add("Button", "x" stored_gui_x + stored_gui_w + updown_default_w + updown_offset_x + 1 " y" stored_gui_y " h" stored_gui_h " Background" background_colour, "Remove")
lora_add_button.Text := "Add"

lora_add_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
lora_remove_button := lora_selection.Add("Button", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " w" stored_gui_w " h" stored_gui_h " Background" background_colour, "Remove")

;--------------------------------------------------
;preview (source image)
;--------------------------------------------------

preview_display := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Image Preview")
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
main_preview_picture := preview_display.Add("Picture", "x0 y" stored_gui_y + stored_gui_h + gap_y " w" A_ScreenHeight / 2 " h" A_ScreenHeight / 2, "stuff\placeholder_pixel.bmp")

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

mask_and_controlnet := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Additional Input Images")
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
controlnet_preprocessor_options := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "ControlNet Preprocessors")
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
controlnet_add_button := mask_and_controlnet.Add("Button", "x" stored_gui_x + stored_gui_w + 1 " y" stored_gui_y " Background" background_colour, "Remove")
controlnet_add_button.Text := "Add"

controlnet_add_button.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
controlnet_remove_button := mask_and_controlnet.Add("Button", "x" stored_gui_x " y" stored_gui_y + stored_gui_h + 1 " Background" background_colour, "Remove")

;--------------------------------------------------
;output image viewer
;--------------------------------------------------

output_viewer := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Output Viewer")
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
;status box
;--------------------------------------------------

status_box := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Status")
status_box.MarginX := 0
status_box.MarginY := 0
status_box.BackColor := transparent_bg_colour
WinSetTransColor transparent_bg_colour
status_box.SetFont("s" text_size " c" text_colour " q0", text_font)

status_box.SetFont("s" text_size " c" label_colour " q3", label_font)
status_text := status_box.Add("Text", "x0 y0 w" A_ScreenWidth / 10 * 4 " r5 Right")
status_box.SetFont("s" text_size " c" text_colour " q0", text_font)

status_text.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
if (FileExist("stuff\assistant.png")) {
  status_picture := status_box.Add("Picture", "x" stored_gui_w " y0 w0 h0", "stuff\assistant.png")
}
else {
  status_picture := status_box.Add("Picture", "x" stored_gui_w " y0 w100 h100", "stuff\placeholder_pixel.bmp")
}
;get specific values
status_picture.GetPos(&status_picture_x, &status_picture_y, &status_picture_w, &status_picture_h)
status_text.GetPos(&status_text_x, &status_text_y, &status_text_w, &status_text_h)

status_text.Move(0, status_text_h > status_picture_h ? 0 : status_picture_h - status_text_h, status_text_w, status_text_h)
status_picture.Move(status_text_w, status_text_h > status_picture_h ? status_text_h - status_picture_h : 0, status_picture_w, status_picture_h)

;--------------------------------------------------
;settings window
;--------------------------------------------------

settings_window := Gui("+AlwaysOnTop +ToolWindow +Owner" overlay.Hwnd " +LastFound", "Options")
server_address_label := settings_window.Add("Text",, "Server Address:")
server_address_edit := settings_window.Add("Edit", "xp w150 Section", server_address)
server_connect_button := settings_window.Add("Button", "yp", "Connect")
open_settings_file_button := settings_window.Add("Button", "xs", "Open Settings File")

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

  upscale_target_option_dropdownlist.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  upscale_method_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Target")

  refiner_combobox.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  refiner_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Refiner")

  refiner_start_step_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  refiner_start_step_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "Start Step")

  cfg_refiner_edit.GetPos(&stored_gui_x, &stored_gui_y, &stored_gui_w, &stored_gui_h)
  cfg_refiner_label := main_controls.Add("Text", "x" stored_gui_x " y" stored_gui_y - label_h , "CFG")

  ;revert font just in case
  main_controls.SetFont("s" text_size " c" text_colour " q0", text_font)

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

;main preview
;--------------------------------------------------
main_preview_picture_menu := Menu()
main_preview_picture_menu.Add("Inputs", inputs_existing_images_menu)
main_preview_picture_menu.Add("Outputs", outputs_existing_images_menu)
main_preview_picture_menu.Add("Clipboard", main_preview_picture_menu_clipboard)
main_preview_picture_menu.Add()
main_preview_picture_menu.Add("Remove", main_preview_picture_menu_remove)

;mask
;--------------------------------------------------
mask_picture_menu := Menu()
mask_picture_menu.Add("Inputs", inputs_existing_images_menu)
mask_picture_menu.Add("Outputs", outputs_existing_images_menu)
mask_picture_menu.Add("Clipboard", mask_picture_menu_clipboard)
mask_picture_menu.Add()
mask_picture_menu.Add("Preview", mask_picture_menu_preview)
mask_picture_menu.Add("Remove", mask_picture_menu_remove)

;controlnet
;--------------------------------------------------
controlnet_picture_menu := Menu()
controlnet_picture_menu.Add("Inputs", inputs_existing_images_menu)
controlnet_picture_menu.Add("Outputs", outputs_existing_images_menu)
controlnet_picture_menu.Add("Clipboard", controlnet_picture_menu_clipboard)
controlnet_picture_menu.Add()
controlnet_picture_menu.Add("Preview", controlnet_picture_menu_preview)
controlnet_picture_menu.Add("Remove", controlnet_picture_menu_remove)

;output images
;--------------------------------------------------
output_picture_menu := Menu()
output_picture_menu.Add("Send to Source", output_picture_menu_to_source)
output_picture_menu.Add("Send to Mask", output_picture_menu_to_mask)
output_picture_menu.Add("Send to ControlNet", output_picture_menu_to_controlnet)
output_picture_menu.Add()
output_picture_menu.Add("Copy", output_picture_menu_copy)


;status box
;--------------------------------------------------
status_picture_menu := Menu()
status_picture_menu.Add("Connect", connect_to_server)
status_picture_menu.Add("Settings", show_settings)
status_picture_menu.Add()
status_picture_menu.Add("Restart", restart_everything)
status_picture_menu.Add("Exit", exit_everything)


;picture frames
;--------------------------------------------------
main_preview_picture_frame := create_picture_frame("source", main_preview_picture)
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
    upscale_target_option_dropdownlist.Enabled := 0
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
    upscale_target_option_dropdownlist.Enabled := 1
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
upscale_target_option_dropdownlist.OnEvent("Change", upscale_target_option_dropdownlist_change)
upscale_target_option_dropdownlist_change(GuiCtrlObj, Info) {
  if (upscale_target_option_dropdownlist.Value = 1) {
    upscale_value_edit.Opt("-Number")
    if (upscale_value_edit.Value < 0) {
      upscale_value_edit.Value := 0
    }
    else if (IsInteger(upscale_value_edit.Value)) {
      upscale_value_edit.Value := Format("{:.3f}", Sqrt(Float(upscale_value_edit.Value) / (image_width_edit.Value * image_height_edit.Value)))
    }
    upscale_value_edit_losefocus(upscale_value_edit, "")
  }
  else if (upscale_target_option_dropdownlist.Value = 2) {
    upscale_value_edit.Opt("+Number")
    if (IsFloat(upscale_value_edit.Value)) {
      upscale_value_edit.Value := Round(image_width_edit.Value * image_height_edit.Value * (upscale_value_edit.Value ** 2))
    }
    upscale_value_edit_losefocus(upscale_value_edit, "")
  }
}

upscale_value_updown.OnEvent("Change", upscale_value_updown_change)
upscale_value_updown_change(GuiCtrlObj, Info) {
  if (upscale_target_option_dropdownlist.Value = 1) {
    number_update(1, 0, 8, 0.01, 3, upscale_value_edit, Info)
  }
  else if (upscale_target_option_dropdownlist.Value = 2) {
    number_update(image_width_edit.Value * image_height_edit.Value, 0, 16000000, 64, 0, upscale_value_edit, Info)
  }
}

upscale_value_edit.OnEvent("LoseFocus", upscale_value_edit_losefocus)
upscale_value_edit_losefocus(GuiCtrlObj, Info) {
  if (upscale_target_option_dropdownlist.Value = 1) {
    number_cleanup("1.000", "0.000", "8.000", GuiCtrlObj)
    if (IsInteger(upscale_value_edit.Value)) {
      upscale_value_edit.Value := Format("{:.3f}", upscale_value_edit.Value)
    }
  }
  else if (upscale_target_option_dropdownlist.Value = 2) {
    number_cleanup(image_width_edit.Value * image_height_edit.Value, 0, 16000000, GuiCtrlObj)
  }
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
  }
  else {
    refiner_start_step_edit.Enabled := 1
    refiner_start_step_updown.Enabled := 1
    cfg_refiner_edit.Enabled := 1
    cfg_refiner_updown.Enabled := 1
    random_seed_refiner_checkbox.Enabled := 1
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
;loras
;--------------------------------------------------

;lora model
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
    lora_available_combobox.Text := ""
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
  if (preprocessor_actual_name.Has(GuiCtrlObj.Text)) {
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
        if scripture[node]["input"][optionality].Has(opt) {
          if (scripture[node]["input"][optionality][opt].Has(2)) {
            if (scripture[node]["input"][optionality][opt][2].Has("default")) {
              preprocessor_controls[node][opt][1].Text := scripture[node]["input"][optionality][opt][2]["default"]
            }
            else {
              if (Type(scripture[node]["input"][optionality][opt][1]) = "Array") {
                preprocessor_controls[node][opt][1].Text := scripture[node]["input"][optionality][opt][1][1]
              }
            }
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
    controlnet_preprocessor_dropdownlist.Text := GuiCtrlObj.GetText(controlnet_current, 6)

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
    controlnet_checkpoint_combobox.Text := ""
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
  if (output_listview.GetNext()) {
    global last_selected_output_image := output_folder output_listview.GetText(output_listview.GetNext(), 1)
    image_load_and_fit_wthout_change(last_selected_output_image, output_picture_frame)
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
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), main_preview_picture_menu_output_file)
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
main_preview_picture_menu_clipboard(ItemName, ItemPos, MyMenu) {
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
;mask
;--------------------------------------------------
mask_picture.OnEvent("ContextMenu", mask_picture_contextmenu)
mask_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()

  for (existing_image in inputs) {
    inputs_existing_images_menu.Add(existing_image, mask_picture_menu_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), mask_picture_menu_output_file)
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

;mask output file
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
mask_picture_menu_clipboard(ItemName, ItemPos, MyMenu) {
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

;--------------------------------------------------
;controlnet
;--------------------------------------------------

;for controlnet, picture frame's "name" is changed as needed
;ie. it becomes "controlnet_1" when the first image is selected
controlnet_picture.OnEvent("ContextMenu", controlnet_picture_contextmenu)
controlnet_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  inputs_existing_images_menu.Delete()

  for (existing_images in inputs) {
    inputs_existing_images_menu.Add(existing_images, controlnet_picture_menu_file)
  }
  outputs_existing_images_menu.Delete()
  while (A_Index <= output_listview.GetCount()) {
    outputs_existing_images_menu.Add(output_listview.GetText(A_Index), controlnet_picture_menu_output_file)
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
controlnet_picture_menu_clipboard(ItemName, ItemPos, MyMenu) {
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

;output images - copy
;--------------------------------------------------
output_picture_menu_copy(ItemName, ItemPos, MyMenu) {
  pToken  := Gdip_Startup()
  try {
    Gdip_SetBitmapToClipboard(pBitmap := Gdip_CreateBitmapFromFile(last_selected_output_image))
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    Gdip_Shutdown(pToken)
    return
  }
}

;--------------------------------------------------
;status box
;--------------------------------------------------
status_picture.OnEvent("ContextMenu", status_picture_contextmenu)
status_picture_contextmenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
  status_picture_menu.Show()
}

show_settings(*) {
  settings_window.Show("w240 x" A_ScreenWidth - 540 " y" A_ScreenHeight - 240)
}

;--------------------------------------------------
;settings window
;--------------------------------------------------

server_connect_button.OnEvent("Click", server_connect_button_click)
server_connect_button_click(GuiCtrlObj, Info) {
  global server_address := server_address_edit.Text
  connect_to_server()
}

open_settings_file_button.OnEvent("Click", open_settings_file_button_click)

open_settings_file_button_click(GuiCtrlObj, Info) {
  overlay_hide()
  try {
    if (!FileExist("fluffy-settings.ini")) {
      FileCopy("fluffy-settings.ini.example", "fluffy-settings.ini")
    }
    Run "Notepad fluffy-settings.ini"
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return
  }
}

;--------------------------------------------------
;--------------------------------------------------
;gui window positioning
;--------------------------------------------------
;--------------------------------------------------

main_controls.Show("Hide")
WinGetPos ,, &main_controls_w, &main_controls_h, main_controls.Hwnd

lora_selection.Show("Hide")
WinGetPos ,, &lora_selection_w, &lora_selection_h, lora_selection.Hwnd

output_viewer.Show("Hide")
WinGetPos ,, &output_viewer_w, &output_viewer_h, output_viewer.Hwnd

status_box.Show("Hide")
WinGetPos ,, &status_box_w, &status_box_h, status_box.Hwnd

;--------------------------------------------------
;--------------------------------------------------
;final preparations
;--------------------------------------------------
;--------------------------------------------------

if (delete_files_on_startup= "DELETE") {
  try {
    DirDelete input_folder, 1
    DirDelete output_folder, 1
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
  }
}
try {
  DirCreate input_folder
  DirCreate output_folder
}
catch Error as what_went_wrong {
  oh_no(what_went_wrong)
}

if (server_address) {
  connect_to_server()
}

Hotkey "*CapsLock", overlay_toggle, "On"

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
    frame["GuiCtrlObj"].Visible := 0
    frame["GuiCtrlObj"].Value := "*w0 *h0 " image
    frame["GuiCtrlObj"].GetPos(,, &w, &h)
    picture_fit_to_frame(w, h, frame)
    frame["GuiCtrlObj"].Redraw()
    frame["GuiCtrlObj"].Visible := 1

    ;https://www.autohotkey.com/docs/v2/lib/SplitPath.htm

    ;determine file name by finding last occurence of "\"
    ;includes the backslash
    original_file_name := Substr(image, Instr(image, "\",, -1))
    ;determine file extension the same way except with "."
    ;includes the dot
    original_file_extension := ""
    if (Instr(original_file_name, ".")) {
      original_file_extension := Substr(original_file_name, Instr(original_file_name, ".",, -1))
    }

    ;msgbox image "`n" "input\" frame["name"] original_file_extension
    ;if ((image != A_WorkingDir "\input\" frame["name"] original_file_extension) and (image != "input\" frame["name"] original_file_extension)) {
    ;  FileCopy image, "input\" frame["name"] ".*" , 1
    ;}

    try {
      FileCopy image, input_folder frame["name"] ".*" , 1
    }
    catch Error as what_went_wrong {
      oh_no(what_went_wrong)
      if (!FileExist(input_folder frame["name"] original_file_extension)) {
        return
      }
    }

    ;delete files with different extensions
    loop files input_folder frame["name"] ".*" {
      if (A_LoopFileName != frame["name"] original_file_extension)
        FileDelete(A_LoopFilePath)
    }
    ;in case of files with no file extension
    if (original_file_extension and FileExist(input_folder frame["name"])) {
      FileDelete(input_folder frame["name"])
    }

    return input_folder frame["name"] original_file_extension
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
  pToken  := Gdip_Startup()
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

    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)
    return input_folder frame["name"] ".png"
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    Gdip_Shutdown(pToken)
    return 0
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
    status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText
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
  upscale_combobox.Add(scripture["ImageScaleBy"]["input"]["required"]["upscale_method"][1])
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
    ;find every node which has the string given as preprocessor_category_name in category name
    if (InStr(scripture[node]["category"], "image/preprocessors") = 1 or InStr(scripture[node]["category"], preprocessor_category_name) = 1) {
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

  if (overlay_visible) {
    WinGetPos &mask_and_controlnet_x, &mask_and_controlnet_y, &mask_and_controlnet_w, &mask_and_controlnet_h, mask_and_controlnet.Hwnd
    controlnet_preprocessor_options.Show("x" mask_and_controlnet_x + controlnet_preprocessor_options_start_x " y" mask_and_controlnet_y + controlnet_preprocessor_options_start_y " NoActivate")
  }
}

;used by connect_to_server to recreate the specific gui for controlnet preprocessors
;so that controls can be destroyed efficiently
;--------------------------------------------------
remake_controlnet_preprocessor_gui() {
  global controlnet_preprocessor_options
  controlnet_preprocessor_options.Destroy()
  controlnet_preprocessor_options := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" overlay.Hwnd " +LastFound", "ControlNet Preprocessors")
  controlnet_preprocessor_options.MarginX := 0
  controlnet_preprocessor_options.MarginY := 0
  controlnet_preprocessor_options.BackColor := transparent_bg_colour
  WinSetTransColor transparent_bg_colour
  controlnet_preprocessor_options.SetFont("s" text_size " c" text_colour " q0", text_font)
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
    if (controlnet_current and controlnet_active_listview.GetText(controlnet_current, 6) = node) {
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
diffusion_time() {
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
      status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText

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
  thought["main_prompt_positive"]["inputs"]["text"] := prompt_positive_edit.Value
  thought["main_prompt_negative"]["inputs"]["text"] := prompt_negative_edit.Value

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
        ;generate a node to vae decode it even
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

  ;upscale
  if (upscale_combobox.Text and upscale_combobox.Text != "None") {
    ;only using non-latent upscaling
    ;determine whether using model to upscale or not by checking the name of upscale method
    upscale_using_model := 1
    for (upscaler in scripture["ImageScaleBy"]["input"]["required"]["upscale_method"][1]) {
      if (upscale_combobox.Text = upscaler) {
        upscale_using_model := 0
        break
      }
    }
    if (upscale_using_model) {
      thought["upscale_with_model"]["inputs"]["image"] := ["main_vae_decode", 0]
      thought["upscale_model_loader"]["inputs"]["model_name"] := upscale_combobox.Text
    }

    ;decide whether to scale by factor or to specific megapixel count
    ;explicitly change to the relevant node
    ;also make some decisions based on "upscale_using_model"
    if (upscale_target_option_dropdownlist.Value = 1) {
      thought["upscale_resize"] := Map(
        "inputs", Map(
          "upscale_method", upscale_using_model ? thought["upscale_resize"]["inputs"]["upscale_method"] : upscale_combobox.Text
          ,"scale_by", upscale_value_edit.Value
          ,"image", upscale_using_model ? ["upscale_with_model" , 0] : ["main_vae_decode", 0]
        ),
        "class_type", "ImageScaleBy"
      )
    }
    else if (upscale_target_option_dropdownlist.Value = 2) {
      thought["upscale_resize"] := Map(
        "inputs", Map(
          "upscale_method", upscale_using_model ? thought["upscale_resize"]["inputs"]["upscale_method"] : upscale_combobox.Text
          ,"megapixels", Float(upscale_value_edit.Value) / 1000000
          ,"image", upscale_using_model ? ["upscale_with_model" , 0] : ["main_vae_decode", 0]
        ),
        "class_type", "ImageScaleToTotalPixels"
      )
    }

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
    thought["refiner_prompt_positive"]["inputs"]["text"] := thought["main_prompt_positive"]["inputs"]["text"]
    thought["refiner_prompt_negative"]["inputs"]["text"] := thought["main_prompt_negative"]["inputs"]["text"]

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
          ,"model", actual_lora_count = 1 ? ["checkpoint_loader", 0] : ["lora_" actual_lora_count - 1, 0]
          ,"clip", actual_lora_count = 1 ? ["checkpoint_loader", 1] : ["lora_" actual_lora_count - 1, 1]
        ),
        "class_type", "LoraLoader"
      )
    }
  }
  if (actual_lora_count) {
    thought["main_prompt_positive"]["inputs"]["clip"] := ["lora_" actual_lora_count, 1]
    thought["main_prompt_negative"]["inputs"]["clip"] := ["lora_" actual_lora_count, 1]
    thought["main_sampler"]["inputs"]["model"] := ["lora_" actual_lora_count, 0]
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      thought["upscale_sampler"]["inputs"]["model"] := ["lora_" actual_lora_count, 0]
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
      ;the image input will come straight from the loader unless there's an upscale
      ;or preprocessor, in which case the input will get replaced further down
      thought["controlnet_apply_" actual_controlnet_count] := Map(
        "inputs", Map(
          "strength", controlnet_active_listview.GetText(A_Index, 3)
          ,"start_percent", controlnet_active_listview.GetText(A_Index, 4)
          ,"end_percent", controlnet_active_listview.GetText(A_Index, 5)
          ,"positive", actual_controlnet_count = 1 ? ["main_prompt_positive", 0] : ["controlnet_apply_" actual_controlnet_count - 1, 0]
          ,"negative", actual_controlnet_count = 1 ? ["main_prompt_negative", 0] : ["controlnet_apply_" actual_controlnet_count - 1, 1]
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
          "inputs", Map()
          ,"class_type", actual_name
        )
        ;untangle the string
        if (controlnet_active_listview.GetText(actual_controlnet_count, 7) != "") {
          Loop Parse controlnet_active_listview.GetText(actual_controlnet_count, 7), "," {
            option_pair := StrSplit(A_LoopField, ":")
            thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"][option_pair[1]] := option_pair[2]
          }
        }

        ;check if the preprocessor needs a mask (inpainting)
        if (scripture.Has(actual_name)) {
          for (optionality in scripture[actual_name]["input"]) {
            for (opt, value_properties in scripture[actual_name]["input"][optionality]) {
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

        ;deal with upscaling
        if (upscale_combobox.Text and upscale_combobox.Text != "None") {
          thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_upscale_resize_" actual_controlnet_count, 0]
        }
        else {
          thought["controlnet_preprocessor_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_image_loader_" actual_controlnet_count, 0]
        }
      }

      if (upscale_combobox.Text and upscale_combobox.Text != "None") {
        ;upscale image with the same method used for main image
        ;assumes controlnet image is the same size as source image
        thought["controlnet_upscale_with_model_" actual_controlnet_count] := Map(
          "inputs", Map(
            "upscale_model", thought["upscale_with_model"]["inputs"]["upscale_model"]
          ),
          "class_type", thought["upscale_with_model"]["class_type"]
        )

        thought["controlnet_upscale_resize_" actual_controlnet_count] := Map(
          "inputs", Map(
            "upscale_method", thought["upscale_resize"]["inputs"]["upscale_method"]
          ),
          "class_type", thought["upscale_resize"]["class_type"]
        )
        if (thought["upscale_resize"]["inputs"].Has("scale_by")) {
          thought["controlnet_upscale_resize_" actual_controlnet_count]["inputs"]["scale_by"] := thought["upscale_resize"]["inputs"]["scale_by"]
        }
        else if (thought["upscale_resize"]["inputs"].Has("megapixels")) {
          thought["controlnet_upscale_resize_" actual_controlnet_count]["inputs"]["megapixels"] := thought["upscale_resize"]["inputs"]["megapixels"]
        }

        if (upscale_using_model) {
          thought["controlnet_upscale_resize_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_upscale_with_model_" actual_controlnet_count, 0]
          thought["controlnet_upscale_with_model_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_image_loader_" actual_controlnet_count, 0]
        }
        else {
          thought["controlnet_upscale_resize_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_image_loader_" actual_controlnet_count, 0]
        }
      }

      ;calculate which image noodle gets attached to controlnet_apply_# here for clarity
      if (controlnet_active_listview.GetText(A_Index, 6) and controlnet_active_listview.GetText(A_Index, 6) != "None") {
        ;if preprocessor
        thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_preprocessor_" actual_controlnet_count, 0]
      }
      else {
        if (upscale_combobox.Text and upscale_combobox.Text != "None") {
          ;no preprocessor but yes upscale
          thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_upscale_resize_" actual_controlnet_count, 0]
        }
        else {
          ;no preprocessor, no upscale
          thought["controlnet_apply_" actual_controlnet_count]["inputs"]["image"] := ["controlnet_image_loader_" actual_controlnet_count, 0]
        }
      }
    }
  }
  if (actual_controlnet_count) {
    thought["main_sampler"]["inputs"]["positive"] := ["controlnet_apply_" actual_controlnet_count, 0]
    thought["main_sampler"]["inputs"]["negative"] := ["controlnet_apply_" actual_controlnet_count, 1]
    if (upscale_combobox.Text and upscale_combobox.Text != "None") {
      thought["upscale_sampler"]["inputs"]["positive"] := ["controlnet_apply_" actual_controlnet_count, 0]
      thought["upscale_sampler"]["inputs"]["negative"] := ["controlnet_apply_" actual_controlnet_count, 1]
    }
  }

  ;saving
  generation_time := thought["save_image"]["inputs"]["filename_prefix"] := A_Now

  prayer := Jxon_dump(Map("prompt", thought, "client_id", client_id))

  try {
    altar.Open("POST", "http://" server_address "/prompt", false)
    altar.Send(prayer)
    response := altar.ResponseText
    status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText "`n" altar.ResponseText
    if (altar.Status = 200) {
      vision := Jxon_load(&response)
      images_to_download[generation_time] := vision["prompt_id"]
      Run assistant_script " " A_ScriptName " " server_address " " client_id " normal_job " vision["prompt_id"]
    }
    else {
      change_status("idle")
      return
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    change_status("idle")
    return
  }
}

;handling in-progress previews and status updates sent from the assistant script
;--------------------------------------------------
message_receive(wParam, lParam, msg, hwnd) {
  out_size := NumGet(lParam, A_PtrSize * 1, "Ptr")
  out_ptr := NumGet(lParam, A_PtrSize * 2, "Ptr")
  possible_string := StrGet(out_ptr)
  switch {
    case possible_string = "something went wrong":
      status_text.Text := FormatTime() "`nSomething went wrong."
      ;also sets status back to idle
      cancel_painting()
      return 1
    case possible_string = "normal_job":
      download_images()
      change_status("idle")
      ;status_text.Text := possible_string
      return 1
    case possible_string = "preview_job":
      download_preview_images()
      change_status("idle")
      return 1
    case (Instr(possible_string, "{") = 1):
      ;lazy check for json
      status_text.Text := FormatTime() "`n" possible_string
      return 1
    default:
      pToken := Gdip_Startup()
      try {
        hMod := DllCall("Kernel32\LoadLibrary", "str", "shlwapi.dll", "ptr")
        local pStream, pBitmap := 0, hBitmap := 0
        pStream  :=  DllCall("Shlwapi\SHCreateMemStream", "ptr",out_ptr + 8, "uint",out_size - 8)
        DllCall("Gdiplus\GdipCreateBitmapFromStream",  "ptr",pStream, "ptrp",&pBitmap)
        DllCall("Gdiplus\GdipCreateHBITMAPFromBitmap", "ptr",pBitmap, "ptrp",&hBitmap, "uint",0)
        DllCall("Gdiplus\GdipDisposeImage", "ptr",pBitmap)
        ObjRelease(pStream)
        DllCall("Kernel32\FreeLibrary", "ptr", hMod)
        main_preview_picture.Value := "HBITMAP:" hBitmap
        Gdip_Shutdown(pToken)
      }
      catch Error as what_went_wrong {
        oh_no(what_went_wrong)
        Gdip_Shutdown(pToken)
      }
      return 1
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
          thought["controlnet_preprocessor"]["inputs"][option_pair[1]] := option_pair[2]
        }
      }

      ;check if preprocessor needs mask
      if (scripture.Has(actual_name)) {
        for (optionality in scripture[actual_name]["input"]) {
          for (opt, value_properties in scripture[actual_name]["input"][optionality]) {
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
        status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText
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
    status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText "`n" altar.ResponseText
    if (altar.Status = 200) {
      vision := Jxon_load(&response)
      ;only dealing with a single image
      preview_image_to_download[picture_frame["name"]] := vision["prompt_id"]
      Run assistant_script " " A_ScriptName " " server_address " " client_id " preview_job " vision["prompt_id"]
    }
    else {
      change_status("idle")
      return
    }
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    change_status("idle")
    return
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
      status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText
      history := Jxon_load(&response)
      if history[prompt_id]["outputs"]["save_image"].Has("images") {
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
      status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText
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
    status_text.Text := FormatTime() "`n" server_address "`n" altar.Status ": " altar.StatusText
  }
  catch Error as what_went_wrong {
    oh_no(what_went_wrong)
    return
  }
  ;attempt salvage
  download_images()
  DetectHiddenWindows True
  if (WinExist(assistant_script " ahk_class AutoHotkey")) {
    WinKill assistant_script " ahk_class AutoHotkey"
    if (WinExist(assistant_script " ahk_class AutoHotkey")) {
      status_text.Text := FormatTime() "`nAttempted to kill assistant but assistant is still alive."
    }
  }
  DetectHiddenWindows False
  change_status("idle")
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
    WinKill assistant_script " ahk_class AutoHotkey"
  }
}

;generic error
;--------------------------------------------------
oh_no(error_message) {
  status_text.Text := FormatTime() "`n" error_message.Message "`n" error_message.Extra
  FileAppend("[" A_Now "]`n" error_message.Message "`n" error_message.Extra "`n" error_message.File "`n" error_message.Line "`n" error_message.Stack "`n", "log", "utf-8")
}

;--------------------------------------------------
;--------------------------------------------------
;hotkeys
;--------------------------------------------------
;--------------------------------------------------

;--------------------------------------------------
;hide and show the overlay
;--------------------------------------------------
overlay_show(*) {
  overlay.Show()
  main_controls.Show("x" screen_border_x " y" A_ScreenHeight - screen_border_y - main_controls_h  " NoActivate")
  lora_selection.Show("x" screen_border_x " y" A_ScreenHeight - screen_border_y - main_controls_h - lora_selection_h " NoActivate")
  preview_display.Show("x" A_ScreenWidth / 2 " y" screen_border_y " NoActivate")
  mask_and_controlnet.Show("x" screen_border_x " y" screen_border_y " NoActivate")
  ;controlnet preprocessor options pretend to belong to the other gui
  WinGetPos &mask_and_controlnet_x, &mask_and_controlnet_y, &mask_and_controlnet_w, &mask_and_controlnet_h, mask_and_controlnet.Hwnd
  controlnet_preprocessor_options.Show("x" mask_and_controlnet_x + controlnet_preprocessor_options_start_x " y" mask_and_controlnet_y + controlnet_preprocessor_options_start_y " NoActivate")
  output_viewer.Show("x" A_ScreenWidth - screen_border_x - output_viewer_w " y" screen_border_y " NoActivate")
  status_box.Show("x" A_ScreenWidth - status_box_w " y" A_ScreenHeight - status_box_h " NoActivate")
  ;status_box.Show("x0 y0 NoActivate")
  global overlay_visible := 1
}

overlay_hide(*) {
  overlay.Hide()
  main_controls.Hide()
  lora_selection.Hide()
  preview_display.Hide()
  mask_and_controlnet.Hide()
  controlnet_preprocessor_options.Hide()
  output_viewer.Hide()
  status_box.Hide()
  settings_window.Hide()
  global overlay_visible := 0
}

overlay_toggle(*) {
  if (!overlay_visible) {
    overlay_show()
  }
  else {
    overlay_hide()
  }
}

;convenience hotkey to allow normal capslock by pushing shift+capslock
;--------------------------------------------------
+CapsLock::Capslock
