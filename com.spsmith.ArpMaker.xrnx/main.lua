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

options = {
  --initial values:
  --instrument to create phrases for
  selected_instrument = 0,

  --initial sample offset
  offset = 0x00,

  --volume range from first to last note
  vol_min = 0x80,
  vol_max = 0x80,

  --stereo spread
  stereo_spread = 0x00,
  stereo_direction = "L ➔ R",

  --glide value for each note
  glide = 0xff,

  --LPB (speed)
  lpb = 4
}

--settings document
local settings = renoise.Document.create("Settings"){
  --instrument that will be edited
  selected_instrument = 0,

  --initial sample offset (S command)
  offset = 0x00,

  --volume range from first to last note
  vol_min = 0x80,
  vol_max = 0x80,

  --stereo spread
  stereo_spread = 0x00,
  stereo_direction = "L ➔ R",

  --glide value for each note (G command)
  glide = 0xff,

  --LPB multiplier (speed)
  speed = 3
}

local function selected_instrument_notifier()
  local value = settings.selected_instrument.value

  show_status(("Selected instrument is '%s"):format(value))
end

local function offset_notifier()
  local value = settings.offset.value

  show_status(("Offset is '%s"):format(value))
end

local function vol_min_notifier()
  local value = settings.vol_min.value

  show_status(("Volume (min) is '%s"):format(value))
end

local function vol_max_notifier()
  local value = settings.vol_max.value

  show_status(("Volume (max) is '%s"):format(value))
end

local function stereo_spread_notifier()
  local value = settings.stereo_spread.value

  show_status(("Stereo spread is '%s"):format(value))
end

local function stereo_direction_notifier()
  local value = settings.stereo_direction.value

  show_status(("Stereo direction is '%s"):format(value))
end

local function glide_notifier()
  local value = settings.glide.value

  show_status(("Glide amount is '%s"):format(value))
end

local function speed_notifier()
  local value = settings.speed.value

  show_status(("Speed value is '%s"):format(value))
end

settings.selected_instrument:add_notifier(selected_instrument_notifier)
settings.offset:add_notifier(offset_notifier)
settings.vol_min:add_notifier(vol_min_notifier)
settings.vol_max:add_notifier(vol_max_notifier)
settings.stereo_spread:add_notifier(stereo_spread_notifier)
settings.stereo_direction:add_notifier(stereo_direction_notifier)
settings.glide:add_notifier(glide_notifier)
settings.speed:add_notifier(speed_notifier)

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
    load_options(renoise.song():instrument(renoise.song().selected_instrument_index))
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

--load arp values from the current instrument into options
function load_options(instrument)
  --first make sure this instrument has arps already
  local phrases = count_phrases(instrument)
  if phrases == renoise.Instrument.MAX_NUMBER_OF_PHRASES then
    --load values from current arps
    show_status(("Loading options from %s"):format(instrument.name))

    --look at phrase 037
    local phrase = instrument:phrase(038) --maybe wrong index idc
    local line1 = phrase.lines[1]

    --load offset, vol, pan, glide, lpb settings
    options.offset = phrase.lines[1].note_columns[1].effect_amount_value
    options.vol_min = phrase.lines[1]:note_column(1).volume_value
    options.vol_max = math.min(phrase.lines[5]:note_column(1).volume_value, 0x80) --value is 255 when column is empty
    local ss = 0x40 - phrase.lines[1]:note_column(1).panning_value
    options.stereo_spread = math.abs(ss)
    if ss >= 0 then
      options.stereo_direction = "L ➔ R"
    else
      options.stereo_direction = "R ➔ L"
    end
    options.glide = phrase.lines[1]:effect_column(1).amount_value
  else
    --load default options
    show_status(("Loading default options"))

    options.offset = 0x00
    options.vol_min = 0x80
    options.vol_max = 0x80
    options.stereo_spread = 0x00
    options.stereo_direction = "L ➔ R"
    options.glide = 0xff
  end
end

--arp making functions
function make_arps(instrument)
  --show_status(string.format("making arps! options are: %d, %d, %d, %d, %d, %d", options.selected_instrument, options.vol_min, options.vol_max, options.pan_min, options.pan_max, options.glide))

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
  --local instrument = renoise.song():instrument(options.selected_instrument + 1)
  local initial_phrases = count_phrases(instrument)

  --create the max number of phrases
  for i = initial_phrases + 1, renoise.Instrument.MAX_NUMBER_OF_PHRASES do
      instrument:insert_phrase_at(i)
  end
end

