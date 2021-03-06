local Class = require('Class')
local ImmigrationEvent = require('GameEvents.ImmigrationEvent')
local Event = require('GameEvents.Event')
local DockingEvent = Class.create(ImmigrationEvent)

local GameRules = require('GameRules')
local Docking = require('Docking')
local DFUtil = require('DFCommon.Util')
local GenericDialog = require('UI.GenericDialog')
local DialogSets = require('DialogSets')
local SoundManager = require('SoundManager')
local Portraits = require('UI.Portraits')
local AlertEntry = require('UI.AlertEntry')
local CharacterManager = require('CharacterManager')
local MiscUtil = require('MiscUtil')

DockingEvent.sEventType = 'friendlyDockingEvents'
DockingEvent.sAlertLC = 'ALERTS028TEXT'
DockingEvent.sFailureLC = 'ALERTS024TEXT'
DockingEvent.sDialogSet = 'dockingEvents'

DockingEvent.sAcceptedSuccessAlert='ALERTS029TEXT'

DockingEvent.nAllowedSetupFailures = 30

function DockingEvent.getSpawnLocationModifier()
    return Event.getPopulationMod() * Event.getHostilityMod(false)
end

function DockingEvent.getWeight(nPopulation, nElapsedTime)
    if nPopulation >= g_nPopulationCap then
        return 0
    end
    return 5.0
end

function DockingEvent.allowEvent(nPopulation, nElapsedTime)
    return not g_Config:getConfigValue('disable_docking') and (nPopulation > 4 or GameRules.elapsedTime > 60*10)
end

function DockingEvent.onQueue(rController, tUpcomingEventPersistentState, nPopulation, nElapsedTime)
    Event.onQueue(rController, tUpcomingEventPersistentState, nPopulation, nElapsedTime)
    Event._attemptDock(rController, tUpcomingEventPersistentState)
end

function DockingEvent.preExecuteSetup(rController, tUpcomingEventPersistentState)
    Event.preExecuteSetup(rController, tUpcomingEventPersistentState)

    local bPopcapFail = not tUpcomingEventPersistentState.bHostile and CharacterManager.getOwnedCitizenPopulation() >= g_nPopulationCap
    if bPopcapFail or not tUpcomingEventPersistentState.bClickedAlert then
        local rClass = rController.tEventClasses[tUpcomingEventPersistentState.sEventType]
        if rClass._ignoreRefusal(tUpcomingEventPersistentState) or tUpcomingEventPersistentState.bSkipDialog then
            -- nothing
        else
            AlertEntry.dOnClick:unregister(ImmigrationEvent.onAlertClick,
                tUpcomingEventPersistentState)
            return false, ImmigrationEvent.sRejectionSuccessAlert
        end
    end

    -- check if the module data from onqueue is still valid
    if tUpcomingEventPersistentState.tDockingTile and Event._verifyDockingData(rController, tUpcomingEventPersistentState) then
            AlertEntry.dOnClick:unregister(ImmigrationEvent.onAlertClick,
            tUpcomingEventPersistentState)
        return true
    else
        AlertEntry.dOnClick:unregister(ImmigrationEvent.onAlertClick,
            tUpcomingEventPersistentState)
        return false
    end
end

function DockingEvent.tick(rController, dT, tCurrentEventPersistentState, tCurrentEventTransientState)
    local tPersistentState, tTransientState = tCurrentEventPersistentState, tCurrentEventTransientState

    if not tTransientState.bStarted then
        Event.pauseGame()
        tTransientState.bStarted=true
        tTransientState.tDialogStatus = {}
        return
    end

    if not tTransientState.bChoseDialog then
        if DockingEvent.dialogTick(rController, tPersistentState, tTransientState, dT) then
            tTransientState.bChoseDialog = true
        end
        return
    end

    -- bSpawn is set by dialogTick... kind of kludgey
    if tTransientState.bSpawn and not tTransientState.bSpawned then
        if not tTransientState.tCutscene then
            local tx,ty = tPersistentState.tDockingTile.x, tPersistentState.tDockingTile.y
            tTransientState.tCutscene = rController.initCameraMove(tx,ty)
            GameRules.startCutscene()
        end
        if rController.tickCamera(MOAISim.getStep(), tTransientState.tCutscene) then
            local wx,wy = g_World._getWorldFromTile(tPersistentState.tDockingTile.x, tPersistentState.tDockingTile.y,1)
            SoundManager.playSfx3D('derelictdocking',wx,wy,0)
            Docking.spawnModule(tPersistentState)
            tTransientState.bSpawned = true
        end
        return
    end
    GameRules.stopCutscene()
    GameRules.nLastNewShip = GameRules.elapsedTime
    Event.resumeGame()
    return true
end

function DockingEvent._ignoreRefusal(tPersistentEventState)
    return false
end

function DockingEvent._getDialogSet()
    local sKey = 'ambiguous'
    return DFUtil.arrayRandom(DialogSets['dockingEvents'][sKey])
end


function DockingEvent.dialogTick(rController, tPersistentEventState, tTransientEventState, dT)
    if tTransientEventState.bWaitingOnDialog then
        return
    end

    -- the initial dialog box has some branching logic for docking event
    -- vs immigration event, but after that just use the immigration event code
    if not tTransientEventState.tDialogStatus.tDlgSet then
        local rClass = rController.tEventClasses[tPersistentEventState.sEventType]
        tTransientEventState.tDialogStatus.tDlgSet = rClass._getDialogSet()
    
        local tDlgSet = tTransientEventState.tDialogStatus.tDlgSet
        tTransientEventState.bWaitingOnDialog = true
        tTransientEventState.tDialogStatus.sPortrait = Portraits.getRandomPortrait()
        local function onDialogClick(bAccepted)
            tTransientEventState.bWaitingOnDialog = false
            tTransientEventState.bDialogAccepted = bAccepted
        end
        local rRequestUI = GenericDialog.new('UILayouts/DockingRequestLayout', onDialogClick, 'DockingButton')
        rRequestUI:setTemplateUITexture('Picture', tTransientEventState.tDialogStatus.sPortrait, Portraits.PORTRAIT_PATH)
        local tReplacements= {
            Title = tDlgSet.title,
            DockMessage = tDlgSet.request,
            DockingLabel = tDlgSet.acceptButton,
            DeclineLabel = tDlgSet.rejectButton
        }
        rRequestUI:replaceText(tReplacements)
        g_GuiManager.addToPopupQueue(rRequestUI, true)

        return
    end

    return ImmigrationEvent.dialogTick(rController, tPersistentEventState, tTransientEventState, dT)
end

return DockingEvent
