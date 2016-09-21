-- Updates the hud with relevant information
class 'MicrobeEditorHudSystem' (System)

function MicrobeEditorHudSystem:__init()
    System.__init(self)
    self.organelleButtons = {}
    self.initialized = false
    self.editor = MicrobeEditor(self)

    -- Scene nodes for the organelle cursors for symmetry.
    self.hoverHex = {}
    self.hoverOrganelle = {}

    self.saveLoadPanel = nil
    self.creationsListbox = nil
    self.creationFileMap = {} -- Map from player creation name to filepath
    self.activeButton = nil -- stores button, not name
    self.helpPanelOpen = true
    self.organelleScrollPane = nil


    -- Some constants
    self.organelleDefinition = {
        flagellum = { buttonName = "AddFlagellum", keymap = kmp.flagellum},
        cilia = { buttonName = "AddCilia"},
        cytoplasm = { buttonName = "AddCytoplasm"},
        mitochondrion = { buttonName = "AddMitochondria", keymap = kmp.mitochondrion},
        vacuole = { buttonName = "AddVacuole", keymap = kmp.vacuole},
        toxin = { buttonName = "AddToxinVacuole", keymap = kmp.oxytoxyvacuole, lock = "Toxin"},
        chloroplast = { buttonName = "AddChloroplast", keymap = kmp.chloroplast, lock = "Chloroplast"}
    }
end


function MicrobeEditorHudSystem:init(gameState)
    System.init(self, "MicrobeEditorHudSystem", gameState)
    self.editor:init(gameState)

    self:createHoverEntities()

    local root = gameState:rootGUIWindow()
    self.mpLabel = root:getChild("MpPanel"):getChild("MpLabel")
    self.nameLabel = root:getChild("SpeciesNamePanel"):getChild("SpeciesNameLabel")
    self.nameTextbox = root:getChild("SpeciesNamePanel"):getChild("NameTextbox")
    root:getChild("SpeciesNamePanel"):registerEventHandler("Clicked",
        function() global_activeMicrobeEditorHudSystem:nameClicked() end)
    -- self.mpProgressBar = root:getChild("BottomSection"):getChild("MutationPoints"):getChild("MPBar")
    self.organelleScrollPane = root:getChild("scrollablepane");

    -- nucleus is a special organelle.
    local nucleusButton = root:getChild("NewMicrobe")
    self.organelleButtons.nucleus = nucleusButton
    nucleusButton:registerEventHandler("Clicked", function() self:nucleusClicked() end)

    -- Create organelle buttons
    for organelleName, definition in pairs(self.organelleDefinition) do
        local organelleButton = root:getChild("scrollablepane"):getChild(definition.buttonName)
        self.organelleButtons[organelleName] = organelleButton
        organelleButton:registerEventHandler("Clicked", function() self:organelleClicked(organelleName) end)
    end

    self.activeButton = nil

    -- self.saveLoadPanel = root:getChild("SaveLoadPanel")
    -- self.creationsListbox = self.saveLoadPanel:getChild("SavedCreations")
    self.undoButton = root:getChild("UndoButton")
    self.undoButton:registerEventHandler("Clicked", function() self.editor:undo() end)
    self.redoButton = root:getChild("RedoButton")
    self.redoButton:registerEventHandler("Clicked", function() self.editor:redo() end)
    self.symmetryButton = root:getChild("SymmetryButton")
    self.symmetryButton:registerEventHandler("Clicked", function() self:changeSymmetry() end)

    root:getChild("FinishButton"):registerEventHandler("Clicked", playClicked)
    --root:getChild("BottomSection"):getChild("MenuButton"):registerEventHandler("Clicked", self:menuButtonClicked)
    root:getChild("MenuButton"):registerEventHandler("Clicked", menuMainMenuClicked)
    --root:getChild("MenuPanel"):getChild("QuitButton"):registerEventHandler("Clicked", self:quitButtonClicked)
    root:getChild("SaveMicrobeButton"):registerEventHandler("Clicked", function() self:saveCreationClicked() end)
    --root:getChild("LoadMicrobeButton"):registerEventHandler("Clicked", function() self:loadCreationClicked() end)

    self.helpPanel = root:getChild("HelpPanel")
    root:getChild("HelpButton"):registerEventHandler("Clicked", function() self:helpButtonClicked() end)
    self.helpPanel:registerEventHandler("Clicked", function() self:helpButtonClicked() end)

    -- Set species name and cut it off if it is too long.
    local name = self.nameLabel:getText()
    if string.len(name) > 18 then
        name = string.sub(name, 1, 15)
        name = name .. "..."
    end
    self.nameLabel:setText(name)