--construct an arp phrase (chord is based on phrase number)
function construct_phrase(instrument, phrase_number)
  show_status(string.format("Constructing phrase %d for %s...", phrase_number, instrument.name))

  --get the instrument
  --local instrument = renoise.song():instrument(options.selected_instrument + 1)

  --get the phrase and clear it
  local phrase = instrument:phrase(phrase_number + 1)
  phrase:clear()
  
  --set phrase settings
  phrase.number_of_lines = 6
  phrase.visible_note_columns = 1
  phrase.visible_effect_columns = 1
  phrase.looping = true
  phrase.autoseek = true
  phrase.panning_column_visible = true
  phrase.sample_effects_column_visible = true

  local stereo_mul = 1
  if options.stereo_direction == "R ➔ L" then
    stereo_mul = -1
  end

  --note 1: root note
  phrase.lines[1]:note_column(1).note_value = 49
  --vol, pan
  phrase.lines[1]:note_column(1).volume_value = options.vol_min
  phrase.lines[1]:note_column(1).panning_value = 0x40 - (stereo_mul * options.stereo_spread)
  --sample offset
  phrase.lines[1].note_columns[1].effect_number_string = '0S'
  phrase.lines[1].note_columns[1].effect_amount_value = options.offset
  if options.glide > 0 then
    --glide
    phrase.lines[1]:effect_column(1).number_string = '0G'
    phrase.lines[1]:effect_column(1).amount_value = options.glide
  end

  --note 2: first arp note
  local note2 = math.floor(phrase_number / 16)
  phrase.lines[3]:note_column(1).note_value = 49 + note2
  --vol, pan
  phrase.lines[3]:note_column(1).volume_value = math.floor(lerp(options.vol_min, options.vol_max, .5))
  phrase.lines[3]:note_column(1).panning_value = 0x40
  if options.glide > 0 then
    --glide
    phrase.lines[3]:effect_column(1).number_string = '0G'
    phrase.lines[3]:effect_column(1).amount_value = options.glide
  else
    --sample offset
    phrase.lines[3].note_columns[1].effect_number_string = '0S'
    phrase.lines[3].note_columns[1].effect_amount_value = options.offset
  end

  --note 3: second arp note
  local note3 = phrase_number % 16
  phrase.lines[5]:note_column(1).note_value = 49 + note3
  --vol, pan
  phrase.lines[5]:note_column(1).volume_value = options.vol_max
  phrase.lines[5]:note_column(1).panning_value = 0x40 + (stereo_mul * options.stereo_spread)
  if options.glide > 0 then
    --glide
    phrase.lines[5]:effect_column(1).number_string = '0G'
    phrase.lines[5]:effect_column(1).amount_value = options.glide
  else
    --sample offset
    phrase.lines[5].note_columns[1].effect_number_string = '0S'
    phrase.lines[5].note_columns[1].effect_amount_value = options.offset
  end
end

-- show_tool_window
function show_tool_window()

  load_options(renoise.song():instrument(options.selected_instrument + 1))

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
      id = "instrument",
      min = 0,
      max = count_instruments() - 1,
      --initialize to the currently selected instrument
      --selected_instrument_index is the selected instrument's number + 1
      value = renoise.song().selected_instrument_index - 1,

      tostring = function(value) 
        return ("%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.selected_instrument = value

        show_status(("Selected instrument '%d'"):
          format(options.selected_instrument))
      end
    }
  }

  local instrument_namebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = ("[%s]"):format(renoise.song():instrument(vb.views.instrument.value + 1).name)
    }
  }

  local offset_valuebox = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Sample Offset"
    },

    vb:valuebox{
      min = 0,
      max = 0xff,
      value = 0,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.offset = value

        show_status(("Sample offset is '%d'"):format(options.offset))
      end
    }
  }

  local vol_min_slider = vb:row{
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Volume (start)"
    },

    vb:slider{
      min = 0,
      max = 0x80,
      default = 0x80,
      value = options.vol_min,

      notifier = function(value)
        options.vol_min = value

        show_status(("Starting volume is '%d'"):
          format(options.vol_min))
      end
    }
  }

    local vol_max_slider = vb:row{
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Volume (end)"
    },

    vb:slider{
      min = 0,
      max = 0x80,
      default = 0x80,
      value = options.vol_max,

      notifier = function(value)
        options.vol_max = value

        show_status(("Ending volume is '%d'"):
          format(options.vol_max))
      end
    }
  }

  local stereo_slider = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Stereo Spread"
    },

    vb:slider{
      min = 0,
      max = 0x40,
      default = 0x00,
      value = options.stereo_spread,

      notifier = function(value)
        options.stereo_spread = value

        show_status(("Stereo spread is '%d'"):
          format(options.stereo_spread))
      end
    },
  }

  local init_ss_value = 1
  if options.stereo_direction == "R ➔ L" then
    init_ss_value = 2
  end

  local stereo_direction = vb:row{

    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Stereo Direction"
    },
--
    vb:switch{
      id = "stereo_direction",
      value = init_ss_value,
      width = 100,
      items = {"L ➔ R", "R ➔ L"},

      notifier = function(index)
        local switch = vb.views.stereo_direction
        options.stereo_direction = switch.items[index]

        show_status(("Stereo direction is '%s'"):
          format(options.stereo_direction))
      end
    }
  }

  local glide_slider = vb:row{
    vb:text{
      width = TEXT_ROW_WIDTH,
      text = "Glide"
    },
    vb:slider{
      min = 0, 
      max = 0xff,
      default = 0xff,
      value = options.glide,

      notifier = function(value)
        options.glide = value

        show_status(("Glide is '%d'"):
          format(options.glide))
      end
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
        make_arps(renoise.song():instrument(options.selected_instrument + 1))
      end,
    },

    vb:button {
      text = "Load",
      width = 60,
      height = DEFAULT_DIALOG_BUTTON_HEIGHT,
      released = function()
        load_options(renoise.song():instrument(options.selected_instrument + 1))
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
        instrument_namebox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        offset_valuebox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        vol_min_slider,
        vol_max_slider,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        stereo_slider,
        stereo_direction,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        glide_slider,

        vb:space {height = DEFAULT_CONTROL_HEIGHT}
      },

    },
    
    -- close
    button_row
  }
  
  --set some default values on start
  options.selected_instrument = renoise.song().selected_instrument_index - 1
  options.lpb = renoise.song().transport.lpb * 3

  -- DIALOG
  
  control_example_dialog = renoise.app():show_custom_dialog(
    "ArpMaker", dialog_content
  )

end

_AUTO_RELOAD_DEBUG = function()
  show_status("ArpMaker loaded.")
end