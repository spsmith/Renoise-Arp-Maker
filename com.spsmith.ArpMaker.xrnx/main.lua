--[[============================================================================
com.renoise.ExampleTool.xrnx/main.lua
============================================================================]]--

-- XRNX Bundle Layout:

-- Tool scripts must describe themself through a manifest XML, to let Renoise
-- know which API version it relies on, what "it can do" and so on, without 
-- actually loading it. See "manifest.xml" in this exampel tool for more info 
-- please
--
-- When the manifest loads and looks OK, the main file of the tool will be 
-- loaded. This  is this file -> "main.lua".
--
-- You can load other files from here via LUAs 'require', or simply put
-- all the code in here. This file simply is the main entry point of your tool. 
-- While initializing, you can register your tool with Renoise, by creating 
-- keybindings, menu entries or listening to events from the application. 
-- We will describe all this below now:

--------------------------------------------------------------------------------
-- global variables
--------------------------------------------------------------------------------

local function direction_arrow(value)
  if value <= 1 then return "L → R"
  else return "L ← R"
  end
end

local function mode_arrow(value)
  if value <= 1 then return "→"
  elseif value == 2 then return "←"
  else return "⟷"
  end
end

--settings document
local settings = renoise.Document.create("Settings"){
  --instrument that will be edited
  selected_instrument = 0,
  selected_instrument_name = "Instrument",

  --initial sample offset (S command)
  offset = 0x00,

  --arp length
  length = 3,
  max_octaves = 4,

  --arp mode
  mode = 1,
  
  --volume range from first to last note
  vol_min = 0x80,
  vol_max = 0x80,
  
  --stereo spread
  stereo_spread = 0x00,
  stereo_direction = 1,
  
  --glide value for each note (G command)
  glide = 0xff,
  
  --LPB multiplier (speed)
  speed = 3,

  --loop
  loop = true
}

local function selected_instrument_notifier()
  --load settings for the selected instrument
  load_settings(renoise.song():instrument(settings.selected_instrument.value + 1))
end

local function mode_notifier()
  show_status(("Mode is %s (%d)"):format(mode_arrow(settings.mode.value), settings.mode.value))
end

settings.selected_instrument:add_notifier(selected_instrument_notifier)
settings.mode:add_notifier(mode_notifier)

--------------------------------------------------------------------------------
-- menu entries
--------------------------------------------------------------------------------

-- you can add new menu entries into any existing context menues or the global 
-- menu in Renoise. to do so, we are using the tool's add_menu_entry function.
-- Please have a look at "Renoise.ScriptingTool.API.txt" i nthe documentation 
-- folder for a complete reference.
--
-- Note: all "invoke" functions here are wrapped into a local function(), 
-- because the functions, variables that are used are not yet know here. 
-- They are defined below, later in this file...

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:ArpMaker",
  invoke = function()
    load_settings(renoise.song():instrument(settings.selected_instrument.value + 1))
    show_tool_window()
  end
}

--------------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------------

function lerp(a,b,t)
  return a * (1 - t) + b * t
end

--show status message
function show_status(message)
  renoise.app():show_status(message)
  print(message)
end

--get total number of instruments
function count_instruments()
  local num_instruments = 0
  for _ in pairs(renoise.song().instruments) do num_instruments = num_instruments + 1 end
  return num_instruments
end

--get total number of phrases for this instrument
function count_phrases(instrument)
  local num_phrases = 0
  for _ in pairs(instrument.phrases) do num_phrases = num_phrases + 1 end
  return num_phrases
end

--load arp values from the current instrument into settings
function load_settings(instrument)
  --update selected instrument name
  settings.selected_instrument_name = instrument.name

  --check if this instrument has arps already
  if count_phrases(instrument) == renoise.Instrument.MAX_NUMBER_OF_PHRASES then
    --load values from current instrument
    --show_status(("Loading settings from '%s'"):format(instrument.name))

    --look at phrase 037
    local phrase = instrument:phrase(038) --maybe wrong index idc

    --load existing settings
    settings.offset.value = phrase.lines[1].note_columns[1].effect_amount_value
    settings.mode.value = phrase.lines[2]:note_column(1).delay_value
    settings.length.value = phrase.number_of_lines / 2
    settings.vol_min.value = phrase.lines[1]:note_column(1).volume_value
    settings.vol_max.value = math.min(phrase.lines[5]:note_column(1).volume_value, 0x80) --value is 255 when column is empty
    local ss = 0x40 - phrase.lines[1]:note_column(1).panning_value
    settings.stereo_spread.value = math.abs(ss)
    if ss >= 0 then
      settings.stereo_direction.value = 1
    else
      settings.stereo_direction.value = 2
    end
    settings.glide.value = phrase.lines[1]:effect_column(1).amount_value
    settings.speed.value = phrase.lpb / renoise.song().transport.lpb

  else
    --load default settings
    --show_status(("Loading default settings"))

    settings.offset.value = 0x00
    settings.length.value = 3
    settings.vol_min.value = 0x80
    settings.vol_max.value = 0x80
    settings.stereo_spread.value = 0x00
    settings.stereo_direction.value = 1
    settings.glide.value = 0xff
    settings.speed.value = 3
  end