end

function MicrobeEditorHudSystem:createHoverEntities()
    function createEntity(name, index)
        local entity = Entity(name .. index)
        local sceneNode = OgreSceneNodeComponent()
        sceneNode.transform.position = Vector3(0,0,0)
        sceneNode.transform:touch()
        if name == "hover-hex" then
            sceneNode.meshName = "hex.mesh"
        end
        entity:addComponent(sceneNode)
        return entity;
    end

    -- There has to be some reason behind those magic numbers? 42 and 6?
    for i=1, 42 do
        self.hoverHex[i] = createEntity("hover-hex", i)
    end
    for i=1, 6 do
        self.hoverOrganelle[i] = createEntity("hover-organelle", i)
    end
end

function MicrobeEditorHudSystem:activate()
    global_activeMicrobeEditorHudSystem = self -- Global reference for event handlers
    self.editor:activate()
    for organelleName, definition in pairs(self.organelleDefinition) do
        print(organelleName)
        local button = self.organelleButtons[organelleName]
        if definition.lock and Engine:playerData():lockedMap():isLocked(definition.lock) then
            button:disable()
        else
            button:enable()
        end
    end
end

function MicrobeEditorHudSystem:setActiveAction(actionName)
    self.editor:setActiveAction(actionName)
    if actionName == "nucleus" then
        -- For now we simply create a new microbe with the nucleus button
        self.editor:performLocationAction()
    end
end

function MicrobeEditorHudSystem:update(renderTime, logicTime)
    function update (table)
        for i,element in ipairs(table) do
            local sceneNode = element:getComponent(OgreSceneNodeComponent.TYPE_ID)
            sceneNode.transform.position = Vector3(0,0,0)
            sceneNode.transform.scale = Vector3(0,0,0)
            sceneNode.transform:touch()
        end
    end
    update(self.hoverHex)
    update(self.hoverOrganelle)

    self.editor:update(renderTime, logicTime)

    -- Handle input
    if Engine.mouse:wasButtonPressed(Mouse.MB_Left) then
        self.editor:performLocationAction()
    end
    if Engine.mouse:wasButtonPressed(Mouse.MB_Right) then
        self:removeClicked()
        self.editor:performLocationAction()
    end

    for organelleName, definition in pairs(self.organelleDefinition) do
        if definition.keymap and keyCombo(definition.keymap) and not Engine:playerData():lockedMap():isLocked(definition.lock) then
            self:organelleClicked(organelleName)
            self.editor:performLocationAction()
            break
        end
    end

    if keyCombo(kmp.newmicrobe) then
        -- These global event handlers are defined in microbe_editor_hud.lua
        self:nucleusClicked()
    elseif keyCombo(kmp.redo) then
        self.editor:redo()
    elseif keyCombo(kmp.remove) then
        self:removeClicked()
        self.editor:performLocationAction()
    elseif keyCombo(kmp.undo) then
        self.editor:undo()
    elseif keyCombo(kmp.togglegrid) then
        self.editor.gridSceneNode.visible = not self.editor.gridVisible
        self.editor.gridVisible = not self.editor.gridVisible
    elseif keyCombo(kmp.gotostage) then
        playClicked()
    elseif keyCombo(kmp.rename) then
        self:updateMicrobeName()
    end

    if Engine.keyboard:wasKeyPressed(Keyboard.KC_LEFT) or Engine.keyboard:wasKeyPressed(Keyboard.KC_A) then
		self.editor.organelleRot = (self.editor.organelleRot + 60)%360
	elseif Engine.keyboard:wasKeyPressed(Keyboard.KC_RIGHT) or Engine.keyboard:wasKeyPressed(Keyboard.KC_D) then
		self.editor.organelleRot = (self.editor.organelleRot - 60)%360
	end

    if keyCombo(kmp.screenshot) then
        Engine:screenShot("screenshot.png")
    end

    if Engine.keyboard:isKeyDown(Keyboard.KC_LSHIFT) then
        properties = Entity(CAMERA_NAME .. 3):getComponent(OgreCameraComponent.TYPE_ID).properties
        newFovY = properties.fovY + Degree(Engine.mouse:scrollChange()/10)
        if newFovY < Degree(10) then
            newFovY = Degree(10)
        elseif newFovY > Degree(120) then
            newFovY = Degree(120)
        end
        properties.fovY = newFovY
        properties:touch()
    else
        local organelleScrollVal = self.organelleScrollPane:scrollingpaneGetVerticalPosition() + Engine.mouse:scrollChange()/1000
        if organelleScrollVal < 0 then
            organelleScrollVal = 0
        elseif organelleScrollVal > 1.0 then
            organelleScrollVal = 1.0
        end
        self.organelleScrollPane:scrollingpaneSetVerticalPosition(organelleScrollVal)

    end
