local function isempty(s)
  return s == nil or s == ''
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function getNpcIdFromUnitId(unitId)  
  local _, _, _, _, _,npcId = strsplit('-', UnitGUID(unitId) or '');
  return tonumber(npcId)
end
local function getNpcIdFromGuid(guid)
  local _, _, _, _, _,npcId = strsplit('-', guid or '');
  return tonumber(npcId)
end

local function createSpellObj(spellName,spellId,zone,unitName,npcId,notInterruptible,histNpcId)
  local spell={};
  spell["spellType"] = "SpellCast";
  spell["spellName"] = spellName;
  spell["spellId"] = spellId;
  spell["zone"] = zone;
  spell["unitName"] = unitName;
  spell["npcId"] = npcId;  
  spell["notInterruptible"] = notInterruptible;  
  spell["histNpcId"] = histNpcId;
  return spell;
end
local function createChannelObj(spellName,spellId,zone,unitName,npcId,notInterruptible,histNpcId)
  local spell={};
  spell["spellType"] = "SpellChannel";
  spell["spellName"] = spellName;
  spell["spellId"] = spellId;
  spell["zone"] = zone;
  spell["unitName"] = unitName;
  spell["npcId"] = npcId;  
  spell["notInterruptible"] = notInterruptible;  
  spell["histNpcId"] = histNpcId;
  return spell;    
end
local function createEnemyBuffObj(spellName,spellId,zone,affectedUnitName,affectedUnitId,sourceUnitName,sourceUnitId,histNpcId)
  local spell={};
  spell["spellType"] = "EnemyBuff";
  spell["spellName"] = spellName;
  spell["spellId"] = spellId;
  spell["zone"] = zone;  
  spell["affectedUnitName"] = affectedUnitName;
  spell["affectedUnitId"] = affectedUnitId;
  spell["sourceUnitName"] = sourceUnitName;
  spell["sourceUnitId"] = sourceUnitId;
  spell["histNpcId"] = histNpcId;
  return spell;
end
local function createPlayerDebuffObj(spellName,spellId,zone,sourceName,sourceUnitId,histNpcId)
  local spell = {};
  spell["spellType"] = "PlayerDebuff";
  spell["spellName"] = spellName;
  spell["spellId"] = spellId;
  spell["zone"] = zone;
  spell["sourceName"] = sourceName;
  spell["sourceUnitId"] = sourceUnitId; -- ist quasi ein platzhalter unit für unbekannte debuffs auf den player
  spell["histNpcId"] = histNpcId; 
  return spell;
end

local function notifySpellCast(unitId,spellId)
  local spellName, _, _, _, endTimeMS,_,_,notInterruptible = UnitCastingInfo(unitId);     
  return createSpellObj(spellName,spellId,GetZoneText(),UnitName(unitId),getNpcIdFromUnitId(unitId),notInterruptible,getNpcIdFromUnitId(unitId));
  --  print("cast ".. spellName.."("..spellId..")".." in ".. zone .." von "..UnitName(unitId).."(".. getNpcIdFromUnitId(unitId) ..")");      
end
local function notifyChannelCast(unitId,spellId)  
  local spellName, _, _, _, endTimeMS,_,notInterruptible = UnitChannelInfo(unitId);            
  return createSpellObj(spellName,spellId,GetZoneText(),UnitName(unitId),getNpcIdFromUnitId(unitId),notInterruptible,getNpcIdFromUnitId(unitId));
  --print("channel ".. spellName.."("..spellId..")".." in ".. zone .." von "..UnitName(unitId).."(".. getNpcIdFromUnitId(unitId) ..")");  
end

local function notifyEnemyBuff(affectedUnitId,count)   
  -- hier hat eine unfriendly unit einen buff 
  local spellName, _, _, _, _, _, sourceUnitId, _, _, spellId= UnitBuff(affectedUnitId,count);                       
  -- probleme
  -- source kann nil sein
  -- source kann friend sein?
  spell={};
  if(sourceUnitId == nil) then
    -- unfriendly hat buff mit unbekannter quelle    
    spell = createEnemyBuffObj(spellName,spellId,GetZoneText(),UnitName(affectedUnitId),getNpcIdFromUnitId(affectedUnitId),"unknown",0,getNpcIdFromUnitId(affectedUnitId));
  else -- könnte hier noch sein das source player ist, dann bug
  -- elseif(not UnitIsPlayer(sourceId)) then
    --unfriendly unit hat buff mit bekannter source 
    spell = createEnemyBuffObj(spellName,spellId,GetZoneText(),UnitName(affectedUnitId),getNpcIdFromUnitId(affectedUnitId),UnitName(sourceUnitId),getNpcIdFromUnitId(sourceUnitId),getNpcIdFromUnitId(affectedUnitId));
  end  
  --print("buff von "..sourceName.."("..tostring(sourceNpcId)..")".. spellName.."("..spellId..")".." in ".. zone .." ist auf "..UnitName(unitId).."(".. getNpcIdFromUnitId(unitId) ..")");
  return spell;
