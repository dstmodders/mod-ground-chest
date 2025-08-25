name = "Ground Chest"
description = "Open a UI to see items on the ground and interact with them."
author = "sauktux & Viktor"
version = "v".."1.3.61"
forumthread = ""
icon_atlas = "modicon.xml"
icon = "modicon.tex"
client_only_mod = true
all_clients_require_mod = false
server_only_mod = false
dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true
api_version = 10
priority = -1

local function AddOption(name,label,hover,options,default)
    return  {
        name = name,
        label = label,
        hover = hover,
        options = options,
        default = default,
        }
end

local function FormatOption(description,data,hover)
   return {description = description, data = data, hover = hover} 
    
end

local function AddEmptySeperator(seperator)
    return AddOption("" , seperator , "" , FormatOption("",0) , 0)
end

local keys_opt = {
    FormatOption("None--",0),
    FormatOption("A",97),
    FormatOption("B",98),
    FormatOption("C",99),
    FormatOption("D",100),
    FormatOption("E",101),
    FormatOption("F",102),
    FormatOption("G",103),
    FormatOption("H",104),
    FormatOption("I",105),
    FormatOption("J",106),
    FormatOption("K",107),
    FormatOption("L",108),
    FormatOption("M",109),
    FormatOption("N",110),
    FormatOption("O",111),
    FormatOption("P",112),
    FormatOption("Q",113),
    FormatOption("R",114),
    FormatOption("S",115),
    FormatOption("T",116),
    FormatOption("U",117),
    FormatOption("V",118),
    FormatOption("W",119),
    FormatOption("X",120),
    FormatOption("Y",121),
    FormatOption("Z",122),
    FormatOption("--None--",0),
    FormatOption("Period",46),
    FormatOption("Slash",47),
    FormatOption("Semicolon",59),
    FormatOption("LeftBracket",91),
    FormatOption("RightBracket",93),
    FormatOption("F1",282),
    FormatOption("F2",283),
    FormatOption("F3",284),
    FormatOption("F4",285),
    FormatOption("F5",286),
    FormatOption("F6",287),
    FormatOption("F7",288),
    FormatOption("F8",289),
    FormatOption("F9",290),
    FormatOption("F10",291),
    FormatOption("F11",292),
    FormatOption("F12",293),
    FormatOption("Up",273),
    FormatOption("Down",274),
    FormatOption("Right",275),
    FormatOption("Left",276),
    FormatOption("PageUp",280),
    FormatOption("PageDown",281),
    FormatOption("Home",278),
    FormatOption("Insert",277),
    FormatOption("Delete",127),
    FormatOption("End",279),
    FormatOption("--None",0),
}

local bool_opt = {
    FormatOption("Disabled",false),
    FormatOption("Enabled",true),
}

local search_ranges = {
    FormatOption("Short",1),
    FormatOption("Medium",2),
    FormatOption("Large",3),
}

local percent_opt = {}
for i = 0,19 do
	percent_opt[i+1] = FormatOption((i*5).."%",i*0.05)
end
percent_opt[1].hover = "Doesn't fade at all."

local queue_types = {
    FormatOption("No",false,"Items will be picked up based on which item is closest."),
    FormatOption("Yes",true,"Items will be picked up in the order they were queued."),
}

local positions = {
    FormatOption("No",false,"UI will always be at the Top position"),
    FormatOption("Yes",true,"UI will be at the last moved position"),
}

configuration_options = {
	AddOption("ui_button","Toggle UI","Press this button to turn the Ground Chest UI On/Off",keys_opt,114), -- Default key is 'R'
	AddOption("searchrange","Search Range","The default range at which items will be searched for",search_ranges,2),
    AddOption("includeskins","Include Skins","Whether the items should be shown as their default item or separated into skins.",bool_opt,false),
    AddOption("ignoreocean","Ignore Ocean","Whether to show items that are in the ocean.",bool_opt,false),
    AddOption("boatmode","Boat Mode","Exclude items not located on the current boat or island.",bool_opt,false),
    AddOption("ignorestacks","Ignore Stacks","Whether items, which are already fully stacked, should be picked up via item queueing.",bool_opt,false),
    AddOption("queuetype","Respect Queue","Should the queue order be respected?",queue_types,false),
    AddOption("uselastposition","Remember Position","Should the UI position be remembered?",positions,false),
    AddOption("uifade","UI Fading","Fades the Ground Chest UI if not focused.\nHigher value means less visibility.",percent_opt,0.50),
}
