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
  --instrument to create phrases for
  selected_instrument = 0,

  --volume range from first to last note
  vol_min = 0x80,
  vol_max = 0x80,

  --panning range from first to last note
  pan_min = 0x40,
  pan_max = 0x40,

  --glide value for each note
  glide = 0xff,

  --LPB (speed)
  lpb = 4
}

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
  name = "Main Menu:Tools:ArpMaker:Launch ArpMaker",
  invoke = function()
    show_tool_window()
  end
}

--------------------------------------------------------------------------------
-- functions
--------------------------------------------------------------------------------

function lerp(a,b ,t)
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

function count_phrases(instrument)
  local num_phrases = 0
  for _ in pairs(instrument.phrases) do num_phrases = num_phrases + 1 end
  return num_phrases
end

--arp making functions
function make_arps()
  --show_status(string.format("making arps! options are: %d, %d, %d, %d, %d, %d", options.selected_instrument, options.vol_min, options.vol_max, options.pan_min, options.pan_max, options.glide))

  create_phrases()

  for i = 1, renoise.Instrument.MAX_NUMBER_OF_PHRASES - 1 do
    --leave the first phrase alone
    construct_phrase(i)
  end
end

function create_phrases()
  local instrument = renoise.song():instrument(options.selected_instrument + 1)

  local initial_phrases = count_phrases(instrument)

  --create the max number of phrases
  for i = initial_phrases + 1, renoise.Instrument.MAX_NUMBER_OF_PHRASES do
      instrument:insert_phrase_at(i)
  end
end

function construct_phrase(phrase_number)
  show_status(string.format("constructing phrase %d", phrase_number))

  --get the instrument
  local instrument = renoise.song():instrument(options.selected_instrument + 1)

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

  --note 1: base note
  phrase.lines[1]:note_column(1).note_value = 49
  phrase.lines[1]:note_column(1).volume_value = options.vol_min
  phrase.lines[1]:note_column(1).panning_value = options.pan_min
  phrase.lines[1]:effect_column(1).number_string = '0G'
  phrase.lines[1]:effect_column(1).amount_value = options.glide

  --note 2: first arp note
  local note2 = math.floor(phrase_number / 16)
  phrase.lines[3]:note_column(1).note_value = 49 + note2
  phrase.lines[3]:note_column(1).volume_value = math.floor(lerp(options.vol_min, options.vol_max, .5))
  phrase.lines[3]:note_column(1).panning_value = math.floor(lerp(options.pan_min, options.pan_max, .5))
  phrase.lines[3]:effect_column(1).number_string = '0G'
  phrase.lines[3]:effect_column(1).amount_value = options.glide

  --note 3: second arp note
  local note3 = phrase_number % 16
  phrase.lines[5]:note_column(1).note_value = 49 + note3
  phrase.lines[5]:note_column(1).volume_value = options.vol_max
  phrase.lines[5]:note_column(1).panning_value = options.pan_max
  phrase.lines[5]:effect_column(1).number_string = '0G'
  phrase.lines[5]:effect_column(1).amount_value = options.glide
end

-- show_tool_window

function show_tool_window()

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
      min = 0,
      max = count_instruments() - 1,
      --selected_instrument_index is the selected instrument's number + 1
      value = renoise.song().selected_instrument_index - 1,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.selected_instrument = value

        show_status(("Selected instrument changed to '%d'"):
          format(options.selected_instrument))
      end
    }
  }

  local vol_header = vb:column {
    margin = CONTROL_MARGIN,
    style = "group",
    vb:text{
      text = "Volume"
    }
  }

  local vol_min_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Start"
    },

    vb:valuebox {
      min = 0,
      max = 0x80,
      value = 0x80,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.vol_min = value

        show_status(("Starting volume is '%d'"):
          format(options.vol_min))
      end
    }
  }

  local vol_max_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "End"
    },

    vb:valuebox {
      min = 0,
      max = 0x80,
      value = 0x80,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.vol_max = value

        show_status(("Ending volume is '%d'"):
          format(options.vol_max))
      end
    }
  }

  local pan_header = vb:column {
    margin = CONTROL_MARGIN,
    style = "group",
    vb:text{
      text = "Panning"
    }
  }

  local pan_min_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Start"
    },

    vb:valuebox {
      min = 0,
      max = 0x80,
      value = 0x40,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.pan_min = value

        show_status(("Starting pan is '%d'"):
          format(options.pan_min))
      end
    }
  }

  local pan_max_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "End"
    },

    vb:valuebox {
      min = 0,
      max = 0x80,
      value = 0x40,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

      notifier = function(value)
        options.pan_max = value

        show_status(("Ending pan is '%d'"):
          format(options.pan_max))
      end
    }
  }

  local glide_header = vb:column {
    margin = CONTROL_MARGIN,
    style = "group",
    vb:text{
      text = "Glide"
    }
  }

  local glide_valuebox = vb:row {
    vb:text {
      width = TEXT_ROW_WIDTH,
      text = "Glide"
    },

    vb:valuebox {
      min = 0,
      max = 0xff,
      value = 0xff,

      tostring = function(value) 
        return ("0x%.2X"):format(value)
      end,

      tonumber = function(str) 
        return tonumber(str, 0x10)
      end,

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
      text = "Make Arps",
      width = 60,
      height = DEFAULT_DIALOG_BUTTON_HEIGHT,
      released = function()
        make_arps()
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

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        vol_header,
        vol_min_valuebox,
        vol_max_valuebox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        pan_header,
        pan_min_valuebox,
        pan_max_valuebox,

        vb:space {height = DEFAULT_CONTROL_HEIGHT},
        glide_header,
        glide_valuebox
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