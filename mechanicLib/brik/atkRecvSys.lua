local ins,rem=table.insert,table.remove
local GC=GC
local gc_setColor=GC.setColor
local gc_rectangle=GC.rectangle

---@type Map<Techmino.Event.Brik>
local atkRecvSys={}

---Select and initialize an attack receive system.
---@param P Techmino.Player.Brik
---@param mode string System name
---@param opts? table
function atkRecvSys.init(P,mode,opts)
    if not P.modeData.atkSys then P.modeData.atkSys={} end
    assert(not P.modeData.atkSys.recvMode,"Attack-Receive system already initialized")

    local A=P.modeData.atkSys
    A.recvMode=mode
    for k,v in next,opts or {} do A[k]=v end
    atkRecvSys[mode..'_init'](P)
end

function atkRecvSys.std_init(P)
    local A=P.modeData.atkSys
    A.buffer=A.buffer or {}
    A.sum=A.sum or 0

    P:addEvent('receive',atkRecvSys.std_event_receive)
    P:addEvent('always',atkRecvSys.std_event_always)
    P:addEvent('afterDiscard',atkRecvSys.std_event_afterDiscard)
    P:addEvent('drawOnPlayer',atkRecvSys.std_event_drawOnPlayer)
    P:addEvent('onAttack',atkRecvSys.std_event_cancel)
end

function atkRecvSys.std_event_cancel(P)
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

function atkRecvSys.std_event_receive(P,data)
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

function atkRecvSys.std_event_always(P)
    local A=P.modeData.atkSys
    local buffer=A.buffer
    for i=1,#buffer do
        local g=buffer[i]
        if g.mode==0 and g._time<g.time then
            g._time=g._time+1
        end
    end
end

function atkRecvSys.std_event_afterDiscard(P)
    local A=P.modeData.atkSys
    if A.allowBlock and P.lastMovement.clear then return end

    local buffer=A.buffer
    local iBuffer=1
    while true do
        local g=buffer[iBuffer]
        if not g then break end
        if g._time==g.time then
            if not A.holePosHis then
                A.holePosHis={}
                for i=1,4 do A.holePosHis[i]=P:random('attackHoleGen',P.settings.fieldW) end
            end
            local holePos
            repeat
                holePos=P:random('attackHoleGen',P.settings.fieldW)
                local valid=true
                for i=1,4 do
                    local d=math.abs(holePos-A.holePosHis[i])
                    if math.min(d,P.settings.fieldW-d)<(i<=2 and 2 or 1) then
                        valid=false
                        break
                    end
                end
            until valid
            A.holePosHis[4]=nil
            table.insert(A.holePosHis,1,holePos)

            P:riseGarbage(holePos,g.power)
            rem(buffer,iBuffer)
            A.sum=A.sum-g.power
            iBuffer=iBuffer-1
        elseif g.mode==1 then
            g._time=g._time+1
        end
        iBuffer=iBuffer+1
    end
end

function atkRecvSys.std_event_drawOnPlayer(P)
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

return atkRecvSys
