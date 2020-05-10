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
  selected_instrument = 0x00,

  --volume range from first to last note
  vol_min = 0x80,
  vol_max = 0x80,

  --panning range from first to last note
  pan_min = 0x40,
  pan_max = 0x40,

  --glide value for each note
  glide = 0xff
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

  --valuebox for instrument selection
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

  -- close button
    
  local close_button_row = vb:horizontal_aligner {
    mode = "right",
    
    vb:button {
      text = "Close",
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
    close_button_row
  }
  
  
  -- DIALOG
  
  control_example_dialog = renoise.app():show_custom_dialog(
    "ArpMaker", dialog_content
  )

end