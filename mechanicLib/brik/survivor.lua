local floor,ceil=math.floor,math.ceil
local max,min=math.max,math.min
local GC=GC

---@type Map<Techmino.Event.Brik>
local survivor={}

function survivor.event_playerInit(P)
    GAME.mechLib.brik.atkSendSys.init(P,'basic')
    GAME.mechLib.brik.atkRecvSys.init(P,'modern')

    local md=P.modeData
    md.curWaveTime=1
    md.waveTimer=0
    md.wave=0
end

function survivor.event_drawOnPlayer(P)
    P:drawInfoPanel(-380,-60,160,120)
    GC.setFont(80); GC.mStr(P.modeData.wave,-300,-70)
    GC.setFont(30); GC.mStr(Text.target_wave,-300,15)

    local cd=P.modeData.waveTimer/P.modeData.curWaveTime
    GC.setLineWidth(10)
    GC.setColor(CLR.l5)
    GC.arc('line','open',-300,130,40,-MATH.pi*.5,cd*MATH.tau-MATH.pi*.5)
    GC.setLineWidth(3)
    GC.setColor(CLR.d4)
    GC.circle('line',-300,130,32)
    GC.circle('line',-300,130,48)
end

function survivor.scattered_event_always(P)
    if not P.timing then return end
    local md=P.modeData
    if md.waveTimer>0 then
        md.waveTimer=min(md.waveTimer-1,(P.field:getHeight()+3*md.atkSys.sum)*260)
    end
    if md.waveTimer<=0 and md.atkSys.sum<=max(15-P.field:getHeight()/2,8) then
        md.wave=md.wave+1

        local wave=md.wave
        md.curWaveTime=math.floor(
            wave<=80 and MATH.interpolate(0,3000,80,2000,wave) or
            wave<=150 and MATH.interpolate(80,2000,150,2500,wave) or
            math.max(2000-(wave-150)*10,1000)
        )
        md.waveTimer=md.curWaveTime
        GAME.send(false,{
            target=GAME.mainID,
            power=P:random('survivor',0,10)+P:random('survivor',-5,5)>=P.field:getHeight() and 2 or 1,
            mode=0,
            time=wave<50 and 100e3/(50+wave)-1000 or 0,
        })
    end
end
function survivor.power_event_always(P)
    if not P.timing then return end
    local md=P.modeData
    if md.waveTimer>0 then
        md.waveTimer=min(md.waveTimer-1,(P.field:getHeight()+3*md.atkSys.sum)*260)
    end
    if md.waveTimer<=0 and md.atkSys.sum<=max(20-P.field:getHeight(),12) then
        md.wave=md.wave+1

        local wave=md.wave
        md.curWaveTime=math.floor(
            wave<=40 and MATH.interpolate(0,6000,40,4000,wave) or
            wave<=80 and MATH.interpolate(40,4000,80,1500,wave) or
            max(MATH.interpolate(80,1500,150,800,wave),800)
        )
        md.waveTimer=md.curWaveTime
        GAME.send(false,{
            target=GAME.mainID,
            power=4+P:random('survivor',0,MATH.clamp(math.floor(wave/30-P.field:getHeight()/10),0,3)),
            mode=0,
            time=
                (wave<50 and 100e3/(100+2*wave)+500 or 1000)+
                MATH.clamp(400-wave,150,350)*max(P.field:getHeight()+md.atkSys.sum-8,0),
        })
    end
end
function survivor.spike_event_always(P)
    if not P.timing then return end
    local md=P.modeData
    if md.waveTimer>0 then
        md.waveTimer=min(md.waveTimer-1,md.atkSys.sum*620)
    end
    if md.waveTimer<=0 and md.atkSys.sum<=10 then
        md.wave=md.wave+1

        local wave=md.wave
        md.curWaveTime=floor(
            wave<=10 and MATH.interpolate(0,20e3,10,15e3,wave) or
            wave<=30 and MATH.interpolate(10,15e3,30,12e3,wave) or
            max(MATH.interpolate(30,12e3,60,10e3,wave),10e3)
        )
        md.waveTimer=md.curWaveTime
        for i=1,3 do
            GAME.send(false,{
                target=GAME.mainID,
                power=
                    2+2*i+ -- Basic Attack (4+6+8)
                    P:random(
                        MATH.clamp(ceil(wave/20-P.field:getHeight()/15),0,2), -- Random lower bound (from 0 to 2 on wave 40, -1 if field reach 15)
                        min(floor(wave/10),4) -- Random Upper bound (from 0 to 4 on wave 40)
                    ),
                mode=0,
                time=
                    max(6000-50*wave,4000)+ -- Basic delay (from 6s to 4s on wave 40)
                    (i-1)*max(3000-wave*30,1500), -- Split time (from 3s to 1.5s on wave 50)
            })
        end

    end
end

function survivor.backfire_storePower_event_beforeCancel(P)
    local atk=P.modeData.atkSys.attack
    if not atk then return end
    P.modeData._currentPower=atk.power
end

function survivor.backfire_triplePower_event_beforeCancel(P)
    local atk=P.modeData.atkSys.attack
    if not atk then return end
    atk.power=atk.power*3
end

function survivor.backfire_easy_event_beforeSend(P) -- Send nerfed attack (when cancelling) to self
    local atk=P.modeData.atkSys.attack
    if not atk then return end
    P:triggerEvent('receive',atk)
end

function survivor.backfire_normal_event_beforeSend(P) -- Recover attack's original power if exist after cancelling, then send it to self
    local atk=P.modeData.atkSys.attack
    if not atk then return end
    atk.power,P.modeData._currentPower=P.modeData._currentPower
    P:triggerEvent('receive',atk)
end

function survivor.backfire_break_event_beforeSend(P) -- Recover power Like "normal" one, but break it into small attacks
    local atk=P.modeData.atkSys.attack
    if not atk then return end
    local powerList={}
    local section=0
    for i=1,P.modeData._currentPower do
        section=section+1
        if P:random('survivor')<.5 or i==P.modeData._currentPower then
            table.insert(powerList,section)
            section=0
        end
    end
    for i=1,#powerList do
        atk.power=powerList[i]
        P:triggerEvent('receive',atk)
    end
    P.modeData._currentPower=nil
end

return survivor