end

local function notifyPlayerDebuff(count) 
  -- hier weiß man player hat debuff, grundlegend worth zu saven, auch ohne source
  local unitId = "player";
  local spellName, _, _, _, _, _, sourceUnitId, _, _, spellId = UnitDebuff(unitId, count);
  local spell={};  
  if(sourceUnitId == nil) then
    -- player hat debuff, keiner weiß woher-> random save     
    spell = createPlayerDebuffObj(spellName,spellId,GetZoneText(),"unknown",0,0);
  --elseif(sourceUnitId ~= nil and not UnitIsPlayer(sourceUnitId)) then              
  elseif(not UnitIsPlayer(sourceUnitId)) then              
    spell = createPlayerDebuffObj(spellName,spellId,GetZoneText(),UnitName(sourceUnitId),getNpcIdFromUnitId(sourceUnitId),getNpcIdFromUnitId(sourceUnitId));
  end
  return spell;
end

--print("buff von "..sourceName.."("..tostring(sourceNpcId)..")".. spellName.."("..spellId..")".." in ".. zone .." ist auf "..UnitName(unitId).."(".. getNpcIdFromUnitId(unitId) ..")");

-- --------------------------------
-- ----- HISTORY PART -------------
-- --------------------------------
local history = {};
local historyLength = 0;

local function addToHistory(spell)   
  if next(spell) == nil then
    return
  end  
  if(history[spell["zone"]] == nil) then
    history[spell["zone"]] = {};  
  end
  if(history[spell["zone"]][spell["histNpcId"]] == nil) then
    history[spell["zone"]][spell["histNpcId"]] = {};
  end
  if(history[spell["zone"]][spell["histNpcId"]][spell["spellId"]] == nil) then
    history[spell["zone"]][spell["histNpcId"]][spell["spellId"]] = {};
  end
  if(history[spell["zone"]][spell["histNpcId"]][spell["spellId"]]["spellType"] == nil) then  
    for key,value in pairs(spell) do
      history[spell["zone"]][spell["histNpcId"]][spell["spellId"]][key] = value;
    end 
    historyLength = historyLength+1;
    print(historyLength);      
  end
end

-- --------------------------------
-- ----- UI PART -------------
-- --------------------------------

local editBox = CreateFrame("EditBox","editBox",UIParent);
editBox:SetHeight(200); -- kommt von region
editBox:SetWidth(800); -- kommt von region
editBox:SetPoint("CENTER",-100,-100); -- von region
editBox:SetBackdrop(GameTooltip:GetBackdrop()) -- von frame
editBox:SetBackdropColor(0, 0, 0, 0.8) -- von frame
editBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) -- von frame
editBox:SetFont("Fonts\\ARIALN.TTF", 18); -- von 
editBox:EnableMouse(true);
editBox:SetMovable(true);
editBox:RegisterForDrag("LeftButton");
editBox:SetScript("OnDragStart", function(self, arg1,arg2)
  editBox:StartMoving();
end)
editBox:SetScript("OnDragStop", function(self, arg1,arg2)
  editBox:StopMovingOrSizing();  
end)
editBox:SetShown(false); -- erstmal aus die kiste

local function addLineToEditBox(lineText)  
  editBox:SetText(editBox:GetText().."\n"..lineText);
end

