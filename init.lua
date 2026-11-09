local require=simpRequire('ZTC.')
Brik=require'briks'
require'rotsys_brik'

local modeLib={} ---@type Map<string | Techmino.Mode>
local skinLib={} ---@type Map<Techmino.Skin>
local skinPath={} ---@type Map<string>
local modeMeta={
    __index={
        initialize=NULL,
        settings={},
        layout='default',
        checkFinish=function() return true end,
        result=NULL,
        resultPage=NULL,
    },
    __metatable=true,
}

local layoutFuncs={}
do -- function layoutFuncs.default():
    local defaultPosList={
        alive={
            [1]={main={0,0}},
            [3]={main={0,0},
                {580,100,.5},
                {-580,100,.5},
            },
            [5]={main={0,0},
                {-580,-240,.5},
                {580,-240,.5},
                {-580,240,.5},
                {580,240,.5},
            },
            [7]={main={0,0},
                {-580,-300,.34},{-580,0,.34},{-580,300,.34},
                {580,-300,.34},{580,0,.34},{580,300,.34},
            },
            [17]={main={0,0},
                {-680,-360,.26},{-680,-120,.26},{-680,120,.26},{-680,360,.26},
                {-480,-360,.26},{-480,-120,.26},{-480,120,.26},{-480,360,.26},
                {480,-360,.26},{480,-120,.26},{480,120,.26},{480,360,.26},
                {680,-360,.26},{680,-120,.26},{680,120,.26},{680,360,.26},
            },
            [37]=(function()
                local l={main={0,0}}
                for y=-2.5,2.5 do
                    for x=0,2 do
                        table.insert(l,{-460-130*x,160*y,.17})
                        table.insert(l,{460+130*x, 160*y,.17})
                    end
                end
                return l
            end)(),
            [73]=(function()
                local l={main={0,0}}
                for y=-4,4 do
                    for x=0,3 do
                        table.insert(l,{-440-100*x,110*y,.13})
                        table.insert(l,{440+100*x, 110*y,.13})
                    end
                end
                return l
            end)(),
            [MATH.inf]={main={0,0}},
        },
        dead={
            [1]={{0,0}},
            [2]={
                {-380,0,.9},{380,0,.9},
            },
            [3]={
                {-520,0,.66},{-800,0,.66},{520,0,.66},
            },
            [4]={
                {-590,0,.5},{-200,0,.5},{200,0,.5},{590,0,.5},
            },
            [15]=(function()
                local l={}
                for y=-1,1 do
                    for x=-2,2 do
                        table.insert(l,{315*x,320*y,.36})
                    end
                end
                return l
            end)(),
            [32]=(function()
                local l={}
                for y=-1.5,1.5 do
                    for x=-3.5,3.5 do
                        table.insert(l,{200*x,240*y,.25})
                    end
                end
                return l
            end)(),
            [72]=(function()
                local l={}
                for y=-2.5,2.5 do
                    for x=-5.5,5.5 do
                        table.insert(l,{130*x,160*y,.17})
                    end
                end
                return l
            end)(),
            [MATH.inf]={},
        },
    }
    function layoutFuncs.default()
        local mode=GAME.mainPlayer and defaultPosList.alive or defaultPosList.dead
        local minCap=MATH.inf
        for count in next,mode do
            if count<=minCap and count>=#GAME.playerList then
                minCap=count
            end
        end
        local layoutData=mode[minCap]

        local pos=1
        for _,P in next,GAME.playerList do
            if P.isMain then
                P:setPosition(unpack(layoutData.main))
            else
                P:setPosition(unpack(layoutData[pos]))
                pos=pos+1
            end
        end
    end
end

---@class Techmino.Game
---@field playing boolean
---@field playerList Techmino.Player[] | false
---@field playerMap Map<Techmino.Player> | false
---@field camera Zenitha.Camera
---@field hitWaves table
---@field seed number | false
---@field mode Techmino.Mode | false
---@field mainID number | false
---@field mainPlayer Techmino.Player | false
---@field skinTime number
local GAME={
    playing=false,

    playerList=false,
    playerMap=false,

    camera=GC.newCamera(),
    hitWaves={},

    seed=false,
    mode=false,

    mainID=false,
    mainPlayer=false,

    skinTime=0,
}

GAME.camera.moveSpeed=12

---@type Techmino.MechLib
GAME.mechLib={}

