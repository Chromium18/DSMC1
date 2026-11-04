--[[ GROUND UNITS AI ENHANCEMENT -- AI-EN

This script is possible thanks to the existence of many other scripts that I had the opportunity to use as inspiration, or partial copy, or modification due to being publicly available.
I basically learnt coding starting with mist, CTLD, SLmod, dismount script, and else. All credits goes to these authors, and I am very grateful. Therefore this script is obviously public
and you should feel free to use it totally, partially or anything else for any DCS gaming purpose.

What is it?
This script is done with the purpose of rehearsing the standard DCS ground groups and units AI, 
implementing additional behaviours using the SSE, aiming to get some more dynamic and realistic
response of those units to the environment and users actions.

The script currently is focused on ground units, except SAM and medium-to-long range air defences which are not being commanded.

This works mostly by changing 2 common behaviours: 
- the fact the the units basically do not react to any hostile fire moving elsewhere: the script provide movement decision
- the fact that artillery units fire only when they directly achieve a target, which is mostly unlikely: the script provide targets on arty groups via allied units informations

It also act on another important thing on ground war: dismountable soldiers' teams. By rehearsing an idea of MBot dismount script,
AIEN add soldier teams to any IFV, APC and trucks unit in the scenery. That means that a ground unit normally "unarmed" like a M-939 
might in fact transport RPG, rifle and even manpads units that will dismount from it when necessary to respond to specific menace.

In the end, if you need a specific group or more to do NOT be altered by the script, you simply have to add the exclusion tag (AIEN_xcl_tag string variable) in their group name: they will be completely ignored.


Usage informations:
- The script does not require any other script to run;
- Load the script in a "do script file" trigger after at least 3 seconds from mission start;
- The script does not need set-up or additional coding besides the user customization variables setup below;
- It won't be properly compatible with any other script that try to change the AI behaviours for ground movers. It should be ok with IADS scripts;
- It alter the ground groups behaviour and any change will effectively "broke" any other actions given by DCS or CA user when kicking in (and that's just normal and ok).
- The script do not use any naming convention (except for the exclusion tag), it will define available AI behaviour change using DCS available parameters such as unit attributes, skills, etc.
- you will be able to customize each of its "features", by enabling and disabling each option you want to use, here below  

Purpose and limitations:
- AIEN dismount feature (see below) can't be run along with CTLD or CSAR script, to avoid conflicts on on-board troop management. For this reason, you should disable the dismount option if you use CTLD or CSAR or both. If you don't, there's still an automated check that will disable AIEN dismount itself if you forgot it.
- The script does not want to provide a complete "automated ground war" thing: this is already in development by both ED and also by DSMC 2 script by me. In fact, this script is also a part of the DSMC 2 script, but still usable externally as standalone.



Suggestion, ideas:
-- Please refer to the script GitHub project, you will find the project details to suggest modification, contribute with coding and else.

--]]--

--## GLOBAL GENERAL AIEN CONTENT TABLE
AIEN                            = {}        -- don't change this

-- ############################################################################################################
--## USER CUSTOMIZATION VARIABLES ## CHECK AIEN GITHUB PAGE FOR ISTRO AND FEEL FREE TO CUSTOMIZE BELOW ########
-- ############################################################################################################

AIEN.config = {}
AIEN.config.dontInitialize      = true     -- if true, AIEN will not initialize; instead, you'll have to run it from your own code - it's useful when you want to override some functions/parameters before the initialization takes place

-- coalition affected by the script
AIEN.config.blueAI 		        = true 		-- true/false. If true, the AI enhancement will be applied to the blue coalition ground groups, else, no script effect will take place
AIEN.config.redAI			    = true 		-- true/false. If true, the AI enhancement will be applied to the red  coalition ground groups, else, no script effect will take place

-- Action sets allowed.
AIEN.config.firemissions        = true      -- true/false. If true, each artillery in the coalition will fire automatically at available targets provided by other ground units and drones
AIEN.config.reactions           = true      -- true/false. If true, when a mover group gets an hit, it will react accordingly to its skills and to its situational awareness, not staying there taking hits without doing nothing
AIEN.config.suppression         = true      -- true/false. If true, once a group take fire from arty or air and it's not armoured, it will be suppressed for 15-45 seconds and won't return fire. Require reactions to be set as 'true'
AIEN.config.dismount 		    = true 	-- true/false. //BEWARE: CAN AFFECT PERFORMANCES ON LOW END SYSTEMS // Thanks to MBot's original script, if true AI ground units with infantry transport capabilities (mainly APC/IFV/Trucks) will dismount soldiers with rifle, rpg and sometimes mandpads when appropriate
AIEN.config.initiative 		    = true 		-- true/false. If true, the ground groups will take limited initiative of attack or advance if intel and terrain allow them
--AIEN.config.conquer 		    = true 		-- true/false. If true, the ground groups will look for nearby towns or DCS ground markers and will try to move there if intel and terrain allow them (this is limited in space cause it's designed to work appropriately with DSMC 2)

-- User advanced customization
AIEN.config.AIEN_xcl_tag		= "XCL" 	-- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed. Any ground group with this 'tag' in its group name won't get AI enhancement behaviour, regardless of its coalition 
AIEN.config.AIEN_zoneFilter     = ""    	-- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed, i.e. "AIEN" will fit. If left nil, or void string like "", won't be used. Only groups inside the named trigger zone will be affected by AIEN script behaviors of reaction, dismount and suppression, and vice versa. If no trigger zone with the specific name is in the mission, then all the groups will use AIEN features.
AIEN.config.message_feed        = true 		-- true/false. If true, each relevant AI action starting will also create a trigger message feedback for its coalition
AIEN.config.mark_on_f10_map     = true 	    -- true/false. If true, when an artillery fire mission is ongoing, a markpoint will appear on the map of the allied coalition to show the expected impact point
AIEN.config.skill_action_const  = false     -- true/false. If true, AI available reactions types will be limited by the group average skill. If not, almost 2/3 of all available actions will be always be available regardless of the group skills
AIEN.config.maxGroupInMovement  = 10        -- number, used to limit the maximum number of groups that can be in movement at the same time. If more than this number are in movement, the script will not allow new movements until one of them is finished. This is useful to avoid too many groups moving at the same time and causing performance issues.    

-- User bug report: prior to report a bug, please try reproducing it with this variable set to "true"
AIEN.config.AIEN_debugProcessDetail = false


-- ############################################################################################################
--## LOCAL HIGH LEVEL VARIABLES ###############################################################################
-- ############################################################################################################

-- changing the variable below is for fine customization, but it's not recommended cause it can change the code behaviour. 
-- If you do so, please revert to original value and retry before reporting bugs.

-- movement variables
AIEN.config.outRoadSpeed                      = 8	              -- do *3.6 for km/h, cause DCS thinks in m/s	
AIEN.config.inRoadSpeed                       = 15	              -- do *3.6 for km/h, cause DCS thinks in m/s
AIEN.config.infantrySpeed                     = 2	              -- do *3.6 for km/h, cause DCS thinks in m/s	
AIEN.config.repositionDistance				  = 500		          -- meters, radius to a specific destination point that will be randomized between 90% and 110% of this value. Used when a group is moved upon another group position: the other group position will be the destination.
AIEN.config.rndFleeDistance		              = 2000 		      -- meters, reposition distance given to a group when a destination is not defined. The direction also will be totally random. Used, i.e., for "panic" reaction
AIEN.config.tacticalRange	                  = 15000 		      -- meters, define maximum distance allowed for each initiative movement
AIEN.config.initiativeRange                   = 7000              -- meters, define maximum distance allowed for each initiative movement when a group is engaged in combat. If the group is not engaged, the distance will be 2000 meters  
AIEN.config.maxSlope                          = 25	              -- degrees, maximum slope allowed for a group to move to a specific destination. If the slope is more than this value, the group will not move there.     

-- dismounted troops variables
AIEN.config.droppedReposition                 = 80                -- if no enemy is identified, this is the distance where dismount group will reposition themselves
AIEN.config.remountTime                       = 600               -- time after which dismounted troops will try to go back to their original vehicle for remount, if commanded
AIEN.config.infantryExtractDist               = 200               -- max distance from vehicle to troops to allow a group extraction
AIEN.config.infantrySearchDist                = 2000              -- max distance from vehicle to troops to allow a dismount group to run toward the enemies

-- informative calls variables
AIEN.config.outAmmoLowLevel                   = 0.5		          -- factor on total amount
AIEN.config.densityRange                      = 5000              -- meters, used for the density calculation of a group. If a group is within this distance from another group, it will be considered "dense" and will not be able to perform some actions

-- reactions and tasking variables
AIEN.config.intelDbTimeout                    = 1200              -- seconds. Used to cancel intelDb entries for units (not static!), when the time of the contact gathering is more than this value
AIEN.config.artyFireLastContactThereshold     = 300               -- seconds, max amount of time since last contact to consider an arty target ok
AIEN.config.taskTimeout                       = 480               -- seconds after which a tasked group is removed from the database
AIEN.config.targetedTimeout                   = 240               -- seconds after which a targeted variable in inteldb is removed from database
AIEN.config.disperseActionTime				  = 120		          -- seconds
AIEN.config.counterBatteryRadarRange          = 50000             -- m, capable distance for a radar to perform counter battery calculations
AIEN.config.counterBatteryPlanDelay           = 240               -- s, will be also randomized on +-35%. Used to define the delay of the planned counter battery fire if available
AIEN.config.smoke_source_num                  = 5                 -- number, between 4 and 9. Generated smokes for each unit when smoke reaction is called in. Any number below 4 or above 9 will be converted in the nearest threshold
AIEN.config.JTACasDrone                       = true              -- if true any JTAC unit will be also added in the droneunitDb, and will be used as a drone for the artillery fire missions. If false, it will be treated as a normal JTAC unit.

-- SA evaluation variables
AIEN.config.proxyBuildingDistance			  = 4000              -- m, if buildings are within this distance value, they are considered "close"
AIEN.config.proxyUnitsDistance                = 5000              -- m, if units are within this distance value, they are considered "close"
AIEN.config.supportDistance					  = 8000			  -- m, maximum distance for evaluating support or cover movements when under attack
AIEN.config.withrawDist                       = 15000             -- m, maximum distance for withdraw manoeuvre nearby a friendly support unit



--####################################################################################################
--###### DO NOT CHANGE CODE BELOW HERE ###############################################################
--####################################################################################################

--###### CONFIG AND VARIABLES ########################################################################

--## MAIN VARIABLES

-- Mark id addition
local markIdStart                       = 12345000000

-- DSMC version of the script check: if already there due to DSMC version, the script won't be loaded.
if AIEN.performPhaseCycle then
    env.info(("AIEN already there in another way, stopping"))
    return
end

--## LOCAL GENERAL INFORMATIONS VARIABLES (mostly used for debug log and info)
local ModuleName  						= "AIEN"
local MainVersion 						= "1"
local SubVersion 						= "4"
local Build 							= "0191"
local Date								= "2025.12.08"

--## LOCAL LOW LEVEL VARIABLES

--Debug 
local AIEN_io 					    	= _G.io  	        -- check if io  is available in mission environment, if so debug will also produce files. NOT-RECOMMENDED to have an unsanitized mission env.
local AIEN_lfs 					    	= _G.lfs		    -- check if lfs is available in mission environment, if so debug will also produce files. NOT-RECOMMENDED to have an unsanitized mission env.

-- FSM and system
local PHASE                             = "Initialization"  -- used by FSM, don't change, it won't affect anything
local phase_index                   	= nil
local phase_keys                        = {}
local phaseCycleTimer                   = 0.2               -- seconds, used by FSM. Define how much time pass between a loop entry calculation and another. You might want to reduce it further or if you feel DCS being "slow" you can raise up to 1.0 second. 
local rndMinRT_xper                     = 2                 -- seconds counted as minimum basic reaction time after an event (beware, reaction time also depends on group averaged skill)
local rndMacRT_xper                     = 4                 -- seconds counted as maximum basic reaction time after an event (beware, reaction time also depends on group averaged skill)
local stupidIndex                       = 1                 -- used to avoid infinite loops

--AI processing timers
local underAttack                       = {}                -- used when a group has been attacked, it keeps "tactical" tasking off for 10 mins leaving room for "reaction" decision making
local movingGroups                      = 0                 -- used to keep track of groups that are currently moving, so that no initiative actions can be taken if the number is more than allowed by AIEN.config.maxGroupInMovement

--Dynamic and_or linked to other code
if not DSMC_baseGcounter then
	DSMC_baseGcounter = 20000000
end
if not DSMC_baseUcounter then
	DSMC_baseUcounter = 19000000
end

--## LOCAL DYNAMIC TABLES (DBs)

local groundgroupsDb    = {} -- used for general purpose on groups command
local droneunitDb       = {} -- used mostly for artillery control
local intelDb           = {} -- used for any enemy assessment evaluation. The getSA function is used for populating the db
local mountedDb         = {} -- used for assign infantry teams to each capable vehicle or trucks
local infcarrierDb      = {} -- used for store infantry carriers informations (i.e. available space)

--## LOCAL STATIC TABLES

-- used for prioritizing arty target by class
local classPriority     = {
    ["MLRS"] = 10,
    ["ARTY"] = 9.5,
    ["MBT"] = 9,
    ["ATGM"] = 8,
    ["SAM"] = 9.6,
    ["SHORAD"] = 7.5,
    ["IFV"] = 7,
    ["APC"] = 4,
    ["RECCE"] = 3.5,
    ["AAA"] = 3,
    ["MISSILE"] = 4.5,
    ["MANPADS"] = 6,
    ["LOGI"] = 2,
    ["INF"] = 1,
    ["UNKN"] = 0.5,
    ["ARBN"] = 0,    
    ["SHIP"] = 2,  
}

-- used to identify if a group is suitable for supporting others in ground battle
local supportGroundClasses  = {
    ["MLRS"] = 2.1,
    ["ARTY"] = 2.3,
    ["MBT"] = 10,
    ["ATGM"] = 9,
    ["SAM"] = 3,
    ["SHORAD"] = 5,
    ["IFV"] = 7,
    ["APC"] = 5.5,
    ["RECCE"] = 3.5,
    ["AAA"] = 2,
    ["MISSILE"] = 1,
    ["MANPADS"] = 0.8,
    ["LOGI"] = 1.2,
    ["INF"] = 0.5,
    ["UNKN"] = 0.9,
    --["ARBN"] = 0,
    --["SHIP"] = 0,  
}

-- used to identify if a group is suitable for supporting others in ground battle
local supportCounterAirClasses  = {
    ["MLRS"] = 0.5,
    ["ARTY"] = 1,
    ["MBT"] = 4,
    ["ATGM"] = 5,
    ["SAM"] = 10,
    ["SHORAD"] = 9,
    ["IFV"] = 4.5,
    ["APC"] = 3,
    ["RECCE"] = 2.5,
    ["AAA"] = 7,
    ["MISSILE"] = 0.2,
    ["MANPADS"] = 8,
    ["LOGI"] = 1.2,
    ["INF"] = 0.1,
    ["UNKN"] = 2,
    --["ARBN"] = 0,
    --["SHIP"] = 0,  
}

-- used in multiple part of the scripts for defining reactions, speed, and smartness of the groups
local skills = {
    ["Average"] = {aim_delay = 170, skillVal = 4},
    ["High"] = {aim_delay = 130, skillVal = 9},
    ["Good"] = {aim_delay = 150, skillVal = 6},
    ["Excellent"] = {aim_delay = 110, skillVal = 12},   
	["Random"] = {aim_delay = 140, skillVal = 8},  -- skill val is NOT used in this case, it's replaced by a randomness.
}

-- used for define infantry teams carrier capacity by attribute. BEWARE: the table key are not "classes", are actual DCS attributes enum. Don't add "casual" things, stick to them. You can find a list here: https://wiki.hoggitworld.com/view/DCS_enum_attributes 
local dismountCarriers = {
    ["Trucks"] = 16,    -- this should be handled as a 3 teams of 4 each
    ["APC"] = 8,        -- this should be handled as a 2 teams of 4 each
    ["IFV"] = 5,        -- this should be handled as a 1 teams of 4 each
}

-- used for define infantry teams composition. In the table, p is the probability from 1 to 100, c is the composition
local dismountTeamsWest = { 
    ["rifle"] = {id = "rifle", p = 55, c = {
        [1] = "Soldier M4",
        [2] = "Soldier M4",
        [3] = "Soldier M4",
        [4] = "Soldier M249",
    }},
    ["mixed"] = {id = "mixed", p = 20, c = {
        [1] = "Soldier M4",
        [2] = "Paratrooper RPG-16",
        [3] = "Soldier M4",
        [4] = "Soldier M249",
    }},-- mixed is actually 3 rifle and 1 rpg      
    ["RPGs"] = {id = "RPGs", p = 9, c = {
        [1] = "Paratrooper RPG-16",
        [2] = "Paratrooper RPG-16",
        [3] = "Soldier M4",
        [4] = "Soldier M4",
    }},              
    ["manpads"] = {id = "manpads", p = 3, c = {
        [1] = "Stinger manpad",
        [2] = "Stinger manpad",
        [3] = "Soldier M4",
    }},  
}

local dismountTeamsEast = { 
    ["rifle"] = {id = "rifle", p = 55, c = {
        [1] = "Infantry AK ver3",
        [2] = "Infantry AK ver2",
        [3] = "Infantry AK ver2",
        [4] = "Infantry AK ver3",
    }},
    ["mixed"] = {id = "mixed", p = 20, c = {
        [1] = "Infantry AK ver2",
        [2] = "Paratrooper RPG-16",
        [3] = "Infantry AK ver3",
        [4] = "Infantry AK ver3",
    }},-- mixed is actually 3 rifle and 1 rpg      
    ["RPGs"] = {id = "RPGs", p = 9, c = {
        [1] = "Paratrooper RPG-16",
        [2] = "Paratrooper RPG-16",
        [3] = "Infantry AK ver2",
        [4] = "Infantry AK ver3",
    }},               
    ["manpads"] = {id = "manpads", p = 3, c = {
        [1] = "SA-18 Igla manpad",
        [2] = "SA-18 Igla manpad",
        [3] = "Infantry AK ver3",
    }},  
}

if env.mission and env.mission.date and env.mission.date.Year then
    local y = tonumber(env.mission.date.Year)

    if AIEN.config.AIEN_debugProcessDetail == true then
        env.info(("AIEN mission date: " .. tostring(y)))
    end

    if y < 1980 then
        dismountTeamsWest["manpads"] = nil
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN removed stinger"))
        end
    elseif y < 1970 then
        dismountTeamsEast["manpads"] = nil
        dismountTeamsWest["manpads"] = nil
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN removed all manpads"))
        end
    end
end



--## LINKED TABLES (or local if not available)
local tblThreatsRange                   = nil  -- this is a foundamental table cause it holds the firing range of any units, but mostly artillery one! Since the required data aren't available in the mission env, it can be either ported by DSMC (if used) or manually prompted. For the latter, obviously, it require to be manually updated. 
if EMBD then -- just for compatibility enhancement
    tblThreatsRange                = EMBD.tblThreatsRange
    if tblThreatsRange then
        for tId, tData in pairs(tblThreatsRange) do
            tData.attr = nil
        end
    end
end

if not tblThreatsRange then
	tblThreatsRange = {
        ["S-60_Type59_Artillery"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 259,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 6000,
            ["detection"] = 5000,
        }, -- end of ["S-60_Type59_Artillery"]
        ["SD10 Loadout"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Missile",
                [6] = "NonArmoredUnits",
                [7] = "NonAndLightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["SD10 Loadout"]
        ["CHAP_T64BV"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 357,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["irsignature"] = 0.11,
            ["detection"] = 5000,
            ["threatmin"] = 100,
        }, -- end of ["CHAP_T64BV"]
        ["Silkworm_SR"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 263,
                [5] = "DetectionByAWACS",
                [6] = "Artillery",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 200000,
            ["irsignature"] = 0.05,
        }, -- end of ["Silkworm_SR"]
        ["SKP-11"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["SKP-11"]
        ["Type_96_25mm_AA"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 376,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 10000,
            ["irsignature"] = 0.01,
        }, -- end of ["Type_96_25mm_AA"]
        ["CHAP_TorM2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 363,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "RADAR_BAND1_FOR_ARM",
                [10] = "Datalink",
                [11] = "All",
                [12] = "Ground Units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "NonAndLightArmoredUnits",
                [16] = "NonArmoredUnits",
                [17] = "Air Defence",
                [18] = "SAM related",
                [19] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 16000,
            ["irsignature"] = 0.09,
            ["detection"] = 32000,
            ["threatmin"] = 1500,
        }, -- end of ["CHAP_TorM2"]
        ["BMP-1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["BMP-1"]
        ["M-113"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["M-113"]
        ["Gepard"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 105,
                [4] = 38,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "RADAR_BAND1_FOR_ARM",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "Armed Air Defence",
                [14] = "Rocket Attack Valid AirDefence",
                [15] = "AAA",
                [16] = "All",
                [17] = "Ground Units",
                [18] = "Vehicles",
                [19] = "Ground vehicles",
                [20] = "SAM related",
                [21] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 15000,
            ["irsignature"] = 0.1,
        }, -- end of ["Gepard"]
        ["M 818"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["M 818"]
        ["Soldier RPG"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier RPG"]
        ["rapier_fsa_launcher"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 260,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "SAM LL",
                [10] = "RADAR_BAND1_FOR_ARM",
                [11] = "RADAR_BAND2_FOR_ARM",
                [12] = "All",
                [13] = "Ground Units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "NonArmoredUnits",
                [18] = "Air Defence",
                [19] = "SAM related",
                [20] = "SAM elements",
                [21] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 6800,
            ["detection"] = 30000,
            ["irsignature"] = 0.03,
        }, -- end of ["rapier_fsa_launcher"]
        ["Type_94_Truck"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Type_94_Truck"]
        ["CHAP_M142_ATACMS_M48"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 367,
                [5] = "MLRS",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 300000,
            ["irsignature"] = 0.075,
            ["detection"] = 0,
            ["threatmin"] = 50000,
        }, -- end of ["CHAP_M142_ATACMS_M48"]
        ["L118_Unit"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 26,
                [4] = 349,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 17200,
            ["detection"] = 17500,
        }, -- end of ["L118_Unit"]
        ["S-300PS 5P85C ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 8,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Air Defence",
                [14] = "SAM related",
                [15] = "SAM elements",
                [16] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 120000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 5P85C ln"]
        ["Merkava_Mk4"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["Merkava_Mk4"]
        ["Patriot cp"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 36,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Patriot cp"]
        ["ATMZ-5"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 4,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ATMZ-5"]
        ["5p73 s-125 ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 74,
                [5] = "AA_missile",
                [6] = "MR SAM",
                [7] = "SAM LL",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 18000,
            ["detection"] = 0,
            ["irsignature"] = 0.02,
        }, -- end of ["5p73 s-125 ln"]
        ["house2arm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["house2arm"]
        ["ural_atz5_civil"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 386,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ural_atz5_civil"]
        ["B600_drivable"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 38,
                [5] = "Cars",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["B600_drivable"]
        ["T-72B"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["T-72B"]
        ["T155_Firtina"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 302,
                [5] = "Artillery",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 41000,
            ["detection"] = 0,
            ["irsignature"] = 0.11,
        }, -- end of ["T155_Firtina"]
        ["55G6 EWR"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 2,
                [5] = "EWR",
                [6] = "NonAndLightArmoredUnits",
                [7] = "NonArmoredUnits",
                [8] = "Air Defence",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Air Defence vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 400000,
            ["irsignature"] = 0.07,
        }, -- end of ["55G6 EWR"]
        ["Suidae"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 47,
                [5] = "Cars",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Suidae"]
        ["prmg_loc_beacon"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 385,
                [5] = "PRMG_LOCALIZER",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["prmg_loc_beacon"]
        ["Predator GCS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Predator GCS"]
        ["hy_launcher"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 339,
                [5] = "SS_missile",
                [6] = "Artillery",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 100000,
            ["detection"] = 100000,
            ["irsignature"] = 0.01,
        }, -- end of ["hy_launcher"]
        ["P20_drivable"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 38,
                [5] = "Cars",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["P20_drivable"]
        ["Uragan_BM-27"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "MLRS",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
                [16] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 35800,
            ["irsignature"] = 0.08,
            ["detection"] = 0,
            ["threatmin"] = 11500,
        }, -- end of ["Uragan_BM-27"]
        ["houseA_arm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["houseA_arm"]
        ["SAU Gvozdika"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 15000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["SAU Gvozdika"]
        ["HQ-7_LN_P"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 346,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "SAM LL",
                [10] = "RADAR_BAND1_FOR_ARM",
                [11] = "RADAR_BAND2_FOR_ARM",
                [12] = "All",
                [13] = "Ground Units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "NonArmoredUnits",
                [18] = "Air Defence",
                [19] = "SAM related",
                [20] = "SAM elements",
                [21] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 15000,
            ["detection"] = 20000,
            ["irsignature"] = 0.08,
        }, -- end of ["HQ-7_LN_P"]
        ["snr s-125 tr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 73,
                [5] = "MR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 100000,
            ["irsignature"] = 0.06,
        }, -- end of ["snr s-125 tr"]
        ["Predator TrojanSpirit"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Predator TrojanSpirit"]
        ["CHAP_T90M"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 352,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["irsignature"] = 0.1,
            ["detection"] = 8000,
            ["threatmin"] = 100,
        }, -- end of ["CHAP_T90M"]
        ["SAU Msta"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 23500,
            ["irsignature"] = 0.1,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["SAU Msta"]
        ["Stinger comm dsr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 59,
                [5] = "MANPADS AUX",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Infantry",
                [13] = "Rocket Attack Valid AirDefence",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "SAM AUX",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["Stinger comm dsr"]
        ["Vulcan"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 105,
                [4] = 46,
                [5] = "AA_flak",
                [6] = "SAM TR",
                [7] = "Mobile AAA",
                [8] = "Datalink",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
                [18] = "Armed Air Defence",
                [19] = "Rocket Attack Valid AirDefence",
                [20] = "AAA",
            }, -- end of ["attr"]
            ["threat"] = 2000,
            ["detection"] = 5000,
            ["irsignature"] = 0.09,
        }, -- end of ["Vulcan"]
        ["Tankcartrinity"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 51,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Tankcartrinity"]
        ["2S6 Tunguska"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 103,
                [4] = 29,
                [5] = "AA_missile",
                [6] = "AA_flak",
                [7] = "Mobile AAA",
                [8] = "SR SAM",
                [9] = "SAM SR",
                [10] = "SAM TR",
                [11] = "RADAR_BAND1_FOR_ARM",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "Armed Air Defence",
                [16] = "Rocket Attack Valid AirDefence",
                [17] = "AAA",
                [18] = "All",
                [19] = "Ground Units",
                [20] = "Vehicles",
                [21] = "Ground vehicles",
                [22] = "SAM related",
                [23] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 8000,
            ["detection"] = 18000,
            ["irsignature"] = 0.1,
        }, -- end of ["2S6 Tunguska"]
        ["CHAP_IRISTSLM_LN"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 361,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 40000,
            ["irsignature"] = 0.08,
            ["detection"] = 0,
            ["threatmin"] = 1000,
        }, -- end of ["CHAP_IRISTSLM_LN"]
        ["tacr2a"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 25,
                [3] = 14,
                [4] = 340,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["tacr2a"]
        ["S_75M_Volhov"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 380,
                [5] = "AA_missile",
                [6] = "LR SAM",
                [7] = "SAM LL",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 43000,
            ["irsignature"] = 0.03,
            ["detection"] = 0,
            ["threatmin"] = 7000,
        }, -- end of ["S_75M_Volhov"]
        ["BMP-2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["BMP-2"]
        ["Leopard-2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 299,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["Leopard-2"]
        ["generator_5i57"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 9,
                [3] = 25,
                [4] = 293,
                [5] = "AD Auxillary Equipment",
                [6] = "NonAndLightArmoredUnits",
                [7] = "NonArmoredUnits",
                [8] = "Air Defence",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Air Defence vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["generator_5i57"]
        ["VAB_Mephisto"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 80,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Datalink",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3800,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["VAB_Mephisto"]
        ["Strela-10M3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 104,
                [4] = 26,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "IR Guided SAM",
                [8] = "SAM TR",
                [9] = "NonAndLightArmoredUnits",
                [10] = "NonArmoredUnits",
                [11] = "Air Defence",
                [12] = "SAM related",
                [13] = "Armed Air Defence",
                [14] = "All",
                [15] = "Ground Units",
                [16] = "Vehicles",
                [17] = "Ground vehicles",
                [18] = "SAM",
                [19] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 8000,
            ["irsignature"] = 0.085,
        }, -- end of ["Strela-10M3"]
        ["M-109"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 22000,
            ["irsignature"] = 0.11,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["M-109"]
        ["LAZ Bus"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 58,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["LAZ Bus"]
        ["TZ-22_KrAZ"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 312,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["TZ-22_KrAZ"]
        ["MaxxPro_MRAP"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 347,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["MaxxPro_MRAP"]
        ["Paratrooper RPG-16"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Paratrooper RPG-16"]
        ["Smerch"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "MLRS",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
                [16] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 70000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 20000,
        }, -- end of ["Smerch"]
        ["M978 HEMTT Tanker"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["M978 HEMTT Tanker"]
        ["Wellcarnsc"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 51,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Wellcarnsc"]
        ["Marder"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1500,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["Marder"]
        ["BRDM-2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1600,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["BRDM-2"]
        ["Sd_Kfz_251"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1100,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Sd_Kfz_251"]
        ["LiAZ Bus"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 58,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["LiAZ Bus"]
        ["Trolley bus"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 49,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.06,
        }, -- end of ["Trolley bus"]
        ["tt_KORD"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 324,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["tt_KORD"]
        ["Tigr_233036"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 10,
                [5] = "APC",
                [6] = "human_vehicle",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Tigr_233036"]
        ["MAZ-6303"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 70,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["MAZ-6303"]
        ["LAV-25"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 7,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["LAV-25"]
        ["GPS_Spoofer_Red"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 382,
                [5] = "Trucks",
                [6] = "Jammer",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["GPS_Spoofer_Red"]
        ["TugHarlan_drivable"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 38,
                [5] = "Cars",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["TugHarlan_drivable"]
        ["UAZ-469"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 38,
                [5] = "Cars",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["UAZ-469"]
        ["FPS-117 Dome"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 327,
                [5] = "EWR",
                [6] = "NonAndLightArmoredUnits",
                [7] = "NonArmoredUnits",
                [8] = "Air Defence",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Air Defence vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 400000,
            ["irsignature"] = 0.07,
        }, -- end of ["FPS-117 Dome"]
        ["RD_75"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 337,
                [5] = "MR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 100000,
            ["irsignature"] = 0.05,
        }, -- end of ["RD_75"]
        ["2B11 mortar"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 7000,
            ["irsignature"] = 0.005,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["2B11 mortar"]
        ["Soldier stinger"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 56,
                [5] = "MANPADS",
                [6] = "IR Guided SAM",
                [7] = "New infantry",
                [8] = "NonAndLightArmoredUnits",
                [9] = "NonArmoredUnits",
                [10] = "Air Defence",
                [11] = "SAM related",
                [12] = "Armed Air Defence",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "SAM",
                [18] = "Ground Units Non Airdefence",
                [19] = "Armed ground units",
                [20] = "Infantry",
                [21] = "Rocket Attack Valid AirDefence",
            }, -- end of ["attr"]
            ["threat"] = 4500,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier stinger"]
        ["PL8 Loadout"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Missile",
                [6] = "NonArmoredUnits",
                [7] = "NonAndLightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["PL8 Loadout"]
        ["Ural-4320T"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 75,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-4320T"]
        ["RPC_5N62V"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 313,
                [5] = "LR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 400000,
        }, -- end of ["RPC_5N62V"]
        ["HL_ZU-23"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 325,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.04,
        }, -- end of ["HL_ZU-23"]
        ["Infantry AK ver3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "New infantry",
                [7] = "Skeleton_type_A",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Infantry AK ver3"]
        ["M-1 Abrams"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.15,
        }, -- end of ["M-1 Abrams"]
        ["Bedford_MWD"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["Bedford_MWD"]
        ["Kub 1S91 str"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 21,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "SAM TR",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "RADAR_BAND2_FOR_ARM",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 70000,
            ["irsignature"] = 0.085,
        }, -- end of ["Kub 1S91 str"]
        ["CHAP_TOS1A"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = "</WSTYPE>",
                [4] = "MLRS",
                [5] = "All",
                [6] = "Ground Units",
                [7] = "Ground Units Non Airdefence",
                [8] = "Armed ground units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Armed vehicles",
                [12] = "Indirect fire",
                [13] = "NonAndLightArmoredUnits",
                [14] = "LightArmoredUnits",
                [15] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 6000,
            ["irsignature"] = 0.11,
            ["detection"] = 0,
            ["threatmin"] = 400,
        }, -- end of ["CHAP_TOS1A"]
        ["M1126 Stryker ICV"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 80,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["M1126 Stryker ICV"]
        ["GAZ-66"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 67,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["GAZ-66"]
        ["Type_98_So_Da"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Type_98_So_Da"]
        ["HL_DSHK"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 321,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["HL_DSHK"]
        ["Soldier AK"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier AK"]
        ["BMD-1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["BMD-1"]
        ["Kub 2P25 ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 22,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Air Defence",
                [14] = "SAM related",
                [15] = "SAM elements",
                [16] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 25000,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["Kub 2P25 ln"]
        ["HQ-7_STR_SP"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 278,
                [5] = "SR SAM",
                [6] = "SAM CC",
                [7] = "SAM SR",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "RADAR_BAND2_FOR_ARM",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 30000,
            ["irsignature"] = 0.08,
        }, -- end of ["HQ-7_STR_SP"]
        ["Cobra"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["Cobra"]
        ["MLRS FDDM"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 14,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["MLRS FDDM"]
        ["bofors40"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 47,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 0,
            ["irsignature"] = 0.01,
        }, -- end of ["bofors40"]
        ["ZU-23 Insurgent"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 70,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.006,
        }, -- end of ["ZU-23 Insurgent"]
        ["Ural-4320-31"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-4320-31"]
        ["Hawk sr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 39,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "Datalink",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 90000,
            ["irsignature"] = 0.06,
        }, -- end of ["Hawk sr"]
        ["TACAN_beacon"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.005,
        }, -- end of ["TACAN_beacon"]
        ["SNR_75V"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 256,
                [5] = "MR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 100000,
            ["irsignature"] = 0.05,
        }, -- end of ["SNR_75V"]
        ["rsbn_beacon"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 383,
                [5] = "RSBN",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["rsbn_beacon"]
        ["Stinger comm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 57,
                [5] = "MANPADS AUX",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Infantry",
                [13] = "Rocket Attack Valid AirDefence",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "SAM AUX",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["Stinger comm"]
        ["outpost"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["outpost"]
        ["prmg_gp_beacon"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 384,
                [5] = "PRMG_GLIDEPATH",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["prmg_gp_beacon"]
        ["Ural-375"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 40,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-375"]
        ["Osa 9A33 ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 23,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "RADAR_BAND2_FOR_ARM",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 10300,
            ["detection"] = 30000,
            ["irsignature"] = 0.08,
        }, -- end of ["Osa 9A33 ln"]
        ["Paratrooper AKS-74"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Paratrooper AKS-74"]
        ["Igla manpad INS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 62,
                [5] = "MANPADS",
                [6] = "IR Guided SAM",
                [7] = "New infantry",
                [8] = "NonAndLightArmoredUnits",
                [9] = "NonArmoredUnits",
                [10] = "Air Defence",
                [11] = "SAM related",
                [12] = "Armed Air Defence",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "SAM",
                [18] = "Ground Units Non Airdefence",
                [19] = "Armed ground units",
                [20] = "Infantry",
                [21] = "Rocket Attack Valid AirDefence",
            }, -- end of ["attr"]
            ["threat"] = 5200,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["Igla manpad INS"]
        ["M1045 HMMWV TOW"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 14,
                [5] = "APC",
                [6] = "ATGM",
                [7] = "Datalink",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3800,
            ["detection"] = 0,
            ["irsignature"] = 0.75,
        }, -- end of ["M1045 HMMWV TOW"]
        ["CHAP_M142_GMLRS_M31"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 365,
                [5] = "MLRS",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 70000,
            ["irsignature"] = 0.075,
            ["detection"] = 0,
            ["threatmin"] = 15000,
        }, -- end of ["CHAP_M142_GMLRS_M31"]
        ["HQ-7_LN_SP"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 277,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM TR",
                [8] = "SAM LL",
                [9] = "RADAR_BAND1_FOR_ARM",
                [10] = "RADAR_BAND2_FOR_ARM",
                [11] = "All",
                [12] = "Ground Units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "NonAndLightArmoredUnits",
                [16] = "NonArmoredUnits",
                [17] = "Air Defence",
                [18] = "SAM related",
                [19] = "SAM elements",
                [20] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 15000,
            ["detection"] = 20000,
            ["irsignature"] = 0.08,
        }, -- end of ["HQ-7_LN_SP"]
        ["SAU 2-C9"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 7000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["SAU 2-C9"]
        ["SAU Akatsia"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 17000,
            ["irsignature"] = 0.095,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["SAU Akatsia"]
        ["CHAP_M142_ATACMS_M39A1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 366,
                [5] = "MLRS",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 300000,
            ["irsignature"] = 0.075,
            ["detection"] = 0,
            ["threatmin"] = 50000,
        }, -- end of ["CHAP_M142_ATACMS_M39A1"]
        ["MCV-80"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["MCV-80"]
        ["ES44AH"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 48,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.15,
        }, -- end of ["ES44AH"]
        ["CHAP_MATV"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 354,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["CHAP_MATV"]
        ["Type_3_80mm_AA"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 374,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 3200,
            ["detection"] = 10000,
            ["irsignature"] = 0.01,
        }, -- end of ["Type_3_80mm_AA"]
        ["VAZ Car"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 47,
                [5] = "Cars",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.065,
        }, -- end of ["VAZ Car"]
        ["Infantry AK Ins"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "New infantry",
                [7] = "Skeleton_type_A",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Infantry AK Ins"]
        ["ATZ-60_Maz"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 310,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["ATZ-60_Maz"]
        ["ZIL-4331"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 71,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ZIL-4331"]
        ["ZIL-131 KUNG"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 79,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ZIL-131 KUNG"]
        ["Patriot str"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 34,
                [5] = "LR SAM",
                [6] = "SAM SR",
                [7] = "SAM TR",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "Datalink",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 160000,
            ["irsignature"] = 0.07,
        }, -- end of ["Patriot str"]
        ["ZiL-131 APA-80"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ZiL-131 APA-80"]
        ["BMP-3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 0,
            ["irsignature"] = 0.095,
        }, -- end of ["BMP-3"]
        ["rapier_fsa_blindfire_radar"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 262,
                [5] = "SR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 30000,
            ["irsignature"] = 0.03,
        }, -- end of ["rapier_fsa_blindfire_radar"]
        ["Hummer"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 14,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "human_vehicle",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Hummer"]
        ["KS-19"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 334,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 20000,
            ["detection"] = 0,
            ["irsignature"] = 0.01,
        }, -- end of ["KS-19"]
        ["leopard-2A4"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 300,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["leopard-2A4"]
        ["T-90"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 358,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["irsignature"] = 0.11,
            ["detection"] = 6000,
            ["threatmin"] = 100,
        }, -- end of ["T-90"]
        ["flak18"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 314,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 0,
            ["irsignature"] = 0.01,
        }, -- end of ["flak18"]
        ["CHAP_IRISTSLM_CP"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 362,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["CHAP_IRISTSLM_CP"]
        ["Type_94_25mm_AA_Truck"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 377,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 10000,
            ["irsignature"] = 0.08,
        }, -- end of ["Type_94_25mm_AA_Truck"]
        ["S-200_Launcher"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 381,
                [5] = "AA_missile",
                [6] = "LR SAM",
                [7] = "SAM LL",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 255000,
            ["threatmin"] = 17000,
            ["detection"] = 0,
        }, -- end of ["S-200_Launcher"]
        ["Hawk pcp"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 6,
                [5] = "SAM CC",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Hawk pcp"]
        ["IKARUS Bus"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 46,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["IKARUS Bus"]
        ["CHAP_FV101"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 351,
                [5] = "Tanks",
                [6] = "Datalink",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 5000,
            ["irsignature"] = 0.06,
        }, -- end of ["CHAP_FV101"]
        ["ZU-23 Emplacement Closed"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 48,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.006,
        }, -- end of ["ZU-23 Emplacement Closed"]
        ["ZIL-135"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 311,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["ZIL-135"]
        ["MJ-1_drivable"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 38,
                [5] = "Cars",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["MJ-1_drivable"]
        ["Soldier M4"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier M4"]
        ["Bunker"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.005,
        }, -- end of ["Bunker"]
        ["GAZ-3308"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 69,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["GAZ-3308"]
        ["SA-18 Igla comm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 55,
                [5] = "MANPADS AUX",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Infantry",
                [13] = "Rocket Attack Valid AirDefence",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "SAM AUX",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["SA-18 Igla comm"]
        ["SA-11 Buk LN 9A310M1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 19,
                [5] = "AA_missile",
                [6] = "MR SAM",
                [7] = "SAM TR",
                [8] = "SAM LL",
                [9] = "RADAR_BAND1_FOR_ARM",
                [10] = "RADAR_BAND2_FOR_ARM",
                [11] = "All",
                [12] = "Ground Units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "NonAndLightArmoredUnits",
                [16] = "NonArmoredUnits",
                [17] = "Air Defence",
                [18] = "SAM related",
                [19] = "SAM elements",
                [20] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 50000,
            ["detection"] = 50000,
            ["irsignature"] = 0.095,
        }, -- end of ["SA-11 Buk LN 9A310M1"]
        ["Patriot ECS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 36,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Patriot ECS"]
        ["CHAP_T84OplotM"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 356,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["irsignature"] = 0.08,
            ["detection"] = 8000,
            ["threatmin"] = 100,
        }, -- end of ["CHAP_T84OplotM"]
        ["tt_B8M1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "</WSTYPE>",
                [6] = "MLRS",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["tt_B8M1"]
        ["SON_9"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 335,
                [5] = "SAM SR",
                [6] = "SAM TR",
                [7] = "AAA",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "RADAR_BAND2_FOR_ARM",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "Armed Air Defence",
                [20] = "Rocket Attack Valid AirDefence",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 55000,
            ["irsignature"] = 0.05,
        }, -- end of ["SON_9"]
        ["CHAP_PantsirS1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 103,
                [4] = 355,
                [5] = "AA_missile",
                [6] = "AA_flak",
                [7] = "Mobile AAA",
                [8] = "SR SAM",
                [9] = "SAM SR",
                [10] = "SAM TR",
                [11] = "RADAR_BAND1_FOR_ARM",
                [12] = "Datalink",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "Armed Air Defence",
                [17] = "Rocket Attack Valid AirDefence",
                [18] = "AAA",
                [19] = "All",
                [20] = "Ground Units",
                [21] = "Vehicles",
                [22] = "Ground vehicles",
                [23] = "SAM related",
                [24] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 20000,
            ["detection"] = 36000,
            ["irsignature"] = 0.08,
        }, -- end of ["CHAP_PantsirS1"]
        ["house1arm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["house1arm"]
        ["Hawk ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 41,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 45000,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Hawk ln"]
        ["BTR-80"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1600,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["BTR-80"]
        ["r11_volvo_drivable"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
        }, -- end of ["r11_volvo_drivable"]
        ["SA-11 Buk SR 9S18M1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 18,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 100000,
            ["irsignature"] = 0.095,
        }, -- end of ["SA-11 Buk SR 9S18M1"]
        ["AAV7"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["AAV7"]
        ["FPS-117"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 329,
                [5] = "EWR",
                [6] = "NonAndLightArmoredUnits",
                [7] = "NonArmoredUnits",
                [8] = "Air Defence",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Air Defence vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 463000,
            ["irsignature"] = 0.07,
        }, -- end of ["FPS-117"]
        ["HEMTT_C-RAM_Phalanx"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 105,
                [4] = 342,
                [5] = "AA_flak",
                [6] = "SAM TR",
                [7] = "Mobile AAA",
                [8] = "C-RAM",
                [9] = "Datalink",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "Armed Air Defence",
                [20] = "Rocket Attack Valid AirDefence",
                [21] = "AAA",
            }, -- end of ["attr"]
            ["threat"] = 2000,
            ["detection"] = 10000,
            ["irsignature"] = 0.1,
        }, -- end of ["HEMTT_C-RAM_Phalanx"]
        ["JTAC"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 90,
                [5] = "Infantry",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["JTAC"]
        ["Patriot ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 37,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 100000,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Patriot ln"]
        ["KrAZ6322"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "human_vehicle",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["KrAZ6322"]
        ["tt_DSHK"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 323,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["tt_DSHK"]
        ["GD-20"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 378,
                [5] = "Trucks",
                [6] = "Cars",
                [7] = "human_vehicle",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Ground Units Non Airdefence",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["GD-20"]
        ["FPS-117 ECS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 328,
                [5] = "SAM CC",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["FPS-117 ECS"]
        ["S-300PS 5H63C 30H6_tr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 344,
                [5] = "LR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 120000,
            ["irsignature"] = 0.05,
        }, -- end of ["S-300PS 5H63C 30H6_tr"]
        ["HL_B8M1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "</WSTYPE>",
                [6] = "MLRS",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["HL_B8M1"]
        ["NASAMS_LN_B"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 307,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 15000,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["NASAMS_LN_B"]
        ["ZU-23 Emplacement"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 47,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.006,
        }, -- end of ["ZU-23 Emplacement"]
        ["NASAMS_LN_C"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 308,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
                [17] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 15000,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["NASAMS_LN_C"]
        ["SA-11 Buk CC 9S470M1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 17,
                [5] = "SAM CC",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.095,
        }, -- end of ["SA-11 Buk CC 9S470M1"]
        ["tt_ZU-23"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 326,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["tt_ZU-23"]
        ["Soldier M4 GRG"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "New infantry",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier M4 GRG"]
        ["M4_Sherman"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["M4_Sherman"]
        ["Ural-4320 APA-5D"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-4320 APA-5D"]
        ["S-300PS 5P85D ln"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 9,
                [5] = "AA_missile",
                [6] = "SAM LL",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Air Defence",
                [14] = "SAM related",
                [15] = "SAM elements",
                [16] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 120000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 5P85D ln"]
        ["Coach a passenger"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 54,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Coach a passenger"]
        ["KAMAZ Truck"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 57,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["KAMAZ Truck"]
        ["Soldier M249"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "Prone",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 700,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Soldier M249"]
        ["M48 Chaparral"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 50,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "IR Guided SAM",
                [8] = "Datalink",
                [9] = "NonAndLightArmoredUnits",
                [10] = "NonArmoredUnits",
                [11] = "Air Defence",
                [12] = "SAM related",
                [13] = "Armed Air Defence",
                [14] = "All",
                [15] = "Ground Units",
                [16] = "Vehicles",
                [17] = "Ground vehicles",
                [18] = "SAM",
            }, -- end of ["attr"]
            ["threat"] = 8500,
            ["detection"] = 10000,
            ["irsignature"] = 0.085,
        }, -- end of ["M48 Chaparral"]
        ["CHAP_IRISTSLM_STR"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 360,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "SAM TR",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "RADAR_BAND2_FOR_ARM",
                [10] = "Datalink",
                [11] = "All",
                [12] = "Ground Units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "NonAndLightArmoredUnits",
                [16] = "NonArmoredUnits",
                [17] = "Air Defence",
                [18] = "SAM related",
                [19] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 250000,
            ["irsignature"] = 0.09,
        }, -- end of ["CHAP_IRISTSLM_STR"]
        ["Patriot EPP"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 36,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Patriot EPP"]
        ["Challenger2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.11,
        }, -- end of ["Challenger2"]
        ["Boxcartrinity"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 51,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Boxcartrinity"]
        ["Roland Radar"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 32,
                [5] = "SAM SR",
                [6] = "RADAR_BAND1_FOR_ARM",
                [7] = "RADAR_BAND2_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 35000,
            ["irsignature"] = 0.085,
        }, -- end of ["Roland Radar"]
        ["Type_89_I_Go"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 5000,
            ["irsignature"] = 0.095,
        }, -- end of ["Type_89_I_Go"]
        ["Ural ATsP-6"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural ATsP-6"]
        ["Coach a tank blue"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 50,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Coach a tank blue"]
        ["Type_98_Ke_Ni"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 5000,
            ["irsignature"] = 0.09,
        }, -- end of ["Type_98_Ke_Ni"]
        ["ZU-23 Closed Insurgent"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 71,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.006,
        }, -- end of ["ZU-23 Closed Insurgent"]
        ["M2A1_halftrack"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["M2A1_halftrack"]
        ["1L13 EWR"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 1,
                [5] = "EWR",
                [6] = "NonAndLightArmoredUnits",
                [7] = "NonArmoredUnits",
                [8] = "Air Defence",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Air Defence vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 300000,
            ["irsignature"] = 0.07,
        }, -- end of ["1L13 EWR"]
        ["RLS_19J6"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 309,
                [5] = "LR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 150000,
            ["irsignature"] = 0.08,
        }, -- end of ["RLS_19J6"]
        ["BTR_D"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 10,
                [5] = "APC",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["BTR_D"]
        ["p-19 s-125 sr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 75,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 160000,
            ["irsignature"] = 0.08,
        }, -- end of ["p-19 s-125 sr"]
        ["GPS_Spoofer_Blue"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 379,
                [5] = "Trucks",
                [6] = "Jammer",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["irsignature"] = 0.07,
        }, -- end of ["GPS_Spoofer_Blue"]
        ["Infantry AK"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "New infantry",
                [7] = "Skeleton_type_A",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Infantry AK"]
        ["HEMTT TFFT"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["HEMTT TFFT"]
        ["Ural-375 ZU-23"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 49,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-375 ZU-23"]
        ["Hawk tr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 40,
                [5] = "MR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "NonAndLightArmoredUnits",
                [14] = "NonArmoredUnits",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 90000,
            ["irsignature"] = 0.06,
        }, -- end of ["Hawk tr"]
        ["NASAMS_Command_Post"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 306,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["NASAMS_Command_Post"]
        ["CHAP_9K720_Cluster"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 369,
                [5] = "SS_missile",
                [6] = "Artillery",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "Indirect fire",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 400000,
            ["irsignature"] = 0.085,
            ["detection"] = 0,
            ["threatmin"] = 75000,
        }, -- end of ["CHAP_9K720_Cluster"]
        ["T-80UD"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["T-80UD"]
        ["rapier_fsa_optical_tracker_unit"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 261,
                [5] = "SR SAM",
                [6] = "SAM SR",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Air Defence",
                [14] = "SAM related",
                [15] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 20000,
            ["irsignature"] = 0.03,
        }, -- end of ["rapier_fsa_optical_tracker_unit"]
        ["SA-18 Igla-S comm"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 53,
                [5] = "MANPADS AUX",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Infantry",
                [13] = "Rocket Attack Valid AirDefence",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
                [19] = "SAM AUX",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["SA-18 Igla-S comm"]
        ["M1128 Stryker MGS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 80,
                [5] = "IFV",
                [6] = "Tanks",
                [7] = "Modern Tanks",
                [8] = "Datalink",
                [9] = "Infantry carriers",
                [10] = "Armored vehicles",
                [11] = "All",
                [12] = "Ground Units",
                [13] = "Ground Units Non Airdefence",
                [14] = "Armed ground units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "Armed vehicles",
                [18] = "AntiAir Armed Vehicles",
                [19] = "NonAndLightArmoredUnits",
                [20] = "LightArmoredUnits",
                [21] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["M1128 Stryker MGS"]
        ["ZSU-23-4 Shilka"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 105,
                [4] = 30,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "SAM TR",
                [8] = "RADAR_BAND1_FOR_ARM",
                [9] = "NonAndLightArmoredUnits",
                [10] = "NonArmoredUnits",
                [11] = "Air Defence",
                [12] = "Armed Air Defence",
                [13] = "Rocket Attack Valid AirDefence",
                [14] = "AAA",
                [15] = "All",
                [16] = "Ground Units",
                [17] = "Vehicles",
                [18] = "Ground vehicles",
                [19] = "SAM related",
                [20] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["ZSU-23-4 Shilka"]
        ["TYPE-59"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["TYPE-59"]
        ["BTR-82A"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 258,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["BTR-82A"]
        ["M1043 HMMWV Armament"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 14,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["M1043 HMMWV Armament"]
        ["LARC-V"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 10,
                [3] = 26,
                [4] = 333,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 500,
        }, -- end of ["LARC-V"]
        ["S_75_ZIL"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 338,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["S_75_ZIL"]
        ["kamaz_tent_civil"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 57,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["kamaz_tent_civil"]
        ["outpost_road"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["outpost_road"]
        ["Electric locomotive"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = "Ground Units",
                [5] = "Trucks",
                [6] = "All",
                [7] = "Vehicles",
                [8] = "Ground vehicles",
                [9] = "Ground Units Non Airdefence",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["Electric locomotive"]
        ["M1A2C_SEP_V3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.15,
        }, -- end of ["M1A2C_SEP_V3"]
        ["Tor 9A331"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 28,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "RADAR_BAND1_FOR_ARM",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 12000,
            ["detection"] = 25000,
            ["irsignature"] = 0.1,
        }, -- end of ["Tor 9A331"]
        ["Sandbox"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Sandbox"]
        ["Hawk cwar"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 42,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "Datalink",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 70000,
            ["irsignature"] = 0.05,
        }, -- end of ["Hawk cwar"]
        ["S-300PS 40B6MD sr_19J6"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 345,
                [5] = "LR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 150000,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 40B6MD sr_19J6"]
        ["T-72B3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4000,
            ["detection"] = 0,
            ["irsignature"] = 0.105,
        }, -- end of ["T-72B3"]
        ["ural_4230_civil_b"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 40,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ural_4230_civil_b"]
        ["Ural-375 ZU-23 Insurgent"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 72,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-375 ZU-23 Insurgent"]
        ["Type_88_75mm_AA"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 375,
                [5] = "AA_flak",
                [6] = "Static AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 10000,
            ["irsignature"] = 0.01,
        }, -- end of ["Type_88_75mm_AA"]
        ["S-300PS 64H6E sr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 7,
                [5] = "LR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 160000,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 64H6E sr"]
        ["MTLB"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1000,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["MTLB"]
        ["ZBD04A"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 276,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Datalink",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 4800,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["ZBD04A"]
        ["AA8"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 295,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["AA8"]
        ["Coach cargo"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 51,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Coach cargo"]
        ["CHAP_M1083"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 353,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.095,
        }, -- end of ["CHAP_M1083"]
        ["NASAMS_Radar_MPQ64F1"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 305,
                [5] = "MR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "RADAR_BAND2_FOR_ARM",
                [9] = "Datalink",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "NonAndLightArmoredUnits",
                [15] = "NonArmoredUnits",
                [16] = "Air Defence",
                [17] = "SAM related",
                [18] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 50000,
            ["irsignature"] = 0.06,
        }, -- end of ["NASAMS_Radar_MPQ64F1"]
        ["CHAP_BMPT"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 370,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 6000,
            ["irsignature"] = 0.1,
            ["detection"] = 7000,
            ["threatmin"] = 800,
        }, -- end of ["CHAP_BMPT"]
        ["M1134 Stryker ATGM"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 80,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Datalink",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3800,
            ["detection"] = 0,
            ["irsignature"] = 0.085,
        }, -- end of ["M1134 Stryker ATGM"]
        ["Ural-375 PBU"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 41,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["Ural-375 PBU"]
        ["Smerch_HE"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "MLRS",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
                [16] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 70000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 20000,
        }, -- end of ["Smerch_HE"]
        ["Land_Rover_109_S3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Land_Rover_109_S3"]
        ["T-55"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["T-55"]
        ["Leclerc"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["Leclerc"]
        ["M6 Linebacker"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 104,
                [4] = 51,
                [5] = "AA_missile",
                [6] = "AA_flak",
                [7] = "SR SAM",
                [8] = "IR Guided SAM",
                [9] = "Datalink",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "Armed Air Defence",
                [15] = "All",
                [16] = "Ground Units",
                [17] = "Vehicles",
                [18] = "Ground vehicles",
                [19] = "SAM",
            }, -- end of ["attr"]
            ["threat"] = 4500,
            ["detection"] = 8000,
            ["irsignature"] = 0.095,
        }, -- end of ["M6 Linebacker"]
        ["M1097 Avenger"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 104,
                [4] = 33,
                [5] = "AA_missile",
                [6] = "AA_flak",
                [7] = "SR SAM",
                [8] = "IR Guided SAM",
                [9] = "Datalink",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "Armed Air Defence",
                [15] = "All",
                [16] = "Ground Units",
                [17] = "Vehicles",
                [18] = "Ground vehicles",
                [19] = "SAM",
            }, -- end of ["attr"]
            ["threat"] = 4500,
            ["detection"] = 5200,
            ["irsignature"] = 0.075,
        }, -- end of ["M1097 Avenger"]
        ["gaz-66_civil"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 67,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["gaz-66_civil"]
        ["GAZ-3307"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 68,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["GAZ-3307"]
        ["S-300PS 40B6M tr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 4,
                [5] = "LR SAM",
                [6] = "SAM TR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 160000,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 40B6M tr"]
        ["Leopard-2A5"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 298,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["Leopard-2A5"]
        ["Coach a platform"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 53,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Coach a platform"]
        ["zil-131_civil"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 387,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["zil-131_civil"]
        ["CHAP_9K720_HE"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 368,
                [5] = "SS_missile",
                [6] = "Artillery",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "Indirect fire",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 400000,
            ["irsignature"] = 0.085,
            ["detection"] = 0,
            ["threatmin"] = 75000,
        }, -- end of ["CHAP_9K720_HE"]
        ["outpost_road_l"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["outpost_road_l"]
        ["Leopard1A3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["Leopard1A3"]
        ["TPZ"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["TPZ"]
        ["PT_76"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 296,
                [5] = "Tanks",
                [6] = "Armored vehicles",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "AntiAir Armed Vehicles",
                [15] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2000,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["PT_76"]
        ["HL_KORD"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 322,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["HL_KORD"]
        ["MLRS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "MLRS",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 32000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 10000,
        }, -- end of ["MLRS"]
        ["M-60"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 8000,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["M-60"]
        ["Infantry AK ver2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 90,
                [5] = "Infantry",
                [6] = "New infantry",
                [7] = "Skeleton_type_A",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 500,
            ["detection"] = 0,
            ["irsignature"] = 0.004,
        }, -- end of ["Infantry AK ver2"]
        ["ZTZ96B"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 275,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Datalink",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 5000,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["ZTZ96B"]
        ["Grad-URAL"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "MLRS",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
                [16] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 19000,
            ["irsignature"] = 0.08,
            ["detection"] = 0,
            ["threatmin"] = 5000,
        }, -- end of ["Grad-URAL"]
        ["SA-18 Igla manpad"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 54,
                [5] = "MANPADS",
                [6] = "IR Guided SAM",
                [7] = "New infantry",
                [8] = "NonAndLightArmoredUnits",
                [9] = "NonArmoredUnits",
                [10] = "Air Defence",
                [11] = "SAM related",
                [12] = "Armed Air Defence",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "SAM",
                [18] = "Ground Units Non Airdefence",
                [19] = "Armed ground units",
                [20] = "Infantry",
                [21] = "Rocket Attack Valid AirDefence",
            }, -- end of ["attr"]
            ["threat"] = 5200,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["SA-18 Igla manpad"]
        ["Strela-1 9P31"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 25,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "IR Guided SAM",
                [8] = "NonAndLightArmoredUnits",
                [9] = "NonArmoredUnits",
                [10] = "Air Defence",
                [11] = "SAM related",
                [12] = "Armed Air Defence",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "SAM",
            }, -- end of ["attr"]
            ["threat"] = 4200,
            ["detection"] = 5000,
            ["irsignature"] = 0.08,
        }, -- end of ["Strela-1 9P31"]
        ["Coach a tank yellow"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 98,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Coach a tank yellow"]
        ["Chieftain_mk3"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 297,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["Chieftain_mk3"]
        ["ZSU_57_2"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 26,
                [4] = 257,
                [5] = "AA_flak",
                [6] = "Mobile AAA",
                [7] = "NonAndLightArmoredUnits",
                [8] = "NonArmoredUnits",
                [9] = "Air Defence",
                [10] = "Armed Air Defence",
                [11] = "Rocket Attack Valid AirDefence",
                [12] = "AAA",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
            }, -- end of ["attr"]
            ["threat"] = 7000,
            ["detection"] = 5000,
            ["irsignature"] = 0.1,
        }, -- end of ["ZSU_57_2"]
        ["Dog Ear radar"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 27,
                [5] = "SAM SR",
                [6] = "RADAR_BAND1_FOR_ARM",
                [7] = "RADAR_BAND2_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 35000,
            ["irsignature"] = 0.08,
        }, -- end of ["Dog Ear radar"]
        ["S-300PS 54K6 cp"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 25,
                [4] = 6,
                [5] = "SAM CC",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "NonAndLightArmoredUnits",
                [11] = "NonArmoredUnits",
                [12] = "Air Defence",
                [13] = "SAM related",
                [14] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["S-300PS 54K6 cp"]
        ["PLZ05"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 279,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 23500,
            ["irsignature"] = 0.1,
            ["detection"] = 0,
            ["threatmin"] = 60,
        }, -- end of ["PLZ05"]
        ["PL5EII Loadout"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Missile",
                [6] = "NonArmoredUnits",
                [7] = "NonAndLightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["PL5EII Loadout"]
        ["CHAP_M142_GMLRS_M30"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 364,
                [5] = "MLRS",
                [6] = "Datalink",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Ground Units Non Airdefence",
                [10] = "Armed ground units",
                [11] = "Vehicles",
                [12] = "Ground vehicles",
                [13] = "Armed vehicles",
                [14] = "Indirect fire",
                [15] = "NonAndLightArmoredUnits",
                [16] = "LightArmoredUnits",
                [17] = "Artillery",
            }, -- end of ["attr"]
            ["threat"] = 70000,
            ["irsignature"] = 0.075,
            ["detection"] = 0,
            ["threatmin"] = 15000,
        }, -- end of ["CHAP_M142_GMLRS_M30"]
        ["SA-18 Igla-S manpad"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 27,
                [4] = 52,
                [5] = "MANPADS",
                [6] = "IR Guided SAM",
                [7] = "New infantry",
                [8] = "NonAndLightArmoredUnits",
                [9] = "NonArmoredUnits",
                [10] = "Air Defence",
                [11] = "SAM related",
                [12] = "Armed Air Defence",
                [13] = "All",
                [14] = "Ground Units",
                [15] = "Vehicles",
                [16] = "Ground vehicles",
                [17] = "SAM",
                [18] = "Ground Units Non Airdefence",
                [19] = "Armed ground units",
                [20] = "Infantry",
                [21] = "Rocket Attack Valid AirDefence",
            }, -- end of ["attr"]
            ["threat"] = 5200,
            ["detection"] = 5000,
            ["irsignature"] = 0.004,
        }, -- end of ["SA-18 Igla-S manpad"]
        ["outpost_road_r"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 96,
                [5] = "Fortifications",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "AntiAir Armed Vehicles",
                [11] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 800,
            ["detection"] = 0,
            ["irsignature"] = 0.007,
        }, -- end of ["outpost_road_r"]
        ["CHAP_FV107"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 350,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 2500,
            ["detection"] = 6000,
            ["irsignature"] = 0.06,
        }, -- end of ["CHAP_FV107"]
        ["Coach cargo open"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 51,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0,
        }, -- end of ["Coach cargo open"]
        ["Roland ADS"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 102,
                [4] = 31,
                [5] = "AA_missile",
                [6] = "SR SAM",
                [7] = "SAM SR",
                [8] = "SAM TR",
                [9] = "SAM LL",
                [10] = "RADAR_BAND1_FOR_ARM",
                [11] = "RADAR_BAND2_FOR_ARM",
                [12] = "All",
                [13] = "Ground Units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "NonArmoredUnits",
                [18] = "Air Defence",
                [19] = "SAM related",
                [20] = "SAM elements",
                [21] = "Armed Air Defence",
            }, -- end of ["attr"]
            ["threat"] = 8000,
            ["detection"] = 12000,
            ["irsignature"] = 0.085,
        }, -- end of ["Roland ADS"]
        ["S-300PS 40B6MD sr"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 16,
                [3] = 101,
                [4] = 5,
                [5] = "LR SAM",
                [6] = "SAM SR",
                [7] = "RADAR_BAND1_FOR_ARM",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Air Defence",
                [15] = "SAM related",
                [16] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 60000,
            ["irsignature"] = 0.08,
        }, -- end of ["S-300PS 40B6MD sr"]
        ["leopard-2A4_trs"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 301,
                [5] = "Tanks",
                [6] = "Modern Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3500,
            ["detection"] = 0,
            ["irsignature"] = 0.12,
        }, -- end of ["leopard-2A4_trs"]
        ["M-2 Bradley"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 104,
                [4] = 7,
                [5] = "IFV",
                [6] = "ATGM",
                [7] = "Datalink",
                [8] = "Infantry carriers",
                [9] = "Armored vehicles",
                [10] = "All",
                [11] = "Ground Units",
                [12] = "Ground Units Non Airdefence",
                [13] = "Armed ground units",
                [14] = "Vehicles",
                [15] = "Ground vehicles",
                [16] = "Armed vehicles",
                [17] = "AntiAir Armed Vehicles",
                [18] = "NonAndLightArmoredUnits",
                [19] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3800,
            ["detection"] = 0,
            ["irsignature"] = 0.095,
        }, -- end of ["M-2 Bradley"]
        ["SpGH_Dana"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 1,
                [5] = "Artillery",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Ground Units Non Airdefence",
                [9] = "Armed ground units",
                [10] = "Vehicles",
                [11] = "Ground vehicles",
                [12] = "Armed vehicles",
                [13] = "Indirect fire",
                [14] = "NonAndLightArmoredUnits",
                [15] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 18700,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 30,
        }, -- end of ["SpGH_Dana"]
        ["ATZ-5"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 294,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ATZ-5"]
        ["Locomotive"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 8,
                [3] = 100,
                [4] = 48,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.15,
        }, -- end of ["Locomotive"]
        ["Land_Rover_101_FC"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.075,
        }, -- end of ["Land_Rover_101_FC"]
        ["Pz_IV_H"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 16,
                [5] = "Tanks",
                [6] = "Old Tanks",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "HeavyArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 3000,
            ["detection"] = 0,
            ["irsignature"] = 0.1,
        }, -- end of ["Pz_IV_H"]
        ["Grad_FDDM"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 10,
                [5] = "APC",
                [6] = "Infantry carriers",
                [7] = "Armored vehicles",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "AntiAir Armed Vehicles",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1000,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["Grad_FDDM"]
        ["CHAP_M1130"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 26,
                [4] = 359,
                [5] = "APC",
                [6] = "Datalink",
                [7] = "Infantry carriers",
                [8] = "Armored vehicles",
                [9] = "All",
                [10] = "Ground Units",
                [11] = "Ground Units Non Airdefence",
                [12] = "Armed ground units",
                [13] = "Vehicles",
                [14] = "Ground vehicles",
                [15] = "Armed vehicles",
                [16] = "AntiAir Armed Vehicles",
                [17] = "NonAndLightArmoredUnits",
                [18] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 1200,
            ["detection"] = 0,
            ["irsignature"] = 0.09,
        }, -- end of ["CHAP_M1130"]
        ["Blitz_36-6700A"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 6,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.75,
        }, -- end of ["Blitz_36-6700A"]
        ["ATZ-10"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 5,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ATZ-10"]
        ["ural_4230_civil_t"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 75,
                [5] = "Trucks",
                [6] = "All",
                [7] = "Ground Units",
                [8] = "Vehicles",
                [9] = "Ground vehicles",
                [10] = "Ground Units Non Airdefence",
                [11] = "NonAndLightArmoredUnits",
                [12] = "NonArmoredUnits",
                [13] = "Unarmed vehicles",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.08,
        }, -- end of ["ural_4230_civil_t"]
        ["Patriot AMG"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 25,
                [4] = 36,
                [5] = "Trucks",
                [6] = "SAM CC",
                [7] = "All",
                [8] = "Ground Units",
                [9] = "Vehicles",
                [10] = "Ground vehicles",
                [11] = "Ground Units Non Airdefence",
                [12] = "NonAndLightArmoredUnits",
                [13] = "NonArmoredUnits",
                [14] = "Unarmed vehicles",
                [15] = "Air Defence",
                [16] = "SAM related",
                [17] = "SAM elements",
            }, -- end of ["attr"]
            ["threat"] = 0,
            ["detection"] = 0,
            ["irsignature"] = 0.05,
        }, -- end of ["Patriot AMG"]
        ["Scud_B"] = 
        {
            ["attr"] = 
            {
                [1] = 2,
                [2] = 17,
                [3] = 27,
                [4] = 63,
                [5] = "SS_missile",
                [6] = "Artillery",
                [7] = "Datalink",
                [8] = "All",
                [9] = "Ground Units",
                [10] = "Ground Units Non Airdefence",
                [11] = "Armed ground units",
                [12] = "Vehicles",
                [13] = "Ground vehicles",
                [14] = "Armed vehicles",
                [15] = "Indirect fire",
                [16] = "NonAndLightArmoredUnits",
                [17] = "LightArmoredUnits",
            }, -- end of ["attr"]
            ["threat"] = 285000,
            ["irsignature"] = 0.09,
            ["detection"] = 0,
            ["threatmin"] = 50000,
        }, -- end of ["Scud_B"]
    } -- end of EMBD.tblThreatsRange.lua
end

--###### UTIL FUNCTIONS ############################################################################

-- all the below functions are basically elements used in other part of the code. Many of them are basically copy or modified copy of other useful code and script, 
-- the credits list would be quite long but mostly mist, MOOSE, CTLD. When able I kept the original name even if slightly modified.

local function escape_string(str)
    local replacements = {
        ['%'] = '%%',
        ['^'] = '%^',
        ['$'] = '%$',
        ['('] = '%(',
        [')'] = '%)',
        ['%['] = '%[%]',
        ['{'] = '%{',
        ['}'] = '%}',
        ['.'] = '%.',
        ['*'] = '%*',
        ['+'] = '%+',
        ['-'] = '%-',
        ['?'] = '%?',
        ['\0'] = '%z'
    }
    
    return (str:gsub(".", replacements))
end

local function contains(haystack, needle)
    -- Effettua l'escape dei caratteri speciali nella stringa 'needle'
    local function escape_special_characters(str)
        local replacements = {
            ['%'] = '%%',
            ['^'] = '%^',
            ['$'] = '%$',
            ['('] = '%(',
            [')'] = '%)',
            ['%['] = '%[%]',
            ['{'] = '%{',
            ['}'] = '%}',
            ['.'] = '%.',
            ['*'] = '%*',
            ['+'] = '%+',
            ['-'] = '%-',
            ['?'] = '%?',
            ['\0'] = '%z'
        }
        
        return (str:gsub(".", replacements))
    end

    -- Escape della stringa 'needle'
    local escaped_needle = escape_special_characters(needle)
    
    -- Controlla se 'needle' è contenuta in 'haystack'
    return haystack:find(escaped_needle) ~= nil
end

local function vec3Check(vec3)
    if vec3 then
        if type(vec3) == 'table' then -- assuming name
            if vec3.x and vec3.y and vec3.z then			
                return vec3
            elseif vec3.x and vec3.y and vec3.z == nil then
                env.info((tostring(ModuleName) .. ", vec3Check: vector is vec2, converting to vec3"))
                local new_y = land.getHeight({x = vec3.x, y = vec3.y})
                
                if new_y then
                    local new_Vec3 = {x = vec3.x, y = new_y, z = vec3.y}
                    return new_Vec3
                else
                    env.info((tostring(ModuleName) .. ", vec3Check: vector is vec2, but no height found, returning nil"))
                    return nil
                end
            else
                env.info((tostring(ModuleName) .. ", vec3Check: wrong vector format"))
                return nil
            end
        else
            env.info((tostring(ModuleName) .. ", vec3Check: wrong variable"))
            return nil
        end
    else
        env.info((tostring(ModuleName) .. ", vec3Check: missing variable"))
        return nil
    end
end

local function getDist(point1, point2, rounded)
    local xUnit = point1.x
    local yUnit = nil
    local xZone = point2.x
    local yZone = nil	
	if point1.z then
		yUnit = point1.z
	elseif point1.y then
		yUnit = point1.y
	end
	if point2.z then
		yZone = point2.z
	elseif point2.y then
		yZone = point2.y
	end
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    local dist = math.sqrt(xDiff * xDiff + yDiff * yDiff)
    if rounded == true then
        return math.floor(dist)
    else
        return dist
    end

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

local function groupTableCheck(group)
    if group then
        if type(group) == 'string' then -- assuming name
            local groupTable = Group.getByName(group)

            if not groupTable then
                groupTable = StaticObject.getByName(group)
            end

            if groupTable then
                return groupTable
            else
                return nil
            end
        elseif type(group) == 'table' then
            return group
        else
            env.info((tostring(ModuleName) .. ", groupTableCheck: wrong variable"))
            return nil
        end
    else
        env.info((tostring(ModuleName) .. ", groupTableCheck: missing variable"))
        return nil
    end
end

local function aie_random(firstNum, secondNum)
    local lowNum, highNum
    if not secondNum then
        highNum = firstNum
        lowNum = 1
    else
        lowNum = firstNum
        highNum = secondNum
    end
    local total = 1
    if math.abs(highNum - lowNum + 1) < 50 then -- if total values is less than 50
        total = math.modf(50/math.abs(highNum - lowNum + 1)) -- make x copies required to be above 50
    end
    local choices = {}
    for i = 1, total do -- iterate required number of times
        for x = lowNum, highNum do -- iterate between the range
            choices[#choices +1] = x -- add each entry to a table
        end
    end
    local rtnVal = math.random(#choices) -- will now do a math.random of at least 50 choices
    for i = 1, 10 do
        rtnVal = math.random(#choices) -- iterate a few times for giggles
    end
    return choices[rtnVal]
end

local function round(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

local function buildWP(point, overRideForm, overRideSpeed)

    if point then 
        local wp = {}
        wp.x = point.x

        if point.z then
            wp.y = point.z
        else
            wp.y = point.y
        end
        local form, speed

        if point.speed and not overRideSpeed then
            wp.speed = point.speed
        elseif type(overRideSpeed) == 'number' then
            wp.speed = overRideSpeed
        else
            wp.speed = 18/3.6
        end

        if point.form and not overRideForm then
            form = point.form
        else
            form = overRideForm
        end

        if not form then
            wp.action = 'Off Road'
        else
            form = string.lower(form)
            if form == 'off_road' or form == 'off road' then
                wp.action = 'Off Road'
            elseif form == 'on_road' or form == 'on road' then
                wp.action = 'On Road'
            elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
                wp.action = 'Rank'
            elseif form == 'cone' then
                wp.action = 'Cone'
            elseif form == 'diamond' then
                wp.action = 'Diamond'
            elseif form == 'vee' then
                wp.action = 'Vee'
            elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
                wp.action = 'EchelonL'
            elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
                wp.action = 'EchelonR'
            else
                wp.action = 'Off Road' -- if nothing matched
            end
        end

        wp.type = 'Turning Point'

        return wp
    else
        return false
    end
end

local function getRandPointInCircle(point, radius, innerRadius)
    local theta = 2*math.pi*math.random()
    local rad = math.random() + math.random()
    if rad > 1 then
        rad = 2 - rad
    end

    local radMult
    if innerRadius and innerRadius <= radius then
        radMult = (radius - innerRadius)*rad + innerRadius
    else
        radMult = radius*rad
    end

    if not point.z then --might as well work with vec2/3
        point.z = point.y
    end

    local rndCoord
    if radius > 0 then
        rndCoord = {x = math.cos(theta)*radMult + point.x, y = math.sin(theta)*radMult + point.z}
    else
        rndCoord = {x = point.x, y = point.z}
    end
    return rndCoord
end

local function getRandTerrainPointInCircle(var, radius, innerRadius, requestV3)
    local point = vec3Check(var)	
    if point and radius and innerRadius then
        for i = 1, 5 do
            local coordRun = getRandPointInCircle(point, radius, innerRadius)
            local destlandtype = land.getSurfaceType({coordRun.x, coordRun.z})
            if destlandtype == 1 or destlandtype == 4 then
                if requestV3 == true then
                    local c2 = {x = coordRun.x, y = land.getHeight({x = coordRun.x, y = coordRun.y}), z = coordRun.y}
                    return c2
                else
                    return coordRun
                end
            end
        end
        return nil -- this means that no valid result has found
        
    end
end

local function deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

local function multyTypeMessage(var)
    local mexType       = var[1]
    local mexText       = var[2]
    local mexDuration   = var[3]
    local mexPos        = var[4]  -- ral 7024
    local unitId        = var[5]
    local groupId       = var[6]
    local countryId     = var[7]
    local coaId         = var[8]
    local mexAuthor     = var[9]
    local voiceGender   = var[10]

    -- text message
    if mexType == "text" or mexType == "both" then
        if mexText and type(mexText) == "string" then

            local t = mexDuration
            if not t then t = 30 end

            if unitId then
                trigger.action.outTextForGroup(unitId, mexText, t)            
            elseif groupId then
                trigger.action.outTextForGroup(groupId, mexText, t)
            elseif countryId then
                trigger.action.outTextForCoalition(countryId, mexText, t)
            elseif coaId then
                trigger.action.outTextForCoalition(coaId, mexText, t)
            else
                trigger.action.outText(mexText, t)
            end

        else
            env.info((tostring(ModuleName) .. " multyTypeMessage, mexText is not a valid input"))
        end
    end

end

local function vecmag(vec)
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end

local function getNorthCorrection(gPoint)
	local point = deepCopy(gPoint)
	if not point.z then --Vec2; convert to Vec3
		point.z = point.y
		point.y = 0
	end
	local lat, lon = coord.LOtoLL(point)
	local north_posit = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north_posit.z - point.z, north_posit.x - point.x)
end

local function kmphToMps(kmph)
	return kmph/3.6
end

local function pointBetween(p1, p2, d)

    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local dz = p2.z - p1.z

    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    if d >= dist then
        return {x = p2.x, y = p2.y, z = p2.z}
    end

    local scale = d / dist

    return {
        x = p1.x + dx * scale,
        y = p1.y + dy * scale,
        z = p1.z + dz * scale
    }
end

local function getTerrainSlopeAtPoint(p1, radius)
    radius = radius or 5  -- raggio in metri per campionare il terreno

    -- Punti attorno a p1
    local offsets = {
        {x = radius, z = 0},    -- Est
        {x = -radius, z = 0},   -- Ovest
        {x = 0, z = radius},    -- Nord
        {x = 0, z = -radius},   -- Sud
    }

    local maxSlope = 0

    for _, offset in ipairs(offsets) do
        local p2 = {
            x = p1.x + offset.x,
            y = 0,
            z = p1.z + offset.z
        }

        local alt1 = land.getHeight({x = p1.x, y = 0, z = p1.z})
        local alt2 = land.getHeight(p2)

        local dz = alt2 - alt1
        local dxz = math.sqrt(offset.x^2 + offset.z^2)

        local slopeRad = math.atan(dz / dxz)
        local slopeDeg = math.deg(math.abs(slopeRad))

        if slopeDeg > maxSlope then
            maxSlope = slopeDeg
        end
    end

    return maxSlope  -- Ritorna l'inclinazione massima in gradi
end

-- revTODO the code below is not used; an error? -> Chromium: check this out -> nope will be used
local function getHeading(unit, rawHeading)
	local unitpos = unit:getPosition()
	if unitpos then
		local Heading = math.atan2(unitpos.x.z, unitpos.x.x)
		if not rawHeading then
			Heading = Heading + getNorthCorrection(unitpos.p)
		end
		if Heading < 0 then
			Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
		end
		return Heading
	end
end

local function makeVec3(vec, y)
	if not vec.z then
		if vec.alt and not y then
			y = vec.alt
		elseif not y then
			y = 0
		end
		return {x = vec.x, y = y, z = vec.y}
	else
		return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
	end
end

local function avgVec3(tblPos)
    local avgPoint = {x = 0, y = 0, z = 0}
    local numpoints = #tblPos

    if numpoints == 0 then
        return avgPoint
    end

    for _, punto in ipairs(tblPos) do
        avgPoint.x = avgPoint.x + punto.x
        avgPoint.y = avgPoint.y + punto.y
        avgPoint.z = avgPoint.z + punto.z
    end

    avgPoint.x = avgPoint.x / numpoints
    avgPoint.z = avgPoint.z / numpoints
    if avgPoint.x and avgPoint.z then
        avgPoint.y = land.getHeight({x = avgPoint.x, y = avgPoint.z})
        return avgPoint
    else
        return nil
    end
end

local function getGroupSpeed(group)
    local g = groupTableCheck(group)
    if g then
        local units = g:getUnits()
        if units and #units > 0 then
            local s = 0
            local ms = 1000
            local u = 0
            for u, uData in pairs(units) do
                u = u + 1
                local us = vecmag(uData:getVelocity())
                if us and us >= 0 then
                    s = s + us
                    if us < ms then
                        ms = us
                    end
                end
            end
            return s, ms
        else
            return nil
        end
    else
        return nil
    end
end

local function toDegree(angle)
	return angle*180/math.pi
end

local function tostringLL(lat, lon, acc, DMS)

	local latHemi, lonHemi
	if lat > 0 then
		latHemi = 'N'
	else
		latHemi = 'S'
	end

	if lon > 0 then
		lonHemi = 'E'
	else
		lonHemi = 'W'
	end

	lat = math.abs(lat)
	lon = math.abs(lon)

	local latDeg = math.floor(lat)
	local latMin = (lat - latDeg)*60

	local lonDeg = math.floor(lon)
	local lonMin = (lon - lonDeg)*60

	if DMS then	-- degrees, minutes, and seconds.
		local oldLatMin = latMin
		latMin = math.floor(latMin)
		local latSec = round((oldLatMin - latMin)*60, acc)

		local oldLonMin = lonMin
		lonMin = math.floor(lonMin)
		local lonSec = round((oldLonMin - lonMin)*60, acc)

		if latSec == 60 then
			latSec = 0
			latMin = latMin + 1
		end

		if lonSec == 60 then
			lonSec = 0
			lonMin = lonMin + 1
		end

		local secFrmtStr -- create the formatting string for the seconds place
		if acc <= 0 then	-- no decimal place.
			secFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			secFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi

	else	-- degrees, decimal minutes.
		latMin = round(latMin, acc)
		lonMin = round(lonMin, acc)

		if latMin == 60 then
			latMin = 0
			latDeg = latDeg + 1
		end

		if lonMin == 60 then
			lonMin = 0
			lonDeg = lonDeg + 1
		end

		local minFrmtStr -- create the formatting string for the minutes place
		if acc <= 0 then	-- no decimal place.
			minFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi

	end
end

local function tostringMGRS(MGRS, acc)
	if acc == 0 then
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph
	else
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph .. ' ' .. string.format('%0' .. acc .. 'd', round(MGRS.Easting/(10^(5-acc)), 0))
		.. ' ' .. string.format('%0' .. acc .. 'd', round(MGRS.Northing/(10^(5-acc)), 0))
	end
end

local function getCurveval(x, maxVal, maxDist, curveType)

    if x < 0 then x = 0 end
    if x > maxDist then x = maxDist end

    if not curveType then
        curveType = "lin" -- default to linear if no curve type is specified
    end

    if curveType == "lin" then
        return maxVal * (1 - x / maxDist)
    elseif curveType == "sqr" then
        local ratio = math.sqrt(x / maxDist)
        return maxVal * (1 - ratio)
    end
end

local function getCirclePoints(center, num)
    local points = {}
    
    -- correct num
    if not num then
        num = 8
    elseif num < 4 then
        num = 4
    elseif num > 12 then
        num = 12
    end

    -- define range
    local range = (AIEN.config.densityRange / 2) / math.sin(math.pi / num * 2)

    for i = 1, num do 
        local angle = math.rad(i * 45) -- 360° diviso 8 = 45°
        local px = center.x + range * math.cos(angle)
        local pz = center.z + range * math.sin(angle)
        local py = center.y -- stesso livello in altezza
        
        points[#points + 1] = {p = {x = px, y = py, z = pz}}
        
    end
    return points
end

local function zoneToVec3(zone)
    local new = {}
	if type(zone) == 'table' then
		if zone.point then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
		elseif zone.x and zone.y and zone.z then
			return zone
		end
		return new
	elseif type(zone) == 'string' then
		zone = trigger.misc.getZone(zone)
		if zone then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
			return new
		end
	end
end

local function pointInPolygon(point, poly) -- mist local copy ot f that function

	point = makeVec3(point)
	local px = point.x
	local pz = point.z
	local cn = 0
	local newpoly = deepCopy(poly)

    local polysize = #newpoly
    newpoly[#newpoly + 1] = newpoly[1]

    newpoly[1] = makeVec3(newpoly[1])

    for k = 1, polysize do
        newpoly[k+1] = makeVec3(newpoly[k+1])
        if ((newpoly[k].z <= pz) and (newpoly[k+1].z > pz)) or ((newpoly[k].z > pz) and (newpoly[k+1].z <= pz)) then
            local vt = (pz - newpoly[k].z) / (newpoly[k+1].z - newpoly[k].z)
            if (px < newpoly[k].x + vt*(newpoly[k+1].x - newpoly[k].x)) then
                cn = cn + 1
            end
        end
    end

    return cn%2 == 1
end

local function getPayload(unitName)
    -- refactor to search by groupId and allow groupId and groupName as inputs
	local unitTbl = Unit.getByName(unitName)
	local unitId = unitTbl:getID()
	local gpTbl = unitTbl:getGroup()
	local gpId = gpTbl:getID()

	if gpId and unitId then
		for coa_name, coa_data in pairs(env.mission.coalition) do
			if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
				if coa_data.country then --there is a country table
					for cntry_id, cntry_data in pairs(coa_data.country) do
						for obj_type_name, obj_type_data in pairs(cntry_data) do
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
									for group_num, group_data in pairs(obj_type_data.group) do
										if group_data and group_data.groupId == gpId then
											for unitIndex, unitData in pairs(group_data.units) do --group index
												if unitData.unitId == unitId then
													return unitData.payload
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		if AIEN.config.AIEN_debugProcessDetail then
			env.info(ModuleName .. " getPayload error, no gId or unitId")
		end	
		return false
	end
	return
end

local function ground_buildWP(point, overRideForm, overRideSpeed)

	local wp = {}
	wp.x = point.x

	if point.z then
		wp.y = point.z
	else
		wp.y = point.y
	end

    local form

	if point.speed and not overRideSpeed then
		wp.speed = point.speed
	elseif type(overRideSpeed) == 'number' then
		wp.speed = overRideSpeed
	else
		wp.speed = kmphToMps(20)
	end

	if point.form and not overRideForm then
		form = point.form
	else
		form = overRideForm
	end

	if not form then
		wp.action = 'Cone'
	else
		form = string.lower(form)
		if form == 'off_road' or form == 'off road' then
			wp.action = 'Off Road'
		elseif form == 'on_road' or form == 'on road' then
			wp.action = 'On Road'
		elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
			wp.action = 'Rank'
		elseif form == 'cone' then
			wp.action = 'Cone'
		elseif form == 'diamond' then
			wp.action = 'Diamond'
		elseif form == 'vee' then
			wp.action = 'Vee'
		elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
			wp.action = 'EchelonL'
		elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
			wp.action = 'EchelonR'
		else
			wp.action = 'Cone' -- if nothing matched
		end
	end

	wp.type = 'Turning Point'

	return wp

end

local function dynAdd(ng)

    local newGroup = deepCopy(ng)

    local cntry = newGroup.country
	if newGroup.countryId then
		cntry = newGroup.countryId
	end

	local groupType = newGroup.category
	local newCountry = ''
	-- validate data

	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
	end

	if newCountry == '' then
		if AIEN.config.AIEN_debugProcessDetail then
			env.info(ModuleName .. " dynAdd Country not found")
		end		
		return false
	end

	local newCat = ''
	for catName, catId in pairs(Unit.Category) do
		if type(groupType) == 'string' then
			if tostring(catName) == string.upper(groupType) then
				newCat = catName
			end
		elseif type(groupType) == 'number' then
			if catId == groupType then
				newCat = catName
			end
		end

		if catName == 'GROUND_UNIT' and (string.upper(groupType) == 'VEHICLE' or string.upper(groupType) == 'GROUND') then
			newCat = 'GROUND_UNIT'
		elseif catName == 'AIRPLANE' and string.upper(groupType) == 'PLANE' then
			newCat = 'AIRPLANE'
		end
	end

	local typeName
	if newCat == 'GROUND_UNIT' then
		typeName = ' gnd '
	elseif newCat == 'AIRPLANE' then
		typeName = ' air '
	elseif newCat == 'HELICOPTER' then
		typeName = ' hel '
	elseif newCat == 'SHIP' then
		typeName = ' shp '
	elseif newCat == 'BUILDING' then
		typeName = ' bld '
	end    
	if newGroup.groupName or newGroup.name then
		if newGroup.groupName then
			newGroup.name = newGroup.groupName
		elseif newGroup.name then
			newGroup.name = newGroup.name
		end
	end

	if newGroup.clone or not newGroup.name then
		newGroup.name = tostring(newCountry .. tostring(typeName) .. string.format("%04d", tostring(stupidIndex)))
        stupidIndex = stupidIndex + 1
	end

	if not newGroup.hidden then
		newGroup.hidden = false
	end

	if not newGroup.visible then
		newGroup.visible = false
	end

	if (newGroup.start_time and type(newGroup.start_time) ~= 'number') or not newGroup.start_time then
		if newGroup.startTime then
			newGroup.start_time = round(newGroup.startTime)
		else
			newGroup.start_time = 0
		end
	end

    for unitIndex, unitData in pairs(newGroup.units) do
        local originalName = newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name
        if newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name then
            if newGroup.units[unitIndex].unitName then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].unitName
            elseif newGroup.units[unitIndex].name then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].name
            end
        end
        if newGroup.clone or not unitData.name then
            newGroup.units[unitIndex].name = tostring(newGroup.name .. ' unit' .. unitIndex)
        end

        if not unitData.skill then
            newGroup.units[unitIndex].skill = 'Random' -- provide something here
        end

        if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
            if newGroup.units[unitIndex].alt_type and newGroup.units[unitIndex].alt_type ~= 'BARO' or not newGroup.units[unitIndex].alt_type then
                newGroup.units[unitIndex].alt_type = 'RADIO'
            end
            if not unitData.speed then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].speed = 60
                end
            end
            if not unitData.payload then
                newGroup.units[unitIndex].payload = getPayload(originalName)
            end
            if not unitData.alt then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].alt = 2000
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].alt = 500
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 60
                end
            end
            
        elseif newCat == 'GROUND_UNIT' then
            if nil == unitData.playerCanDrive then
                unitData.playerCanDrive = true
            end
        
        end
    end
    if newGroup.route then
        if newGroup.route and not newGroup.route.points then
            if newGroup.route[1] then
                local copyRoute = deepCopy(newGroup.route)
                newGroup.route = {}
                newGroup.route.points = copyRoute
            end
        end
    else -- if aircraft and no route assigned. make a quick and stupid route so AI doesnt RTB immediately
        --if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
            newGroup.route = {}
            newGroup.route.points = {}
            newGroup.route.points[1] = {}
        --end
    end
	newGroup.country = newCountry

    -- update and verify any self tasks
    if newGroup.route and newGroup.route.points then 
        --log:warn(newGroup.route.points)
        for i, pData in pairs(newGroup.route.points) do
            if pData.task and pData.task.params and pData.task.params.tasks and #pData.task.params.tasks > 0 then
                for tIndex, tData in pairs(pData.task.params.tasks) do
                    if tData.params and tData.params.action then  
                        if tData.params.action.id == "EPLRS" then
                            tData.params.action.params.groupId = newGroup.groupId
                        elseif tData.params.action.id == "ActivateBeacon" or tData.params.action.id == "ActivateICLS" then 
                            tData.params.action.params.unitId = newGroup.units[1].unitId
                        end 
                    end
                end
            end
        
        end
    end

	-- sanitize table
	newGroup.groupName = nil
	newGroup.clone = nil
	newGroup.category = nil
	newGroup.country = nil

	newGroup.tasks = {}

	for unitIndex, unitData in pairs(newGroup.units) do
		newGroup.units[unitIndex].unitName = nil
	end

	coalition.addGroup(country.id[newCountry], Unit.Category[newCat], newGroup) -- QUIIIII, problema con ID?

	return newGroup

end

local function genSmokePoints(pos, dist, n)
    local points = {}
    local angle_step = 360 / n 

    for i = 0, n - 1 do
       
        local rad = (i * angle_step) * math.pi / 180
        local x = pos.x + dist * math.cos(rad)
        local z = pos.z + dist * math.sin(rad)
        table.insert(points, {x = x, y = pos.y-50, z = z})
    end

    return points
end

local function pcallGetCategory(obj) -- done to avoid DCS errors 
    local function effectiveCheck(obj)
        if obj then
           if obj.isExist and obj:isExist() then
                if obj:getPosition() then
                    if Object.getCategory(obj) then
                        return Object.getCategory(obj)
                    else
                        if AIEN.config.AIEN_debugProcessDetail == true then
                            env.info(("AIEN pcallGetCategory, missing category"))
                        end    
                        return nil
                    end
                else
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info(("AIEN pcallGetCategory, missing pos"))
                    end    
                    return nil
                end
            else
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info(("AIEN pcallGetCategory, isExist failed"))
                end    
                return nil 
            end
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN pcallGetCategory, missing obj"))
            end    
            return nil 
        end
    end
    local noError, errorOrResult = pcall(effectiveCheck, obj)
    if noError then
        return errorOrResult
    else
        env.info(string.format("AIEN pcallGetCategory, error returned when calling the function: %s", errorOrResult or ""))
    end
end



-- desanitized functions (if available), for logging, table printing and debug purposes

-- You should never run DCS desanitized unless specifically knowing the risks. However, if you already do that, for debug purposes AIEN will take advantages of the available io and lfs
-- to print out tables of the databases created in it.

if AIEN_io and AIEN_lfs then
	env.info(("AIEN loading desanitized additional function"))

    function IntegratedbasicSerialize(s)
        if s == nil then
            return "\"\""
        else
            if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
                return tostring(s)
            elseif type(s) == 'string' then
                return string.format('%q', s)
            end
        end
    end
    
    function Integratedserialize(name, value, level)
        -----Based on ED's serialize_simple2
        local basicSerialize = function (o)
            if type(o) == "number" then
            return tostring(o)
            elseif type(o) == "boolean" then
            return tostring(o)
            else -- assume it is a string
            return IntegratedbasicSerialize(o)
            end
        end
    
        local serialize_to_t = function (name, value, level)
        ----Based on ED's serialize_simple2
    
            local var_str_tbl = {}
            if level == nil then level = "" end
            if level ~= "" then level = level.."  " end
    
            table.insert(var_str_tbl, level .. name .. " = ")
    
            if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
            table.insert(var_str_tbl, basicSerialize(value) ..  ",\n")
            elseif type(value) == "table" then
                table.insert(var_str_tbl, "\n"..level.."{\n")
    
                for k,v in pairs(value) do -- serialize its fields
                local key
                if type(k) == "number" then
                    key = string.format("[%s]", k)
                else
                    key = string.format("[%q]", k)
                end
    
                table.insert(var_str_tbl, Integratedserialize(key, v, level.."  "))
    
                end
                if level == "" then
                table.insert(var_str_tbl, level.."} -- end of "..name.."\n")
    
                else
                table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")
    
                end
            else
            print("Cannot serialize a "..type(value))
            end
            return var_str_tbl
        end
    
        local t_str = serialize_to_t(name, value, level)
    
        return table.concat(t_str)
    end
    
    function IntegratedserializeWithCycles(name, value, saved)
        local basicSerialize = function (o)
            if type(o) == "number" then
                return tostring(o)
            elseif type(o) == "boolean" then
                return tostring(o)
            else -- assume it is a string
                return IntegratedbasicSerialize(o)
            end
        end
    
        local t_str = {}
        saved = saved or {}       -- initial value
        if ((type(value) == 'string') or (type(value) == 'number') or (type(value) == 'table') or (type(value) == 'boolean')) then
            table.insert(t_str, name .. " = ")
            if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
                table.insert(t_str, basicSerialize(value) ..  "\n")
            else
    
                if saved[value] then    -- value already saved?
                    table.insert(t_str, saved[value] .. "\n")
                else
                    saved[value] = name   -- save name for next time
                    table.insert(t_str, "{}\n")
                    for k,v in pairs(value) do      -- save its fields
                        local fieldname = string.format("%s[%s]", name, basicSerialize(k))
                        table.insert(t_str, IntegratedserializeWithCycles(fieldname, v, saved))
                    end
                end
            end
            return table.concat(t_str)
        else
            return ""
        end
    end

	function tableShow(tbl, loc, indent, tableshow_tbls)
		tableshow_tbls = tableshow_tbls or {} --create table of tables
		loc = loc or ""
		indent = indent or ""
		if type(tbl) == 'table' then --function only works for tables!
			tableshow_tbls[tbl] = loc
			
			local tbl_str = {}

			tbl_str[#tbl_str + 1] = indent .. '{\n'
			
			for ind,val in pairs(tbl) do -- serialize its fields
				if type(ind) == "number" then
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = tostring(ind)
					tbl_str[#tbl_str + 1] = '] = '
				else
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(ind)
					tbl_str[#tbl_str + 1] = '] = '
				end
						
				if ((type(val) == 'number') or (type(val) == 'boolean')) then
					tbl_str[#tbl_str + 1] = tostring(val)
					tbl_str[#tbl_str + 1] = ',\n'		
				elseif type(val) == 'string' then
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(val)
					tbl_str[#tbl_str + 1] = ',\n'
				elseif type(val) == 'nil' then -- won't ever happen, right?
					tbl_str[#tbl_str + 1] = 'nil,\n'
				elseif type(val) == 'table' then
					if tableshow_tbls[val] then
						tbl_str[#tbl_str + 1] = tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ',\n'
					else
						tableshow_tbls[val] = loc ..  '[' .. IntegratedbasicSerialize(ind) .. ']'
						tbl_str[#tbl_str + 1] = tostring(val) .. ' '
						tbl_str[#tbl_str + 1] = tableShow(val,  loc .. '[' .. IntegratedbasicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
						tbl_str[#tbl_str + 1] = ',\n'  
					end
				elseif type(val) == 'function' then
					if debug and debug.getinfo then
						local fcnname = tostring(val)
						local info = debug.getinfo(val, "S")
						if info.what == "C" then
							tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', C function') .. ',\n'
						else 
							if (string.sub(info.source, 1, 2) == [[./]]) then
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')' .. info.source) ..',\n'
							else
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')') ..',\n'
							end
						end
						
					else
						tbl_str[#tbl_str + 1] = 'a function,\n'	
					end
				else
					tbl_str[#tbl_str + 1] = 'unable to serialize value type ' .. IntegratedbasicSerialize(type(val)) .. ' at index ' .. tostring(ind)
				end
			end
			
			tbl_str[#tbl_str + 1] = indent .. '}'
			return table.concat(tbl_str)
		end
	end

	function dumpTableAIEN(fname, tabledata, varInt)
		
        if AIEN_lfs and AIEN_io then
            local fdir = AIEN_lfs.writedir() .. [[Logs\]] .. fname
            local f = AIEN_io.open(fdir, 'w')
            local str = nil
            if varInt then
                if varInt == "basic" then
                    str = IntegratedbasicSerialize(tabledata)
                elseif varInt == "cycles" then
                    str = IntegratedserializeWithCycles(fname, tabledata)
                elseif varInt == "int" then
                    str = Integratedserialize(fname, tabledata)
                else
                    str = IntegratedserializeWithCycles(fname, tabledata)
                end
            else
                str = IntegratedserializeWithCycles(fname, tabledata)
            end
            
            if f then
                f:write(str)
                f:close()
            end
		end
	end		

	env.info(("AIEN desanitized additional function loaded"))
end

local function round(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

local function getReactionTime(avg_skill)
    if avg_skill then -- 
        local multiplier = 10/(avg_skill/10)/4
        local min = math.floor(rndMinRT_xper*multiplier)
        local max = math.floor(rndMacRT_xper*multiplier)
        return aie_random(min, max)
    else
        return aie_random(3, 15)
    end
end

local function groupAllowedForAI(group)
    if group and group:isExist() and group:getUnits() and #group:getUnits() > 0 then
        if type(AIEN.config.AIEN_xcl_tag) == 'string' then
            if contains(group:getName(), AIEN.config.AIEN_xcl_tag) then
                return false
            end
        elseif type(AIEN.config.AIEN_xcl_tag) == 'table' then
            for _, tag in ipairs(AIEN.config.AIEN_xcl_tag) do
                if contains(group:getName(), tag) then
                    return false
                end
            end
        else
            env.info("AIEN groupAllowedForAI, AIEN_xcl_tag is not a string or table")
            return true
        end
        return true
    end
    
end

--###### GROUP AI QUERY FUNCTIONS ##################################################################

-- Below functions has been created to query ground groups for informations about them, most of them used in the key getSA functions that
-- try to built the "situational awareness" of a group. When done, each time the FSM cycle goes to that group,  it register bunch of info 
-- so that these would be fastly accessibile during reactions or decision making.


--## CAPABILITY CHECKS -- these exist to identify some key characteristics of the group.
-- revTODO the code below is not used; an error? -> Chromium: check this out -> nope will be used
local function group_hasAttribute(group, attribute) -- group tbl, attribute string (reference on DCS attributes) 
    if group then		
        local units = group:getUnits()
		if units and #units > 0 then
			for _, uData in pairs(units) do
				if uData:hasAttribute(attribute) then
					return true
				end
			end
			return false
		else
		    if AIEN.config.AIEN_debugProcessDetail == true then
				env.info(("AIEN group_hasAttribute, no units retrievable"))
			end	
			return false
		end
	else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN group_hasAttribute, missing variable"))
        end	
		return false		
    end
end

-- revTODO the code below is not used; an error? -> Chromium: check this out -> nope will be used
local function group_hasSensors(group, sensor) -- group tbl, attribute string (reference on DCS attributes) 
    if group then		
        local units = group:getUnits()
		if units and #units > 0 then
		
			--[[
			Unit.SensorType = {
			  OPTIC     = 0,
			  RADAR     = 1,
			  IRST      = 2,
			  RWR       = 3
			}
			
			Unit.OpticType = {
			  TV     = 0, --TV-sensor
			  LLTV   = 1, --Low-level TV-sensor
			  IR     = 2  --Infra-Red optic sensor
			}		

			Unit.RadarType = {
			  AS    = 0, --air search radar
			  SS    = 1 --surface/land search radar
			}		
			--]]--			
		
			local optic, ir, radar, irst
			for _, uData in pairs(units) do
				if uData:hasSensors(0) then
					optic = true
				end
				if uData:hasSensors(0, 2) then
					ir = true
				end
				if uData:hasSensors(1) then
					radar = true
				end
				if uData:hasSensors(2) then
					irst =  true
				end
			end
			
			return optic, ir, radar, irst
		else
		    if AIEN.config.AIEN_debugProcessDetail == true then
				env.info((tostring(ModuleName) .. ", hasSensors no units retrievable"))
			end	
			return false
		end
	else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", hasSensors missing variable"))
        end	
		return false		
    end
end


--## INFORMATIVE CHECKS -- these are basic informative "get" functions
local function groupStatus(group)
    if group and group:isExist() == true then
        local units = group:getUnits()
		local curLife 	= 0
		local initLife 	= 0
		if units and #units > 0 then
			for _, uData in pairs(units) do
				if uData:isExist() then
					curLife = curLife + uData:getLife()
					initLife = initLife + uData:getLife0()
				end
			end
		end
	
        if curLife == initLife then
            return false, 1, curLife
        else
			local ratio = math.floor(curLife/initLife*10)/10
            return true, ratio, curLife
        end
    end
end

local function groupLowAmmo(group)
    if group and group:isExist() == true then
        local tblUnits = group:getUnits()
        local groupSize = group:getSize()
        local groupOutAmmo = 0
        
        if tblUnits and groupSize then
            if table.getn(tblUnits) > 0 then
                for uId, uData in pairs(tblUnits) do
                    local uAmmo = uData:getAmmo()
                    if uAmmo then
                        for aId, aData in pairs(uAmmo) do
                            if aData.count == 0 then
                                groupOutAmmo = groupOutAmmo + 1
                            end
                        end
                    else    
                        groupOutAmmo = groupOutAmmo + 1
                    end
                end
            else
                env.info(("AIEN.groupLowAmmo, tblUnits is 0"))
                return false				
            end
        else
            env.info(("AIEN.groupLowAmmo, missing tblUnits or groupSize"))
            return false		
        end

        local fraction = groupOutAmmo/tonumber(groupSize)
        if fraction then
            if fraction > AIEN.config.outAmmoLowLevel then
                return true
            else
                return false
            end
        else
            env.info(("AIEN.groupLowAmmo, error calculating fraction"))
            return false		
        end
    end
end

local function groupHasLosses(group)
    if group and group:isExist() == true then
        local curSize = group:getSize()
        local iniSize = group:getInitialSize()
        if iniSize == curSize then
            return false, 1
        else
			local ratio = math.floor(curSize/iniSize*10)/10
            return true, ratio
        end
    end
end

local function groupHasTargets(group, report)
	if group and group:isExist() == true then
		local tblUnits = Group.getUnits(group)

		if table.getn(tblUnits) > 0 then
			local tbltargets = {}
			for _, uData in pairs(tblUnits) do
				local uController = uData:getController()
				local utblTargets = uController:getDetectedTargets()
				if utblTargets then
					if table.getn(utblTargets) > 0 then
						if report and report == true then
							return true
						else
							for _, utData in pairs(utblTargets) do
                                if utData.object and utData.object:isExist() == true then
								    tbltargets[utData.object.id_] = utData
                                end
							end
						end
					end
				end
			end
			
			if tbltargets and tbltargets ~= {} then
				return true, tbltargets
			end
			
			return false
			
		else
			env.info(("AIEN.groupHasTargets: tblUnits has 0 units"))
			return false			
		end
	else
		env.info(("AIEN.groupHasTargets: group is nil"))
		return false	
	end	
end

local function getGroupClass(group) 

	if group and group:isExist() == true then     
		local units = group:getUnits()
		local coa = group:getCoalition()
		local cls = "none"

		if units and coa then
            local clsCount = {}

			for uId, unit in pairs(units) do -- first unit define group class
				if unit:hasAttribute("Ground Units") then
					if unit:hasAttribute("Tanks") then
						if clsCount["MBT"] then
                            clsCount["MBT"] = clsCount["MBT"] + 1
                        else
                            clsCount["MBT"] = 1
                        end
                        if uId == 1 then
                            cls = "MBT"
                        end
                    elseif unit:hasAttribute("ATGM") then
						if clsCount["ATGM"] then
                            clsCount["ATGM"] = clsCount["ATGM"] + 1
                        else
                            clsCount["ATGM"] = 1
                        end
                        if uId == 1 then
                            cls = "ATGM"
                        end                        						
					elseif unit:hasAttribute("Indirect fire") and not unit:hasAttribute("SS_missile") then
						if unit:hasAttribute("MLRS") then
                            if clsCount["MLRS"] then
                                clsCount["MLRS"] = clsCount["MLRS"] + 1
                            else
                                clsCount["MLRS"] = 1
                            end
                            if uId == 1 then
                                cls = "MLRS"
                            end   
                        elseif unit:hasAttribute("Artillery") then
                            if clsCount["ARTY"] then
                                clsCount["ARTY"] = clsCount["ARTY"] + 1
                            else
                                clsCount["ARTY"] = 1
                            end
                            if uId == 1 then
                                cls = "ARTY"
                            end   
                        end						
					elseif unit:hasAttribute("SS_missile") then
                        if clsCount["MISSILE"] then
                            clsCount["MISSILE"] = clsCount["MISSILE"] + 1
                        else
                            clsCount["MISSILE"] = 1
                        end
                        if uId == 1 then
                            cls = "MISSILE"
                        end    
					elseif unit:hasAttribute("MANPADS") then
                        if clsCount["MANPADS"] then
                            clsCount["MANPADS"] = clsCount["MANPADS"] + 1
                        else
                            clsCount["MANPADS"] = 1
                        end
                        if uId == 1 then
                            cls = "MANPADS"
                        end                          
					elseif unit:hasAttribute("Air Defence vehicles") then
                        if clsCount["SHORAD"] then
                            clsCount["SHORAD"] = clsCount["SHORAD"] + 1
                        else
                            clsCount["SHORAD"] = 1
                        end
                        if uId == 1 then
                            cls = "SHORAD"
                        end  						
                    elseif unit:hasAttribute("AAA") then    
                        if clsCount["AAA"] then
                            clsCount["AAA"] = clsCount["AAA"] + 1
                        else
                            clsCount["AAA"] = 1
                        end
                        if uId == 1 then
                            cls = "AAA"
                        end                         
                    elseif unit:hasAttribute("SAM elements") then    
                        if clsCount["SAM"] then
                            clsCount["SAM"] = clsCount["SAM"] + 1
                        else
                            clsCount["SAM"] = 1
                        end
                        if uId == 1 then
                            cls = "SAM"
                        end   
                    elseif unit:hasAttribute("Armored vehicles") then
						if unit:hasAttribute("IFV") then
                            if clsCount["IFV"] then
                                clsCount["IFV"] = clsCount["IFV"] + 1
                            else
                                clsCount["IFV"] = 1
                            end
                            if uId == 1 then
                                cls = "IFV"
                            end   
                        elseif unit:hasAttribute("APC") then
                            if clsCount["APC"] then
                                clsCount["APC"] = clsCount["APC"] + 1
                            else
                                clsCount["APC"] = 1
                            end
                            if uId == 1 then
                                cls = "APC"
                            end   
                        end
					elseif unit:hasAttribute("Armed vehicles") then
                        if clsCount["RECCE"] then
                            clsCount["RECCE"] = clsCount["RECCE"] + 1
                        else
                            clsCount["RECCE"] = 1
                        end
                        if uId == 1 then
                            cls = "RECCE"
                        end   						
					elseif unit:hasAttribute("Unarmed vehicles") and unit:hasAttribute("Trucks") then
                        if clsCount["LOGI"] then
                            clsCount["LOGI"] = clsCount["LOGI"] + 1
                        else
                            clsCount["LOGI"] = 1
                        end
                        if uId == 1 then
                            cls = "LOGI"
                        end                            
                    elseif unit:hasAttribute("Infantry") then
                        if clsCount["INF"] then
                            clsCount["INF"] = clsCount["INF"] + 1
                        else
                            clsCount["INF"] = 1
                        end
                        if uId == 1 then
                            cls = "INF"
                        end 
                    else
                        if clsCount["UNKN"] then
                            clsCount["UNKN"] = clsCount["UNKN"] + 1
                        else
                            clsCount["UNKN"] = 1
                        end
                        if uId == 1 then
                            cls = "UNKN"
                        end                     
					end
                elseif unit:hasAttribute("Air") then
                    cls = "ARBN"
                elseif unit:hasAttribute("Ships") then
                    cls = "SHIP"
				end
			end

            local mClass = nil
            local mVal = 2
            for class, num in pairs(clsCount) do
                if num > mVal then
                    mClass = class
                    mVal = num
                end
            end
            if mClass then
                cls = mClass
            end
            
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", getGroupClass, group " .. tostring(group:getName()) .. " class: " .. tostring(cls)))
            end
			return cls

		else
			env.info((tostring(ModuleName) .. ", getGroupClass, missing units"))
			return false
		end
	else
		env.info((tostring(ModuleName) .. ", getGroupClass, missing group"))
		return false
	end
end

local function getUnitClass(unit) 

	if unit and unit:isExist() == true then     
		local coa = unit:getCoalition()
		local cls = "none"

		if coa then
            if unit:hasAttribute("Air") then
                cls = "ARBN"
            elseif unit:hasAttribute("Ships") then
                cls = "SHIP"
            elseif unit:hasAttribute("Ground Units") then
                if unit:hasAttribute("Tanks") then
                    cls = "MBT"
                elseif unit:hasAttribute("Indirect fire") and not unit:hasAttribute("SS_missile") then
                    if unit:hasAttribute("MLRS") then
                        cls = "MLRS"
                    elseif unit:hasAttribute("Artillery") then
                        cls = "ARTY"
                    end						
                elseif unit:hasAttribute("SS_missile") then
                    cls = "MISSILE"
                elseif unit:hasAttribute("MANPADS") then
                    cls = "MANPADS"                         
                elseif unit:hasAttribute("Air Defence vehicles") then
                    cls = "SHORAD"
                elseif unit:hasAttribute("AAA") then    
                    cls = "AAA"                        
                elseif unit:hasAttribute("SAM elements") then    
                    cls = "SAM" 
                elseif unit:hasAttribute("ATGM") then
                    cls = "ATGM"                       
                elseif unit:hasAttribute("Armored vehicles") then
                    if unit:hasAttribute("IFV") then
                        cls = "IFV" 
                    elseif unit:hasAttribute("APC") then
                        cls = "APC" 
                    end                    
                elseif unit:hasAttribute("Armed vehicles") then
                    cls = "RECCE"                    
                elseif unit:hasAttribute("Unarmed vehicles") and unit:hasAttribute("Trucks") then
                    cls = "LOGI"                    
                elseif unit:hasAttribute("Infantry") then
                    cls = "INF"
                else
                    cls = "UNKN"
                end
            end
            
			return cls

		else
			env.info((tostring(ModuleName) .. ", getUnitClass, missing coa"))
			return false
		end
	else
		env.info((tostring(ModuleName) .. ", getUnitClass, missing unit"))
		return false
	end
end

local function getGroupSkillNum(g) -- important: this try to create an "average skill scoring number" that will be used a lot elsewhere, i.e. for defining reaction time or even the available reactions. AIEN does not handle well the "Random" skill value (cause DCS skill is not available in real time): for best purpose, you should define the skill value of your ground units in the ME.
    local id = g:getID()
    --env.info((tostring(ModuleName) .. ", getGroupSkillNum: skLevel " .. tostring(g:getName()) ))
	for _,coalition in pairs(env.mission["coalition"]) do
		for _,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					if attrID == "vehicle" then
						for _,group in pairs(attr["group"]) do
							if (group) then	
                                if group.groupId == id then
                                    --env.info((tostring(ModuleName) .. ", getGroupSkillNum: skLevel " .. tostring(g:getName()).. " group found" ))
                                    local skLevel = 0
                                    local unitsCount = 0
                                
                                    for _, unit in pairs(group["units"]) do
                                        local skTbl = skills[unit.skill]
                                        if skTbl then
                                            local val = skTbl.skillVal
                                            if unit.skill == "Random" then
                                                val = aie_random(4,12)
                                            end
                                            skLevel = skLevel + val
                                            unitsCount = unitsCount + 1
                                            --env.info((tostring(ModuleName) .. ", getGroupSkillNum: skLevel " .. tostring(skLevel) .. ", unit num " .. tostring(unitsCount) ))
                                        end
                                    end

                                    if skLevel > 0 then
                                        local k =  math.floor((skLevel/unitsCount)*10)/10
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info((tostring(ModuleName) .. ", getGroupSkillNum: skLevel " .. tostring(k)))
                                        end
                                        return k
                                    else
                                        return 3
                                    end
                                end
							end
						end	
					end
				end
			end
		end
	end	
    --env.info((tostring(ModuleName) .. ", getGroupSkillNum: sklevel not retournable, going random"))
    return aie_random(2,5)
end

local function getRanges(group)
	if group and group:isExist() == true then
		local units = group:getUnits()
        local maxDec = 0
        local maxThr = 0
        local minThr = 0
        for _, uData in pairs(units) do
            local t = uData:getTypeName()

            if AIEN.config.AIEN_debugProcessDetail then
			    env.info((tostring(ModuleName) .. ", getRanges checking type : " .. tostring(t) ))
		    end

            if t then
                local tData = tblThreatsRange[t]
                if tData then
                    if tData.detection and tData.detection > maxDec then
                        maxDec = tData.detection
                    end
                    if tData.threat and tData.threat > maxThr then
                        maxThr = tData.threat
                    end
                    if tData.threatmin and tData.threatmin > minThr then
                        minThr = tData.threatmin
                    end                    
                end
            end
        end

        if maxDec == 0 then
            maxDec = nil
        end
        if maxThr == 0 then
            maxThr = nil
        end
        if minThr == 0 then
            minThr = nil
        end

		if AIEN.config.AIEN_debugProcessDetail then
			env.info((tostring(ModuleName) .. ", getRanges returning maxDec: " .. tostring(maxDec) .. ", maxThr: " .. tostring(maxThr) .. ", minThr: " .. tostring(minThr)))
		end

        return maxDec, maxThr, minThr
		
	else
		if AIEN.config.AIEN_debugProcessDetail then
			env.info((tostring(ModuleName) .. ", getRanges failed, group variable is nil"))
		end
		
	end
end

local function getLeadPos(group)

	if group and group:isExist() == true then
		local units = group:getUnits()

		local leader = units[1]
		if leader then
			if not Unit.isExist(leader) then	-- SHOULD be good, but if there is a bug, this code future-proofs it then.
				local lowestInd = math.huge
				for ind, unit in pairs(units) do
					if Unit.isExist(unit) and ind < lowestInd then
						lowestInd = ind
						return unit:getPosition().p
					end
				end
			end
		end
		if leader and Unit.isExist(leader) then	-- maybe a little too paranoid now...
			return leader:getPosition().p
		end
	else
		if AIEN.config.AIEN_debugProcessDetail then
			env.info((tostring(ModuleName) .. ", getLeadPos failed, group variable is nil"))
		end
		
	end
end

local function getTroops(group)
	if group and group:isExist() then
		if group:getUnits() and #group:getUnits() > 0 then
			local troopsTbl = {}
			for _, uData in pairs(group:getUnits()) do              
				local mount = mountedDb[tostring(uData:getID())]
				if mount and uData then
					troopsTbl[uData:getID()] = {u = uData, t = mount}
				end
			end
			
			if troopsTbl and next(troopsTbl) ~= nil then
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info(("AIEN.getTroops, returning troopstbl for: " .. tostring(group:getName()) ))
                end	
				return troopsTbl
			end
		end
	end
	return nil
end

local function getDangerClose(vec3, coa, range)
    if vec3 and type(vec3) == "table" and coa then
        if vec3.x and vec3.y and vec3.z then
            if not range or type(range) ~= "number" then
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info((tostring(ModuleName) .. ", getDangerClose: range missing reverted to 500 m "))
                end
                range = 500
            end

            -- check targets   
            local firePoint = vec3
            local friendly = nil
            local _volume = {
                id = world.VolumeType.SPHERE,
                params = {
                    point = firePoint,
                    radius = range,
                },
            }

            local _search = function(_obj)
                pcall(function()
                    if _obj ~= nil and _obj:isExist() and Object.getCategory(_obj) == 1 and _obj:getCoalition() == coa then
                        friendly = true
                        if AIEN.config.AIEN_debugProcessDetail == true then
                            env.info((tostring(ModuleName) .. ", getDangerClose: found friendly unit"))
                        end
                        return -- is this ok?
                    end
                end)
            end
            world.searchObjects(Object.Category.UNIT, _volume, _search)

            if friendly == true then
                return true
            end
            return false

        end
    end
end

local function groupInZone(group)
    local point = getLeadPos(group)
    local zone = nil
    
    if point then
    
        if env.mission and env.mission.triggers and env.mission.triggers.zones and #env.mission.triggers.zones > 0 then
            for _, zData in pairs(env.mission.triggers.zones) do
                if zData.name == AIEN.config.AIEN_zoneFilter then
                    zone = zData
                    zone.center = {x = zone.x, y = land.getHeight({x = zone.x, y = zone.y}), z = zone.y}
                end
            end
        end

        if not zone then
            return true
        else
            if zone.verticies then
                if pointInPolygon(point, zone.verticies) == true then
                    return true
                else
                    return false
                end
            elseif zone.radius then
                if getDist(point, zone.center) < zone.radius then
                    return true
                else
                    return false
                end
            end

        end
    end
end

local function getDensityValueAtPoint(vec3, coa, range) -- coa is optional, range is optional
    -- return "density" value for units strenght at a specific point or each coalition or the specified one.
    -- No intel required, mimic the fact that you should know that the enemies is there even if you don't have
    -- detailed informations about it. Also used for initiative to command decision making.

    -- check coa and accept both number and string
    local c = nil
    if coa and type(coa) ~= "number" then
        c = coa
    elseif coa and type(coa) == "string" then
        if string.lower(coa) == "blue" then
            c = 2
        elseif string.lower(coa) == "red" then
            c = 1
        elseif string.lower(coa) == "neutral" then
            c = 0
        end
    end

    -- check range
    local r = range or AIEN.config.densityRange

    -- calculate density
    local d_neu, d_red, d_blue, d_tot = 0, 0, 0, 0
    local p = vec3Check(vec3)
    if p then
        local _volume = {
            id = world.VolumeType.SPHERE,
            params = {
                point = p,
                radius = r,
            },
        }

        local _search = function(_obj)
            pcall(function()
                if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() then

                    if c then
                        if _obj:getCoalition() ~= c then
                            return -- skip this object
                        end
                    end

                    if _obj.getLife and _obj.getPoint then
                        local l = _obj:getLife()
                        local pz = _obj:getPoint()
                        if l and l > 0 then
                            local d = getDist(p, pz)
                            local v = getCurveval(d, l, r, "sqr")

                            d_tot = d_tot + v
                            if not c then
                                if _obj:getCoalition() == 1 then
                                    d_red = d_red + v
                                elseif _obj:getCoalition() == 2 then
                                    d_blue = d_blue + v
                                elseif _obj:getCoalition() == 0 then
                                    d_neu = d_neu + v
                                end
                            end
                        else
                            return -- skip this object, no life value
                        end
                    else
                        return -- skip this object, no life value
                    end
                end
            end)
        end

        world.searchObjects(Object.Category.UNIT, _volume, _search)

        if c then
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", getDensityValueAtPoint: found " .. tostring(d_tot) .. " d_tot"))
            end
            return d_tot
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", getDensityValueAtPoint: found " .. tostring(d_red) .. " red, " .. tostring(d_blue) .. " blue, " .. tostring(d_neu) .. " neutral, " .. tostring(d_tot) .. " d_tot"))
            end

            local result = {}
            result[0] = d_neu
            result[1] = d_red
            result[2] = d_blue     
            result["tot"] = d_tot   
            return result

        end
    else
        env.info((tostring(ModuleName) .. ", getDensityValueAtPoint: vec3 is nil"))
    end    

end


--## AWARENESS CONSTRUCTION FOR FSM USE -- the core of the reaction decision making behaviour: this functions use the upper ones to try to built a virtual situational awareness, and also collect for faster access some key informations.

local function getSA(group) -- built a situational awareness check and also populate intelDb
    
	if group and group:isExist() == true then
        local dbEntry = groundgroupsDb[group:getID()] or droneunitDb[group:getID()]
        local dbGround = groundgroupsDb[group:getID()]

        if dbEntry then

            local sa = {}

            -- derivable functions
            sa.enInContact, sa.targets 	= groupHasTargets(group)
            sa.loss 		            = groupHasLosses(group)
            sa.dmg, sa.life, sa.str     = groupStatus(group) -- str must be added
            sa.low_ammo 	            = groupLowAmmo(group)
            sa.pos			            = getLeadPos(group)
            sa.coa                      = group:getCoalition()
            sa.det                      = dbEntry["detection"]
            sa.rng                      = dbEntry["threat"]
            sa.cls                      = dbEntry["class"]
            sa.nearAlly                 = nil -- table {n = amount, p = nearest position, s = strength as life count}
            sa.nearEnemy                = nil -- table {n = amount, p = nearest position, s = strength as life count}
            sa.moving                   = getGroupSpeed(group) -- will be set to true if the group is moving        

            if sa.moving and sa.moving > 0 and dbGround then
                movingGroups = movingGroups + 1              
            end

            if sa.pos and sa.coa then

                -- fix potential det and range issue
                if not sa.rng then
                    if sa.cls == "ARTY" then
                        sa.rng = 15000
                    elseif sa.cls == "MLRS" then
                        sa.rng = 30000
                    elseif sa.cls == "ATGM" then
                        sa.rng = 4000
                    elseif sa.cls == "UAV" then
                        sa.rng = 8000                
                    else
                        sa.rng = 2000
                    end
                end
                if not sa.det then
                    if sa.cls == "ARTY" then
                        sa.det = 2000
                    elseif sa.cls == "MLRS" then
                        sa.det = 2000
                    elseif sa.cls == "ATGM" then
                        sa.det = 4000
                    elseif sa.cls == "UAV" then
                        sa.det = 40000                
                    else
                        sa.det = 2000
                    end
                end 
            
                -- nearby allies (within proxyUnitsDistance)
                local an = 0
                local as = 0
                local near_a = nil
                local _volume = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = sa.pos,
                        radius = AIEN.config.proxyUnitsDistance,
                    },
                }
                local _search = function(_obj)
                    pcall(function()
                        if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() then
                            local o_coa = _obj:getCoalition()
                            local o_pos = _obj:getPosition().p
                            local o_str = _obj:getLife()
                            if o_coa and o_pos and o_str then
                                if o_coa ~= 0 then -- skip neutral
                                    if o_coa == sa.coa then -- ally
                                        local md = AIEN.config.proxyUnitsDistance
                                        local d = getDist(sa.pos, o_pos)
                                        an = an + 1
                                        as = as + o_str
                                        if d < md then
                                            md = d
                                            near_a = o_pos
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                world.searchObjects(Object.Category.UNIT, _volume, _search)	
                if an and near_a and as then
                    sa.nearAlly = {n = an, p = near_a, s = as}
                end

                -- update intelDb
                if sa.targets and sa.targets ~= {} then
                    for _, tgtData in pairs(sa.targets) do
                        local tgt = tgtData.object

                        local check = pcallGetCategory(tgt)

                        if check == 1 then
                            if tgt and tgt:isExist() then
                                local t_id = tgt:getID()
                                local t_pos = tgt:getPosition().p
                                local t_coa = tgt:getCoalition()
                                local t_life = tgt:getLife()
                                local t = math.floor(timer.getTime())
                                local s = vecmag(tgt:getVelocity())

                                local knownType = tgt.type
                                local t_type = nil
                                if knownType == true then
                                    t_type = tgt:getTypeName()
                                else
                                    t_type = "unknown"
                                end

                                local ob_cat = pcallGetCategory(tgt)
                                local t_ucat = nil
                                local t_scat = nil
                                if ob_cat and ob_cat == 1 then
                                    t_ucat = tgt:getCategory()
                                elseif ob_cat and ob_cat == 3 then
                                    t_scat = tgt:getCategory()
                                end

                                local ob_desc = tgt:getDesc()
                                local t_attr = nil
                                if ob_desc and ob_desc.attributes then
                                    t_attr = ob_desc.attributes
                                end

                                local t_cls = getUnitClass(tgt)
                                intelDb[t_id] = {obj = tgt, pos = t_pos, coa = t_coa, life = t_life, record = t, speed = s, type = t_type, ucat = t_ucat, scat = t_scat, attr = t_attr, cls = t_cls, identifier = sa.cls}
                            
                            end
                        end
                    end           
                end        

                -- nearby enemies (use combined intel source DBs) + update intelDb
                local near_e = nil
                local es = 0
                local en = 0
                local dist = nil
                for iId, iData in pairs(intelDb) do
                    if iData.obj:isExist() then
                        if iData.coa ~= sa.coa and iData.coa ~= 0 and (timer.getTime() - iData.record) < AIEN.config.intelDbTimeout then
                            local d = getDist(sa.pos, iData.pos)
                            if d < AIEN.config.proxyUnitsDistance then
                                en = en + 1
                                es = es + iData.life
                                if d < AIEN.config.proxyUnitsDistance then
                                    near_e = iData.pos
                                    dist = d
                                end
                            end                
                        end
                    else
                        intelDb[iId] = nil -- removing the non existing object anymore. Do this any available cycle of intelDb
                    end
                end
                if en and near_e and es then
                    sa.nearEnemy = {n = en, p = near_e, s = es, d = dist}
                end

                return sa
            else
                return false
            end
        else
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", group not in db"))
            end
            return false
        end
	else
		if AIEN.config.AIEN_debugProcessDetail then
			env.info((tostring(ModuleName) .. ", group doesn't exist"))
		end	
		return false
	end
end


--###### GROUP AI COMMAND FUNCTIONS ################################################################

-- Below functions has been created to give command to ground groups, from the most basic to the more advanced. 
-- These functions are the core of the things that will be done by your units.


--## BASIC STATE ACTION -- these are basic command for the group.
-- revTODO the code below is not used; an error? -> Chromium: check this out -> nope will be used
local function groupGoQuiet(group)
    if group and group:isExist() == true then	
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 1) -- green -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.groupGoQuiet status quiet"))
        end			
    end
end

-- revTODO the code below is not used; an error? -> Chromium: check this out -> nope will be used
local function groupGoActive(group)
    if group and group:isExist() == true then
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.groupGoActive status active and return fire"))
        end				
    end
end

local function groupGoShoot(group)
    if group and group:isExist() == true then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 2) -- open fire -- Ground or GROUND?
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.groupGoShoot status fire at will"))
        end			
    end
end

local function groupAllowDisperse(group)
    if group and group:isExist() == true then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, AIEN.config.disperseActionTime) -- Ground or GROUND?
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.groupAllowDisperse will allow dispersal"))
            end		
        else
            env.info(("AIEN.groupAllowDisperse, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.info(("AIEN.groupAllowDisperse, missing group"))        
    end
end

local function groupPreventDisperse(group)
    if group and group:isExist() == true then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, false) -- Ground or GROUND?
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.groupPreventDisperse will prevent dispersal"))
            end		
        else
            env.info(("AIEN.groupPreventDisperse, missing controller for: " ..tostring(group:getName())))
        end
    else
        env.info(("AIEN.groupPreventDisperse, missing group"))    
    end
end

local function groupSuppress(group) -- quite important: provide random "suppression" effect by enabling the ROE "hold fire" for a limited amount of time that will depend from group skill
    if group and group:isExist() == true then
        local c = group:getController()
        if c then
			local s = getGroupSkillNum(group)
			local st = getReactionTime(s)*2
			
            c:setOption(AI.Option.Ground.id.ROE, 4)
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.groupSuppress group has been suppressed " .. tostring(group:getName()) ))
            end	
            local back = function()
                c:setOption(AI.Option.Ground.id.ROE, 2)
            end
            if back then
                timer.scheduleFunction(back, {}, timer.getTime() + st)
            end
        end
    end
end 


--## MISSION ACTION -- these are more advanced command for groups
local function groupfireAtPoint(var)
    local group = var[1] -- groupTableCheck(var[1])
    if AIEN.config.AIEN_debugProcessDetail == true then
        env.info((tostring(ModuleName) .. ", groupfireAtPoint group check"))
    end	
    if group and group:isExist() then
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", groupfireAtPoint group name: " .. tostring(group:getName())))
        end	
        local gController   = group:getController()
        local vec3          = vec3Check(var[2])
        local qty           = var[3]
        local desc          = var[4]
        local radi          = var[5]
        local skmsg         = var[6]

        if gController and vec3 then
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", groupfireAtPoint controller and vec3 identified"))
            end	
            local expd = true
            
            if not var[3] then
                expd = false
                qty = nil
            end

            if not radi then
                radi = 50
            end

            local _tgtVec2 =  { x = vec3.x  , y = vec3.z} 
            local _task = { 
                id = 'FireAtPoint', 
                params = { 
                point = _tgtVec2,
                radius = 50,
                expendQty = qty,
                expendQtyEnabled = expd,
                alt_type = 1,
                }
            } 

            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", groupfireAtPoint variables set"))
            end	

            gController:pushTask(_task)
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", groupfireAtPoint fire mission planned"))
            end
            
            -- message feedback
            if AIEN.config.message_feed == true and skmsg == false then

                local lat, lon = coord.LOtoLL(vec3)
                local MGRS = coord.LLtoMGRS(coord.LOtoLL(vec3))
                if lat and lon then

                    local LL_string = tostringLL(lat, lon, 0, true)
                    local MGRS_string = tostringMGRS(MGRS ,4)

                    local txt = ""
                    txt = txt .. "C2, " .. tostring(group:getName()) .. ", request fire mission, fire for Effect. coordinates:"
                    txt = txt .. "\n" .. tostring(MGRS_string) .. "\n" .. tostring(LL_string)
                    if desc and type(desc) == "string" then
                        txt = txt .. "\n" .. desc
                    end
                    if expd and qty and type(qty) == "number" then
                        txt = txt .. "\n" .. tostring(qty) .. " rounds"
                    end                    
                    txt = txt .. "\n" .. "Cleared for fire when ready"
                    
                    local vars = {"text", txt, 20, nil, nil, nil, group:getCoalition()}

                    multyTypeMessage(vars)

                end
            end

            -- mark on map for coalition
            if AIEN.config.mark_on_f10_map == true then

                local lat, lon = coord.LOtoLL(vec3)
                local MGRS = coord.LLtoMGRS(coord.LOtoLL(vec3))
                if lat and lon then

                    local LL_string = tostringLL(lat, lon, 0, true)
                    local MGRS_string = tostringMGRS(MGRS ,4)
                    local txt = ""
                    txt = txt .. tostring(group:getName())
                    txt = txt .. "\n" .. "Fire mission, coordinates:"
                    txt = txt .. "\n" .. tostring(MGRS_string) .. "\n" .. tostring(LL_string)

                    markIdStart = markIdStart + 1
                    trigger.action.markToCoalition(markIdStart, txt, vec3, group:getCoalition(), false, false)

                end
            end


        else
            env.info((tostring(ModuleName) .. ", groupfireAtPoint, missing controller or for: " .. tostring(group:getName())))
        end	
    else
        env.info((tostring(ModuleName) .. ", groupfireAtPoint, missing group"))        
    end
end


--## ROUTE AND PATHFINDING

local function checkValidTerrainSurface(vec3)
    if vec3 then
        if type(vec3) == 'table' then -- assuming name
            if vec3.x and vec3.y and vec3.z then
                local l = land.getSurfaceType({x = vec3.x, y = vec3.z})
                if l then
                    if l == 1 or l == 4 or l == 5 then
                        
                        -- check slope
                        local slope = getTerrainSlopeAtPoint(vec3, 20)     
                        if slope and slope < AIEN.config.maxSlope then
                            return true, l
                        else
                            env.info((tostring(ModuleName) .. ", checkValidDestination: terrain slope more than max!"))
                            return false, l
                        end            

                    else
                        return false, l
                    end
                else
                    env.info((tostring(ModuleName) .. ", checkValidDestination: l not identified!"))
                    return false
                end
            else
                env.info((tostring(ModuleName) .. ", checkValidDestination: wrong vector format"))
                return false
            end
        else
            env.info((tostring(ModuleName) .. ", checkValidDestination: wrong variable"))
            return false
        end
    else
        env.info((tostring(ModuleName) .. ", checkValidDestination: missing variable"))
        return false
    end
end

local function getMEroute(group) -- basically a copy of getGroupRoute
    -- refactor to search by groupId and allow groupId and groupName as inputs
	local gpId = nil
    if group and group:isExist() == true then
        gpId = group:getID()
	end
	
	if gpId then
		for coa_name, coa_data in pairs(env.mission.coalition) do
			if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
				if coa_data.country then --there is a country table
					for _, cntry_data in pairs(coa_data.country) do
						for obj_type_name, obj_type_data in pairs(cntry_data) do
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
									for _, group_data in pairs(obj_type_data.group) do
										if group_data and group_data.groupId == gpId	then -- this is the group we are looking for
											if group_data.route and group_data.route.points and #group_data.route.points > 0 then
												local points = {}

												for point_num, point in pairs(group_data.route.points) do
													local routeData = {}
													routeData.name = point.name
													if not point.point then
														routeData.x = point.x
														routeData.y = point.y
													else
														routeData.point = point.point	--it's possible that the ME could move to the point = Vec2 notation.
													end
													routeData.form = point.action
													routeData.speed = point.speed
													routeData.alt = point.alt
													routeData.alt_type = point.alt_type
													routeData.airdromeId = point.airdromeId
													routeData.helipadId = point.helipadId
													routeData.type = point.type
													routeData.action = point.action
													routeData.task = point.task
													points[point_num] = routeData
												end

												return points
											end
											return
										end	--if group_data and group_data.name and group_data.name == 'groupname'
									end --for group_num, group_data in pairs(obj_type_data.group) do
								end --if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then
							end --if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" or obj_type_name == "static" then
						end --for obj_type_name, obj_type_data in pairs(cntry_data) do
					end --for cntry_id, cntry_data in pairs(coa_data.country) do
				end --if coa_data.country then --there is a country table
			end --if coa_name == 'red' or coa_name == 'blue' and type(coa_data) == 'table' then
		end --for coa_name, coa_data in pairs(mission.coalition) do
	else
		return nil
	end
end

local function groupRoadOnly(group)
    if group and group:isExist() == true  then
        local units = group:getUnits()
        for _, uData in pairs(units) do
            if uData:hasAttribute("Trucks") or uData:hasAttribute("Cars") or uData:hasAttribute("Unarmed vehicles") then
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info(("AIEN.groupRoadOnly found at least one road only unit!"))
                end
                return true
            end
        end
    end
    if AIEN.config.AIEN_debugProcessDetail then
        env.info(("AIEN.groupRoadOnly no road only unit found, or no group"))
    end
    
    return false
end

local function goRoute(group, path)
    if group and path and group:isExist() == true then
        local misTask = {
            id = 'Mission',
            params = {
                route = {
                    points = deepCopy(path),
                },
            },
        }

        local groupCon = group:getController()
        if groupCon then
            groupCon:setTask(misTask)
            return true
        end
        return false
    end
end

local function moveToPoint(group, Vec3destination, destRadius, destInnerRadius, reqUseRoad, formation, haltContact, issuedByClient, clientCoa, groupSpeed) -- move the group to a point or, if the point is missing, to a random position at about 2 km. Need to make haltContact to work
    
    if Vec3destination then
        local vt, vv = checkValidTerrainSurface(Vec3destination) 
        if vt == false then
            local newX, newZ = land.getClosestPointOnRoads('roads', Vec3destination.x, Vec3destination.z)
            local newY = land.getHeight({x = newX, y = newZ})
            Vec3destination = {x = newX, y = newY, z = newZ}
            env.info((tostring(ModuleName) .. ", moveToPoint Vec3destination corrected for land, was type " .. tostring(vv)))
        else
            env.info((tostring(ModuleName) .. ", moveToPoint Vec3destination is identified as land, type " .. tostring(vv)))
        end
    else
        env.info((tostring(ModuleName) .. ", moveToPoint Vec3destination is nil, will use random point"))
    end
    
    if group and group:isExist() == true then

        local unit1 = group:getUnit(1)
        if unit1 then
            local curPoint = unit1:getPosition().p
            local point = Vec3destination --required
            local dist = getDist(point,curPoint)
            
            -- start answer
            local msg = ""
            if clientCoa and issuedByClient then
                msg = msg .. tostring(tostring(group:getName()))
            end

            if clientCoa and issuedByClient then
                local latitude, longitude, elev = coord.LOtoLL(point)
                local LL_string = tostringLL(latitude, longitude, 0, true)
                msg = msg .. " move to " .. tostring(LL_string) .. "\n"
            end

            -- checking and define road routing requests
            local useRoads = false
            if issuedByClient == true then
                if not reqUseRoad or reqUseRoad == false then
                    if env.mission.weather.clouds.iprecptns > 0 then
                        useRoads= true
                        if clientCoa then
                            msg = msg .. "unable to move on open ground due to weather, will use road" .. "\n"
                        end                
                    elseif groupRoadOnly(group) == true then
                        useRoads= true
                        if clientCoa then
                            msg = msg .. "unable to move on open ground due to vehicle spec, will use roads" .. "\n"
                        end
                    elseif dist > 30000 then
                        useRoads = true
                        if clientCoa then
                            msg = msg .. "unable to move in open ground due to distance, will use road instead" .. "\n"
                        end
                    else
                        useRoads = false
                        if clientCoa then
                            msg = msg .. "will move on open ground" .. "\n"
                        end
                    end
                else
                    useRoads = true
                    if clientCoa then
                        msg = msg .. "using roads " .. "\n"
                    end
                    -- check if possible and the relative answer
                end
            else
                if not reqUseRoad or reqUseRoad == false then
                    if env.mission.weather.clouds.iprecptns > 0 then
                        useRoads= true            
                    elseif groupRoadOnly(group) == true then
                        useRoads= true
                    elseif dist > 5000 then
                        useRoads = true
                    else
                        useRoads = false
                    end
                else
                    useRoads = true
                end                
            end        

            local rndCoord = nil
            if point == nil then
                point = getRandTerrainPointInCircle(group:getPosition().p, AIEN.config.rndFleeDistance*1.3, AIEN.config.rndFleeDistance*0.9)
                rndCoord = point
            end
        
            if point then	

                local radius = destRadius or 10
                local innerRadius = destInnerRadius or 1		
                
                -- define formation
                local form = formation or 'Offroad'
                if issuedByClient == true and clientCoa and formation then
                    if useRoads == false then
                        msg = msg .. "will deploin in " .. tostring(form) .. " formation " .. "\n"
                    else
                        msg = msg .. "when in open ground, will deploin in " .. tostring(form) .. " formation " .. "\n"
                    end
                end  

                -- define heading
                local heading = math.random()*2*math.pi
                if heading >= 2*math.pi then
                    heading = heading - 2*math.pi
                end

                -- define speed
                local speed = groupSpeed
                if not speed then
                    if useRoads == false then
                        speed = AIEN.config.outRoadSpeed
                    else
                        speed = AIEN.config.inRoadSpeed
                    end
                end

                if issuedByClient == true and clientCoa then
                    msg = msg .. "moving at " .. tostring(math.floor(speed/3.6*10)/10) .. " kmh \n"
                end                

                local path = {}
                if not rndCoord then
                    rndCoord = getRandTerrainPointInCircle(point, radius, innerRadius)
                end
                
                if rndCoord then

                    local offset = {}
                    local posStart = getLeadPos(group)
                    if posStart then
                        offset.x = round(math.sin(heading - (math.pi/2)) * 50 + rndCoord.x, 3)
                        offset.z = round(math.cos(heading + (math.pi/2)) * 50 + rndCoord.y, 3)
                        path[#path + 1] = buildWP(posStart, form, speed)


                        if useRoads == true and ((point.x - posStart.x)^2 + (point.z - posStart.z)^2)^0.5 > radius * 1.3 then
                            path[#path + 1] = buildWP({x = posStart.x + 11, z = posStart.z + 11}, 'off_road', AIEN.config.outRoadSpeed)
                            path[#path + 1] = buildWP(posStart, 'on_road', speed)
                            path[#path + 1] = buildWP(offset, 'on_road', speed)
                        else
                            path[#path + 1] = buildWP({x = posStart.x + 25, z = posStart.z + 25}, form, speed)
                        end

                        path[#path + 1] = buildWP(offset, form, speed)
                        path[#path + 1] = buildWP(rndCoord, form, speed)

                        goRoute(group, path)

                        if issuedByClient == true and clientCoa then
                            trigger.action.outTextForCoalition(clientCoa, msg, 30)
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info(("AIEN.moveToPoint msg " .. tostring(msg)))
                            end                        
                        end                     

                        return
                    end
                else
                    env.info((tostring(ModuleName) .. ", moveToPoint failed, no valid coord available"))
                end
            else
                env.info((tostring(ModuleName) .. ", moveToPoint failed, no valid destination available"))
            end
        else
            env.info((tostring(ModuleName) .. ", moveToPoint failed, unit1 not available"))
        end
    end
end


--###### COUNTER BATTERY FIRE ######################################################################

local function counterBattery(hitPos, tgtPos, coa) -- this function emulates counter battery fire
    -- this function is not about simulating the counter battery fire process, which involves projectiles radar detection,
    -- balistic calculations and then defining a shooter position. Instead, for performance purposes, the process is "hinted" using the following method, and start only if the shooter is an "indirect fire" attributes units
    -- this way:
    -- * first, since we don't want to do calc, we took the shooter current position when the hit event occours, to use it later if allowed, called tgtPos   
    -- * second, same reason, we pre-check if a free arty is available in range for fire on shooter position.
    -- * if arty is ok, and given the hit position, we look for the presence of a suitable radar ("SAM SR", "SAM TR", "EWR" since DCS world doesn't have the right kind of unit) within 50km 
    -- * if it's there, since we don't want to do calc much, we simply apply some random math formula that depends on distance as a probabilty of trajectory calc IRL and, also, the accuracy
    
    -- * if the random pass, the tgt is the passed for arty fire after a random timing that is counterBatteryPlanDelay+-35%.
    if hitPos and tgtPos and coa then
        if type(hitPos) == "table" and type(tgtPos) == "table" then
            if hitPos.x and hitPos.z and tgtPos.x and tgtPos.z then

                local arty = nil
                for _, og in pairs(groundgroupsDb) do
                    if og.coa == coa and og.tasked == false then
                        if og.class == "ARTY" or og.class == "MLRS" then --  or og.class == "MLRS" -- not considering MLRS as they're intended for more area or tactical fire
                            if og.group and og.group:isExist() == true and og.sa and og.sa.pos then
                                local d = getDist(og.sa.pos, tgtPos)
                                if d < og.threat*0.9 then
                                    og.tasked = true
                                    og.taskTime = timer.getTime()
                                    og.firePoint = tgtPos
                                    
                                    if AIEN.config.AIEN_debugProcessDetail == true then
                                        env.info((tostring(ModuleName) .. ", counterBattery artillery potentially available"))
                                    end
                                    arty = og.group
                                    break
                                end
                            end
                        end
                    end
                end

                if arty then

                    -- check for near radar within 50 km, if there, return closer distance
                    local closestRange = AIEN.config.counterBatteryRadarRange
                    local _volume = {
                        id = world.VolumeType.SPHERE,
                        params = {
                            point = hitPos,
                            radius = AIEN.config.counterBatteryRadarRange,
                        },
                    }

                    local _search = function(_obj)
                        pcall(function()
                            if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() and _obj:getCoalition() == coa then
                                if _obj:hasAttribute("SAM SR") or _obj:hasAttribute("SAM TR") or _obj:hasAttribute("EWR") then
                                    local d = getDist(_obj:getPoint(), hitPos)
                                    if d < closestRange then
                                        closestRange = d
                                    end
                                end
                            end
                        end)
                    end
                    world.searchObjects(Object.Category.UNIT, _volume, _search)

                    if closestRange < AIEN.config.counterBatteryRadarRange then
                        local f = math.floor((1-(closestRange/AIEN.config.counterBatteryRadarRange)^2)*100)
                        local r = aie_random(1,100)
                        if f > r then
                            local a = math.floor( ((closestRange/AIEN.config.counterBatteryRadarRange)^1.5)*300)
                            local fpos = getRandTerrainPointInCircle(tgtPos, a, 1)
                            if fpos then
                                local t = aie_random(math.floor(AIEN.config.counterBatteryPlanDelay*0.65), math.floor(AIEN.config.counterBatteryPlanDelay*1.35))
                                
                                if AIEN.config.message_feed == true then

                                    local lat, lon = coord.LOtoLL(hitPos)
                                    local MGRS = coord.LLtoMGRS(coord.LOtoLL(hitPos))
                                    if lat and lon then
                    
                                        local LL_string = tostringLL(lat, lon, 0, true)
                                        local MGRS_string = tostringMGRS(MGRS ,4)
                    
                                        local txt = ""
                                        txt = txt .. "C2, " .. tostring(arty:getName()) .. ", identified enemy artillery fire. coordinates:"
                                        txt = txt .. "\n" .. tostring(MGRS_string) .. "\n" .. tostring(LL_string)                  
                                        txt = txt .. "\n" .. "Trying to evaluate enemy position. Please wait"
                                        
                                        local vars = {"text", txt, 20, nil, nil, nil, coa}
                    
                                        multyTypeMessage(vars)
                    
                                    end
                                end

                                local func = function()
                                    groupfireAtPoint({arty, fpos, 20, "Counter battery fire"})
                                end
                                timer.scheduleFunction(func, nil, timer.getTime() + t)

                            else
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info((tostring(ModuleName) .. ", counterBattery failed fpos calculation"))
                                end
                                return false
                            end

                        else
                            if AIEN.config.AIEN_debugProcessDetail == true then
                                env.info((tostring(ModuleName) .. ", counterBattery f=" .. tostring(f) .. ", r=" .. tostring(r) .. " failed"))
                            end
                            return false
                        end

                    end

                else
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", counterBattery artillery not available"))
                    end
                    return false
                end
            else
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info((tostring(ModuleName) .. ", counterBattery variable x and z missing"))
                end
                return false
            end
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", counterBattery variables wrong format"))
            end
            return false
        end

    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_fireMissionOnShooter return false due to missing variable"))
        end
        return false
    end        


end



--###### DISMOUNT FUNCTIONS ########################################################################

-- This part of the code, basically modified from CTLD ones, handle the automatic troop dismount-remount behaviour.
-- Those functions are maybe the most "delicate" of the code, so think about them at least three times before touching ;)

local function createUnit(_x, _y, _angle, _n, _t)

    local id = aie_random(1,4) -- had to do this cause random is not defined once in game
    local sk = nil
    if id == 1 then
        sk = "Average"
    elseif id == 2 then
        sk = "Good"
    elseif id == 3 then
        sk = "High"
    elseif id == 4 then
        sk = "Excellent"
    end

    local _newUnit = {
        ["y"] = _y,
        ["type"] = _t,
        ["name"] = _n,
        ["heading"] = _angle,
        ["playerCanDrive"] = true,
        ["skill"] = sk,
        ["x"] = _x,
    }

    return _newUnit
end

local function findNearestEnemy(_side, _point, _searchDistance, _reposition)

    local repoOffset
    if not _reposition then
        repoOffset = 3
    else
        repoOffset = AIEN.config.droppedReposition
    end

    local mindistance = _searchDistance
    local enemyPos = nil
    local volS = {
    id = world.VolumeType.SPHERE,
    params = {
        point = _point,
        radius = _searchDistance
        }
    }
    
    local ifFound = function(foundItem, val)
        local itemPos = foundItem:getPosition().p
        local itemCoa = foundItem:getCoalition()
        if itemPos and itemCoa and itemCoa ~= _side and itemCoa ~= 0 then
            local dist = getDist(itemPos, _point)
            if dist < mindistance then
                mindistance = dist
                enemyPos = foundItem:getPosition().p
            end
        end
    end
    world.searchObjects(Object.Category.UNIT, volS, ifFound)    

    if enemyPos ~= nil then
        local _x = enemyPos.x + aie_random(1, 20) - aie_random(1, 20)
        local _z = enemyPos.z + aie_random(1, 20) - aie_random(1, 20)
        local _y = enemyPos.y + aie_random(1, 20) - aie_random(1, 20)
        return { x = _x, y =_y, z = _z}

    else
        local _x = _point.x + aie_random(1, repoOffset) - aie_random(1, repoOffset)
        local _z = _point.z + aie_random(1, repoOffset) - aie_random(1, repoOffset)
        local _y = _point.y + aie_random(1, repoOffset) - aie_random(1, repoOffset)
        return { x = _x, y =_y, z = _z}
    end    

end

local function getEnemyStrInrange(_side, _point, _searchDistance)

    local _enemySide = nil
    if _side == 1 then
        _enemySide = 2
    elseif _side == 2 then
        _enemySide = 1
    end

    local volS = {
    id = world.VolumeType.SPHERE,
    params = {
        point = _point,
        radius = _searchDistance
        }
    }
    
    local _count = 0
    local _search = function(_obj)
        pcall(function()
            if _obj then
                if _obj:getLife() > 0 and _obj:getCoalition() == _enemySide then
                    _count = _count + _obj:getLife()
                end
            end
        end)
        return true
    end
    world.searchObjects(Object.Category.UNIT, volS, _search)     

    return _count

end

local function getAliveGroup(_group)
    if _group and _group:isExist() == true and #_group:getUnits() > 0 then
        return _group
    end
    return nil
end

local function orderInfantryToMoveToPoint(_group, _destination)

    local _start = getLeadPos(_group)
    local _path = {}

    local routing = 'Off Road'
    local volS = {
        id = world.VolumeType.SPHERE,
        params = {
            point = _start,
            radius = AIEN.config.infantrySearchDist,
        }
    }
    local _count = 0
    local _search = function(_obj)
        pcall(function()

            -- filters to avoid objects that are not exactly valuable
            local _d = _obj:getDesc()
            if _d then
                if _d.attributes and _d.attributes.Buildings then -- must be building
                    _count = _count + 1
                end
            end
        end)
        return true
    end
    world.searchObjects(Object.Category.SCENERY, volS, _search)     
    
    if AIEN.config.AIEN_debugProcessDetail == true then
        env.info(("AIEN.orderInfantryToMoveToPoint buildings _count = " .. tostring(_count)))
    end	

    if _count > 5 then
        routing = 'on_road'
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.orderInfantryToMoveToPoint buildings identified, moving on road"))
        end	
    end

    local _dTbl
    if _destination then
        local _x = _destination.x + aie_random(1, 5) - aie_random(1, 5)
        local _z = _destination.z + aie_random(1, 5) - aie_random(1, 5)
        local _y = _destination.y + aie_random(1, 5) - aie_random(1, 5)
        _dTbl = { x = _x, y =_y, z = _z}        
    end


    table.insert(_path, ground_buildWP(_start, routing, AIEN.config.infantrySpeed))
    table.insert(_path, ground_buildWP(_dTbl, routing, AIEN.config.infantrySpeed))
    if routing == 'on_road' then
        table.insert(_path, ground_buildWP(_dTbl, 'Off Road', 5))
    end

    local _mission = {
        id = 'Mission',
        params = {
            route = {
                points =_path
            },
        },
    }

    timer.scheduleFunction(function(_arg)
        local _grp = getAliveGroup(_arg[1])

        if _grp ~= nil then
            local _controller = _grp:getController();
            Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)
            Controller.setOption(_controller, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
            _controller:setTask(_arg[2])
        end
    end
        , {_group, _mission}, timer.getTime() + 2)

end

local function defineTroopsNumber(unit)
    if unit and unit:isExist() then
        local num = 0
        for dId, dNum in pairs(dismountCarriers) do
            if unit:hasAttribute(dId) then
                if num < dNum then
                    num = dNum
                end
            end
        end
        if num and num > 0 then
            return num
        end
    end
    return 0
end

local function deployTroops(unit, exactPos)
	
    local _point = unit:getPoint()
    local _onboard = mountedDb[unit:getID()]
    local _coa = unit:getCoalition()

    local function deploy(team, num)
        if team then
            local isMortar = false
            local _groupName = unit:getName() .. "_dismounted_" .. tostring(num)
            local _group = {
                ["visible"] = false,
                ["hidden"] = false,
                ["units"] = {},
                ["name"] = _groupName,
                ["task"] = {},
            }

            local _pos = _point
            for _i, _soldier in ipairs(team) do
                if contains(_soldier, "mortar") then
                    isMortar = true
                end            

                local _angle = math.pi * 2 * (_i - 1) / #team
                local _xOffset = math.cos(_angle) * 15 + num
                local _yOffset = math.sin(_angle) * 15 + num
                local _name = _groupName .. "_".. tostring(_i)

                _group.units[_i] = createUnit(_pos.x + _xOffset, _pos.z + _yOffset, _angle, _name, _soldier)
            end


            _group.category = Group.Category.GROUND;
            _group.country = unit:getCountry();

            local _spawnedGroup = Group.getByName(dynAdd(_group).name)

            if _spawnedGroup then
                if exactPos then
                    if isMortar == false then
                        orderInfantryToMoveToPoint(_spawnedGroup, exactPos)
                    end
                else
                    local _enemyPos = findNearestEnemy(_coa, _point, AIEN.config.infantrySearchDist)

                    if _enemyPos and isMortar == false then
                        orderInfantryToMoveToPoint(_spawnedGroup, _enemyPos)
                    end

                    mountedDb[unit:getID()] = nil
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info(("AIEN.deployTroops units deployed for unit " .. tostring(unit:getName())))
                    end	
                end
                return _spawnedGroup
            end
        end
    end

    if _onboard then
        for _g, _team in ipairs(_onboard) do
            deploy(_team, _g)
        end

        infcarrierDb[unit:getID()] = defineTroopsNumber(unit)
    end



end

local function extractTroops(unit)

    if unit and unit:isExist() then
        if unit:hasAttribute("IFV") or unit:hasAttribute("APC") or unit:hasAttribute("Trucks") then
            local people = infcarrierDb[unit:getID()]
            if not people then
                infcarrierDb[unit:getID()] = defineTroopsNumber(unit)
            end
            local uCoa = unit:getCoalition()
            if people and people > 0 then

                local foundAnything = true    
                local done = {}

                local function loadTeam()
                    
                    local mindistance = AIEN.config.infantryExtractDist

                    local volS = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = unit:getPoint(),
                        radius = AIEN.config.infantryExtractDist
                        }
                    }

                    local nearestU = nil
                    local ifFound = function(foundItem, val)
                        if foundItem:getCoalition() == uCoa then
                            local fgId = foundItem:getGroup():getID()
                            if not done[fgId] then
                                if foundItem:hasAttribute("Infantry") then
                                    local posu = foundItem:getPoint()
                                    local dist = getDist(posu, unit:getPoint())
                                    if dist < mindistance then
                                        mindistance = dist
                                        nearestU = foundItem
                                    end
                                end
                            end
                        end
                    end
                    world.searchObjects(Object.Category.UNIT, volS, ifFound)

                    local typ = nil
                    local gtbl = nil
                    if nearestU then
                        local foundg = nearestU:getGroup()
                        if foundg then
                            if not done[foundg:getID()] then
                                local units = foundg:getUnits()
                                if units and #units > 0 then
                                    local tot = 0
                                    local inf = 0
                                    for _, u in pairs(units) do
                                        if u:hasAttribute("Infantry") then
                                            inf = inf + 1
                                            if not typ then
                                                typ = {}
                                            end
                                            typ[#typ+1] = u:getTypeName()
                                        end
                                        tot = tot + 1
                                    end

                                    if inf == tot and inf <= people then
                                        people = people - inf
                                        gtbl = foundg
                                    end
                                end    
                            end
                        end    
                    end

                    if typ and gtbl then
                        infcarrierDb[unit:getID()] = people
                        local loadedGroups = mountedDb[unit:getID()] or {}
                        loadedGroups[#loadedGroups+1] = typ
                        mountedDb[unit:getID()] = loadedGroups
                        if AIEN.config.AIEN_debugProcessDetail == true then
                            env.info(("AIEN.groupExtractTroop unit " .. tostring(unit:getName()) ..  ", extracted " .. tostring(gtbl:getName()) .. ", people: " .. tostring(people) ))
                        end	
                        done[gtbl:getID()] = true
                        gtbl:destroy()
                    else
                        if AIEN.config.AIEN_debugProcessDetail == true then
                            env.info(("AIEN.groupExtractTroop extraction found anything" ))
                        end	
                        foundAnything = false
                    end
                end

                while people >= 4 and foundAnything == true do
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info(("AIEN.groupExtractTroop unit " .. tostring(unit:getName()) ..  ", launching loadTeam, people " .. tostring(people) ))
                    end	
                    loadTeam()
                end

                if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
                    dumpTableAIEN("infcarrierDb.lua", infcarrierDb, "int")
                    dumpTableAIEN("mountedDb.lua", mountedDb, "int")
                end

            end
        end
    end

end

local function groupExtractTroop(group)

    if group and group:isExist() == true and #group:getUnits() > 0 then
        local units = group:getUnits()
        for _, uData in pairs(units) do
            if mountedDb[uData:getID()] == nil then
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info(("AIEN.groupExtractTroop units extracting troops " .. tostring(uData:getName())))
                end	
                extractTroops(uData)
            end
        end
    end
    return nil
end

local function groupCarryInfantry(group) -- needed?
    if group and group:isExist() == true and #group:getUnits() > 0 then
        local units = group:getUnits()
        local isCarrying = false
        for _, uData in pairs(units) do
            if mountedDb[uData:getID()] then
                isCarrying = true
                break
            end
        end
        return isCarrying 
    end
end

local function mountTeam(unit)

	local uName = unit:getName()
	local volS = {
		id = world.VolumeType.SPHERE,
		params = {
			point = unit:getPoint(),
			radius = AIEN.config.infantrySearchDist
		}
	}

	local commandIssued = {}
	local groupMoving = 0
	local ifFound = function(foundItem, val)
		if contains(foundItem:getName(), uName) then
			if AIEN.config.AIEN_debugProcessDetail then
				env.info((tostring(ModuleName) .. ", groupMountTeam, " .. tostring(foundItem:getName()) .. " recognized for " .. tostring(uName)))
			end	
			local foundg = foundItem:getGroup()
			if not commandIssued[foundg:getID()] then
				if foundg and foundg:isExist() == true and #foundg:getUnits() > 0 then
					orderInfantryToMoveToPoint(foundg, unit:getPoint())
					commandIssued[foundg:getID()] = true
					groupMoving = groupMoving + 1
				end
			end
		end
	end
	world.searchObjects(Object.Category.UNIT, volS, ifFound)

	if AIEN.config.AIEN_debugProcessDetail then
		env.info((tostring(ModuleName) .. ", groupMountTeam, " .. tostring(groupMoving) .. " groups have been ordered to move nearby " .. tostring(uName)))
	end	

	if groupMoving > 0 then
		timer.scheduleFunction(extractTroops, unit, timer.getTime() + 600)
	end


end

local function groupMountTeam(group) 
    -- this differs substantially from "Extract": basically it's calling the deployed teams to go back to its original vehicle
    -- the original vehicle is defined in a very "stupid" way: by searching unit name in the others groups nearby, which should be there
    -- in the dismounted group name. It's a very "hardcoded" convetion, I know, but still less complicated than many other solutions
    -- and does not require to track troops in another separated db (which already are too many to me)
    -- timing of 7 mins (420 s) seems reasonable to me for the regrouping of the dismounted troops, given the 2 km range.

    if group and group:isExist() == true and #group:getUnits() > 0 then
        for _, uData in pairs(group:getUnits()) do 
			mountTeam(uData)
        end
    end
end

local function groupDeployTroop(group, nocomeback, exactPos)
    if group and group:isExist() == true and group:getUnits() and #group:getUnits() > 0 then
        local units = group:getUnits()
        for _, uData in pairs(units) do

            local id = uData:getID()
            if id then
                if mountedDb[uData:getID()] then
                    deployTroops(uData, exactPos)

                    if not nocomeback then
                        timer.scheduleFunction(groupMountTeam, group, timer.getTime() + AIEN.config.remountTime)
                    end

                    return true
                end
            end
        end
    end
    return nil
end

local function groupCheckForManpad(group)
	if group and group:isExist() then
		local unitsWithTroops = getTroops(group)
		if unitsWithTroops and next(unitsWithTroops) ~= nil then
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.groupCheckForManpad, unitsWithTroops available" ))
            end	
			local manpadTeams = {}
			for uId, uData in pairs(unitsWithTroops) do 
				for _, teams in pairs(uData.t) do
					for _, soldier in pairs(teams) do
						if contains(soldier, "manpad") then
                            if AIEN.config.AIEN_debugProcessDetail == true then
                                env.info(("AIEN.groupCheckForManpad, has manpads" ))
                            end	
							manpadTeams[uId] = uData.u
						end
					end
				end
			end

            return manpadTeams
			
		end
	end
    return nil
end

local function groupDeployManpad(group) -- this won't trigger the deploy of any kind of troops, but only for the manpad team (if there)
	if group and group:isExist() then
		local manpadTeams = groupCheckForManpad(group)
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.groupDeployManpad, manpadTeams: " .. tostring(manpadTeams) ))
        end	
		if manpadTeams and next(manpadTeams) ~= nil then 
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.groupDeployManpad, confirmed deployable manpads team" ))
            end	
			for _, manpads in pairs(manpadTeams) do
				deployTroops(manpads)
                timer.scheduleFunction(groupMountTeam, group, timer.getTime() + AIEN.config.remountTime)			
			end
		end
	end
end

-- ## externally access command, by script

function AIEN_groupDeploy(gName, noremount) -- this one is global, to provide any user to make a group manually dismount via script or trigger action (do script) if remountVar is true, the dismounted group will go back to its vehicle after about 10 mins.
    if gName and type(gName) == "string" then
        local g = Group.getByName(gName)
        if g then
            groupDeployTroop(g, noremount)
        end
    end
end



--###### MISSION REACTIONS #########################################################################

--[[ Reactions is probably the most important behaviour change you will notice using this scripts. Reactions are (currently) triggered only by an hit event on one of the group unit. 
    Obvioulsy optimizable, the code structure basically works this way:
    1. when the hit event happen, some info are gathered in the event function event_hit that will launch executeReactions
    2. the function executeReactions basically will "try" to execute each of the below actions, in a priority order defined in the event_hit
    3. before defining priorities, all these functions are "filtered" by group skills (less skilleg group won't have the most refined solutions) and prioritized by conditions and available informations
    4. the first function that return as a "success" is then executed, and the behaviour take place.

    Side note: suppression, dismount (of all or only manpads) effect are NOT dependand to the scoring model and will take place in parallel.
--]]--


local function ac_accelerate(group, ownPos, tgtPos, resume, sa, skill) -- self-explanatory
    -- doesn't stop a moving group, it simply set its speed as fast as possible. If the group is stationary, it does nothing
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_accelerate launched"))
    end    
    
    if group then
        local s, ms = getGroupSpeed(group)
        if s and s > 0 then
            local c = group:getController()
            if c then
                c:setSpeed(30, true) -- 30 m/s = 108 km/h
                return true
            else
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", ac_accelerate controller not found"))
                end    
                return false
            end
        else
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_accelerate failed to get speed, group is stationary calling false"))
            end  
            return false
        end
    end
    return false
end

local function ac_disperse(group, ownPos, tgtPos, resume, sa, skill) -- basically simply allow for dispersion
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_disperse launched, move randomly"))
    end    
    
    if group then
        groupAllowDisperse(group)
        return true
    else
        return false
    end
end

local function ac_panic(group, ownPos, tgtPos, resume, sa, skill) -- this will make the group to run away randomly.. that mean sometimes even toward the enemy.
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_panic launched, move randomly"))
    end    
    
    if group and group:isExist() and ownPos then

        if AIEN.config.dismount == true then
            groupDeployTroop(group, false)
        end

        local funcDoAction = function()
            if group:isExist() then
                local np = nil
                local maxTries = 1000
                while not np do
                    if AIEN.config.AIEN_debugProcessDetail then
                        env.info((tostring(ModuleName) .. ", ac_panic creating point..."))
                    end
                    maxTries = maxTries - 1
                    if maxTries < 0 then
                        break
                    end
                    np = getRandTerrainPointInCircle(ownPos, AIEN.config.repositionDistance*6, AIEN.config.repositionDistance*3, true)
                end
                
                moveToPoint(group, np, 50, 5)
            end 
        end

        local funcSetParameters = function()
            if group:isExist() then
                local c = group:getController()
                if c then
                    c:setSpeed(30, true) -- 30 m/s = 108 km/h
                end
            end
        end

        local delay = getReactionTime(skill)
        timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)    
        timer.scheduleFunction(funcSetParameters, nil, timer.getTime() + delay + 5)  

        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_panic group planned reaction"))
        end

        return true
    end
    return false
end

local function ac_dropSmoke(group, ownPos, tgtPos, resume, sa, skill) -- basically spawn smokes around the vehicle and move it for 20-30 meters, trying to hide from enemies
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_dropSmoke launched"))
    end    
    
    if group and group:isExist() and ownPos and sa then

        local units = group:getUnits()
        if units then
            -- check at least 50% units can use smoke
            local numTot = 0
            local numSmk = 0
            for _, iData in pairs(units) do
                numTot = numTot + 1
                if iData:hasAttribute("HeavyArmoredUnits") or iData:hasAttribute("IFV") then
                    numSmk = numSmk +1
                end
            end
            if numTot > 0 then
                if numSmk/numTot < 0.5 then
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", ac_dropSmoke dropped cause less than 50% units can do that"))
                    end
                    return false
                end
            end
        end

        local funcDoAction = function()
            
            if group:isExist() then

                if AIEN.config.smoke_source_num > 9 then
                    AIEN.config.smoke_source_num = 9
                elseif AIEN.config.smoke_source_num < 4 then
                    AIEN.config.smoke_source_num = 4
                end
                
                local units = group:getUnits()
                local smoked = false
                if units then

                    -- plan smoke
                    for _, uData in pairs(units) do

                        if uData:hasAttribute("HeavyArmoredUnits") or uData:hasAttribute("IFV") then

                            local uPos = uData:getPoint()

                            local points = genSmokePoints(uPos, aie_random(15, 30), AIEN.config.smoke_source_num)
                    
                            if points and #points > 0 then
                                
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info((tostring(ModuleName) .. ", ac_dropSmoke points " .. tostring(#points)))
                                end

                                --phase 1 generate smoke
                                for _, pPos in pairs(points) do
                                    local f = function()
                                        trigger.action.smoke(pPos, 2)
                                    end
                                    timer.scheduleFunction(f, nil, timer.getTime() + aie_random(1, 5)) 
                                end
                    
                                --phase 2 move in a random point very near (20-30 mt)
                                smoked = true
                    
                            else
                                if AIEN.config.AIEN_debugProcessDetail then
                                    env.info((tostring(ModuleName) .. ", ac_dropSmoke unable to define smoke points"))
                                end  
                                --return false
                            end   
                        end
                    end
                end
                
                if smoked == true then
                    moveToPoint(group, ownPos, 5, 14) 
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", ac_dropSmoke group planned reaction"))
                    end
                end
            end
        end

        local delay = getReactionTime(skill)
        timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)    
        return true  
        
    else
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", ac_dropSmoke missing variables"))
        end  
        return false
    end
end

local function ac_withdraw(group, ownPos, tgtPos, resume, sa, skill) -- this will make the group to run away to the nearest allied ground group
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_withdraw launched, withdraw"))
    end    
    
    if group and ownPos then
        local bestPos = nil
        local maxDist = AIEN.config.withrawDist
        for _, og in pairs(groundgroupsDb) do
            if og.coa == group:getCoalition() then
                if og.n ~= group:getName() then
                    if og.group and og.group:isExist() == true and og.sa and og.sa.pos then
                        local p     = og.sa.pos
                        --local td    = og.threat
                        if p then -- and td
                            -- within range
                            local d = getDist(p, ownPos)
                            if AIEN.config.AIEN_debugProcessDetail == true then
                                env.info((tostring(ModuleName) .. ", ac_withdraw d " .. tostring(d)))
                            end
                            if d and d < maxDist and d > 2000 then
                                bestPos = p
                                maxDist = d
                                --break -- just the first one available
                            end
                        end
                    end
                end
            end
        end

        if bestPos then 
            local funcDoAction = function()
                if group:isExist() then
                    moveToPoint(group, bestPos, AIEN.config.repositionDistance*1.5, AIEN.config.repositionDistance*0.5, false) 
                end
            end
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_withdraw group planned reaction"))
            end
            local delay = getReactionTime(skill)
            timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)      

            if resume then
                -- check if there's a route to be followed once action end
                if group:isExist() then
                    local destination = nil
                    local points = getMEroute(group)
                    if points and #points > 1 then
                        local last = #points
                        local data = points[last] 
                        if data and type(data) == "table" then
                            destination = { x = data.x, y = land.getHeight({x = data.x, y = data.y}), z = data.y}
                        end
                    end
                    if not destination then
                        destination = ownPos
                    end            
                    local funcresumeRoute = function()
                        if group:isExist() then
                            moveToPoint(group, destination, 200, 10)
                        end
                    end
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", ac_withdraw group planning coming back"))
                    end
                    timer.scheduleFunction(funcresumeRoute, nil, timer.getTime() + aie_random(600, 900))     
                end
            end

            return true
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_withdraw return false due to missing widraw opportunities"))
            end
            return false
        end
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_withdraw return false due to missing variable"))
        end
        return false
    end
end

local function ac_attack(group, ownPos, tgtPos, resume, sa, skill) -- this will make the group to run toward the shooting enemy and open fire
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_attack launched, move toward enemy"))
    end    
    
    if group and tgtPos then

        -- check for enemies nearby
        local enemyForce = getEnemyStrInrange(group:getCoalition(), tgtPos, 8000)
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_attack enemyForce " .. tostring(enemyForce)))
        end

        if enemyForce and enemyForce > 20 then
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_attack enemy seems too strong for 1 group, abort action"))
            end
            return false
        end

        local funcDoAction = function()
            if group:isExist() then
                local speed = 10
                if AIEN.config.dismount == true then
                    local deployed = groupDeployTroop(group, false, tgtPos)
                    if deployed == true then
                        speed = 4
                    end
                end

                moveToPoint(group, tgtPos, 300, 500, false, "cone", nil, nil, nil, speed) 
            end
        end
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_attack group planned reaction"))
        end
        local delay = getReactionTime(skill)
        timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)      
        groupGoShoot(group)

        if resume then
            -- check if there's a route to be followed once action end
            local destination = nil
            local points = getMEroute(group)
            if points and #points > 1 then
                local last = #points
                local data = points[last] 
                if data and type(data) == "table" then
                    destination = { x = data.x, y = land.getHeight({x = data.x, y = data.y}), z = data.y}
                end
            end
            if not destination then
                destination = ownPos
            end            
            local funcresumeRoute = function()
                if group:isExist() then
                    moveToPoint(group, destination, 200, 10, false)
                end
            end
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_attack group planning coming back"))
            end
            timer.scheduleFunction(funcresumeRoute, nil, timer.getTime() + aie_random(900, 1200))     
        end

        return true

    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_attack return false due to missing variable"))
        end
        return false
    end
end

local function ac_coverBuildings(group, ownPos, tgtPos, resume, sa, skill) -- this will make the group to run looking cover in a nearby urban area
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_coverBuildings launched"))
    end    
    
    if group and ownPos and sa then

		-- nearby building (within AIEN.config.proxyBuildingDistance)

        local pN1 = ownPos
        local pN2 = ownPos
        local pN3 = ownPos
        local pN4 = ownPos
        local pos1, pos2, pos3, pos4
        local gCoa = group:getCoalition()

        if pN1 and pN2 and pN3 and pN4 then
            pos1 = {x = pN1.x, y = pN1.y, z = pN1.z + AIEN.config.proxyBuildingDistance}
            pos2 = {x = pN2.x, y = pN2.y, z = pN2.z - AIEN.config.proxyBuildingDistance}
            pos3 = {x = pN3.x + AIEN.config.proxyBuildingDistance, y = pN3.y, z = pN3.z}
            pos4 = {x = pN4.x - AIEN.config.proxyBuildingDistance, y = pN4.y, z = pN4.z}

            local function countBld(p)
                local _volume = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = p,
                        radius = AIEN.config.proxyBuildingDistance,
                    },
                }
                local count = 0
                local tblPos = {}
                local enemies = false
                
                local _searchB = function(_obj)
                    pcall(function()
                        if _obj ~= nil then
                            local o_desc = _obj:getDesc()
                            if o_desc then
                                if o_desc.attributes and o_desc.attributes.Buildings then
                                    count = count + 1
                                    tblPos[#tblPos+1] = _obj:getPoint()
                                end
                            end              
                        end
                    end)
                end

                local _searchU = function(_obj)
                    pcall(function()
                        if _obj ~= nil then
                            local o_coa = _obj:getCoalition()
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info((tostring(ModuleName) .. ", ac_coverBuildings o_coa: " .. tostring(o_coa)))
                            end    
                            if o_coa  then
                                if o_coa ~= gCoa then
                                    if AIEN.config.AIEN_debugProcessDetail then
                                        env.info((tostring(ModuleName) .. ", ac_coverBuildings enemies true! " .. tostring(enemies)))
                                    end   
                                    enemies = true
                                end
                            end              
                        end
                    end)
                end                

                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", ac_coverBuildings enemies: " .. tostring(enemies)))
                end    

                world.searchObjects(Object.Category.SCENERY, _volume, _searchB)	
                world.searchObjects(Object.Category.UNIT,    _volume, _searchU)

                if count > 3 and #tblPos > 3 and enemies == false then
                    if AIEN.config.AIEN_debugProcessDetail then
                        env.info((tostring(ModuleName) .. ", ac_coverBuildings adding point, count: " .. tostring(count)))
                    end  
                    local bestPos = avgVec3(tblPos)
                    return count, bestPos
                end
            end

            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings starting c1p1"))
            end 
            local _, p1 = countBld(pos1)
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings starting c2p2"))
            end
            local _, p2 = countBld(pos2)
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings starting c3p3"))
            end
            local _, p3 = countBld(pos3)
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings starting c4p4"))
            end
            local _, p4 = countBld(pos4)
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings done all P's"))
            end

            if p1 or p2 or p3 or p4 then -- at least one should exist
            local function findNearestPoint(p0, ...)
                    local points = {...}
                    local nearestPoint = nil
                    local minDist = nil
                
                    for _, point in ipairs(points) do
                        if point then
                            local dist = getDist(p0, point)
                            if not minDist or dist < minDist then
                                minDist = dist
                                nearestPoint = point
                            end
                        end
                    end
                
                    return nearestPoint
                end
                local dest = findNearestPoint(ownPos, p1, p2, p3, p4)
                
                if dest then
                    local funcDoAction = function()
                        if group:isExist() then
                            moveToPoint(group, dest, AIEN.config.repositionDistance, AIEN.config.repositionDistance*0.2) 
                        end
                    end
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", ac_coverBuildings group planned reaction"))
                    end
                    local delay = getReactionTime(skill)
                    timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)    
                    
                    if resume then
                        -- check if there's a route to be followed once action end
                        local destination = nil
                        local points = getMEroute(group)
                        if points and #points > 1 then
                            local last = #points
                            local data = points[last] 
                            if data and type(data) == "table" then
                                destination = { x = data.x, y = land.getHeight({x = data.x, y = data.y}), z = data.y}
                            end
                        end
                        if not destination then
                            destination = ownPos
                        end            
                        local funcresumeRoute = function()
                            if group:isExist() then
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info((tostring(ModuleName) .. ", ac_coverBuildings group planning coming back to original destination"))
                                end
                                moveToPoint(group, destination, 200, 10)
                            end
                        end
                        timer.scheduleFunction(funcresumeRoute, nil, timer.getTime() + aie_random(420, 900))     
                    end                    

                    return true
                else
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", ac_coverBuildings return false due to missing buildings area"))
                    end
                    return false
                end                    
            else
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info((tostring(ModuleName) .. ", ac_coverBuildings didn't found a suitable place"))
                end
                return false
            end
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_coverBuildings return false due wrong math around the starting point"))
            end
            return false
        end
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_coverBuildings return false due to missing variable"))
        end
        return false
    end
end

local function ac_groundSupport(group, ownPos, tgtPos, resume, sa, skill) -- this will make another ground group to come in support
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_groundSupport launched, move randomly"))
    end    
    
    if group and ownPos and sa then
        local bestVal = 0
        local bestTd  = 1000 
        local AllyGroup = nil
        for _, og in pairs(groundgroupsDb) do
            if og.coa == group:getCoalition() and og.n ~= group:getName() then
                if og.group and og.group:isExist() == true then
                    if supportGroundClasses[og.class] and supportGroundClasses[og.class] > bestVal and og.sa and og.sa.pos then
                        local p     = og.sa.pos
                        local td    = og.threat
                        if p and td then
                            -- within range
                            local d = getDist(p, ownPos)
                            if d and d < AIEN.config.supportDistance and d > 3000 then
                                bestTd = td/2
                                bestVal = supportGroundClasses[og.class]
                                AllyGroup = og.group
                            end
                        end
                    end
                end
            end
        end

        if AllyGroup and bestTd then 
            local funcDoAction = function()
                if group:isExist() then
                    moveToPoint(AllyGroup, ownPos, bestTd*0.5, bestTd*0.3) 
                end
            end
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_groundSupport group planned reaction"))
            end
            local delay = getReactionTime(skill)
            timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)      
 
            return true
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_groundSupport return false due to missing widraw opportunities"))
            end
            return false
        end
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_groundSupport return false due to missing variable"))
        end
        return false
    end
end

local function ac_coverADS(group, ownPos, tgtPos, resume, sa, skill) -- this will make the group to run into the effective range of an allied air defence group
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_coverADS launched"))
    end    
    
    if group and ownPos and sa then
        local bestPos = nil
        local bestVal = 0
        local bestTd  = 3000 
        for _, og in pairs(groundgroupsDb) do
            if og.coa == group:getCoalition()  and og.n ~= group:getName() then
                if og.group and og.group:isExist() == true then
                    if supportCounterAirClasses[og.class] and supportCounterAirClasses[og.class] > bestVal and og.sa and og.sa.pos then
                        local p     = og.sa.pos
                        local td    = og.threat
                        if p and td then
                            -- within range
                            local d = getDist(p, ownPos)
                            if d and d < AIEN.config.supportDistance*1.5 and d > 2000 then
                                bestPos = p
                                bestTd = td
                                bestVal = supportCounterAirClasses[og.class]
                            end
                        end
                    end
                end
            end
        end

        if bestPos and bestTd then 
            local funcDoAction = function()
                if group:isExist() then
                    moveToPoint(group, bestPos, bestTd*0.3, bestTd*0.05) 
                end
            end
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_coverADS group planned reaction"))
            end
            local delay = getReactionTime(skill)
            timer.scheduleFunction(funcDoAction, nil, timer.getTime() + delay)      

            if resume then
                -- check if there's a route to be followed once action end
                local destination = nil
                local points = getMEroute(group)
                if points and #points > 1 then
                    local last = #points
                    local data = points[last] 
                    if data and type(data) == "table" then
                        destination = { x = data.x, y = land.getHeight({x = data.x, y = data.y}), z = data.y}
                    end
                end
                if not destination then
                    destination = ownPos
                end            
                local funcresumeRoute = function()
                    if group:isExist() then
                        moveToPoint(group, destination, 200, 10)
                    end
                end
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info((tostring(ModuleName) .. ", ac_coverADS group planning coming back"))
                end
                timer.scheduleFunction(funcresumeRoute, nil, timer.getTime() + aie_random(900, 1200))     
            end
 
            return true
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info((tostring(ModuleName) .. ", ac_coverADS return false due to missing widraw opportunities"))
            end
            return false
        end
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_coverADS return false due to missing variable"))
        end
        return false
    end
end

local function ac_fireMissionOnShooter(group, ownPos, tgtPos, resume, sa, skill) -- this will make an allied artillery in range to fire at enemy shooter position
    -- group is the group subject of the action
    -- pos is, when needed, the reference position for the actions, or own position
    -- resume is a boolean. If true, after some time the group will resume it's previous condition, else no.
    -- sa is the SA table passed from the group DB, which hold some useful information for addressing the action 
    if AIEN.config.AIEN_debugProcessDetail then
        env.info((tostring(ModuleName) .. ", ac_fireMissionOnShooter launched, planning"))
    end    
    
    if tgtPos then
        for _, og in pairs(groundgroupsDb) do
            if og.coa and og.coa == group:getCoalition() and og.tasked == false then
                if og.class and og.class == "ARTY" then --  or og.class == "MLRS" -- not considering MLRS as they're intended for more area or tactical fire
                    if og.group and og.group:isExist() == true then
                        if og.sa and og.sa.pos and og.threat then
                            local d = getDist(og.sa.pos, tgtPos)
                            if d < og.threat*0.8 then
                                og.tasked = true
                                og.taskTime = timer.getTime()
                                og.firePoint = tgtPos
                                groupfireAtPoint({og.group, tgtPos, 20, "Immediate suppression"})
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info((tostring(ModuleName) .. ", ac_fireMissionOnShooter return true, planning the fire mission"))
                                end

                                return true
                            end
                        end
                    end
                end
            end
        end
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_fireMissionOnShooter return false being unable to plan the fire mission"))
        end
        return false
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info((tostring(ModuleName) .. ", ac_fireMissionOnShooter return false due to missing variable"))
        end
        return false
    end
end

-- summary tablem holds the "scoring model points" for each condition. This can be seen as a decision matrix for evaluate best reaction available.
-- used for fast-filtering actions availability based on group leader skill. 
-- It basically is an array, where the actions are listed in order of complexity. 
-- This way, the skill could be converted into a number, and that number will became the maximum index available.
-- The higher the skill, the higher the index, the higher the actions that could be evaluated
local reactionsDb = {
	[1] 	= { -- ac_accelerate
        ["name"] = "ac_accelerate",
        ["ac_function"] = ac_accelerate,
        ["message"] = "",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 2, -- shell
            [1] = 2, -- missile
            [2] = 1, -- rocket
            [3] = 0, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 1, -- airplane
            [1] = 0, -- helicopter
            [2] = 2, -- ground unit
            [3] = 1, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 2, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 1, -- not so close
            [1] = 0, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 2, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 2,
            ["ATGM"] = 1,
            ["MLRS"] = 0,
            ["ARTY"] = 0,
            ["MISSILE"] = 0,
            ["MANPADS"] = 0,
            ["SHORAD"] = 3,
            ["AAA"] = 3,
            ["SAM"] = 5,
            ["IFV"] = 0,
            ["APC"] = 0,
            ["RECCE"] = 0,
            ["LOGI"] = 0,
            ["INF"] = 0,
            ["UNKN"] = 0,
        },  
        ["s_cls"] = { 
            ["MBT"] = 0.2,
            ["ATGM"] = 0.4,
            ["MLRS"] = 2.1,
            ["ARTY"] = 1.5,
            ["MISSILE"] = 3.1,
            ["MANPADS"] = 2,
            ["SHORAD"] = 2.2,
            ["AAA"] = 2.8,
            ["SAM"] = 2.3,
            ["IFV"] = 0.4,
            ["APC"] = 0.9,
            ["RECCE"] = 1.2,
            ["LOGI"] = 1.9,
            ["INF"] = 0.8,
            ["UNKN"] = 1,
            ["ARBN"] = 1.4,
        },         
    }, 
	[2] 	= { -- ac_panic
        ["name"] = "ac_panic",
        ["ac_function"] = ac_panic,
        ["message"] = "We're trying to escape fire%!",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 0.45, -- shell
            [1] = 2.5, -- missile
            [2] = 0.5, -- rocket
            [3] = 0, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 1, -- airplane
            [1] = 1, -- helicopter
            [2] = 0.5, -- ground unit
            [3] = 1.5, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 0.5, -- not an indirect fire unit
            [1] = 0.5, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 0.5, -- not so close
            [1] = 0, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 1, -- detailed shooter position known
        },     
        ["o_cls"] = {
            ["MBT"] = 1.5,
            ["ATGM"] = 1.3,
            ["MLRS"] = 1,
            ["ARTY"] = 1,
            ["MISSILE"] = 2,
            ["MANPADS"] = 2,
            ["SHORAD"] = 0,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 0.7,
            ["APC"] = 0.5,
            ["RECCE"] = 0,
            ["LOGI"] = 0.2,
            ["INF"] = 0,
            ["UNKN"] = 0.1,
        },  
        ["s_cls"] = { 
            ["MBT"] = 1.3,
            ["ATGM"] = 0.5,
            ["MLRS"] = 1.3,
            ["ARTY"] = 0.3,
            ["MISSILE"] = 0.2,
            ["MANPADS"] = 0,
            ["SHORAD"] = 0,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 0.7,
            ["APC"] = 0.9,
            ["RECCE"] = 0.3,
            ["LOGI"] = 0.2,
            ["INF"] = 0.1,
            ["UNKN"] = 1,
            ["ARBN"] = 0.5,
        },            
    },     
	[3] 	= { -- ac_disperse
        ["name"] = "ac_disperse",
        ["ac_function"] = ac_disperse,
        ["message"] = "We're stuck here, we ask support if available",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 0, -- shell
            [1] = 0, -- missile
            [2] = 1, -- rocket
            [3] = 1, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 0, -- airplane
            [1] = 0, -- helicopter
            [2] = 2, -- ground unit
            [3] = 2, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 1, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 0, -- not so close
            [1] = 1, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 1.5,
            ["ATGM"] = 1.3,
            ["MLRS"] = 1,
            ["ARTY"] = 1,
            ["MISSILE"] = 2,
            ["MANPADS"] = 2,
            ["SHORAD"] = 0,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 0.7,
            ["APC"] = 0.5,
            ["RECCE"] = 0,
            ["LOGI"] = 0.2,
            ["INF"] = 0,
            ["UNKN"] = 0.1,
        }, 
        ["s_cls"] = { 
            ["MBT"] = 1,
            ["ATGM"] = 1.2,
            ["MLRS"] = 1,
            ["ARTY"] = 0,
            ["MISSILE"] = 0,
            ["MANPADS"] = 0.3,
            ["SHORAD"] = 1.5,
            ["AAA"] = 0.6,
            ["SAM"] = 0.6,
            ["IFV"] = 0.8,
            ["APC"] = 0.7,
            ["RECCE"] = 0.3,
            ["LOGI"] = 0.2,
            ["INF"] = 0.1,
            ["UNKN"] = 1,
            ["ARBN"] = 0.4,
        },          
    },     
	[4] 	= { -- ac_dropSmoke
        ["name"] = "ac_dropSmoke",
        ["ac_function"] = ac_dropSmoke,
        ["message"] = "Dropping smoke cover",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 0, -- shell
            [1] = 3, -- missile
            [2] = 1, -- rocket
            [3] = 2, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 2, -- airplane
            [1] = 1, -- helicopter
            [2] = 1, -- ground unit
            [3] = 0, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 1, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 0, -- not so close
            [1] = 1, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 1.5,
            ["ATGM"] = 2,
            ["MLRS"] = 0,
            ["ARTY"] = 0,
            ["MISSILE"] = 0,
            ["MANPADS"] = 0,
            ["SHORAD"] = 0,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 2,
            ["APC"] = 1.1,
            ["RECCE"] = 0,
            ["LOGI"] = 0,
            ["INF"] = 0,
            ["UNKN"] = 0,
        }, 
        ["s_cls"] = { 
            ["MBT"] = 2.1,
            ["ATGM"] = 1.8,
            ["MLRS"] = 0,
            ["ARTY"] = 0,
            ["MISSILE"] = 0,
            ["MANPADS"] = 0,
            ["SHORAD"] = 0,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 2,
            ["APC"] = 2.3,
            ["RECCE"] = 0,
            ["LOGI"] = 0,
            ["INF"] = 0,
            ["UNKN"] = 0,
            ["ARBN"] = 3,
        },          
    },     
	[5] 	= { -- ac_withdraw
        ["name"] = "ac_withdraw",
        ["ac_function"] = ac_withdraw,
        ["message"] = "We're moving in safer area",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 3, -- shell
            [1] = 2, -- missile
            [2] = 1, -- rocket
            [3] = 2, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 1, -- airplane
            [1] = 1, -- helicopter
            [2] = 2, -- ground unit
            [3] = 2, -- ship
            [4] = 1, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 0, -- not an indirect fire unit
            [1] = 2, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 2, -- not so close
            [1] = 0, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 3, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 0,
            ["ATGM"] = 0,
            ["MLRS"] = 0,
            ["ARTY"] = 1,
            ["MISSILE"] = 1,
            ["MANPADS"] = 1,
            ["SHORAD"] = 2,
            ["AAA"] = 2,
            ["SAM"] = 0,
            ["IFV"] = 0,
            ["APC"] = 0,
            ["RECCE"] = 0,
            ["LOGI"] = 3,
            ["INF"] = 3,
            ["UNKN"] = 1,
        }, 
        ["s_cls"] = { 
            ["MBT"] = 0,
            ["ATGM"] = 1.8,
            ["MLRS"] = 0.6,
            ["ARTY"] = 0.4,
            ["MISSILE"] = 0.5,
            ["MANPADS"] = 0.1,
            ["SHORAD"] = 0.3,
            ["AAA"] = 0.2,
            ["SAM"] = 0.2,
            ["IFV"] = 1.5,
            ["APC"] = 0.7,
            ["RECCE"] = 0.3,
            ["LOGI"] = 0.2,
            ["INF"] = 0.1,
            ["UNKN"] = 1,
            ["ARBN"] = 0.7,
        },         
    },     
    [6] 	= { -- ac_attack
        ["name"] = "ac_attack",
        ["ac_function"] = ac_attack,
        ["message"] = "We're going to ambush the enemy",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 1, -- shell
            [1] = 1, -- missile
            [2] = 0, -- rocket
            [3] = 0, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 0, -- airplane
            [1] = 0, -- helicopter
            [2] = 2, -- ground unit
            [3] = 0, -- ship
            [4] = 2, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 2, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 1, -- not so close
            [1] = 2, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 2, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = {
            ["MBT"] = 0,
            ["ATGM"] = 0,
            ["MLRS"] = 2,
            ["ARTY"] = 0,
            ["MISSILE"] = 0,
            ["MANPADS"] = 0,
            ["SHORAD"] = 2,
            ["AAA"] = 0,
            ["SAM"] = 0,
            ["IFV"] = 1,
            ["APC"] = 0,
            ["RECCE"] = 0,
            ["LOGI"] = 0,
            ["INF"] = 0,
            ["UNKN"] = 0,
        },  
        ["s_cls"] = { 
            ["MBT"] = 0,
            ["ATGM"] = 0,
            ["MLRS"] = 3,
            ["ARTY"] = 2.5,
            ["MISSILE"] = 3,
            ["MANPADS"] = 3,
            ["SHORAD"] = 1.3,
            ["AAA"] = 2.2,
            ["SAM"] = 2.2,
            ["IFV"] = 0.6,
            ["APC"] = 0.9,
            ["RECCE"] = 1.7,
            ["LOGI"] = 4,
            ["INF"] = 2.4,
            ["UNKN"] = 1,
            ["ARBN"] = 0,
        },          
    },    
    [7] 	= { -- ac_coverBuildings
        ["name"] = "ac_coverBuildings",
        ["ac_function"] = ac_coverBuildings,
        ["message"] = "We're moving nearby the closest urbanized area for concealment",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 2, -- shell
            [1] = 2, -- missile
            [2] = 2, -- rocket
            [3] = 1, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 2, -- airplane
            [1] = 2, -- helicopter
            [2] = 1, -- ground unit
            [3] = 2, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 2, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 1, -- not so close
            [1] = 2, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 2, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 0,
            ["ATGM"] = 1,
            ["MLRS"] = 2,
            ["ARTY"] = 1,
            ["MISSILE"] = 0,
            ["MANPADS"] = 3,
            ["SHORAD"] = 3,
            ["AAA"] = 2,
            ["SAM"] = 0,
            ["IFV"] = 2,
            ["APC"] = 3,
            ["RECCE"] = 3,
            ["LOGI"] = 3,
            ["INF"] = 3,
            ["UNKN"] = 3,
        },  
        ["s_cls"] = { 
            ["MBT"] = 1.3,
            ["ATGM"] = 1.8,
            ["MLRS"] = 2,
            ["ARTY"] = 2,
            ["MISSILE"] = 0.5,
            ["MANPADS"] = 0.1,
            ["SHORAD"] = 0.3,
            ["AAA"] = 0.2,
            ["SAM"] = 0.2,
            ["IFV"] = 1.4,
            ["APC"] = 1,
            ["RECCE"] = 0.3,
            ["LOGI"] = 0.2,
            ["INF"] = 0.1,
            ["UNKN"] = 1,
            ["ARBN"] = 2,
        },         
    },
    [8] 	= { -- ac_groundSupport
        ["name"] = "ac_groundSupport",
        ["ac_function"] = ac_groundSupport,
        ["message"] = "We asked for ground support, they're on the way",
        ["resume"] = true,
        ["w_cat"] = { -- weapon category
            [0] = 0, -- shell
            [1] = 1, -- missile
            [2] = 0, -- rocket
            [3] = 0, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 0, -- airplane
            [1] = 1, -- helicopter
            [2] = 4, -- ground unit
            [3] = 0, -- ship
            [4] = 2, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 1, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 0, -- not so close
            [1] = 2, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 1,
            ["ATGM"] = 1,
            ["MLRS"] = 2,
            ["ARTY"] = 2,
            ["MISSILE"] = 3,
            ["MANPADS"] = 2,
            ["SHORAD"] = 2,
            ["AAA"] = 2,
            ["SAM"] = 2,
            ["IFV"] = 1,
            ["APC"] = 2,
            ["RECCE"] = 1,
            ["LOGI"] = 2,
            ["INF"] = 3,
            ["UNKN"] = 1,
        }, 
        ["s_cls"] = { 
            ["MBT"] = 1.8,
            ["ATGM"] = 1.4,
            ["MLRS"] = 3,
            ["ARTY"] = 2.5,
            ["MISSILE"] = 3,
            ["MANPADS"] = 3,
            ["SHORAD"] = 1.3,
            ["AAA"] = 1,
            ["SAM"] = 0.9,
            ["IFV"] = 2,
            ["APC"] = 2.2,
            ["RECCE"] = 1.7,
            ["LOGI"] = 1.1,
            ["INF"] = 0.4,
            ["UNKN"] = 1,
            ["ARBN"] = 0,
        },         
    },
    [9] 	= { -- ac_coverADS
        ["name"] = "ac_coverADS",
        ["ac_function"] = ac_coverADS,
        ["resume"] = false,
        ["message"] = "Attack comes from airborne asset, we are moving within the closest air defence covered area",
        ["w_cat"] = { -- weapon category
            [0] = 1, -- shell
            [1] = 3, -- missile
            [2] = 2, -- rocket
            [3] = 3, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 5, -- airplane
            [1] = 5, -- helicopter
            [2] = 0, -- ground unit
            [3] = 0, -- ship
            [4] = 0, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 2, -- not an indirect fire unit
            [1] = 2, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 2, -- not so close
            [1] = 2, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 0, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 3,
            ["ATGM"] = 2,
            ["MLRS"] = 3,
            ["ARTY"] = 3,
            ["MISSILE"] = 3,
            ["MANPADS"] = 1,
            ["SHORAD"] = 0,
            ["AAA"] = 1,
            ["SAM"] = 0,
            ["IFV"] = 3,
            ["APC"] = 3,
            ["RECCE"] = 3,
            ["LOGI"] = 3,
            ["INF"] = 3,
            ["UNKN"] = 3,
        },  
        ["s_cls"] = { 
            ["MBT"] = 1.8,
            ["ATGM"] = 1.4,
            ["MLRS"] = 3,
            ["ARTY"] = 2.5,
            ["MISSILE"] = 3,
            ["MANPADS"] = 3,
            ["SHORAD"] = 1.3,
            ["AAA"] = 1,
            ["SAM"] = 0.9,
            ["IFV"] = 2,
            ["APC"] = 2.2,
            ["RECCE"] = 1.7,
            ["LOGI"] = 1.1,
            ["INF"] = 0.4,
            ["UNKN"] = 1,
            ["ARBN"] = 5,
        },         
    },
    [10] 	= { -- ac_fireMissionOnShooter
        ["name"] = "ac_fireMissionOnShooter",
        ["ac_function"] = ac_fireMissionOnShooter,
        ["resume"] = true,
        ["message"] = "We got the enemy position and asked for indirect fire mission.",
        ["w_cat"] = { -- weapon category
            [0] = 3, -- shell
            [1] = 3, -- missile
            [2] = 3, -- rocket
            [3] = 3, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 0, -- airplane
            [1] = 3, -- helicopter
            [2] = 2, -- ground unit
            [3] = 3, -- ship
            [4] = 5, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 2, -- not an indirect fire unit
            [1] = 0, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 5, -- not so close
            [1] = 0, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 5, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 1,
            ["ATGM"] = 1,
            ["MLRS"] = 3,
            ["ARTY"] = 3,
            ["MISSILE"] = 1,
            ["MANPADS"] = 1,
            ["SHORAD"] = 1,
            ["AAA"] = 1,
            ["SAM"] = 1,
            ["IFV"] = 1,
            ["APC"] = 1,
            ["RECCE"] = 1,
            ["LOGI"] = 1,
            ["INF"] = 1,
            ["UNKN"] = 2,
            ["ARBN"] = 1,
        },  
        ["s_cls"] = { 
            ["MBT"] = 1.8,
            ["ATGM"] = 1.4,
            ["MLRS"] = 3,
            ["ARTY"] = 2.5,
            ["MISSILE"] = 3,
            ["MANPADS"] = 3,
            ["SHORAD"] = 1.3,
            ["AAA"] = 1,
            ["SAM"] = 0.9,
            ["IFV"] = 2,
            ["APC"] = 2.2,
            ["RECCE"] = 1.7,
            ["LOGI"] = 1.1,
            ["INF"] = 0.4,
            ["UNKN"] = 1,
            ["ARBN"] = 5,
        },          
    },
    -- revTODO interesting, does this mean that you planned the "call for air support" feature? -> Chromium: check this out -> yes, it will be added as a client request
    --[[
    [11] 	= {
        ["name"] = "ac_airSupport",
        ["ac_function"] = ac_airSupport,
        ["w_cat"] = { -- weapon category
            [0] = 2, -- shell
            [1] = 2, -- missile
            [2] = 2, -- rocket
            [3] = 2, -- bomb
        }, 				
        ["s_cat"] = { -- unit category
            [0] = 0, -- airplane
            [1] = 2, -- helicopter
            [2] = 4, -- ground unit
            [3] = 0, -- ship
            [4] = 3, -- structure
        }, 				
        ["s_indirect"] = { -- unit category
            [0] = 1, -- not an indirect fire unit
            [1] = 1, -- is an indirect fire unit
        }, 			
        ["s_close"] = { -- shooter is within wpn range
            [0] = 2, -- not so close
            [1] = 3, -- close
        }, 	     	      
        ["s_fireMis"] = { -- shooter position and speed
            [0] = 0, -- detailed shooter position not known
            [1] = 5, -- detailed shooter position known
        },     
        ["o_cls"] = { 
            ["MBT"] = 2,
            ["ATGM"] = 2,
            ["MLRS"] = 2,
            ["ARTY"] = 2,
            ["MISSILE"] = 2,
            ["MANPADS"] = 1,
            ["SHORAD"] = 2,
            ["AAA"] = 2,
            ["SAM"] = 2,
            ["IFV"] = 2,
            ["APC"] = 2,
            ["RECCE"] = 2,
            ["LOGI"] = 1,
            ["INF"] = 1,
            ["UNKN"] = 0,
        },  
        ["o_cls"] = { 
            ["MBT"] = 3,
            ["ATGM"] = 3,
            ["MLRS"] = 3,
            ["ARTY"] = 3,
            ["MISSILE"] = 3,
            ["MANPADS"] = 0.4,
            ["SHORAD"] = 0.2,
            ["AAA"] = 0.4,
            ["SAM"] = 0,
            ["IFV"] = 2.8,
            ["APC"] = 2,
            ["RECCE"] = 2,
            ["LOGI"] = 1,
            ["INF"] = 1,
            ["UNKN"] = 0,
            ["ARBN"] = 1.9,
        },          
    },
    --]]--
}

-- the functions that handles the reactions, using priorities
local function executeReactions(gr, ownPos, tgtPos, actTbl, saTbl, skill)
    if gr and gr:isExist() and ownPos and tgtPos and actTbl and saTbl and skill then
        if actTbl and #actTbl>0 then
            for _, aData in pairs(actTbl) do 
                for _, dbActData in pairs(reactionsDb) do
                    if aData.name == dbActData.name then
                        local f = dbActData.ac_function
                        if f then

                            trigger.action.groupContinueMoving(gr)
                            local success = f(gr, ownPos, tgtPos, dbActData.resume, saTbl, skill)
                            if AIEN.config.AIEN_debugProcessDetail == true then
                                env.info(("AIEN.executeReactions, action success = " .. tostring(success)))
                            end
                            if success and success == true then
                                -- message feedback
                                if AIEN.config.message_feed == true then

                                    local lat, lon = coord.LOtoLL(ownPos)
                                    local MGRS = coord.LLtoMGRS(coord.LOtoLL(ownPos))
                                    if lat and lon then

                                        local LL_string = tostringLL(lat, lon, 0, true)
                                        local MGRS_string = tostringMGRS(MGRS ,4)


                                        local txt = ""
                                        local txt = txt .. "C2, " .. tostring(gr:getName()) .. ", report under attack. Coordinates: " .. tostring(LL_string) .. ", " .. tostring(MGRS_string) .. "." .. dbActData.message
                                        local vars = {"text", txt, 30, nil, nil, nil, gr:getCoalition()}

                                        multyTypeMessage(vars)

                                    end
                                end

                                return dbActData.name
                            end
                        end
                    end
                end
            end
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.executeReactions, actTbl missing or void"))
            end
            return false
        end
    else
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info(("AIEN.executeReactions error, missing one or more variables:"))
            env.info(("AIEN.executeReactions error: " .. tostring(gr)))
            env.info(("AIEN.executeReactions error: " .. tostring(ownPos)))
            env.info(("AIEN.executeReactions error: " .. tostring(tgtPos)))
            env.info(("AIEN.executeReactions error: " .. tostring(actTbl)))
            env.info(("AIEN.executeReactions error: " .. tostring(saTbl)))
            env.info(("AIEN.executeReactions error: " .. tostring(skill)))
        end
        return false
    end
end

-- this 'global' test function let you test a specific reaction of your choice, using the group name and the reaction name to execute. 
-- for those action where the shooter is required for evaluation, the test function will look for the nearest target within 20 km.
-- if data are not gathered, it will print an advice 

function AIEN_testReactions(groupName, actionName)
    
    if groupName and type(groupName) == "string" and actionName and type(actionName) == "string" then
        --local gr = Group.getByName(groupName)

        -- get group info
        local gr 			= nil
        local saTbl 		= nil
        local ownPos 		= nil
        local skill 		= nil
		local coa 			= nil
        for _, gData in pairs(groundgroupsDb) do
            if groupName == gData.n then
				gr 		= gData.group
				saTbl 	= gData.sa
				ownPos	= gData.sa.pos
				skill	= gData.skill
				coa		= gData.coa
            end
        end

        -- get action info
		local actionFunc	= nil
		local actionResume	= nil
		local actionMess	= nil
        for _, aData in pairs(reactionsDb) do
            if actionName == aData.name then
				actionFunc = aData.ac_function
				actionResume = aData.resume
				actionMess	 = aData.message
            end
        end

		-- filter conditions
		if gr and saTbl and ownPos and skill and coa and actionFunc then

			-- get nearest enemy
			local tgtPos = nil
			local maxDist = 20000
			local _volume = {
				id = world.VolumeType.SPHERE,
				params = {
					point = ownPos,
					radius = 20000,
				},
			}

			local _search = function(_obj)
				pcall(function()
					if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() and _obj:getCoalition() ~= coa then
						local _objPos = _obj:getPoint()
						if _objPos then
							local d = getDist(_objPos, ownPos)
							if d and d < maxDist then
								maxDist = d
								tgtPos = _objPos
							end
						end
					end
				end)
			end
			world.searchObjects(Object.Category.UNIT, _volume, _search)		
			
			-- tgtPos might be unnecessary, therefore I don't check it.
			local success = actionFunc(gr, ownPos, tgtPos, actionResume, saTbl, skill)
			if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.AIEN_testReactions, result " .. tostring(success)))
            end
			if success and success == true then
				-- message feedback
				if AIEN.config.message_feed == true then

					local lat, lon = coord.LOtoLL(ownPos)
					if lat and lon then

						local LL_string = tostringLL(lat, lon, 0, true)

						local txt = ""
						local txt = txt .. "C2, " .. tostring(gr:getName()) .. ", report under attack. Coordinates: " .. tostring(LL_string) .. "." .. tostring(actionMess)
						local vars = {"text", txt, 20, nil, nil, nil, gr:getCoalition()}

						multyTypeMessage(vars)

					end
				end

				return actionName
			end
			
		end
		return nil

    end
end


--###### MISSION TACTICAL ACTIONS ##################################################################

--[[ Tactical actions are tasks that are issued by C2, given intel and own forces informations, in real time, to reposition ground units at medium ranges (up to 15 km unless you change AIEN.config.tacticalRange) 
    While initiative is up to the single group with only it's own informations and targets detected, tactical actions are issued by C2 to reposition MBT, IFV, APC and ATGM groups in a more effective way, using the information available to the coalition

    While optimizable, the code structure basically works this way:
    1. For each non-tasked and not under attack group entry, it looks for intel contact within the tactical range, choosing the closest 5 of them. On each, it will evaluate them as units assemblies (not DCS groups) by proximity of 1 km each. For each assembly, it will consider units type total strenght.
    2. After evaluation, different solutions are considered if enemies are within 8 km range:
        - If an enemy units assemblies is significantly stronger than the group, it won't intervene or, if own group is arty, it will consider repositioning away from them (80% threat range or 15 km, the lesser).
        - If an enemy units assemblies is significantly weaker than the group or non-threatening type (i.e. arty, air defences), and the group is a mover, it will plan a route to attack them and exploit the weakness.
        - If an enemy units assemblies is similar in strength and the group is a mover or recce and the enemy is in arty range (but not suitable target), it will reposition to have a direct LOS on enemy.
        These actions are executed by the executeActions function..
    
    3. if enemies are from 8 to 15 km away: 
        - If an enemy units assemblies is significantly weaker or similar strenght than the group or non-threatening type (i.e. arty, air defences), and the group is a mover, it will get closer up to 6 km.

    4. in any case where enemies are not attacked or engaged, C2 will open a task in the F10 menù for clients with relevant informations: target position, number & type, enemy known air defences within 50 km (bearing and range from tgt)

--]]--


--###### DB CONSTRUCTION & HANDLING ################################################################

--[[ DB structure
    each db element is added as this: [objectID] = {group = Group Object, class = Result of getGroupClass function, i = index in table}
    They're not array to speed up the object calls when needed, cause you can simply do a referencedDB[objectID] call w/o coding for table loop
    when a db is referred to a unit, to skip units loop in the group (i.e. droneunitDb), the "group" key is replaced by "unit"

    DBs are used mostly for FSM loops, that are needed to keep a low impact on the process (FSM 1st level will loop db's, while FSM 2nd level will loop each entry one every phaseCycleTimer timer (default 0.2 seconds)).
    Not all the DBs are used in loops, some are only event-related like the ones used for dismount options.

]]--

local function populate_Db() -- this one is launched once at mission start and collect everything relevant that is already there.

	-- only ground groups
	groundgroupsDb = {}
	for i = 0, 2 do
		for _, gp in pairs(coalition.getGroups(i,2)) do -- ground only
			if gp:isExist() then

                local c = getGroupClass(gp)
                local gpcoa = gp:getCoalition()
                -- classes reminder from getGroupClass:
                -- MBT
                -- ATGM
                -- IFV
                -- APC
                -- RECCE
                -- LOGI
                -- MLRS
                -- ARTY
                -- MISSILE
                -- MANPADS
                -- SHORAD
                -- AAA
                -- SAM
                -- INF
                -- UNKN
                
                local s = getGroupSkillNum(gp)
                env.info((tostring(ModuleName) .. ", populate_Db: s " .. tostring(s)))
                local det, thr, thrmin = getRanges(gp)
                local hasRoute = false
                for coa_name, coa_data in pairs(env.mission.coalition) do
                    if type(coa_data) == 'table' then
                        if coa_data.country then --there is a country table
                            for cntry_id, cntry_data in pairs(coa_data.country) do
                                for obj_type_name, obj_type_data in pairs(cntry_data) do
                                    if obj_type_name == "vehicle" then	-- only these types have points
                                        if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
                                            for group_num, group_data in pairs(obj_type_data.group) do
                                                if group_data and group_data.name == gp:getName() then -- this is the group we are looking for
                                                    if group_data.route and group_data.route.points and #group_data.route.points > 1 then
                                                        hasRoute = true
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if c then
                    --
                    local foundGuidance = 0
                    if c == "MLRS" then                        
                        local units = gp:getUnits()
                        for _, uData in pairs(units) do
                            local ammoTbl = uData:getAmmo()
                            if ammoTbl then
                                for aId, aData in pairs(ammoTbl) do 
                                    if aData.desc then
                                        if aData.desc.guidance then
                                            foundGuidance = aData.desc.guidance
                                            env.info((tostring(ModuleName) .. ", populate_Db: adding to groundgroupsDb " .. tostring(gp:getName() .. ", can shoot MLRS with guidance" )))
                                        end
                                    end
                                end
                            end
                        end    

                        env.info((tostring(ModuleName) .. ", populate_Db: MLRS guidance " .. tostring(gp:getName() .. ", class " .. tostring(foundGuidance) )))
                    end
                    --]]--

                    groundgroupsDb[gp:getID()] = {group = gp, class = c, n = gp:getName(), coa = gpcoa, detection = det, threat = thr, threatmin = thrmin, tasked = false, skill = s, hasMeRoute = hasRoute, artyWpnGuidance = foundGuidance}  --, route = r
                    env.info((tostring(ModuleName) .. ", populate_Db: adding to groundgroupsDb " .. tostring(gp:getName() .. ", class " .. tostring(c) )))
                else
                    env.info((tostring(ModuleName) .. ", populate_Db: skipping group due to unable to identify class " .. tostring(gp:getName() )))
                end

                -- dismount dbs
                if AIEN.config.dismount == true then
                    if gp:getUnits() and #gp:getUnits() > 0 then
                        for _, un in pairs(gp:getUnits()) do
                            if un:hasAttribute("IFV") or un:hasAttribute("APC") or un:hasAttribute("Trucks") then
                                -- define dismount capacity
                                local people = defineTroopsNumber(un)
                                infcarrierDb[un:getID()] = people

                                -- define pre-loaded groups!
                                local function loadTeam(unit)
                                    local refTbl = dismountTeamsWest
                                    if gpcoa == 1 then
                                        refTbl = dismountTeamsEast
                                    end


                                    local r = aie_random(1,100)
                                    --env.info((tostring(ModuleName) .. ", populate_Db: random for " .. tostring(unit:getName()) .. ": " .. tostring(r) ))
                                    local c = nil
                                    local i = nil
                                    local lim = 0
                                    for _, tData in pairs(refTbl) do
                                        if r > tData.p and tData.p > lim then
                                            c = tData.c
                                            i = tData.id
                                            lim = tData.p
                                            --env.info((tostring(ModuleName) .. ", populate_Db: found " .. tostring(i) ))
                                        end
                                    end

                                    if c then
                                        local curMount = mountedDb[unit:getID()] or {}
                                        env.info((tostring(ModuleName) .. ", populate_Db: adding " .. tostring(i) .. " to " .. tostring(unit:getName()) ))
                                        curMount[#curMount+1] = c
                                        mountedDb[unit:getID()] = curMount
                                        
                                        local freePlace = infcarrierDb[un:getID()]
                                        freePlace = freePlace - #c
                                        infcarrierDb[un:getID()] = freePlace
                                    end
                                end

                                local loadings = math.floor(people/4)
                                for i = 1, loadings do
                                    if infcarrierDb[un:getID()] >=4 then
                                        loadTeam(un)
                                    end
                                end

                            end
                        end
                    end
                end

                -- set prevent disperse
                groupPreventDisperse(gp)

			end
		end
	end
	
	-- only drone units
	droneunitDb = {}	
	for i = 0, 2 do
		for _, gp in pairs(coalition.getGroups(i,0)) do -- airplane only
			if gp:isExist() then
                local c = nil
                if gp:getUnits() then
                    for _, un in pairs(gp:getUnits()) do
                        if un:hasAttribute("UAVs") then -- drone only
                            c = "UAV"
                        end
                    end
                end
                if c then
                    env.info((tostring(ModuleName) .. ", populate_Db: adding to droneunitDb " .. tostring(gp:getName() )))
                    droneunitDb[gp:getID()] = {group = gp, class = c, n = gp:getName(), coa = gp:getCoalition()}
                end				
			end
		end
	end


    if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
        dumpTableAIEN("groundgroupsDb.lua", groundgroupsDb, "int")
        dumpTableAIEN("droneunitDb.lua", droneunitDb, "int")
        dumpTableAIEN("infcarrierDb.lua", infcarrierDb, "int")
        dumpTableAIEN("mountedDb.lua", mountedDb, "int")
    end
	
end


--###### FINITE STATE MACHINE LOOP #################################################################

--[[ FSM is the key element that allow this script to be as lightweight as possibile (for my low skills), cause basically make all the recurring functions to run each every "n" time instead of all-together at once every second. 
    There are 2 levels of FSM:
    - 1st level is the "bigger" one that is divided in phases: each phase update a DB table, plus a fourth one that handle the artillery groups fire missions.
    - 2nd level is the "group cycle", that handle each database entry update.

    Each time a 2nd level cycle is complete, the subsequent 1st level start and at the end it will simply re-start from the first. Check AIEN.performPhaseCycle() for 1st level cycle.

]]--

-- utils
local function createIterator(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function getNextKey(keys, currentKey)
    for i, key in ipairs(keys) do
        if key == currentKey then
            return keys[i + 1]
        end
    end
    return nil
end

-- 2ND LEVEL CYCLE FUNCTIONS

-- SA update, PHASE "A"
local function update_GROUND()
    if PHASE == "A" then -- confirm correct PHASE of performPhaseCycle
        if groundgroupsDb and next(groundgroupsDb) ~= nil then -- check that table exist and that it's not void
            if not phase_index then -- escape condition from the 2nd loop!
                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
                -- debug steps
                if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
                    dumpTableAIEN("groundgroupsDb.lua", groundgroupsDb, "int")
                end
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_GROUND: phase A completed"))
                end

            else
                local gData = groundgroupsDb[phase_index]
                if gData then
                    local remove = false
                    if gData.group then
                        if gData.group and gData.group:isExist() == true and gData.group:getUnits() then

                            -- filter under attack, SA already gained and need to focus on reactions
                            if not underAttack[phase_index] then 

                                -- update/create sa
                                gData.sa = getSA(gData.group)

                                -- check tasked
                                if gData.tasked == true and gData.taskTime then
                                    if timer.getTime() - gData.taskTime >= AIEN.config.taskTimeout then
                                        if AIEN.config.AIEN_debugProcessDetail then
                                            env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " is still tasked. Removing it"))
                                        end
                                        gData.tasked = false
                                        gData.taskTime = nil
                                    end
                                end
                            else
                                local t = timer.getTime() - underAttack[phase_index]
                                if t > AIEN.config.taskTimeout*2 then
                                    underAttack[phase_index] = nil
                                    if AIEN.config.AIEN_debugProcessDetail then
                                        env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " removed from the under attack table"))
                                    end
                                else
                                    if AIEN.config.AIEN_debugProcessDetail then
                                        env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " is still under attack"))
                                    end                                        
                                end
                            end

                        else
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " other variables does not exist, remove true"))
                            end
                            remove = true
                        end
                    else
                        if AIEN.config.AIEN_debugProcessDetail then
                            env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " gData.group does not exist, remove true"))
                        end
                        remove = true
                    end

                    if remove == true then
                        if AIEN.config.AIEN_debugProcessDetail then
                            env.info((tostring(ModuleName) .. ", update_GROUND, group name " .. tostring(gData.n) .. " missing. Removing it"))
                        end
                        groundgroupsDb[phase_index] = nil
                        phase_keys = createIterator(groundgroupsDb)                        
                    end

                end
                phase_index = getNextKey(phase_keys, phase_index)
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            end
        else
            PHASE = "Initialization"
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_GROUND, reinizializzazione dei DB, poiché groundgroupsDb sembra vuoto o inesistente!"))
            end
            timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
        end
    end
end

local function check_CTLD_CSAR()
    if AIEN.config.dismount == true then
        if ctld or csar then
            AIEN.config.dismount = false
            env.info(("AIEN.check_CTLD_CSAR, identified CTLD or CSAR script being active, disabling AIEN dismount feature to prevent issues"))
            mountedDb         = {}
            infcarrierDb      = {}
            trigger.action.outText("AIEN information: identified CTLD or CSAR script being active, disabling AIEN dismount feature to prevent issues", 20)
        end
    end
end

-- ISR update, PHASE "B"
local function update_ISR() -- basically clean old ISR data
    if PHASE == "B" then -- confirm correct PHASE of performPhaseCycle
        if intelDb and next(intelDb) ~= nil then -- check that table exist and that it's not void
            if not phase_index then -- escape condition from the 2nd loop!
                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
                -- debug steps
                if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
                    dumpTableAIEN("intelDb.lua", intelDb, "int")
                end
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_ISR: fase B completed"))
                end

            else
                local tData = intelDb[phase_index]
                if tData then
                    --local remove = false
                    if not tData.obj or tData.obj:isExist() == false then
                        if AIEN.config.AIEN_debugProcessDetail then
                            env.info((tostring(ModuleName) .. ", update_ISR, target id " .. tostring(phase_index) .. " missing. Removing it"))
                        end
                        intelDb[phase_index] = nil
                        phase_keys = createIterator(intelDb) 
                    else
                        if tData.targeted then
                            if type(tData.targeted) == "number" then
                                if timer.getTime() - tData.targeted >= AIEN.config.targetedTimeout then
                                    if AIEN.config.AIEN_debugProcessDetail then
                                        env.info((tostring(ModuleName) .. ", update_ISR, target id " .. tostring(phase_index) .. " is still targeted. Removing it"))
                                    end
                                    intelDb[phase_index].targeted = nil
                                end
                            end
                        end
                    end
                end
                phase_index = getNextKey(phase_keys, phase_index)
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            end
        else
            AIEN.changePhase()
            timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            -- debug steps
            if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
                dumpTableAIEN("intelDb.lua", intelDb, "int")
            end
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_ISR: fase B skipped"))
            end            
        end
    end
end

-- DRONE update, PHASE "C"
local function update_DRONE()
    if PHASE == "C" then -- confirm correct PHASE of performPhaseCycle
        if droneunitDb and next(droneunitDb) ~= nil then -- check that table exist and that it's not void
            if not phase_index then -- escape condition from the 2nd loop!
                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
                -- debug steps
                if AIEN.config.AIEN_debugProcessDetail and AIEN_io and AIEN_lfs then
                    dumpTableAIEN("droneunitDb.lua", droneunitDb, "int")
                end
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_DRONE: fase B completata"))
                end

            else
                local dData = droneunitDb[phase_index]
                if dData then
                    local remove = false
                    if dData.group then
                        if dData.group and dData.group:isExist() == true then
                            -- update/create sa
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info((tostring(ModuleName) .. ", update_DRONE, add SA " .. tostring(dData.n)))
                            end
                            dData.sa = getSA(dData.group)
                        else
                            remove = true
                        end
                    else
                        remove = true
                    end

                    if remove == true then
                        if AIEN.config.AIEN_debugProcessDetail then
                            env.info((tostring(ModuleName) .. ", update_DRONE, group name " .. tostring(dData.n) .. " missing. Removing it"))
                        end
                        droneunitDb[phase_index] = nil
                        phase_keys = createIterator(droneunitDb)                        
                    end

                end
                phase_index = getNextKey(phase_keys, phase_index)
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            end
        else
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_DRONE, no drone available!"))
            end
            AIEN.changePhase()
            timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_DRONE: fase B completata"))
            end
        end
    end

end

-- ARTY update, PHASE "D"
local function update_ARTY()
    if PHASE == "D" then -- confirm correct PHASE of performPhaseCycle
        if groundgroupsDb and next(groundgroupsDb) ~= nil then -- check that table exist and that it's not void
            if not phase_index or AIEN.config.firemissions == false then -- escape condition from the 2nd loop!
                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_ARTY: phase D completed or skipped"))
                end
            else
                if not underAttack[phase_index] then 
                    local gData = groundgroupsDb[phase_index]
                    if gData then

                        local AI_consent = true
                        if gData.coa == 2 and AIEN.config.blueAI == false then
                            AI_consent = false
                        end
                        if gData.coa == 1 and AIEN.config.redAI == false then
                            AI_consent = false
                        end                
                        local remove = false
                        
                        if AI_consent == true and groupAllowedForAI(gData.group) == true then -- both coalition AI should be on and group exclusion tag shouldn't be there
                            if gData.group then
                                if gData.group and gData.group:isExist() == true and gData.sa and gData.sa.pos then
                                    if not underAttack[phase_index] and gData.tasked == false then
                                        if gData.class == "MLRS" or gData.class == "ARTY" then
                                            if gData.threat then -- necessary to understand available firing range
                                                -- check ammo
                                                local ammoAvail = 0
                                                local units = gData.group:getUnits()
                                                for _, uData in pairs(units) do
                                                    local ammoTbl = uData:getAmmo()
                                                    if ammoTbl then
                                                        for aId, aData in pairs(ammoTbl) do 
                                                            if aId == 1 then
                                                                if aData.count > ammoAvail then
                                                                    ammoAvail = aData.count + ammoAvail
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                                local roundsToFire = 0
                                                if ammoAvail > 30 then
                                                    roundsToFire = 30
                                                else
                                                    roundsToFire = ammoAvail
                                                end

                                                if roundsToFire > 0 then -- add different behaviour for precision guided MLRS

                                                    if gData.artyWpnGuidance and gData.artyWpnGuidance > 0 then
                                                        -- check targets, precision fire method, multiple points for multiple targets (guided missiles)
                                                        if AIEN.config.AIEN_debugProcessDetail then
                                                            env.info((tostring(ModuleName) .. ", update_ARTY, group " .. gData.n .. " is capable of precision fire, using multiple targets method"))
                                                        end

                                                        local firePoints = {}
                                                        local _volume = {
                                                            id = world.VolumeType.SPHERE,
                                                            params = {
                                                                point = gData.sa.pos,
                                                                radius = gData.threat*0.85,
                                                            },
                                                        }

                                                        local _search = function(_obj)
                                                            -- revTODO warning with "pcall", it's a costly feature -> Chromium: check this out  -> wanted to avoid risk of weirdness over DCS bugs
                                                            pcall(function()
                                                                if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() and _obj:getCoalition() ~= gData.coa then
                                                                    
                                                                    local _obj_id = _obj:getID()
                                                                    
                                                                    -- dist check by Leka
                                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                                        env.info((tostring(ModuleName) .. ", update_ARTY, checking _obj_id " .. tostring(_obj_id) .. " for group " .. tostring(gData.n) .. ", threat min: ".. tostring(gData.threatmin) .. ", threat max: ".. tostring(gData.threat) .. ", dist " .. tostring(getDist(gData.sa.pos, _obj:getPoint()))))
                                                                    end
                                                                    if getDist(gData.sa.pos, _obj:getPoint()) > gData.threat * 0.85 then 
                                                                        return
                                                                    end
                                                                    if gData.threatmin then
                                                                        if getDist(gData.sa.pos, _obj:getPoint()) < gData.threatmin * 1.05 then 
                                                                            return
                                                                        end
                                                                    end 

                                                                    local report = intelDb[_obj_id]
                                                                    if report and report.speed < 1 and report.targeted == nil then
                                                                        local lastContact = (timer.getTime() - report.record )
                                                                        if lastContact < AIEN.config.artyFireLastContactThereshold then
                                                                            local timeFactor = (AIEN.config.artyFireLastContactThereshold-lastContact)/AIEN.config.artyFireLastContactThereshold
                                                                            local pri = classPriority[report.cls]
                                                                            if not pri then
                                                                                pri = 0.5
                                                                            end
                                                                            pri = pri * timeFactor
                                                                            local go = getDangerClose(report.pos, gData.coa)
                                                                            if go == false then
                                                                                firePoints[#firePoints+1] = {o = _obj_id, id = report.cls, p = report.pos, l = pri, t = timer.getTime()}
                                                                            else
                                                                                if AIEN.config.AIEN_debugProcessDetail then
                                                                                    env.info((tostring(ModuleName) .. ", update_ARTY, target skipped for danger close"))
                                                                                end
                                                                            end
                                                                        end
                                                                    end

                                                                end
                                                            end)
                                                        end
                                                        world.searchObjects(Object.Category.UNIT, _volume, _search)

                                                        -- issuing mission
                                                        if firePoints and #firePoints > 0 then
                                                            
                                                            -- sort by priority
                                                            table.sort(firePoints, function(a, b) return a.l > b.l end)

                                                            local shotLimit = roundsToFire
                                                            if shotLimit > 4 then
                                                                shotLimit = 4
                                                            end
                                                            if #firePoints > shotLimit then
                                                                -- limit number of targets to max 4
                                                                local limitedFirePoints = {}
                                                                for i = 1, shotLimit do
                                                                    limitedFirePoints[i] = firePoints[i]
                                                                end
                                                                firePoints = limitedFirePoints
                                                            end

                                                            if AIEN.config.AIEN_debugProcessDetail then
                                                                env.info((tostring(ModuleName) .. ", update_ARTY, suitable targets found for precision fire : " .. tostring(gData.n) .. ", will fire " .. tostring(#firePoints) .. " rounds, guided"))
                                                            end

                                                            for fId, fData in pairs(firePoints) do
                                                                gData.tasked = true
                                                                gData.taskTime = timer.getTime()
                                                                gData.firePoint = fData.p
                                                                local description = nil
                                                                if fData.id then
                                                                    description = "Target is " .. tostring(fData.id)
                                                                end

                                                                local skip = nil
                                                                if fId == 1 then
                                                                    skip = true
                                                                end

                                                                groupfireAtPoint({gData.group, fData.p, 1, description, nil, skip})

                                                                if intelDb[fData.o] then
                                                                    intelDb[fData.o].targeted = timer.getTime()
                                                                end
                                                            end

                                                        end

                                                    else
                                                        
                                                        -- check targets, normal fire method, one point with radius (non guided missiles or shells)
                                                        local firePoint = nil
                                                        local targetId = nil
                                                        local _volume = {
                                                            id = world.VolumeType.SPHERE,
                                                            params = {
                                                                point = gData.sa.pos,
                                                                radius = gData.threat*0.85,
                                                            },
                                                        }

                                                        local curPri = 0
                                                        local _search = function(_obj)
                                                            -- revTODO warning with "pcall", it's a costly feature -> Chromium: check this out  -> wanted to avoid risk of weirdness over DCS bugs
                                                            pcall(function()
                                                                if _obj ~= nil and Object.getCategory(_obj) == 1 and _obj:isExist() and _obj:getCoalition() ~= gData.coa then
                                                                    
                                                                    local _obj_id = _obj:getID()

                                                                    -- dist check by Leka
                                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                                        env.info((tostring(ModuleName) .. ", update_ARTY, checking _obj_id " .. tostring(_obj_id) .. " for group " .. tostring(gData.n) .. ", threat min: ".. tostring(gData.threatmin) .. ", threat max: ".. tostring(gData.threat) .. ", dist " .. tostring(getDist(gData.sa.pos, _obj:getPoint()))))
                                                                    end
                                                                    if getDist(gData.sa.pos, _obj:getPoint()) > gData.threat * 0.85 then 
                                                                        return
                                                                    end
                                                                    if gData.threatmin then
                                                                        if getDist(gData.sa.pos, _obj:getPoint()) < gData.threatmin * 1.05 then 
                                                                            return
                                                                        end
                                                                    end 

                                                                    local report = intelDb[_obj_id]
                                                                    if report and report.speed < 1 and report.targeted == nil then
                                                                        local lastContact = (timer.getTime() - report.record )
                                                                        if lastContact < AIEN.config.artyFireLastContactThereshold then
                                                                            local timeFactor = (AIEN.config.artyFireLastContactThereshold-lastContact)/AIEN.config.artyFireLastContactThereshold
                                                                            local pri = classPriority[report.cls]
                                                                            if not pri then
                                                                                pri = 0.5
                                                                            end
                                                                            pri = pri * timeFactor
                                                                            if pri > curPri then
                                                                                local go = getDangerClose(report.pos, gData.coa)
                                                                                if go == false then
                                                                                    curPri = pri
                                                                                    firePoint = report.pos
                                                                                    targetId = report.cls
                                                                                    report.targeted = timer.getTime()
                                                                                else
                                                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                                                        env.info((tostring(ModuleName) .. ", update_ARTY, target skipped for danger close"))
                                                                                    end
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                            end)
                                                        end
                                                        world.searchObjects(Object.Category.UNIT, _volume, _search)
                                                        
                                                        -- issuing mission
                                                        if firePoint then
                                                            if AIEN.config.AIEN_debugProcessDetail then
                                                                env.info((tostring(ModuleName) .. ", update_ARTY, suitable target found for : " .. tostring(gData.n) .. ": " .. tostring(targetId) .. ", will fire " .. tostring(roundsToFire) .. " rounds, unguided"))
                                                            end
                                                            gData.tasked = true
                                                            gData.taskTime = timer.getTime()
                                                            gData.firePoint = firePoint
                                                            local description = nil
                                                            if targetId then
                                                                description = "Target is " .. tostring(targetId)
                                                            end

                                                            groupfireAtPoint({gData.group, firePoint, roundsToFire, description})
                                                        end
                                                    end
                                                end

                                            else
                                                if AIEN.config.AIEN_debugProcessDetail then
                                                    env.info((tostring(ModuleName) .. ", update_ARTY, threat range not available"))
                                                end
                                            end
                                        end
                                    end
                                else
                                    remove = true
                                end
                            else
                                remove = true
                            end
                        end

                        if remove == true then
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info((tostring(ModuleName) .. ", update_ARTY, group name " .. tostring(gData.n) .. " missing. Removing it"))
                            end
                            groundgroupsDb[phase_index] = nil
                            phase_keys = createIterator(groundgroupsDb)                        
                        end

                    end
                end
                phase_index = getNextKey(phase_keys, phase_index)
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            end
        else
            PHASE = "Initialization"
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_ARTY, reinizializzazione dei DB, poiché groundgroupsDb sembra vuoto o inesistente!"))
            end
            timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
        end
    end
end

-- INITIATIVE update, PHASE "E"
local function update_TACTICAL()
    if PHASE == "E" then -- confirm correct PHASE of performPhaseCycle


                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_INITIATIVE: phase E completed or skipped. movingGroups: " .. tostring(movingGroups) .. ", max allowed: " .. tostring(AIEN.config.maxGroupInMovement)))
                end       


    end
end

-- INITIATIVE update, PHASE "F"
local function update_INITIATIVE()
    if PHASE == "E" then -- confirm correct PHASE of performPhaseCycle
        if groundgroupsDb and next(groundgroupsDb) ~= nil then -- check that table exist and that it's not void
            if not phase_index or AIEN.config.initiative == false or movingGroups >= AIEN.config.maxGroupInMovement then -- escape condition from the 2nd loop!
                if AIEN.config.AIEN_debugProcessDetail then
                    env.info((tostring(ModuleName) .. ", update_INITIATIVE: phase F completed or skipped. movingGroups: " .. tostring(movingGroups) .. ", max allowed: " .. tostring(AIEN.config.maxGroupInMovement)))
                end                
                AIEN.changePhase()
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            else
                if not underAttack[phase_index] then -- skip if group is under attack
                    local gData = groundgroupsDb[phase_index]
                    if gData then
                        if gData.hasMeRoute == false then
                            local otherCoa = nil
                            local AI_consent = true
                            if gData.coa == 2 and AIEN.config.blueAI == false then
                                AI_consent = false
                                otherCoa = 1
                            end
                            if gData.coa == 1 and AIEN.config.redAI == false then
                                AI_consent = false
                                otherCoa = 2
                            end                
                            local remove = false
                            
                            if AI_consent == true then -- both coalition AI should be on and group exclusion tag shouldn't be there
                                if groupAllowedForAI(gData.group) == true then
                                    if gData.group then
                                        if gData.group and gData.group:isExist() == true then
                                            if gData.sa and gData.sa.pos then
                                                if gData.tasked == false then
                                                    if gData.class == "MBT" or gData.class == "ATGM" or gData.class == "IFV" or gData.class == "APC" then 
                                                        --if AIEN.config.AIEN_debugProcessDetail then
                                                        --    env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " is in contact with enemy, evaluating direct threat"))
                                                        --end  

                                                        if gData.sa and gData.sa.str > 3 then
                                                            if gData.sa.targets and gData.sa.targets ~= {} then

                                                                local nearestDist = AIEN.config.initiativeRange or 10000 -- default value
                                                                local nearest       = nil -- data of the group in groundgroupsDb, not the object

                                                                for tId, tData in pairs(gData.sa.targets) do

                                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                                        env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. "  check target: " .. tostring(tData.object:getName())))
                                                                    end  

                                                                    if tData.object and tData.object:isExist() == true then
                                                                        local g = tData.object:getGroup()
                                                                        local g_id = g:getID()
                                                                        local e = groundgroupsDb[g_id]

                                                                        if e and e.sa and e.sa.pos then
                                                                            local d = getDist(gData.sa.pos, e.sa.pos, true)
                                                                            if AIEN.config.AIEN_debugProcessDetail then
                                                                                env.info((tostring(ModuleName) .. ", update_INITIATIVE: tgt distance " .. tostring(d) .. " meters"))
                                                                            end                                                                      

                                                                            local d = getDist(gData.sa.pos, e.sa.pos)
                                                                            if d < nearestDist then
                                                                                nearest         = e
                                                                                nearestDist     = d
                                                                                if AIEN.config.AIEN_debugProcessDetail then
                                                                                    env.info((tostring(ModuleName) .. ", update_INITIATIVE: defined as nearest"))
                                                                                end                                                                             
                                                                            end
                                                                        end
                                                                    end
                                                                end

                                                                if nearest then
                                                                    local en_str = nearest.sa.str or 5 -- default value
                                                                    local ow_str = gData.sa.str
                                                                    
                                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                                        env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. ":  nearest enemy group " ..  tostring(nearest.n) .. " strength: " .. tostring(en_str) .. ", own strength: " .. tostring(ow_str)))
                                                                    end

                                                                    if ow_str > en_str then
                                                                        local vec3 = pointBetween(gData.sa.pos, nearest.sa.pos, 5000)
                                                                        if AIEN.config.AIEN_debugProcessDetail then
                                                                            env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. "  found suitable destination for movement"))
                                                                        end         
                                                                        
                                                                        -- message feedback
                                                                        if AIEN.config.message_feed == true then

                                                                            local lat, lon = coord.LOtoLL(vec3)
                                                                            local MGRS = coord.LLtoMGRS(coord.LOtoLL(vec3))
                                                                            if lat and lon then

                                                                                local LL_string = tostringLL(lat, lon, 0, true)
                                                                                local MGRS_string = tostringMGRS(MGRS ,4)

                                                                                local txt = ""
                                                                                txt = txt .. tostring(gData.n) .. ", C2, " .. ", we're moving to engage hasty targets, coordinates:"
                                                                                txt = txt .. "\n" .. tostring(MGRS_string) .. "\n" .. tostring(LL_string)
                                                                                txt = txt .. "\n" .. "target is " .. tostring(nearest.class)
                                                                                
                                                                                local vars = {"text", txt, 20, nil, nil, nil, gData.coa}

                                                                                multyTypeMessage(vars)

                                                                            end
                                                                        end

                                                                        gData.tasked = true
                                                                        gData.taskTime = timer.getTime()
                                                                        moveToPoint(gData.group, vec3, 300, 100, false, "cone", true, false, false, nil)
                                                                    else
                                                                        if AIEN.config.AIEN_debugProcessDetail then
                                                                            env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " is weaker than the nearest enemy, skip initiative"))
                                                                        end                                                            

                                                                    end
                                                                else
                                                                    --if AIEN.config.AIEN_debugProcessDetail then
                                                                        --env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " no suitable enemy within " .. tostring(AIEN.config.initiativeRange/1000) .. " km, skip initiative"))
                                                                    --end                                                      
                                                                end
                                                            else
                                                                if AIEN.config.AIEN_debugProcessDetail then
                                                                    env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " no targets identified in targets table, skip initiative"))
                                                                end                                                      
                                                            end
                                                        else
                                                            if AIEN.config.AIEN_debugProcessDetail then
                                                                env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " gData sa not available or strenght not available, skip initiative"))
                                                            end  
                                                        end
                                                    end
                                                else
                                                    if AIEN.config.AIEN_debugProcessDetail then
                                                        env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " is already tasked, skip initiative"))
                                                    end  
                                                end                                            
                                            else
                                                if AIEN.config.AIEN_debugProcessDetail then
                                                    env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " SA not available"))
                                                end                                        
                                            end
                                        else
                                            if AIEN.config.AIEN_debugProcessDetail then
                                                env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " not available"))
                                            end
                                        end
                                    else
                                        if AIEN.config.AIEN_debugProcessDetail then
                                            env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " missing group info in the db"))
                                        end
                                    end
                                else
                                    if AIEN.config.AIEN_debugProcessDetail then
                                        env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " specific group not allowed for AI, skipping"))
                                    end                                
                                end
                            end
                        else
                            if AIEN.config.AIEN_debugProcessDetail then
                                env.info((tostring(ModuleName) .. ", update_INITIATIVE: group " .. tostring(gData.n) .. " already has a planned route from ME, skipping"))
                            end                                
                        end                            
                    end
                else
                    if AIEN.config.AIEN_debugProcessDetail then
                        env.info((tostring(ModuleName) .. ", update_INITIATIVE: group is under attack, skip initiative"))
                    end                      
                end
                phase_index = getNextKey(phase_keys, phase_index)
                timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
            end
        else
            PHASE = "Initialization"
            if AIEN.config.AIEN_debugProcessDetail then
                env.info((tostring(ModuleName) .. ", update_ARTY, reinizializzazione dei DB, poiché groundgroupsDb sembra vuoto o inesistente!"))
            end
            timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)
        end
    end
end

-- 1ST LEVEL CYCLE FUNCTIONS

function AIEN.changePhase()
    if PHASE == "Initialization" then -- udpate terrain data
        PHASE = "A"
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end    

    elseif PHASE == "A" then -- udpate terrain data
        PHASE = "B"
        phase_keys = nil
        phase_keys = createIterator(intelDb) -- focus phase_keys on intelDb
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end

    elseif PHASE == "B" then
        PHASE = "C"
        phase_keys = nil
        phase_keys = createIterator(droneunitDb) -- focus phase_keys on droneunitDb
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end

    elseif PHASE == "C" then
        PHASE = "D"
        phase_keys = nil
        phase_keys = createIterator(groundgroupsDb) -- focus phase_keys on groundgroupsDb
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end
        
    elseif PHASE == "D" then
        
        PHASE = "E"
        phase_keys = nil
        phase_keys = createIterator(groundgroupsDb) -- focus phase_keys on groundgroupsDb -- QUESTO?!?!?!?!
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end       

    --[[ elseif PHASE == "E" then
        PHASE = "F"
        phase_keys = nil
        phase_keys = createIterator(groundgroupsDb) -- focus phase_keys on groundgroupsDb
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end  
    --]]--         
    
    elseif PHASE == "E" then
        PHASE = "Z" -- LAST STEP
        AIEN.changePhase()

    elseif PHASE == "Z" then

        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase: movingGroups reset. Value was: " .. tostring(movingGroups) .. ", max allowed: " .. tostring(AIEN.config.maxGroupInMovement)))
        end        
        movingGroups = 0 -- reset movingGroups counter        

        PHASE = "A"
        phase_keys = nil
        phase_keys = createIterator(groundgroupsDb) -- focus phase_keys on groundgroupsDb
        phase_index = phase_keys[1]
        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.changePhase, new PHASE: " .. tostring(PHASE)))
        end


    end
end

function AIEN.performPhaseCycle()

    if PHASE == "Initialization" then
        populate_Db()
        phase_keys = nil
        phase_keys = createIterator(groundgroupsDb) -- focus phase_keys on groundgroupsDb
        phase_index = phase_keys[1]        
        AIEN.changePhase()
        timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + phaseCycleTimer)

        if AIEN.config.AIEN_debugProcessDetail then
            env.info((tostring(ModuleName) .. ", AIEN.config.blueAI:        " .. tostring(AIEN.config.blueAI)))
            env.info((tostring(ModuleName) .. ", AIEN.config.redAI:         " .. tostring(AIEN.config.redAI)))
            env.info((tostring(ModuleName) .. ", AIEN.config.firemissions:  " .. tostring(AIEN.config.firemissions)))
            env.info((tostring(ModuleName) .. ", AIEN.config.reactions:     " .. tostring(AIEN.config.reactions)))
            env.info((tostring(ModuleName) .. ", AIEN.config.suppression:   " .. tostring(AIEN.config.suppression)))
            env.info((tostring(ModuleName) .. ", AIEN.config.dismount:      " .. tostring(AIEN.config.dismount)))
            env.info((tostring(ModuleName) .. ", AIEN.config.initiative:    " .. tostring(AIEN.config.initiative)))
        end            

    elseif PHASE == "A" then
        check_CTLD_CSAR()
        update_GROUND()

    elseif PHASE == "B" then
        update_ISR()

    elseif PHASE == "C" then
        update_DRONE()

    elseif PHASE == "D" then
        update_ARTY()

    elseif PHASE == "E" then
        update_INITIATIVE()   
        --update_TACTICAL()      

    --elseif PHASE == "F" then
        --update_INITIATIVE()   

    end
end

--###### EVENT HANDLER FUNCTIONS ###################################################################

-- I believe this is self explanatory. Still, the event_hit function holds a lot on reactions and decision making. I'm sorry if it appear confuse, but currently it fits my condition XD.

local function event_hit(unit, shooter, weapon) -- this functions run eacht time a unit gets an hit. Unit only, no statics. That's basically the core for reactions
    if not unit and not shooter then
        env.info("AIEN.event_hit: both unit and shooter nil")
        return
    end

    --if AIEN.config.reactions == true then
        local ugrp = nil
        local unitCat = nil
        
        if unit then
            local ok, g = pcall(Unit.getGroup, unit)
            if ok and g and g:isExist() then
                ugrp = g
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info("AIEN.event_hit: group from unit ok -> "..tostring(g:getName()))
                    env.info("AIEN.event_hit: group from unit g -> "..tostring(g:getName()))
                end
            end
        end
        
        if ugrp then
            local ok, c, c2 = pcall(Group.getCategory, ugrp)
            if ok and c then
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info("AIEN.event_hit: category from group ok -> "..tostring(ok))
                    env.info("AIEN.event_hit: category from group c -> "..tostring(c))
                end
                unitCat = c
            end
        end

        if not unitCat then
            return
        end

        local shooterCat = pcallGetCategory(shooter)
        if AIEN.config.AIEN_debugProcessDetail == true then
            env.info("AIEN.event_hit: shooterCat -> "..tostring(shooterCat))
        end

        if unitCat == 2 and shooterCat == 1 then

            local vehicle       = unit:hasAttribute("Vehicles")
            local infantry      = unit:hasAttribute("Infantry")
            local armoured      = unit:hasAttribute("Armored vehicles")
            local position      = unit:getPoint()

            local ground_unit   = nil
            if vehicle == true then --  or infantry == true
                ground_unit = true
            end

            if ground_unit then
                local group     = unit:getGroup()
            
                if group and group:isExist() and groupAllowedForAI(group) == true then -- filtering both for existance and for exclusion tag being not there
                    
                    local AI_consent = true

                    -- filter for coalition
                    if group:getCoalition() == 2 and AIEN.config.blueAI == false then
                        AI_consent = false
                    end
                    if group:getCoalition() == 1 and AIEN.config.redAI == false then
                        AI_consent = false
                    end  

                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info(("AIEN.event_hit, S_EVENT_HIT, coalition check return AI_consent " .. tostring(AI_consent) ))
                    end	

                    if AI_consent == true then
                        if AIEN.config.AIEN_zoneFilter and AIEN.config.AIEN_zoneFilter ~= "" then
                            AI_consent = groupInZone(group)
                            if AIEN.config.AIEN_debugProcessDetail == true then
                                env.info(("AIEN.event_hit, S_EVENT_HIT, group zone check return AI_consent " .. tostring(AI_consent) ))
                            end	
                        end
                    end
                    
                    if AI_consent == true then

                        trigger.action.groupStopMoving(group)

                        -- suppression part
                        if AIEN.config.suppression == true and armoured then
                            local suppressEffects = false
                            if shooter:hasAttribute("Air") or shooter:hasAttribute("Ships") or shooter:hasAttribute("Indirect fire") then
                                suppressEffects = true
                            end
                            if suppressEffects == true then
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info(("AIEN.event_hit, S_EVENT_HIT, group is suppressed: " .. tostring(group:getName()) ))
                                end		
                                groupSuppress(group)
                            end
                        end

                        -- dismount part
                        if AIEN.config.dismount == true then
                            if not underAttack[group:getID()] then
                                if shooter:hasAttribute("Air") then
                                    timer.scheduleFunction(groupDeployManpad, group, timer.getTime() + aie_random(8, 15))
                                    if AIEN.config.AIEN_debugProcessDetail == true then
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, shooter is airborne, manpad dismount happens"))
                                    end	 
                                elseif shooter:hasAttribute("Ground Units") then
                                    local d = AIEN.config.infantrySearchDist
                                    local dist = getDist(shooter:getPoint(), position)
                                    if dist < d then
                                        timer.scheduleFunction(groupDeployTroop, group, timer.getTime() + aie_random(8, 15))
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, distance is close, infantry dismount happens"))
                                        end	    
                                    end                            
                                end
                            end
                        end

                        -- reaction part
                        local choosenAct = nil
                        if AIEN.config.reactions == true then
                            if not underAttack[group:getID()] then -- if a group has already been identified as "attacked", it won't repeat all the whole process every time or it could became a freaking mess in case of multiple hits
                                
                                if AIEN.config.AIEN_debugProcessDetail == true then
                                    env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) ))
                                end					

                                -- retrieve SA & Controller
                                local con = group:getController()
                                local db_group = groundgroupsDb[group:getID()]
                                if con and db_group and db_group.sa then

                                    -- define if the attacker is known and and with what details
                                    local s_detected, s_visible, s_lastTime, s_type, s_distance, s_lastPos, s_lastVel, s_cat, w_cat, o_cat, s_indirect, s_close, s_fireMis, a_pos, o_cls, s_cls, o_pos
                                    w_cat       = 0
                                    s_cat       = nil
                                    s_indirect  = 0
                                    s_close     = 0
                                    s_fireMis   = 0
                                    o_cls       = db_group.sa.cls
                                    s_cls       = "UNKN"
                                    o_pos       = unit:getPoint()
                                    
                                    -- define weapon info, used to identify arty attack
                                    if weapon and weapon:isExist() then
                                        w_cat = weapon:getDesc().category
                                        --[[-- 
                                            Weapon.Category
                                            SHELL     0
                                            MISSILE   1
                                            ROCKET    2
                                            BOMB      3
                                        --]]--
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", w_cat: " .. tostring(w_cat) ))
                                        end								
                                    end

                                    if shooter and con then
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, shooter known"))
                                        end	

                                        -- revise a_pos
                                        a_pos = shooter:getPoint()

                                        -- parameters identification
                                        s_detected , s_visible , s_lastTime , s_type , s_distance , s_lastPos , s_lastVel = con:isTargetDetected(shooter)

                                        o_cat, s_cat = shooter:getCategory()
                                        s_cls = getUnitClass(shooter)


                                        --[[ o_cat: 
                                            UNIT    1
                                            WEAPON  2
                                            STATIC  3
                                            BASE    4
                                            SCENERY 5
                                            Cargo   6
                                        --]]--                                        
                                        
                                        --[[ s_cat: 
                                            AIRPLANE      = 0,
                                            HELICOPTER    = 1,
                                            GROUND_UNIT   = 2,
                                            SHIP          = 3,
                                            STRUCTURE     = 4
                                        --]]--
                                        
                                        -- shooter is indirect fire
                                        if shooter:hasAttribute("Indirect fire") then
                                            s_indirect = 1
                                        end

                                        -- shooter is close
                                        if a_pos and position then
                                            local d = db_group.sa.rng or 1500
                                            local dist = getDist(a_pos, position)
                                            if dist < d then
                                                s_close = 1
                                            end
                                        end      

                                        -- position and speed
                                        --[[ removed cause of issues with isTargetDetected function returned variables
                                        if a_pos and s_lastVel and s_lastTime then
                                            if timer.getTime() - s_lastTime < 30 and s_lastVel < 1 then
                                                s_fireMis = 1
                                            end
                                        end
                                        --]]--
                                        local rnd = math.random(1,100)
                                        if rnd > 70 then
                                            s_fireMis = 1
                                        end


                                    else -- try to address things when the shooter is unknown, based on weapon and effects
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, shooter unknown"))
                                        end	 

                                        if w_cat then
                                            --[[-- 
                                                Weapon.Category
                                                SHELL     0
                                                MISSILE   1
                                                ROCKET    2
                                                BOMB      3
                                            --]]--
                                            if w_cat == 0 or w_cat == 2 then -- shooter is unknown, and the weapon is a shell or a rocket: artillery is possibile
                                                s_indirect = 1
                                                if AIEN.config.AIEN_debugProcessDetail == true then
                                                    env.info(("AIEN.event_hit, S_EVENT_HIT, shooter unknown but arty fire possibile"))
                                                end	 
                                            elseif w_cat == 1 or w_cat == 3 then -- shooter is unknown, and the weapon is a missile or a bomb: airborne threat is possibile
                                                s_cls = "ARBN"
                                                if AIEN.config.AIEN_debugProcessDetail == true then
                                                    env.info(("AIEN.event_hit, S_EVENT_HIT, shooter unknown but airborne fire possibile"))
                                                end	 
                                            end

                                        end
                                    end

                                    if AIEN.config.AIEN_debugProcessDetail == true then
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", w_cat: " .. tostring(w_cat) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", s_cat: " .. tostring(s_cat) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", s_indirect: " .. tostring(s_indirect) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", s_close: " .. tostring(s_close) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", s_fireMis: " .. tostring(s_fireMis) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", o_cls: " .. tostring(o_cls) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", s_cls: " .. tostring(s_cls) ))
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, group " .. tostring(group:getName()) .. ", a_pos: " .. tostring(a_pos) ))
                                    end	

                                    local av_ac = deepCopy(reactionsDb) 

                                    -- remove not doable actions due to missin informations
                                    if s_fireMis < 1 or AI_consent == false then -- shooter position is not sufficiently recent
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, s_fireMis is 0, won't be able to call fire support"))
                                        end	                                  
                                        av_ac[9] = nil
                                    end 
                                    if not a_pos or not s_detected then -- enemy position unknown
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, enemy not detected, won't be able to move toward the enemy"))
                                        end	                                  
                                        av_ac[5] = nil
                                    end
                                    if db_group.class == "ARTY" or db_group.class == "MISSILE" or db_group.class == "MLRS" then -- group is an arty or mlrs
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, ally is an arty or mlrs, won't be able to move toward the enemy"))
                                        end	                                  
                                        av_ac[5] = nil
                                    end
                                    if s_cat == 0 or s_cat == 1 or s_cls == "ARBN" then -- shooter is airborne
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            env.info(("AIEN.event_hit, S_EVENT_HIT, shooter is airborne, removing less sensed decision"))
                                        end	                                  
                                        av_ac[6] = nil -- remove attack
                                        av_ac[8] = nil -- remove ground support
                                        av_ac[3] = nil -- remove disperse
                                    end
                                    if s_cls ~= "ARBN" then -- shooter is not airborne
                                        av_ac[9] = nil -- remove cover ADS
                                    end
                                    if not unit:hasAttribute("Armored vehicles") then
                                        av_ac[4] = nil -- remove drop smoke
                                    end
                                
                                    -- filter available actions by skill
                                    local filter = db_group.skill
                                    if AIEN.config.skill_action_const == false then
                                        filter = filter * 2
                                    end

                                    for aSk, action in pairs(av_ac) do
                                        if aSk > filter then
                                            av_ac[aSk] = nil
                                        end
                                    end
                                    if AIEN.config.AIEN_debugProcessDetail == true then
                                        env.info(("AIEN.event_hit, S_EVENT_HIT, available actions " .. tostring(#av_ac) ))
                                    end
                                    
                                    -- calculate points for each remaining actions
                                    local bc_ac = {}
                                    for _, aData in pairs(av_ac) do
                                        local points = 0
                                        local px1 = aData["w_cat"][w_cat] or 0
                                        local px2 = aData["s_cat"][s_cat] or 0
                                        local px3 = aData["s_indirect"][s_indirect] or 0
                                        local px4 = aData["s_close"][s_close] or 0
                                        local px5 = aData["s_fireMis"][s_fireMis] or 0
                                        local px6 = aData["o_cls"][o_cls] or 0
                                        local px7 = aData["s_cls"][s_cls] or 0

                                        points = px1 + px2 + px3 + px4 + px5 + px6 + px7 
                                        if AIEN.config.AIEN_debugProcessDetail == true then
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for w_cat: " .. tostring(aData["w_cat"][w_cat])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for s_cat: " .. tostring(aData["s_cat"][s_cat])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for s_indirect: " .. tostring(aData["s_indirect"][s_indirect])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for s_close: " .. tostring(aData["s_close"][s_close])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for s_fireMis: " .. tostring(aData["s_fireMis"][s_fireMis])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for o_cls: " .. tostring(aData["o_cls"][o_cls])))
                                            --env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points for s_cls: " .. tostring(aData["s_cls"][s_cls])))
                                            env.info(("AIEN.event_hit, S_EVENT_HIT," .. tostring(aData.name) ..  ", points total: " .. tostring(points)))
                                        end	

                                        bc_ac[#bc_ac+1] = {name = aData.name, action = aData.action, rank = points}
                                    end
                                    table.sort(bc_ac, function(a,b)
                                        if a.rank and b.rank then
                                            return a.rank > b.rank 
                                        end
                                    end)

                                    -- record the attack, for preventing phases to act for 10 mins
                                    underAttack[group:getID()] = timer.getTime()

                                    choosenAct = executeReactions(group, o_pos, a_pos, bc_ac, db_group.sa, db_group.skill)

                                end

                            end
                        end

                        -- counter battery part
                        if choosenAct ~= "ac_fireMissionOnShooter" then
                            if AIEN.config.firemissions == true then
                                if shooter:getPoint() and position then
                                    counterBattery(position, shooter:getPoint(), group:getCoalition())
                                end
                            end
                        end

                    else
                        if AIEN.config.AIEN_debugProcessDetail == true then
                            env.info(("AIEN.event_hit, S_EVENT_HIT, AI consent is false"))
                        end	
                    end
                end
            else
                if AIEN.config.AIEN_debugProcessDetail == true then
                    env.info(("AIEN.event_hit, missing unit"))
                end	                
            end
        else
            if AIEN.config.AIEN_debugProcessDetail == true then
                env.info(("AIEN.event_hit, either shooter or unit are not valid units"))
            end	                
        end
    --end
end

local function event_birth(initiator)
    
    local check = pcallGetCategory(initiator)
    
    if check then
        local objCat = nil
        local subCat = nil
        objCat, subCat = initiator:getCategory()
        if objCat == 1 and subCat == 2 then -- unit, ground unit    
            local passFilter = false
            
            if not initiator:hasAttribute("Infantry") then
                passFilter = true
            else
                if AIEN.config.JTACasDrone == true and initiator:getTypeName() == "JTAC" then
                    passFilter = true
                end
            end
            
            if passFilter == true then
                local gp = initiator:getGroup()
                if gp then
                    if not groundgroupsDb[gp:getID()] then -- since event is launched for each unit, this prevent re-adding the same group multiple times
                        local c = getGroupClass(gp)
                        local det, thr = getRanges(gp)
                        local s = getGroupSkillNum(gp)
                        groupPreventDisperse(gp)
                        --env.info((tostring(ModuleName) .. ", event_birth: s " .. tostring(s)))
                        groundgroupsDb[gp:getID()] = {group = gp, class = c, n = gp:getName(), coa = gp:getCoalition(), detection = det, threat = thr, tasked = false, skill = s}
                        --env.info((tostring(ModuleName) .. ", event_birth: adding to groundgroupsDb " .. tostring(gp:getName() )))
                    end
                end
            end

        elseif objCat == 1 and subCat == 0 then -- unit, plane unit (drone)	
            local gp = initiator:getGroup() 
            if gp then				
                local c = nil
                if gp:getUnits() and #gp:getUnits() > 0 then
                    for _, un in pairs(gp:getUnits()) do
                        if un:hasAttribute("UAVs") then -- drone only
                            c = "UAV"
                        end
                    end
                end
                if c then
                    if AIEN.config.AIEN_debugProcessDetail == true then
                        env.info((tostring(ModuleName) .. ", event_birth: adding to droneunitDb " .. tostring(un:getName() )))
                    end
                    
                    droneunitDb[gp:getID()] = {group = gp, class = c, n = gp:getName(), coa = gp:getCoalition()}
                end                        					
            end
        end
    end
end

local function event_dead(initiator)
    
    -- revTODO why do this twice (once below and then calling Object.getCategory lower)? -> Chromium: check this out -> cause pcallGetCategory only return the objCat and not subCat 
    local check = pcallGetCategory(initiator)
    
    if check then
        local objCat = nil
        local subCat = nil
        objCat, subCat =  Object.getCategory(initiator)
        if objCat and subCat then
            if objCat == 1 and subCat == 2 then -- unit, ground unit    
                mountedDb[initiator:getID()] = nil
                infcarrierDb[initiator:getID()] = nil

            end
        end
    end
end

--## EVENTS HANDLING CALLS

AIEN.eventHandler = {} -- define event based real time unit reactions. I prefer to have 1 single handler that then will route itself on the right directions event based.
function AIEN.eventHandler:onEvent(event)	

    if event.id == world.event.S_EVENT_HIT then 
        local u = event.target
        local s = event.initiator
		local w	= event.weapon 

        event_hit(u, s, w)

    elseif event.id == world.event.S_EVENT_BIRTH then 
        local i = event.initiator
        if i then
            event_birth(i)
        end

    elseif event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_UNIT_LOST then 
        local i = event.initiator
        if i then
            event_dead(i)
        end

    end
end
world.addEventHandler(AIEN.eventHandler)



--## INIT SCRIPT
if AIEN.config.dontInitialize then
	env.info((ModuleName .. ": Loaded (BUT NOT INITIALIZED) " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date))
else
    timer.scheduleFunction(AIEN.performPhaseCycle, {}, timer.getTime() + 3)
	env.info((ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date))
end


--~=