end

--arp making functions
function make_arps(instrument)
  --make sure there are enough empty phrases for this instrument
  create_phrases(instrument)

  --fill in phrases with arp data
  for i = 1, renoise.Instrument.MAX_NUMBER_OF_PHRASES - 1 do
    --leave the first phrase alone
    construct_phrase(instrument, i)
  end
end

--initialize this instrument with the max number of phrases
function create_phrases(instrument)
  --local instrument = renoise.song():instrument(settings.selected_instrument + 1)
  local initial_phrases = count_phrases(instrument)

  --create the max number of phrases
  for i = initial_phrases + 1, renoise.Instrument.MAX_NUMBER_OF_PHRASES do
      instrument:insert_phrase_at(i)
  end
end

function construct_phrase(instrument, phrase_number)
  --get the phrase and clear it
  local phrase = instrument:phrase(phrase_number + 1)
  phrase:clear()
  
  --set phrase settings
  phrase.number_of_lines = settings.length.value * 2 --two lines per note
  phrase.visible_note_columns = 1
  phrase.visible_effect_columns = 1
  phrase.looping = settings.loop.value
  phrase.autoseek = true
  phrase.panning_column_visible = true
  phrase.sample_effects_column_visible = true
  phrase.lpb = renoise.song().transport.lpb * settings.speed.value
  
  --store the arp mode in the delay value for line 2 - ignored when playing the phrase, also not visible by default
  phrase.lines[2]:note_column(1).delay_value = settings.mode.value
  phrase.delay_column_visible = false

  --construct notes
  for i = 1, settings.length.value do
    construct_note(phrase, phrase_number, i)
  end
end

function construct_note(phrase, phrase_number, note_number)
  --various different outcomes based on settings
  --note_number should start at 1

  --get the line
  local two_note_arp = math.floor(phrase_number / 16) == 0 and settings.length.value % 3 == 0 and settings.mode.value ~= 3  --special settings for arps with only two pitches
  local line_number = (note_number * 2) - 1
  if two_note_arp then
    if note_number % 3 == 2 then
      line_number = (note_number * 2) --space the second note halfway
    elseif note_number % 3 == 0 then
      return --skip the third note
    end
  end
  local line = phrase.lines[line_number]
  local note_columns = line.note_columns[1]
  local note_column = line:note_column(1)
  local effect_column = line:effect_column(1)
  local t = (note_number - 1) / (settings.length.value - 1)
  if two_note_arp then
    if note_number % 3 == 1 then
      t = 0
    elseif note_number % 3 == 2 then
      t = 1
    end
  end
  local stereo_mul = 1
  if settings.stereo_direction.value == 2 then
    stereo_mul = -1
  end

  --pitch
  local note_index
  local root = 49
  local notes = {0, math.floor(phrase_number / 16), phrase_number % 16}
  local all_notes = {}
  for i = 0, (settings.length.value) - 1 do
    table.insert(all_notes, notes[(i % 3) + 1] + (math.floor(i / 3) * 12))
  end
  if settings.mode.value == 1 then
    --forwards order
    note_index = note_number
  elseif settings.mode.value == 2 then
    --reverse note order
    note_index = settings.length.value - (note_number - 1)
  elseif settings.mode.value == 3 then
    --pingpong (reverse after midpoint)
    local midpoint = math.ceil(settings.length.value / 2)
    if note_number > midpoint then
      if settings.length.value % 2 == 0 then
        note_index = (settings.length.value - note_number) + 2
      else
        note_index = (settings.length.value - note_number) + 3 --doesn't really work with odd lengths
      end
    else
      note_index = note_number
    end
  end
  note_column.note_value = root + all_notes[note_index]

  --offset
  if note_number == 1 or math.floor(settings.glide.value) == 0 then
    note_columns.effect_number_string = '0S'
    note_columns.effect_amount_value = settings.offset.value
  end

  --volume
  note_column.volume_value = lerp(settings.vol_min.value, settings.vol_max.value, t)

  --pan
  note_column.panning_value = 0x40 + (stereo_mul * lerp(-settings.stereo_spread.value, settings.stereo_spread.value, t))

  --glide
  if math.floor(settings.glide.value) > 0 then
    effect_column.number_string = '0G'
    effect_column.amount_value = settings.glide.value
  end
end

