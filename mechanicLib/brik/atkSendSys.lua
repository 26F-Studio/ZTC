local max,min=math.max,math.min
local floor,ceil=math.floor,math.ceil

---@type Map<Techmino.Event.Brik>
local atkSendSys={}

---Select and initialize an attack generation system.
---@param P Techmino.Player.Brik
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
    for k,v in next,opts or {} do A[k]=v end

    P:addEvent('onAttack',{-100,assert(atkSendSys[mode..'_calc'],"Unknown atk send system: "..tostring(mode))})
    P:addEvent('onAttack',{100,atkSendSys.event_send})
end

---@param P Techmino.Player.Brik
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

-- N attack N
function atkSendSys.basic_calc(P)
    local A=P.modeData.atkSys
    local atk
    if P.lastMovement.clear then
        local lines=#P.lastMovement.clear
        P.texts:add{
            text=Text.clearName[lines] or ('['..lines..']'),
            a=.626,
            fontSize=min(40+10*lines,70),
            style=lines>=4 and 'stretch' or 'appear',
            duration=lines/2,
        }
        A.attack={power=lines,time=lines}
        P.stat.atk=P.stat.atk+lines
    end
end

function atkSendSys.modern_init(P)
    local A=P.modeData.atkSys
    A.charge=0
    P.settings.spin_immobile=true
    P.settings.spin_corners=3
    P.settings.combo_sound=true
end

function atkSendSys.modern_calc(P)
    local A=P.modeData.atkSys
    local atk
    local M=P.lastMovement
    local tspin=P.hand.name=='T' and M.action=='rotate' and (M.corners or M.immobile)
    if M.clear then
        local lines,combo=#M.clear,M.combo

        local oldCharge=A.charge or 0
        local newCharge=
            tspin and min(oldCharge+1,26) or
            lines>=4 and min(oldCharge+1,26) or
            max(oldCharge-6,0)
        A.charge=newCharge

        do -- Calculate attack
            local power
            local time

            if tspin then
                power=2*lines
                power=power+min(ceil(oldCharge/4),2)
                time=300
            elseif lines>=4 then
                power=lines
                time=200
                power=power+min(ceil(oldCharge/4),4)
            else
                power=lines-1+floor((oldCharge-newCharge)/2)
                time=100
                if newCharge>=2 then
                    P:playSound('discharge')
                end
            end

            if P.field:getHeight()==0 then
                power=max(power,10)
            end

            time=time+P.combo*100
            power=power+min(floor(P.combo/3),3)

            if power>0 then
                atk={
                    power=power,
                    time=time+power*50,
                }
            end
        end

        do -- Text & Sound
            local t=STRING.newBuf()

            if newCharge>oldCharge then
                if newCharge>1 then
                    t:put(Text.charge.." ")
                    P:playSound('charge',newCharge)
                end
            elseif oldCharge-newCharge>=2 then
                t:put(Text.charge.." ")
                P:playSound('discharge')
            end

            if tspin then
                t:put(Text.spin:repD(M.brik.name).." ")
                P:playSound('spin',lines)
            end

            if P.field:getHeight()==0 then
                P.texts:add{
                    text=Text.allClear,
                    a=.626,
                    fontSize=75,
                    style='flicker',
                    duration=2.5,
                }
                P:playSound('clear_all')
            else
                P.texts:add{
                    text=t..(Text.clearName[lines] or ('['..lines..']')),
                    a=.626,
                    fontSize=min(30+lines*10,60)+(tspin and 0 or 10),
                    style=lines>=4 and 'stretch' or tspin and 'spin' or 'appear',
                    duration=lines/3+(tspin and .6 or 0),
                }
            end

            if combo>1 then
                P.texts:add{
                    text=
                        combo<11 and Text.combo_small:repD(combo-1) or
                        combo<21 and Text.combo_large:repD(combo-1) or
                        Text.mega_combo,
                    a=.7-.3/(2+combo),
                    y=60,
                    fontSize=15+min(combo,15)*5,
                }
            end
        end
    end
    if atk then
        A.attack=atk
        P.stat.atk=P.stat.atk+atk.power
    end
end

function atkSendSys.nextgen_init(P)
    local A=P.modeData.atkSys
    A.charge=0
    P.settings.spin_immobile=true
    P.settings.combo_sound=true
end

function atkSendSys.nextgen_calc(P)
    local A=P.modeData.atkSys
    local text=''
    local M=P.lastMovement
    local spin=M.action=='rotate' and (M.corners or M.immobile)
    local atk
    if M.clear then
        local lines,combo=#M.clear,M.combo
        local textDuration=lines/3

        local multi
        if lines>=4 and combo>1 then
            local lastClear=P.clearHistory[#P.clearHistory-1]
            if lastClear and lines==lastClear.line then
                multi=true
            end
        end

        if multi then
            text=text.."M-"
            textDuration=textDuration+.6
            P:playSound('frenzy')
        end

        if spin then
            text=Text.spin:repD(M.brik.name).." "
            textDuration=textDuration+.6
            P:playSound('spin',lines)
        end

        text=text..(Text.clearName[lines] or ('['..lines..']'))
        P.texts:add{
            text=text,
            a=.626,
            fontSize=min(lines-3,0)*10+(spin and 60 or 70),
            style=lines>=4 and 'stretch' or spin and 'spin' or 'appear',
            duration=textDuration,
        }

        if combo>1 then
            P.texts:add{
                text=
                    combo<11 and Text.combo_small:repD(combo-1) or
                    combo<21 and Text.combo_large:repD(combo-1) or
                    Text.mega_combo,
                a=.7-.3/(2+combo),
                y=60,
                fontSize=15+min(combo,15)*5,
            }
        end

        if P.field:getHeight()==0 then
            P.texts:add{
                text=Text.allClear,
                y=-80,
                a=.626,
                fontSize=75,
                style='flicker',
                duration=2.5,
            }
            P:playSound('clear_all')
        elseif M.y>P.field:getHeight() then
            P.texts:add{
                text=Text.halfClear,
                y=-80,
                a=.8,
                fontSize=65,
                style='fly',
                duration=1.6,
            }
            P:playSound('clear_half')
        end

        local pwr
        if lines>=4 then
            pwr=lines
            if multi then pwr=pwr+1 end
        elseif spin then
            pwr=2*lines
        else
            pwr=lines-1
        end

        if P.field:getHeight()==0 then
            pwr=pwr+8
        elseif M.y>P.field:getHeight() then
            pwr=pwr+4
        end

        pwr=pwr+min(floor(P.combo/3),3)

        if pwr>0 then
            atk={
                power=pwr,
                time=200+pwr*50,
            }
        end
    end
    if atk then
        A.attack=atk
        P.stat.atk=P.stat.atk+atk.power
    end
end

return atkSendSys
