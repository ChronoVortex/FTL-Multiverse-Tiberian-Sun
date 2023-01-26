mods.chronoutil = {}

----------------------------
-- MISC UTILITY FUNCTIONS --
----------------------------
-- Generic iterator for C vectors
function mods.chronoutil.vter(cvec)
    local i = -1 --so the first returned value is indexed at zero
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Check if a given crew member is being mind controlled by a ship system
function mods.chronoutil.under_mind_system(crewmem)
    local controlledCrew = nil
    local otherShipId = (crewmem.iShipId + 1)%2
    pcall(function() controlledCrew = Hyperspace.Global.GetInstance():GetShipManager(otherShipId).mindSystem.controlledCrew end)
    if controlledCrew then
        for crew in mods.chronoutil.vter(controlledCrew) do
            if crewmem == crew then
                return true
            end
        end
    end
    return false
end

-- Get a list of all crew on the room tile at the given point
function mods.chronoutil.get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in mods.chronoutil.vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

---------------------------
-- BETTER PRINT FUNCTION --
---------------------------
local PrintHelper = {
    queue = {},

    timer = 999,           -- So it doesn't render on game startup
    config = {
        x = 154,           -- x coordinate of printed lines
        y = 100,           -- y coordinate of printed lines
        font = 10,         -- The font to use
        line_length = 250, -- How long a line can be before it is broken
        duration = 5,      -- The number of seconds before something is cleared from the console
        messages = 10,     -- How many messages can be on the console at once
    },
    Render = function(self)
        if self.timer <= self.config.duration then
           Graphics.freetype.easy_printAutoNewlines(
               self.config.font,
               self.config.x,
               self.config.y,
               self.config.line_length,
               table.concat(self.queue, "\n")
           )
           self.timer = self.timer + (Hyperspace.FPS.SpeedFactor/16) -- Makes the time pass in proportion to game speed, maybe change
        else
            self.timer = 0
            table.remove(self.queue, 1)
        end
    end,
    
    AddString = function(self, string)
        if self.timer > self.config.duration then
            self.timer = 0
        end
        table.insert(self.queue, tostring(string))
        if #self.queue > self.config.messages then
            table.remove(self.queue, 1)
        end
    end,
}

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function() end, function()
    PrintHelper:Render()
end)

local old_print = print
function print(x)
    PrintHelper:AddString(x)
    old_print(x)
end

-----------------------
-- CREW DATA MANAGER --
-----------------------
-- Set up a table that always contains all CrewMember instances
local crewtable = {}
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmember)
    local crewId = Hyperspace.Get_CrewMember_Extend(crewmember).selfId
    if not crewtable[crewId] then
        crewtable[crewId] = {}
    end
end, 1000) -- Priority such that this runs before all CREW_LOOP functions that assume the existance of this table

-- Clean out old CrewMember instances every 5 seconds
local cycleTime = 5
local timer = 0
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    timer = timer + Hyperspace.FPS.SpeedFactor/16
    if timer > cycleTime then
        timer = 0
        
        -- Find all existing crew members
        local shouldSave = {}
        local crewCheckList = nil
        if pcall(function() crewCheckList = Hyperspace.ships.player.vCrewList end) then
            for existingCrew in mods.chronoutil.vter(crewCheckList) do
                shouldSave[Hyperspace.Get_CrewMember_Extend(existingCrew).selfId] = true
            end
        end
        if pcall(function() crewCheckList = Hyperspace.ships.enemy.vCrewList end) then
            for existingCrew in mods.chronoutil.vter(crewCheckList) do
                shouldSave[Hyperspace.Get_CrewMember_Extend(existingCrew).selfId] = true
            end
        end

        -- Remove crew members that no longer exist
        for crewId in pairs(crewtable) do
            if not shouldSave[crewId] then
                crewtable[crewId] = nil
            end
        end
    end
end)

-- For access to the data outside of this file
function mods.chronoutil.crew_data(crewmember)
    return crewtable[Hyperspace.Get_CrewMember_Extend(crewmember).selfId]
end

----------------------------
-- TUTORIAL ARROW MANAGER --
----------------------------
local tutArrowAlphaInterval = 0.38
local tutArrowSpr1 = Hyperspace.Resources:GetImageId("tutorial/arrow.png")
local tutArrowSpr2 = Hyperspace.Resources:GetImageId("tutorial/arrow2.png")
local tutArrow = {
    visible = false,
    dir = 0,
    x = 0,
    y = 0,
    timer = 0
}
function mods.chronoutil.ShowTutorialArrow(dir, x, y)
    tutArrow.visible = true
    tutArrow.dir = dir
    tutArrow.x = x
    tutArrow.y = y
    tutArrow.timer = 0
end
function mods.chronoutil.HideTutorialArrow()
    tutArrow.visible = false
end
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
    if tutArrow.visible then
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr1,
            tutArrow.x, tutArrow.y,
            tutArrowSpr1.width, tutArrowSpr1.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1), false
        )
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr2,
            tutArrow.x, tutArrow.y,
            tutArrowSpr2.width, tutArrowSpr2.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1 - math.abs(tutArrow.timer - tutArrowAlphaInterval)/tutArrowAlphaInterval), false
        )
        tutArrow.timer = (tutArrow.timer + Hyperspace.FPS.SpeedFactor/16)%(2*tutArrowAlphaInterval)
    end
end)