-- Basic sound events, insert more for specific game designs
GAME.sndFunc={__metatable=true}
GAME.sndFunc.__index=GAME.sndFunc
for _,v in next,{
    'move','move_down','move_failed','touch','tuck',
    'rotate','rotate_init','rotate_locked','rotate_corners','rotate_failed',
    'drop','lock','clear_all',
    'hold','hold_init',
    'suffocate','desuffocate',
    'finish_win','finish_suffocate','finish_lockout','finish_topout',
    'finish_timeout','finish_rule','finish_exhaust','finish_taskfail','finish_other',
    'beep_rise','beep_drop','beep_notice',
} do GAME.sndFunc[v]=function(vol) SFX.play(v,vol) end end
function GAME.sndFunc.countdown(num,vol) SFX.play('countdown_'..MATH.clamp(num,1,3),vol) end
function GAME.sndFunc.clear(lines,vol) SFX.play('clear_'..MATH.clamp(lines,1,5),vol) end
function GAME.sndFunc.spin(lines,vol) SFX.play('spin_'..MATH.clamp(lines,0,3),vol) end
function GAME.sndFunc.combo(num,vol) SFX.play('combo_'..MATH.clamp(num,1,10),vol) end
-- Add lines (outside ZTC) like these (below) to register more sound functions
function GAME.sndFunc.frenzy(vol) SFX.play('frenzy',vol) end
function GAME.sndFunc.rotate_special(vol) SFX.play('rotate_special',vol) end

GAME.regFtoS,GAME.regStoF={},{}
---Flatten a table of functions into string-to-function and function-to-string maps
---@param obj table | function
---@param path string
function GAME.regFunc(obj,path)
    if type(obj)=='function' or type(obj)=='table' and rawget(obj,'__register') then
        GAME.regFtoS[obj]=path
        GAME.regStoF[path]=obj
    elseif type(obj)=='table' then
        for k,v in next,obj do
            if k~='__index' then
                GAME.regFunc(v,path.."."..k)
            end
        end
    end
end

GAME.regFunc(GAME.sndFunc,'GAME.sndFunc')

function GAME._refresh()
    TABLE.clear(modeLib)
    TABLE.update(GAME.mechLib,TABLE.linkSource({},require'mechanicLib',function(path) return FILE.load(path,'-lua') end,true))
    GAME.regFunc(GAME.mechLib,'mechLib')
end
GAME._refresh()

--- Register mode to the modeLib
---@param name string
---@param path string
function GAME.addMode(name,path)
    assert(type(name)=='string',"name must be string")
    assert(not modeLib[name],"mode "..tostring(name).." already exists")
    assert(type(path)=='string',"path must be string")
    if not (love.filesystem.getInfo(path) and FILE.isSafe(path)) then LOG('warn',"No mode file named "..tostring(name)) end
    modeLib[name]=path
end

function GAME.getMode(name)
    local M=modeLib[name]
    if type(M)=='table' then return M end
    ---@cast M string

    -- Load & Cache the mode file
    assert(love.filesystem.getInfo(M) and FILE.isSafe(M),"No mode file: "..tostring(name))
    M=FILE.load(M,'-lua')
    assert(type(M)=='table',"Mode file must return a table")
    setmetatable(M,modeMeta)
    assert(type(M.initialize)=='function',"[mode].initialize must be function")
    assert(type(M.settings)=='table',   "[mode].settings must be table")
    assert(type(layoutFuncs[M.layout])=='function',"[mode].layout type wrong")
    assert(type(M.checkFinish)=='function',"[mode].checkFinish must be function")
    assert(type(M.result)=='function',"[mode].result must be function")
    assert(type(M.resultPage)=='function',"[mode].resultPage must be function")
    for _,plyType in next,{'brik','gela','acry'} do
        if M.settings[plyType] then
            GAME.regFunc(M.settings[plyType].event,name)
        end
    end
    M.name=name
    modeLib[name]=M
    return M
end

--- Register skin to the skinLib
---@param name string
---@param path string
function GAME.addSkin(name,path)
    assert(type(name)=='string',"name must be string")
    assert(not skinPath[name],"skin "..tostring(name).." already exists")
    assert(type(path)=='string',"path must be string")
    if not (love.filesystem.getInfo(path) and FILE.isSafe(path)) then LOG('warn',"No skin file named "..tostring(name)) end
    skinPath[name]=path
end

---Set time for a skin and all its base skins
---@param skin Techmino.Skin
---@param time number ms
local function setSkinTime(skin,time)
    skin.time=time
    local mt=getmetatable(skin)
    local base=mt and rawget(mt,'__index')
    if type(base)=='table' then setSkinTime(base,time) end
end

