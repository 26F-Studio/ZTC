local book={
    Z={
        [0]={
            {'['},
            {'<<','[>'},
            {'<'},
            {''},
            {'>'},
            {'>>'},
            {']<'},
            {']'},
        },
        [1]={
            {'A['},
            {'[,R'},
            {'L<'},
            {'L'},
            {'R'},
            {'R>'},
            {'R>>','],L<'},
            {'],L'},
            {'A]'},
        },
    },
    J={
        [0]={
            {'['},
            {'<<','[>'},
            {'<'},
            {''},
            {'>'},
            {'>>'},
            {']<'},
            {']'},
        },
        [1]={
            {'R['},
            {'[,R'},
            {'[,R>','R<<'},
            {'R<'},
            {'R'},
            {'R>'},
            {'R>>'},
            {'R]<'},
            {'R]'},
        },
        [2]={
            {'F['},
            {'F<<','F[>'},
            {'F<'},
            {'F'},
            {'F>'},
            {'F>>'},
            {'F]<'},
            {'F]'},
        },
        [3]={
            {'L['},
            {'L[>'},
            {'L<'},
            {'L'},
            {'L>'},
            {'L>>'},
            {'],L<'},
            {'],L'},
            {'L]'},
        },
    },
    O={
        [0]={
            {'['},
            {'[>'},
            {'<<'},
            {'<'},
            {''},
            {'>'},
            {'>>'},
            {']<'},
            {']'},
        },
    },
    I={
        [0]={
            {'['},
            {'[>','<<'},
            {'<'},
            {''},
            {'>'},
            {']<','>>'},
            {']'},
        },
        [1]={
            {'A['},
            {'[,L'},
            {'[,R'},
            {'<R'},
            {'L'},
            {'R'},
            {'<L'},
            {'],L'},
            {'],R'},
            {'A]'},
        },
    },
}
book.Z[2]=book.Z[0]
book.Z[3]=book.Z[1]
book.O[1]=book.O[0]
book.O[2]=book.O[0]
book.O[3]=book.O[0]
book.I[2]=book.I[0]
book.I[3]=book.I[1]
book.S=book.Z
book.L=book.J
book.T=book.J

---@type Map<Techmino.Event.Brik>
local finesse={}

function finesse.event_playerInit(P)
    -- P.stat.key                  -- Total keys
    -- P.stat.piece                -- Total drops
    P.modeData.kpp=0               -- KPP (traditional)

    P.modeData.fault=0             -- Fault count
    P.modeData.overCnt=0           -- Extra moves count

    P.modeData.movSeq=''           -- Current piece move history (count)
    P.modeData.movCnt=0            -- Total moves/rotations
    -- P.stat.spawn                -- Total spawns
    P.modeData.neatPiece=0         -- Open-air drops
    P.modeData.mpp=0               -- Moves per piece (open-air drops only, hard drop counts but hold doesn't, measures placement quality)
    P.modeData.dropRate='100%'     -- Open-air drop rate
    P.modeData.refAns=false        -- Reference answer list of last drop (after fault)
    P.modeData.onFinesseFault=NULL -- Callback for finesse fault

    P:addEvent('afterResetPos',finesse.event_afterResetPos)
    P:addEvent('beforeMove',finesse.event_beforeMove)
    P:addEvent('afterDrop',finesse.event_afterDrop)
    P:addEvent('beforeDiscard',finesse.event_beforeDiscard)
end

function finesse.event_afterResetPos(P)
    if P.keyState.moveLeft~=P.keyState.moveRight then
        P.modeData.movSeq='!' -- pre-charged
    end
end
function finesse.event_beforeMove(P,act,A,B,C,D)
    --[[
        moveX:  dx,noShade,byAutoShift,ifInit
        moveY:  dy,noShade
        drop:   dy,noShade
        rotate: x,y,dir,ifInit
        reset:  x,y
    ]]
    local md=P.modeData
    if act=='rotate' then
        md.movSeq=md.movSeq..(
            C=='R' and 'R' or
            C=='L' and 'L' or
            C=='F' and 'F' or
            error("WTF")
        )
    elseif act=='moveX' then
        if C then
            local tail=md.movSeq:sub(-1)
            if tail=='<' or tail=='>' then
                md.movSeq=md.movSeq:sub(1,-2)..(tail=='<' and '[' or ']')
            end
        else
            md.movSeq=md.movSeq..(A<0 and '<' or '>')
        end
    elseif act=='reset' then
        P.modeData.movSeq=''
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
        if not book[piece] then return end

        local x=P.handX
        local dir=P.hand.direction
        local move=#md.movSeq
        local ansList=book[piece][dir][x]
        local par=#ansList[1]
        if ansList[1]:find(',') then par=par-1 end
        if md.movSeq:sub(1,1)=='!' then par=par+1 end
        if not md.force180 and ansList[1]:find('F') and not md.movSeq:find('F') then par=par+1 end
        if move>par then
            md.refAns=TABLE.copy(ansList)
            md.onFinesseFault(P)
            if not P.hand then return end
            md.fault=md.fault+1
            md.overCnt=md.overCnt+(move-par)
        else
            md.refAns=false
        end

        md.neatPiece=md.neatPiece+1
        if #md.movSeq>0 then md.movCnt=md.movCnt+#md.movSeq end
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