--/script print(GetSpellDescription(23381)=="");
--/script print(GetSpellSubtext(20295));
-- name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellId)
-- desc = 
local function printSpellDetails(spellDetails,spellCount)  
  local description = GetSpellDescription(spellDetails["spellId"]);
  local _, _, icon, castTime, minRange, maxRange = GetSpellInfo(spellDetails["spellId"]);
  if spellCount == 0 then -- nur beim ersten mal den unitnamen noch davor
    if(spellDetails["spellType"] == "SpellCast" or spellDetails["spellType"] == "SpellChannel") then
      addLineToEditBox("  "..spellDetails["unitName"].."("..spellDetails["histNpcId"]..")");
    elseif(spellDetails["spellType"] == "EnemyBuff") then
      addLineToEditBox("  "..spellDetails["affectedUnitName"].."("..spellDetails["histNpcId"]..")");
    else -- playerdebuff      
      addLineToEditBox("  "..spellDetails["sourceName"].."("..spellDetails["histNpcId"]..")");
    end    
  end  
  if(spellDetails["spellType"] == "SpellCast" or spellDetails["spellType"] == "SpellChannel") then
    addLineToEditBox("    "..tostring(spellDetails["spellType"]).." "..spellDetails["spellName"].."("..spellDetails["spellId"]..") interruptable: "..tostring(not spell["notInterruptible"]).." castTime: "..castTime.." minRange: "..minRange.." maxRange: "..maxRange.." icon "..icon);
    addLineToEditBox("      Desc: "..(description or "no description"));
  elseif(spellDetails["spellType"] == "EnemyBuff") then          
    addLineToEditBox("    "..tostring(spellDetails["spellType"]).." "..spellDetails["spellName"].."("..spellDetails["spellId"]..") bekommen von "..spellDetails["sourceUnitName"].."("..spellDetails["sourceUnitId"]..")".." castTime: "..castTime.." minRange: "..minRange.." maxRange: "..maxRange.." icon "..icon);
    addLineToEditBox("      Desc: "..(description or "no description"));
  else -- playerdebuff
    addLineToEditBox("    "..tostring(spellDetails["spellType"]).." "..spellDetails["spellName"].."("..spellDetails["spellId"]..")".." castTime: "..castTime.." minRange: "..minRange.." maxRange: "..maxRange.." icon "..icon);
    addLineToEditBox("      Desc: "..(description or "no description"));
  end    
end       

-- /script print(GetSpellDescription(34906));

local function printHistoryToEditBox()  
  for zoneName,npcTable in pairs(history) do
    addLineToEditBox(zoneName);    
    for npcId,spellTable in pairs(npcTable) do    
      local spellCount=0;        
      for spellId,spellDetails in pairs(spellTable) do   
        -- hier werden alle spells für eine unit aufgelistet
        printSpellDetails(spellDetails,spellCount);
        spellCount = spellCount + 1;
      end      
    end    
  end
end


local button = CreateFrame("Button","asdf",UIParent);
button:SetHeight(30); -- kommt von region
button:SetWidth(30); -- kommt von region
button:SetPoint("CENTER",0,100); -- von region
button:SetBackdrop(GameTooltip:GetBackdrop()) -- von frame
button:SetBackdropColor(0, 0, 0, 0.8) -- von frame
button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) -- von frame
button:SetMovable(true);
button:RegisterForDrag("LeftButton");
local fs = button:CreateFontString("myButton3[B]Text[/B]", nil, "GameFontNormal")
fs:SetText("OF")
fs:SetPoint("CENTER",0,0)
button:SetFontString(fs);
button:SetScript("OnDragStart", function(self, arg1,arg2)
  button:StartMoving();
end)
button:SetScript("OnDragStop", function(self, arg1,arg2)
  button:StopMovingOrSizing();  
end)
button:SetScript("OnClick", function(self, arg1,arg2)
  editBox:SetShown(not editBox:IsVisible());
  if(editBox:IsVisible()) then
    printHistoryToEditBox();
  end  
end)

-- --------------------------------
-- ----- HANDLER FUNCTIONS -------------
-- --------------------------------

local function spellCastHandler(self, event, ...)  
  local unitId, _, spellId = ...;
  if not UnitIsPlayer(unitId) then        
    addToHistory(notifySpellCast(unitId,spellId));    
  end
end

local function spellChannelHandler(self,event,...)    
  local unitId, _, spellId = ...;
  if not UnitIsPlayer(unitId) then        
    addToHistory(notifyChannelCast(unitId,spellId));    
  end
end

local function playerDebuffHandler(self,event,unitId,...)   
  -- debuffs auf dem player      
  if unitId=="player" then
    local count=1;  
    while UnitDebuff(unitId,count) do    
      -- name, icon, count, debuffType, duration, expirationTime, sourceId, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitDeBuff("unit", count)      
        --print("debuff ".. spellName.."("..spellId..")".." in ".. zone .." auf player von "..UnitName(sourceId).."(".. getNpcIdFromUnitId(sourceId) ..")");
      addToHistory(notifyPlayerDebuff(count));        
        -- createPlayerDebuffObj(spellType,spellName,spellId,zone,affectedUnitId,sourceUnitId)            
       -- muss ganz am ende sonst crasherino
      count = count+1;
    end
  end
