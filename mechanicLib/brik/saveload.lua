---@type Map<Techmino.Event.Brik>
local sl={}

function sl.event_playerInit(P)
    local md=P.modeData
    md.undoData={}
    P:setAction('func1',sl.action_load)
    P:addEvent('afterSpawn',sl.event_afterSpawn)
    P:addEvent('beforeDiscard',sl.event_beforeDiscard)
    P:addEvent('drawOnPlayer',sl.event_drawOnPlayer)
    P:addEvent('afterClear',sl.event_afterClear)

    md.undoInfo={
        time=0,               -- total undo count
        depth=0,              -- current undo depth
        confirmOnClear=false, -- clear undo history on clear
    }
    md.undoDepthLimit=6
end
function sl.action_load(P)
    local md=P.modeData
    if md.undoInfo.depth>md.undoDepthLimit then return end
    if #md.undoData>1 and P.hand then
        -- Snapshot values
        local undoData,undoInfo=md.undoData,md.undoInfo
        md.undoData,md.undoInfo=nil,nil

        local gameTime=P.gameTime
        table.remove(undoData)
        P:unserialize(undoData[#undoData])
        md=P.modeData

        -- Restore snapshot values
        md.undoData,md.undoInfo=undoData,undoInfo

        -- Update undo info
        md.undoInfo.time=md.undoInfo.time+1
        md.undoInfo.depth=md.undoInfo.depth+1

        P.gameTime=gameTime
        P.fieldRisingSpeed=0
        P.fieldDived=0
        P:release('moveLeft'); P:release('moveRight')
        P:release('rotateCW'); P:release('rotateCCW'); P:release('rotate180')
        P:release('holdPiece'); P:release('softDrop'); P:release('hardDrop')
        P:restoreBrikState()
        P:resetPos()
        P:freshGhost()
        P.pos={x=0,y=0,k=1,a=0,dx=0,dy=0,dk=0,da=0,vx=0,vy=0,vk=0,va=0}
        -- print('SL: loaded',#undoData)
    end
end
function sl.event_afterSpawn(P)
    local md=P.modeData
    if P.hand then
        local undoData,undoInfo=md.undoData,md.undoInfo
        md.undoData,md.undoInfo=nil,nil

        if #undoData>md.undoDepthLimit then table.remove(undoData,1) end
        table.insert(undoData,P:serialize())

        md.undoData,md.undoInfo=undoData,undoInfo
        -- print('SL: saved',#undoData)
    end
end
function sl.event_beforeDiscard(P)
    local md=P.modeData
    md.undoInfo.depth=math.max(md.undoInfo.depth-1,0)
end
function sl.event_afterClear(P)
    local md=P.modeData
    if not md.undoInfo.confirmOnClear then return end
    TABLE.clear(md.undoData)
end
function sl.event_drawOnPlayer(P)
    local md=P.modeData
    if #md.undoData>1 then
        GC.setColor(1,1,1,.26)
        GC.rectangle('fill',-380,326,160*(math.max(#md.undoData-1,0)/md.undoDepthLimit),26)
    end
    GC.setColor(0,0,0,.42)
    GC.rectangle('line',-380,326,160,26)
end

return sl
