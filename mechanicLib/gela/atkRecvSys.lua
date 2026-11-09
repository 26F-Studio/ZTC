local ins,rem=table.insert,table.remove
local GC=GC
local gc_setColor=GC.setColor
local gc_rectangle=GC.rectangle

---@type Map<Techmino.Event.Brik>
local atkRecvSys={}

---@param P Techmino.Player.Gela
---@param mode string System name
---@param opts? table
function atkRecvSys.init(P,mode,opts)
    if not P.modeData.atkSys then P.modeData.atkSys={} end
    assert(not P.modeData.atkSys.recvMode,"Attack-Receive system already initialized")

    local A=P.modeData.atkSys
    A.recvMode=mode
    for k,v in next,opts or {} do A[k]=v end

    local initialize=atkRecvSys[mode..'_event_init']
    if initialize then initialize(P) end
end

do
    function atkRecvSys.classic_event_init(P)
        local A=P.modeData.atkSys
        A.buffer=A.buffer or {}
        A.sum=A.sum or 0

        P:addEvent('receive',atkRecvSys.classic_event_receive)
        P:addEvent('always',atkRecvSys.classic_event_always)
        P:addEvent('garbageRelease',atkRecvSys.classic_event_garbageRelease)
        P:addEvent('drawOnPlayer',atkRecvSys.classic_event_drawOnPlayer)
        P:addEvent('onAttack',atkRecvSys.classic_event_onAttack_cancel)
    end
    function atkRecvSys.classic_event_receive(P,data)
        local A=P.modeData.atkSys
        local g={
            power=data.power,
            mode=data.mode or 0,
            time=math.floor((data.time or 0)+.5),
            _time=0,
        }
        ins(A.buffer,g)
        A.sum=A.sum+g.power
    end
    function atkRecvSys.classic_event_onAttack_cancel(P)
        local A=P.modeData.atkSys
        local atk=A.attack
        if not atk or not A.allowCancel then return end

        local buffer=A.buffer
        while atk and buffer[1] do
            local gbg=buffer[1]
            local ap,gp=atk.power,gbg.power
            local cancel=math.min(ap,gp)
            ap=ap-cancel
            gp=math.floor(gp-cancel+.5)
            if gp==0 then
                atk.power=ap
                A.sum=A.sum-gbg.power
                rem(buffer,1)
            else
                A.sum=A.sum-gbg.power+gp
                gbg.power=gp
            end
            if ap==0 then
                A.attack=nil
                return
            end
        end
        A.attack=atk
    end
    function atkRecvSys.dropGarbage(P,count)
        local F=P.field
        local w=P.settings.fieldW
        local curGenY=P.settings.spawnH+1
        while count>=w do
            for x=1,w do
                F:setCell({
                    color=555,
                    diggable=true,
                },x,curGenY)
            end
            curGenY=curGenY+1
            count=count-w
        end
        if count>0 then
            local pos={}
            for x=1,w do pos[x]=x end
            for n=1,count do
                F:setCell({
                    color=555,
                    diggable=true,
                },table.remove(pos,P:random('garbageGen',w+1-n)),curGenY)
            end
        end
    end
    function atkRecvSys.classic_event_garbageRelease(P)
        local A=P.modeData.atkSys
        if A.allowBlock and P.chain>0 then return end
        local buffer=A.buffer
        local i=1
        while true do
            local g=buffer[i]
            if not g then break end
            if g._time==g.time then
                atkRecvSys.dropGarbage(P,g.power)
                rem(buffer,i)
                A.sum=A.sum-g.power
                i=i-1
            elseif g.mode==1 then
                g._time=g._time+1
            end
            i=i+1
        end
    end
    function atkRecvSys.classic_event_always(P)
        local A=P.modeData.atkSys
        for i=1,#A.buffer do
            local g=A.buffer[i]
            if g.mode==0 and g._time<g.time then
                g._time=g._time+1
            end
        end
    end
    function atkRecvSys.classic_event_drawOnPlayer(P)
        local A=P.modeData.atkSys
        local buffer=A.buffer
        local y=0
        for i=1,#buffer do
            local g=buffer[i]
            local h=g.power*40
            if y+h>800 then
                h=800-y
            end
            if g._time<g.time then
                gc_setColor(CLR.l2RySSS)
                gc_rectangle('fill',210,400-y-h+3,10,h-6)
                gc_setColor(CLR.l9)
                local progress=g._time/g.time
                gc_rectangle('fill',210,400-y-h+3+(h-6)*(1-progress),10,(h-6)*progress)
            else
                gc_setColor(GAME.skinTime*1000%100<50 and CLR.l2RySSS or CLR.l9)
                gc_rectangle('fill',210,400-y-h+3,10,h-6)
            end
            y=y+h
            if y>=800 then break end
        end
    end
end

return atkRecvSys