---Load and cache a registered skin file
---@param name string
---@return Techmino.Skin?
local function loadSkin(name)
    local path=skinPath[name] or error("No skin named "..tostring(name),2)

    assert(love.filesystem.getInfo(path) and FILE.isSafe(path),"No skin file: "..tostring(name))
    local S=FILE.load(path,'-lua')
    assert(type(S)=='table',"Skin file must return a table")
    assert(getmetatable(S)==nil,"Skin table must not have metatable")

    local base=S.base
    if base~=nil then
        assert(type(base)=='string' and base~=name,"Skin.base must be a valid skin name")
        setmetatable(S,{__index=GAME.getSkin(base)})
    end

    if S.drawNext==nil then S.drawNext=true end
    if S.drawHold==nil then S.drawHold=true end
    assert(type(S.drawNext)=='boolean',"Skin.drawNext must be boolean")
    assert(type(S.drawHold)=='boolean',"Skin.drawHold must be boolean")

    skinLib[name]=S
    return S
end

setmetatable(skinLib,{
    __index=function(_,name) return loadSkin(name) end,
})

---@param name string
---@return Techmino.Skin
function GAME.getSkin(name)
    local S=skinLib[name]
    setSkinTime(S,math.floor(GAME.skinTime*1000))
    return S
end

function GAME.load(name,seed)
    -- print("Game Loaded: "..mode.."-"..seed)
    if GAME.mode then
        MSG.log('warn',"Game is running")
        return
    end
    GAME.playing=true
    GAME.playerList={}
    GAME.playerMap={}
    GAME.mainPlayer=false
    GAME.skinTime=0
    GAME.seed=seed or math.random(2^16,2^26)
    GAME.mode=GAME.getMode(name)
    if GAME.mode.initialize then GAME.mode.initialize() end
    if #GAME.playerList==0 then
        MSG.log('warn',"No players created in this mode")
    else
        if GAME.mainPlayer then
            local conf=CONF['game_'..GAME.mainPlayer.gameMode]
            if conf then GAME.mainPlayer:loadSettings(conf) end
        end
        if GAME.mode.settings then
            for i=1,#GAME.playerList do
                local conf=GAME.mode.settings[GAME.playerList[i].gameMode]
                if conf then
                    GAME.playerList[i]:loadSettings(conf)
                end
            end
        end

        for i=1,#GAME.playerList do
            GAME.playerList[i]:initialize()
            GAME.playerList[i]:triggerEvent('playerInit')
        end

        layoutFuncs[GAME.mode['layout']]()
    end

    GAME.hitWaves={}
end

function GAME.unload()
    -- print("Game Unloaded")
    GAME.playing=false
    GAME.playerList=false
    GAME.playerMap=false

    GAME.hitWaves={}

    GAME.seed=false
    GAME.mode=false

    GAME.mainID=false
    GAME.mainPlayer=false
end

---@param id integer
---@param pType 'brik' | 'gela' | 'acry'
---@param remote? boolean
function GAME.newPlayer(id,pType,remote)
    if not (type(id)=='number' and math.floor(id)==id and id>=1 and id<=1000) then
        MSG.log('error',"player id must be 1~1000 integer")
        return
    end

    local P
    if pType=='brik' then
        P=require'brikPlayer'.new(remote)
    elseif pType=='gela' then
        P=require'gelaPlayer'.new(remote)
    elseif pType=='acry' then
        P=require'acryPlayer'.new(remote)
    else
        MSG.log('error',"invalid player type :'"..tostring(pType).."'")
        return
    end

    P.gameMode=pType
    P.id=id
    P.team=0
    GAME.playerMap[id]=P
    table.insert(GAME.playerList,P)
end

function GAME.setMain(id)
    if GAME.mainPlayer then
        GAME.playerMap[GAME.mainPlayer].isMain=false
        GAME.mainID=false
        GAME.mainPlayer=false
    end
    if GAME.playerMap[id] then
        GAME.mainID=id
        GAME.mainPlayer=GAME.playerMap[id]
        GAME.mainPlayer.isMain=true
        GAME.mainPlayer.sound=true
    end
end

function GAME.setTeam(id,teamID)
    assert(type(teamID)=='number' and teamID>=0 and teamID%1==teamID,"Invalid team id")
    if GAME.playerMap[id] then
        GAME.playerMap[id].team=teamID
    end
end

function GAME.press(action,id)
    local p=id and GAME.playerMap[id] or GAME.mainPlayer
    p:pressKey(action)
end

function GAME.release(action,id)
    local p=id and GAME.playerMap[id] or GAME.mainPlayer
    p:releaseKey(action)
end

function GAME.cursorDown(x,y,tid,id)
    local p=id and GAME.playerMap[id] or GAME.mainPlayer
    if p.gameMode=='acry' then
    x,y=GAME.camera.transform:inverseTransformPoint(SCR.xOy_m:inverseTransformPoint(SCR.xOy:transformPoint(x,y)))
        p:mouseDown(x,y,tid)
    elseif CONF.system.touchControl then
        VCTRL.press(x,y,tid)
    end
end

