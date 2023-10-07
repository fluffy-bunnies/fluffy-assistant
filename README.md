# fluffy-assistant
<p>
fluffy-assistant is an interface for ComfyUI created to assist with image generations and adjustments. It is intended to metaphorically shuttle pixels between common Stable Diffusion tasks and image editors. It also works with AI Horde if your computer is slightly potato.
</p>

<b>Requirements</b><br>
<ul>
  <li>Windows</li>
  <li>An instance of <a href="https://github.com/comfyanonymous/ComfyUI">ComfyUI</a> to connect to, or alternatively, <a href="https://stablehorde.net/">AI Horde</a></li>
  <li>A display with a resolution of at least 1920*1080 (100% DPI scaling) is strongly recommended</li>
</ul>

<b>Installation</b><br>
<ul>
  <li>Download the .zip from <a href="https://github.com/fluffy-bunnies/fluffy-assistant/releases">Releases</a><br> (For the uncompiled scripts, download source code or clone the repo.)</li>
  <li>Unzip somewhere</li>
  <li>(Optional) To use ControlNet preprocessors with ComfyUI, install the custom nodes from <a href="https://github.com/Fannovel16/comfyui_controlnet_aux">here<a></li>
  <li>(Optional) To use IPAdapter with ComfyUI, install the custom nodes from <a href="https://github.com/cubiq/ComfyUI_IPAdapter_plus">here<a></li>
</ul>

<b>Usage</b><br>
<ul>
  <li>Run fluffy-assistant.ahk or fluffy-assistant.exe</li>
  <li>Press CapsLock to toggle the overlay on and off</li>
  <li>Right click on the character in the corner for some basic options - make sure to connect to an address or the program will do nothing</li>
  <li>Press Ctrl+Tab or Ctrl+Shift+Tab to switch between ComfyUI and Horde</li>
  <li>Right click on the empty images for options or drop image files onto them</li>
  <li>The Script can be shut down from the system tray</li>
</ul>

<b>Notes</b><br>
<ul>
<li>For more options, make a copy of the settings.ini.example file, rename it to settings.ini and open with a text editor (or click on "Open Settings File" and the script will attempt to do this automatically with Notepad).</li>
<li>By default, CapsLock is used to toggle the overlay's visibility. This can be changed or disabled. IF YOU CANNOT STOP SHOUTING, press CapsLock while holding down a modifier key (press Shift+CapsLock for example).</li>
<li>Pressing Shift+F-key (F1 to F12) saves the current generation parameters to a save slot. Pressing an F-key (without shift) loads the corresponding saved state. A new set of 12 slots can be created by changing the "Workspace". Save states are enabled by default as insurance against some bugs.</li>
<li>Other hotkeys can be set in the settings file for clipboard operation shortcuts or to toggle only one specific overlay.</li>
<li>By default, the script does not automatically connect to any server. Save an address to change this behaviour.</li>
<br>
<li>A local installation of ComfyUI can be reached at 127.0.0.1:8188 by default.</li>
<li>For ComfyUI, put "00" (a pair of zeros and nothing else) in either prompt field to zero it out - this behaviour is specific to this interface.</li>
<li>For ComfyUI, ControlNet preprocessors and IPAdapter currently depend on the specific custom nodes linked above. They were tested at time of writing but compatibility may break if the node behaviours change.</li>
<br>
<li>stablehorde.net is the default instance of AI Horde, and can be used anonymously with the API key, "0000000000".</li>
<li>For the Horde, sharing generations with LAION is turned on by default. This can be turned off, but leaving it on benefits the quality of future AI and society will love you for it.</li>
<li>For the Horde, NSFW results are turned off by default. This can be changed in the settings to disable all censorship with <a href="https://github.com/Haidra-Org/AI-Horde/blob/main/FAQ.md#do-you-censor-generations">one exception</a>. The "Replacement Filter" option is intended to prevent users from ending up in the naughty corner unintentionally because of this.</li>
<br>
<li>The little assistant character can be changed by replacing assistant.png with another file using the same name.</li>
</ul>