end

function MicrobeEditorHudSystem:updateMutationPoints()
    --self.mpProgressBar:progressbarSetProgress(self.editor.mutationPoints/100)
    self.mpLabel:setText("" .. self.editor.mutationPoints)
end

-----------------------------------------------------------------
-- Event handlers -----------------------------------------------
function playButtonClickedSound()
    local guiSoundEntity = Entity("gui_sounds")
    guiSoundEntity:getComponent(SoundSourceComponent.TYPE_ID):playSound("button-hover-click")
end

function gameStateButtonClicked(gameState)
    playButtonClickedSound()
    Engine:setCurrentGameState(gameState)
end

function playClicked()
    gameStateButtonClicked(GameState.MICROBE)
end

function menuPlayClicked()
    Engine:currentGameState():rootGUIWindow():getChild("MenuPanel"):hide()
    playClicked()
end

function menuMainMenuClicked()
    gameStateButtonClicked(GameState.MAIN_MENU)
end

-- the rest of the event handlers are MicrobeEditorHudSystem methods

function MicrobeEditorHudSystem:nameClicked()
    self.nameLabel:hide()
    self.nameTextbox:show()
    self.nameTextbox:setFocus()
end

function MicrobeEditorHudSystem:updateMicrobeName()
    self.editor.currentMicrobe.microbe.speciesName = self.nameTextbox:getText()
    local name = self.editor.currentMicrobe.microbe.speciesName
    if string.len(name) > 18 then
        name = string.sub(self.editor.currentMicrobe.microbe.speciesName, 1, 15)
        name = name .. "..."
    end
    self.nameLabel:setText(name)
    self.nameTextbox:hide()
    self.nameLabel:show()
end

function MicrobeEditorHudSystem:helpButtonClicked()
    playButtonClickedSound()
    if self.helpPanelOpen then
        self.helpPanel:hide()
    else
        self.helpPanel:show()
    end
    self.helpPanelOpen = not self.helpPanelOpen
end

function MicrobeEditorHudSystem:nucleusClicked()
    if self.activeButton ~= nil then
        self.activeButton:enable()
    end
    self:setActiveAction("nucleus")
end

function MicrobeEditorHudSystem:organelleClicked(organelleName)
    if self.activeButton ~= nil then
        self.activeButton:enable()
    end
    self.activeButton = self.organelleButtons[organelleName]
    self.activeButton:disable()
    self:setActiveAction(organelleName)
end

function MicrobeEditorHudSystem:removeClicked()
    if self.activeButton ~= nil then
        self.activeButton:enable()
    end
    self.activeButton = nil
    self:setActiveAction("remove")
