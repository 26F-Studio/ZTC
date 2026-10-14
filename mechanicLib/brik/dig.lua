---@type Map<Techmino.Event.Brik>
local dig={}

local freq={
    neat={1,2,1,2},
    stairs={2.6,6.2,1},
    stairs_r={1,6.2,2.6},
}
local min,abs=math.min,math.abs
local function cheeseDistCheck(r,his,w)
    return
        min(abs(r-his[1]),abs(r+w-his[1]))>=2 and
        min(abs(r-his[2]),abs(r+w-his[2]))>=2 and
        min(abs(r-his[3]),abs(r+w-his[3]))>=1 and
        min(abs(r-his[4]),abs(r+w-his[4]))>=1
end
local garbageTypes={
    neat=function(P)
        if not P.modeData.neat then
            P.modeData.neat={init=true,pos=0,amount=0}
            for i=1,P.settings.fieldW do P.modeData.neat[i]=8 end
        end
        local d=P.modeData.neat
        if d.amount<=0 then
            local R=P:random('dig',P.settings.fieldW-1)
            d.amount=P:randFreq('dig',freq.neat)
            if R>=d.pos then R=R+1 end

            local sum=0
            for i=1,#d do
                sum=sum+math.max(d[i],0)
            end
            local r0=P:random('dig',sum)
            local r
            for x=1,#d do
                if d[x]>0 then
                    r0=r0-d[x]
                    if r0<=0 then
                        r=x
                        break
                    end
                end
            end
            d.pos=r or P:random('dig',P.settings.fieldW)

            for x=1,P.settings.fieldW do
                local dist=not r and 1e99 or min(abs(x-r),10-abs(x-r))
                d[x]=MATH.clamp(d[x]+(
                    dist==0 and -10 or
                    dist==1 and -8 or
                    3
                ),-4,8)
            end
        end
        P:riseGarbage(d.pos)
        d.amount=d.amount-1
    end,
    stairs=function(P)
        if not P.modeData.stairs then
            P.modeData.stairs={
                init=true,
                pos=P:random('dig',2,P.settings.fieldW-1),
                dir=P:coin('dig',-1,1),
                amount=0,
            }
        end
        local d=P.modeData.stairs
        if d.amount<=0 then
            d.pos=d.pos+d.dir
            if d.pos==1 or d.pos==P.settings.fieldW then
                d.dir=-d.dir
            end
            d.amount=P:randFreq('dig',(d.pos<=2 or d.pos>=P.settings.fieldW-1) and freq.stairs_r or freq.stairs)
        end
        P:riseGarbage(d.pos)
        d.amount=d.amount-1
    end,
    cheese=function(P)
        local md=P.modeData
        if not md.cheeseHis then
            md.cheeseHis={}
            for i=1,4 do md.cheeseHis[i]=P:random('dig',P.settings.fieldW) end
        end

        local r
        repeat
            r=P:random('dig',P.settings.fieldW)
        until cheeseDistCheck(r,md.cheeseHis,P.settings.fieldW)
        md.cheeseHis[4]=nil
        table.insert(md.cheeseHis,1,r)

        P:riseGarbage(r)
    end,
    ruins=function(P)
        P:riseGarbage(P:calculateHolePos(
            8,  -- count
            0,  -- splitRate
            0,  -- copyRate
            -.5 -- sandwichRate
        ))
    end,

    line=function(P)
        if not P.modeData.dig_line_init then
            P.modeData.dig_line_init=true
            P.modeData.risePosition=math.floor((P.settings.fieldW+1)/2+P:random('dig'))
            P.modeData.riseDirection=P:random('dig',0,1)*2-1
        end
        P:riseGarbage(P.modeData.risePosition)
        if P.modeData.risePosition<=1 or P.modeData.risePosition>=P.settings.fieldW then
            P.modeData.riseDirection=-P.modeData.riseDirection
        end
        P.modeData.risePosition=P.modeData.risePosition+P.modeData.riseDirection
        P.modeData.garbageRised=P.modeData.garbageRised+1
    end,
    drill=function(P)
        if not P.modeData.dig_drill_init then
            P.modeData.dig_drill_init=true
            P.modeData.dig_drill_data=TABLE.new(10,P.settings.fieldW)
        end

        local d=P.modeData.dig_drill_data
        local sum=0
        for i=1,#d do
            sum=sum+d[i]
        end
        local r=P:random('dig',sum)
        for x=1,#d do
            r=r-d[x]
            if r<=0 then
                r=x
                break
            end
        end
        P:riseGarbage(r)

        for x=1,P.settings.fieldW do
            local dist=math.abs(x-r)
            if dist<=2 then
                d[x]=math.max(d[x]-(dist==0 and 26 or dist==1 and 5 or 2),0)
            else
                d[x]=math.min(d[x]+3,12)
            end
        end
    end,
    solid=function(P)
        P:riseGarbage({})
        P.modeData.garbageRised=P.modeData.garbageRised+1
    end,
    shale=function(P)
        P:riseGarbage(P:calculateHolePos(
            P:random('dig',2,3), -- count
            -.2, -- splitRate
            -.1, -- copyRate
            -1   -- sandwichRate
        ))
        P.modeData.garbageRised=P.modeData.garbageRised+1
    end,
    volcanics=function(P)
        P:riseGarbage(P:calculateHolePos(
            P:random('dig',3,4), -- count
            .2,  -- splitRate
            -.1, -- copyRate
            .1   -- sandwichRate
        ))
        P.modeData.garbageRised=P.modeData.garbageRised+1
    end,
    checker=function(P)
        P:riseGarbage(P.modeData.garbageRised%2==0 and {1,3,5,7,9} or {2,4,6,8,10})
        P.modeData.garbageRised=P.modeData.garbageRised+1
    end,
}

function dig.event_playerInit(P)
    P.modeData.garbageRised=0
    P.modeData.lineDig=0
    P.modeData.lineExist=P.modeData.lineStay
    for _=1,P.modeData.lineStay do
        garbageTypes[P.modeData.digMode](P)
    end
end

function dig.event_afterClear(P,clear)
    local md=P.modeData
    local digLine=0
    for _,v in next,clear.linePos do
        if v<=md.lineExist then
            digLine=digLine+1
        end
    end
    if digLine>0 or md.lineExist<md.lineStay then
        md.lineDig=md.lineDig+digLine
        md.lineExist=md.lineExist-digLine
        if md.lineDig>=md.target.lineDig then
            P:finish('win')
        else
            -- print(md.target.lineDig-md.lineDig,md.lineStay)
            local add=math.min(md.target.lineDig-md.lineDig,md.lineStay)-md.lineExist
            if add>0 then
                for _=1,add do garbageTypes[P.modeData.digMode](P) end
                md.lineExist=md.lineExist+add
            end
        end
    end
end

function dig.event_drawOnPlayer(P)
    P:drawInfoPanel(-380,-60,160,120)
    FONT.set(80) GC.mStr(P.modeData.target.lineDig-P.modeData.lineDig,-300,-70)
    FONT.set(30) GC.mStr(Text.target_line,-300,15)
end

return dig
