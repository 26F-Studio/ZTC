local floor=math.floor

---@type Map<Techmino.Event.Brik>
local atkSendSys={}

---@param P Techmino.Player.Gela
---@param mode string System name
---@param opts? table
function atkSendSys.init(P,mode,opts)
    if not P.modeData.atkSys then P.modeData.atkSys={} end
    assert(not P.modeData.atkSys.atkMode,"Attack-Send system already initialized")

    local initialize=atkSendSys[mode..'_init']
    if initialize then initialize(P) end

    local A=P.modeData.atkSys
    A.atkMode=mode
    A.attack=nil
    for k,v in next,opts or NONE do A[k]=v end

    local eventAttack=atkSendSys[mode..'_calc']
    assert(type(eventAttack)=='function',"Unknown atk send system: "..tostring(mode))

    P:addEvent('onAttack',{-100,eventAttack})
    P:addEvent('onAttack',{100,atkSendSys.event_send})
end

---@param P Techmino.Player.Gela
---@param atk table
function atkSendSys.send(P,atk)
    P.stat.sent=P.stat.sent+atk.power
    GAME.send(P,atk)
end

function atkSendSys.event_send(P)
    local A=P.modeData.atkSys
    local atk=A.attack
    A.attack=nil
    if atk then atkSendSys.send(P,atk) end
end

function atkSendSys.classic_init(P)
    P.modeData.atkSys.remainder=0
end

function atkSendSys.classic_calc(P)
    local A=P.modeData.atkSys
    local clear=P.lastClear
    local groups=clear and clear.groups or P.clearingGroups
    local sizes={}
    for i=1,#groups do
        sizes[i]=TABLE.getSize(groups[i])
    end
    local chip,mult=MATH.sum(sizes)*10,0

    mult=mult+(P.chain<=3 and 8*(P.chain-1) or 32*(P.chain-3))

    local colors=#groups
    mult=mult+(
        colors==1 and 0 or
        colors==2 and 3 or
        6*(2^(colors-3))
    )

    for i=1,#sizes do
        mult=mult+(
            sizes[i]==4 and 0 or
            sizes[i]<=10 and sizes[i]-3 or
            10
        )
    end

    if mult==0 then mult=1 end
    local score=(A.remainder or 0)+chip*mult
    local power=floor(score/70)
    A.remainder=score-power*70
    if power>0 then
        local atk={power=power,time=1000}
        A.attack=atk
        P.stat.atk=P.stat.atk+atk.power
    end
end

return atkSendSys