end

local function enemyBuffHandler(self,event,unitId,...)
  -- bei unit_aura und nameplate event ist unitId die richtige(nameplateN)    
  if not UnitIsFriend("player", unitId) then -- unitId, kann jeder sein der einen Buff hat, sollte enemy sein
    local count = 1;  
    while UnitBuff(unitId,count) do --kein sinnvolles nameplate wäre nil            
      -- hier hat eine unfriendly unit einen buff
      addToHistory(notifyEnemyBuff(unitId,count));        
      -- muss ganz am ende sonst crasherino
      count = count+1;
    end
  end
end

local function deepscan()
  -- 5. debuff, welcher auf mob ist, aber auch von mobs kommt    - source stuggle ... z.B. druide verwandlung in walling caverns  
  local unitId = "target";
  local count = 1;
  while UnitDebuff(unitId,count) do 
    local spellName, _, _, _, _, _, sourceUnitId, _, _, spellId = UnitDebuff(unitId, count);    
    if(sourceUnitId ~= nil and not UnitIsPlayer(sourceUnitId)) then --target hat einen debuff von einer unit, welche kein player ist      
      addToHistory(createEnemyBuffObj(spellName,spellId,GetZoneText(),UnitName(unitId),getNpcIdFromUnitId(unitId),UnitName(sourceUnitId),getNpcIdFromUnitId(sourceUnitId),getNpcIdFromUnitId(unitId)));      
    end    
    count = count + 1;
  end
  -- 6. buffs auf player, welcher aber von npc kommt
  local unitId = "player";
  local count = 1;
  while UnitBuff(unitId,count) do
    local spellName, _, _, _, _, _, sourceUnitId, _, _, spellId = UnitBuff(unitId, count);    
    if(sourceUnitId == nil) then      
      addToHistory(createPlayerDebuffObj(spellName,spellId,GetZoneText(),"unknown",0,0));
    elseif(not UnitIsPlayer(sourceUnitId)) then      
      addToHistory(createPlayerDebuffObj(spellName,spellId,GetZoneText(),UnitName(sourceUnitId),getNpcIdFromUnitId(sourceUnitId),getNpcIdFromUnitId(sourceUnitId)));
    end
    count = count + 1;
  end
end
--/script print(UnitBuff("player", 1));
-- --------------------------------
-- ----- FRAME CREATION -------------
-- --------------------------------

local spellCastFrame = CreateFrame("FRAME", "spellCastFrame");
spellCastFrame:RegisterEvent("UNIT_SPELLCAST_START");
spellCastFrame:SetScript("OnEvent", spellCastHandler);

local spellChannelFrame = CreateFrame("FRAME", "spellChannelFrame");
spellChannelFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
spellChannelFrame:SetScript("OnEvent", spellChannelHandler);

local playerDebuffFrame = CreateFrame("FRAME", "debuffFrame");
playerDebuffFrame:RegisterEvent("UNIT_AURA");
playerDebuffFrame:SetScript("OnEvent", playerDebuffHandler);

local enemyBuffFrame = CreateFrame("FRAME", "debuffFrame");
enemyBuffFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
enemyBuffFrame:RegisterEvent("UNIT_AURA");
enemyBuffFrame:SetScript("OnEvent", enemyBuffHandler);

--- COMMAND --------------

SLASH_DEEPSCAN1 = "/deepscan";
SlashCmdList["DEEPSCAN"] = function(msg)
  deepscan();
end


-- was soll man alles loggen
-- 1. spells, welche von mobs gecasted werden
-- 2. spells, welche von mobs gechannelt werden
-- 3. buffs, welche auf enemy unit ist   - source stuggle
-- 4. debuff, welcher auf player ist
-- 5. debuff, welcher auf mob ist, aber auch von mobs kommt    - source stuggle ... z.B. druide verwandlung in walling caverns
-- 6. buffs auf player, welcher aber von npc kommt

--TODO: was ist wenn source nicht da?

--name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo("unit")
  --name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo();
  --print(name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID);

-- lady anacondra zähl als boss mob, dh normale ini bosse zählen auch als bossN unitId

-- GetSubZoneText() nochmal kleine teile in der ini
-- GetZoneText() sowas wie walling caverns ini

--frame:RegisterEvent("NAME_PLATE_CREATED"); gibt haufen daten wieder, wahrscheinlich mit hook was machbar