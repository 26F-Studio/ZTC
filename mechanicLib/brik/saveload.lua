---@type Map<Techmino.Event.Brik>
local saveload={}

function saveload.event_playerInit(P,limit,onBeforeLoad,onAfterLoad)
    local md=P.modeData

    -- Options
    md.onBeforeLoad=onBeforeLoad or NULL -- Callback before undo happens, could return [custom data]
    md.onAfterLoad=onAfterLoad or NULL   -- Callback after undo happens, will receive the [custom data]
    md.undoDepthLimit=limit or 6

    md.undoData={}
    md.undoInfo={
        time=0,               -- total undo count
        depth=0,              -- current undo depth
        confirmOnClear=false, -- clear undo history on clear
    }
    P:setAction('func1',saveload.action_load)
    P:addEvent('afterSpawn',saveload.event_afterSpawn)
    P:addEvent('beforeDiscard',saveload.event_beforeDiscard)
    P:addEvent('drawOnPlayer',saveload.event_drawOnPlayer)
    P:addEvent('afterClear',saveload.event_afterClear)
end
function saveload.action_load(P)
    local md=P.modeData
    if md.undoInfo.depth>md.undoDepthLimit then return end
    if #md.undoData>1 and P.hand then
        -- Snapshot
        local undoData,undoInfo=md.undoData,md.undoInfo
        md.undoData,md.undoInfo=nil,nil
        local customData
        customData=P.modeData.onBeforeLoad(P)

        local gameTime=P.gameTime
        table.remove(undoData)
        P:unserialize(undoData[#undoData])
        md=P.modeData

        -- Restore snapshot
        md.undoData,md.undoInfo=undoData,undoInfo
        P.modeData.onAfterLoad(P,customData)

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
function saveload.event_afterSpawn(P)
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
function saveload.event_beforeDiscard(P)
    local md=P.modeData
    md.undoInfo.depth=math.max(md.undoInfo.depth-1,0)
end
function saveload.event_afterClear(P)
    local md=P.modeData
    if not md.undoInfo.confirmOnClear then return end
    TABLE.clear(md.undoData)
end
function saveload.event_drawOnPlayer(P)
    local md=P.modeData
    if #md.undoData>1 then
        GC.setColor(1,1,1,.26)
        GC.rectangle('fill',-380,326,160*(math.max(#md.undoData-1,0)/md.undoDepthLimit),26)
    end
    GC.setColor(0,0,0,.42)
    GC.rectangle('line',-380,326,160,26)
end

return saveload