function GAME.cursorMove(x,y,dx,dy,tid,id)
    local p=id and GAME.playerMap[id] or GAME.mainPlayer
    if p.gameMode=='acry' then
        x,y=GAME.camera.transform:inverseTransformPoint(SCR.xOy_m:inverseTransformPoint(SCR.xOy:transformPoint(x,y)))
        p:mouseMove(x,y,dx,dy,
            tid or
            IsMouseDown(1) and 1 or
            IsMouseDown(2) and 2 or
            3
        )
    elseif CONF.system.touchControl then
        VCTRL.move(x,y,tid)
    end
end

function GAME.cursorUp(x,y,tid,id)
    local p=id and GAME.playerMap[id] or GAME.mainPlayer
    if p.gameMode=='acry' then
        x,y=GAME.camera.transform:inverseTransformPoint(SCR.xOy_m:inverseTransformPoint(SCR.xOy:transformPoint(x,y)))
        p:mouseUp(x,y,tid)
    elseif CONF.system.touchControl then
        VCTRL.release(tid)
    end
end

---@param sender Techmino.Player | number | false
---@param atk table?
function GAME.send(sender,atk)
    if not atk then return end

    ---@type Techmino.Player
    local target

    -- Find target
    if atk.target==nil then
        ---@type Techmino.Player[]
        local l=GAME.playerList
        local sourceTeam=sender and sender.team or 0 -- 0 means no team, not Team 0
        if #l>1 then
            local count=0
            for i=1,#l do
                if sourceTeam==0 and l[i]~=sender or sourceTeam~=l[i].team then
                    count=count+1
                end
            end
            if count>0 then
                count=math.random(count)
                for i=1,#l do
                    if sourceTeam==0 and l[i]~=sender or sourceTeam~=l[i].team then
                        count=count-1
                        if count==0 then
                            target=l[i]
                            break
                        end
                    end
                end
            end
        end
    elseif type(atk.target)=='number' then
        target=GAME.playerMap[atk.target]
    else
        error("GAME.send: invalid target type")
    end

    -- Sending airmail
    if target then
        target:triggerEvent('receive',atk)
    end
end

function GAME.checkFinish()
    if GAME.playing and GAME.mode.checkFinish() then
        GAME.playing=false
        GAME.mode.result()
    end
end

function GAME.update(dt)
    if not GAME.playerList then return end
    GAME.skinTime=GAME.skinTime+dt
    for _,P in next,GAME.playerList do P:update(dt) end

    GAME.camera:update(dt)
    for i=#GAME.hitWaves,1,-1 do
        local wave=GAME.hitWaves[i]
        wave.time=wave.time+dt
    end
end

local _canvasSetting={stencil=true}
local gc_setCanvas,gc_setShader=GC.setCanvas,GC.setShader
local gc_replaceTransform,gc_applyTransform=GC.replaceTransform,GC.applyTransform
local gc_clear,gc_draw,gc_setColor=GC.clear,GC.draw,GC.setColor
function GAME.render()
    if not GAME.playerList then return end
    _canvasSetting[1]=ZENITHA.bigCanvas.player
    gc_setCanvas(_canvasSetting)
    gc_replaceTransform(SCR.xOy_m)
    gc_applyTransform(GAME.camera.transform)
    gc_clear(0,0,0,0)
    for _,P in next,GAME.playerList do P:render() end
    gc_setCanvas()

    gc_replaceTransform(SCR.origin)
    if GAME.hitWaves[1] then
        local L=GAME.hitWaves
        for i=1,#L do
            local timeK=1/(400*L[i].time+50)-.0026
            if timeK<=0 then
                L[i][3]=0
            else
                L[i][3]=6.26-2.6*L[i].time
                L[i][4]=math.cos(L[i].time*26)*L[i].power*timeK
            end
        end
        SHADER.warp:send('hitWaves',unpack(L))
        gc_setShader(SHADER.warp)
    else
        gc_setShader(SHADER.none) -- Directly draw the content, don't consider color, for better performance(?)
    end
    gc_setColor(1,1,1)
    gc_draw(ZENITHA.bigCanvas.player)
    gc_setShader()
end

function GAME._addHitWave(x,y,power)
    if CONF.system.hitWavePower<=0 then return end
    if #GAME.hitWaves>=8 then
        local maxI=1
        for i=2,#GAME.hitWaves do
            if GAME.hitWaves[i].time>GAME.hitWaves[maxI].time then
                maxI=i
            end
        end
        table.remove(GAME.hitWaves,maxI)
    end
    table.insert(GAME.hitWaves,{
        x,
        y,
        nil,
        nil, -- power1 & power2, calculated before sending uniform
        time=0,
        power=power*CONF.system.hitWavePower,
    })
end

return GAME
