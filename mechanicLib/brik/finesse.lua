local ins=table.insert

local finesseData={
    Z={
        [0]={1,2,1,0,1,-2,2,1},
        [1]={2,2,2,1,1,2,3,2,2},
    },
    J={
        [0]={1,2,1,0,1,-2,2,1},
        [1]={2,2,3,2,1,2,3,3,2},
        [2]={3,4,3,2,3,-4,4,3},
        [3]={2,3,2,1,2,3,3,2,2},
    },
    O={
        [0]={1,2,-2,1,0,1,-2,2,1},
    },
    I={
        [0]={1,2,1,0,1,2,1},
        [1]={2,2,2,-2,1,1,-2,2,2,2},
    },
}
finesseData.Z[2]=finesseData.Z[0]
finesseData.Z[3]=finesseData.Z[1]
finesseData.O[1]=finesseData.O[0]
finesseData.O[2]=finesseData.O[0]
finesseData.O[3]=finesseData.O[0]
finesseData.I[2]=finesseData.I[0]
finesseData.I[3]=finesseData.I[1]
finesseData.S=finesseData.Z
finesseData.L=finesseData.J
finesseData.T=finesseData.J

---@type Map<Techmino.Event.Brik>
local finesse={}

function finesse.event_playerInit(P)
    -- P.stat.key                  -- Total keys
    -- P.stat.piece                -- Total drops
    P.modeData.kpp=0               -- KPP (traditional)

    P.modeData.fault=0             -- Fault count
    P.modeData.overCnt=0           -- Extra moves count

    P.modeData.movHis={}           -- Current piece move history (count)
    P.modeData.movCnt=0            -- Total moves/rotations
    -- P.stat.spawn                -- Total spawns
    P.modeData.neatPiece=0         -- Open-air drops
    P.modeData.mpp=0               -- Moves per piece (open-air drops only, hard drop counts but hold doesn't, measures placement quality)
    P.modeData.dropRate='100%'     -- Open-air drop rate
    P.modeData.onFinesseFault=NULL -- Callback for finesse fault

    P:addEvent('afterResetPos',finesse.event_afterResetPos)
    P:addEvent('beforeMove',finesse.event_beforeMove)
    P:addEvent('afterDrop',finesse.event_afterDrop)
    P:addEvent('beforeDiscard',finesse.event_beforeDiscard)
end

function finesse.event_afterResetPos(P)
    TABLE.clear(P.modeData.movHis)
    if P.keyState.moveLeft~=P.keyState.moveRight then
        ins(P.modeData.movHis,P.keyState.moveLeft and '<' or '>') -- pre-charged
    end
end
function finesse.event_beforeMove(P,act,A,B,C,D)
    if act=='rotate' then
        ins(P.modeData.movHis,
            C=='R' and 'r' or
            C=='L' and 'l' or
            C=='F' and 'f' or
            error("WTF")
        )
    elseif act=='moveX' and not C then
        ins(P.modeData.movHis, A<0 and '[' or ']')
    end
end


function finesse.event_afterDrop(P)
    -- Overhang check
    local fine=true
    for y=P.handY,P.field:getHeight() do
        if P:ifoverlap(P.hand.matrix,P.handX,y) then
            fine=false
            break
        end
    end

    local md=P.modeData
    if fine then
        local piece=P.hand.name
        local x=P.handX
        local dir=P.hand.direction
        local move=#md.movHis
        local par=finesseData[piece][dir][x]
        if par<0 then
            par=-par
            if md.movHis[1]=='<' or md.movHis[1]=='>' then
                move=move-1
            end
        end
        if md.force180 and dir==2 and (piece=='J' or piece=='L' or piece=='T') then
            par=par-1
        end
        if move>par then
            md.fault=md.fault+1
            md.overCnt=md.overCnt+(move-par)
            md.onFinesseFault(P)
        end

        md.neatPiece=md.neatPiece+1
        if #md.movHis>0 then
            md.movCnt=md.movCnt+#md.movHis
            TABLE.clear(md.movHis)
        end
    end
end

function finesse.event_beforeDiscard(P)
    local md=P.modeData
    -- Update statistics
    md.kpp=MATH.roundUnit(P.stat.key/P.stat.piece,.01)
    md.mpp=MATH.roundUnit((md.movCnt+md.neatPiece)/md.neatPiece,.01)
    md.dropRate=MATH.roundUnit(md.neatPiece/P.stat.piece*100,.1).."%"
end

return finesse