-- show_tool_window
function show_tool_window()

  load_settings(renoise.song():instrument(settings.selected_instrument.value + 1))

  local vb = renoise.ViewBuilder()

  local control_example_dialog = nil

  local CONTROL_MARGIN =
    renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

  local DIALOG_MARGIN = 
    renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN

  local DIALOG_SPACING =
    renoise.ViewBuilder.DEFAULT_DIALOG_SPACING
  
  local CONTENT_SPACING = 
    renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  
  local CONTENT_MARGIN = 
    renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
  
  local DEFAULT_CONTROL_HEIGHT = 
    renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT
  
  local DEFAULT_DIALOG_BUTTON_HEIGHT =
    renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  
  local DEFAULT_MINI_CONTROL_HEIGHT = 
    renoise.ViewBuilder.DEFAULT_MINI_CONTROL_HEIGHT
  
  local TEXT_ROW_WIDTH = 80

  ---- CONTROLS

  --valueboxes
  local instrument_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Instrument"
    },

    vb:valuebox {
      bind = settings.selected_instrument,
      id = "instrument",
      min = 0,
      max = count_instruments() - 1,
      steps = {0x01, 0x10},

      tostring = function(value) 
        return ("%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end
    }
  }

  local instrument_namebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      --text = ("[%s]"):format(renoise.song():instrument(settings.selected_instrument.value + 1).name)
      text = ""
    },

    vb:textfield{
      active = false,
      value = settings.selected_instrument_name.value,
      --bind = settings.selected_instrument_name
    }
  }

  local offset_valuebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Sample Offset"
    },

    vb:valuebox{
      bind = settings.offset,
      min = 0,
      max = 0xff,
      steps = {0x08, 0x10},

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end
    }
  }

  local length_valuebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Notes"
    },

    vb:valuebox{
      bind = settings.length,
      min = 3,
      max = 12,
      steps = {1, 3}
    }
  }

  local mode_switch = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Mode"
    },

    vb:switch{
      bind = settings.mode,
      width = 100,
      items = {mode_arrow(1), mode_arrow(2), mode_arrow(3)}
    }
  }

  local vol_min_slider = vb:row{
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Volume (start)"
    },

    vb:slider{
      bind = settings.vol_min,
      min = 0,
      max = 0x80,
      default = 0x80,
      steps = {0x08, 0x10}
    }
  }

    local vol_max_slider = vb:row{
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Volume (end)"
    },

    vb:slider{
      bind = settings.vol_max,
      min = 0,
      max = 0x80,
      default = 0x80,
      steps = {0x08, 0x10}
    }
  }

  local stereo_slider = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Stereo Spread"
    },

    vb:slider{
      bind = settings.stereo_spread,
      min = 0,
      max = 0x40,
      default = 0x00,
      steps = {0x08, 0x10}
    }
  }

  local stereo_direction = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Stereo Direction"
    },

    vb:switch{
      bind = settings.stereo_direction,
      width = 100,
      items = {direction_arrow(1), direction_arrow(2)}
    }
  }

  local glide_slider = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Glide"
    },

    vb:slider{
      bind = settings.glide,
      min = 0, 
      max = 0xff,
      default = 0xff,
      steps = {0x10, 0xff}
    }
  }

  local speed_valuebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Speed"
    },

    vb:valuebox{
      bind = settings.speed,
      min = 1,
      max = 9,
      steps = {1, 3}
    }
  }

  local loop_checkbox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Loop"
    },

    vb:checkbox{
      bind = settings.loop
    }
  }

  -- buttons
  local button_row = vb:horizontal_aligner {
    mode = "right",
    
    vb:button {
      text = "Apply",
      width = 60,
      height = DEFAULT_DIALOG_BUTTON_HEIGHT,
      released = function()
        make_arps(renoise.song():instrument(settings.selected_instrument.value + 1))
      end,
    },

    vb:button {
      text = "Clear",
      width = 60,
      height = DEFAULT_DIALOG_BUTTON_HEIGHT,
      released = function()
        clear_arps(renoise.song():instrument(settings.selected_instrument.value + 1))
      end,
    },

    vb:button {
      text = "Done",
      width = 60,
      height = DEFAULT_DIALOG_BUTTON_HEIGHT,
      notifier = function()
        control_example_dialog:close()
      end,
    }
  }

  ---- MAIN CONTENT & LAYOUT
  
  local dialog_content = vb:column {
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
    
    vb:row{
      spacing = 4*CONTENT_SPACING,

      vb:column {
        spacing = CONTENT_SPACING,
        
        instrument_valuebox,
        --instrument_namebox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        offset_valuebox,
        glide_slider,
        
        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        vol_min_slider,
        vol_max_slider,
        
        --vb:space {height = DEFAULT_CONTROL_HEIGHT},
        stereo_slider,
        stereo_direction,
        
        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        length_valuebox,
        mode_switch,
        
        --vb:space {height = DEFAULT_CONTROL_HEIGHT},
        speed_valuebox,
        loop_checkbox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT}
      },

    },
    
    -- close
    button_row
  }
  
  --set some default values on start
  settings.selected_instrument.value = renoise.song().selected_instrument_index - 1

  -- DIALOG
  
  control_example_dialog = renoise.app():show_custom_dialog(
    "ArpMaker", dialog_content
  )

end

_AUTO_RELOAD_DEBUG = function()
  show_status("ArpMaker loaded.")
end