end

function MicrobeEditorHudSystem:rootLoadCreationClicked()
    playButtonClickedSound()
    panel = self.saveLoadPanel
    panel:getChild("SaveButton"):hide()
    panel:getChild("NameTextbox"):hide()
    panel:getChild("CreationNameDialogLabel"):hide()
    panel:getChild("LoadButton"):show()
    panel:getChild("SavedCreations"):show()
    panel:show()
    self.creationsListbox:itemListboxResetList()
    self.creationFileMap = {}
    i = 0
    pathsString = Engine:getCreationFileList("microbe")
    -- using pattern matching for splitting on spaces
    for path in string.gmatch(pathsString, "%S+")  do
        -- this is unsafe when one of the paths is, for example, C:\\Application Data\Thrive\saves
        item = CEGUIWindow("Thrive/ListboxItem", "creationItems"..i)
        pathSep = package.config:sub(1,1) -- / for unix, \ for windows
        text = string.sub(path, string.len(path) - string.find(path:reverse(), pathSep) + 2)
        item:setText(text)
        self.creationsListbox:itemListboxAddItem(item)
        self.creationFileMap[text] = path
        i = i + 1
    end
    self.creationsListbox:itemListboxHandleUpdatedItemData()
end

function MicrobeEditorHudSystem:saveCreationClicked()
    playButtonClickedSound()
    name = self.editor.currentMicrobe.microbe.speciesName
    print("saving "..name)
    -- Todo: Additional input sanitation
    name, _ = string.gsub(name, "%s+", "_") -- replace whitespace with underscore
    if string.match(name, "^[%w_]+$") == nil then
        print("unsanitary name: "..name) -- should we do the test before whitespace sanitization?
    elseif string.len(name) > 0 then
        Engine:saveCreation(self.editor.currentMicrobe.entity.id, name, "microbe")
    end
end

function MicrobeEditorHudSystem:loadCreationClicked()
    playButtonClickedSound()
    item = self.creationsListbox:itemListboxGetLastSelectedItem()
    if not item:isNull() then
        entity = Engine:loadCreation(self.creationFileMap[item:getText()])
        self.editor:loadMicrobe(entity)
        panel:hide()
    end
end

-- useful debug functions

function MicrobeEditorHudSystem:loadByName(name)
    if string.find(name, ".microbe") then
        print("note, you don't need to add the .microbe extension")
    else
        name = name..".microbe"
    end
    name, _ = string.gsub(name, "%s+", "_")
    creationFileMap = {}
    i = 0
    pathsString = Engine:getCreationFileList("microbe")
    -- using pattern matching for splitting on spaces
    for path in string.gmatch(pathsString, "%S+")  do
        -- this is unsafe when one of the paths is, for example, C:\\Application Data\Thrive\saves
        pathSep = package.config:sub(1,1) -- / for unix, \ for windows
        text = string.sub(path, string.len(path) - string.find(path:reverse(), pathSep) + 2)
        creationFileMap[text] = path
        i = i + 1
    end
    entity = Engine:loadCreation(creationFileMap[name])
    self.editor:loadMicrobe(entity)
    self.nameLabel:setText(self.editor.currentMicrobe.microbe.speciesName)
end

function MicrobeEditorHudSystem:changeSymmetry()
    self.editor.symmetry = (self.editor.symmetry+1)%4
    local symmetryMap = {"None", "Two", "Four", "Six"}
    local symmetry = symmetryMap[self.editor.symmetry]
    self.symmetryButton:setProperty("ThriveGeneric/Symmetry" + symmetry + "Normal", "Image")
    self.symmetryButton:setProperty("ThriveGeneric/Symmetry" + symmetry + "Hover", "PushedImage")
    self.symmetryButton:setProperty("ThriveGeneric/Symmetry" + symmetry + "Hover", "HoverImage")
end

function saveMicrobe() global_activeMicrobeEditorHudSystem:saveCreationClicked() end
function loadMicrobe(name) global_activeMicrobeEditorHudSystem:loadByName(name) end
