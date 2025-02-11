local Config = Config or {}
local Framework = nil

if Config.Framework == 'ESX' then
    Citizen.CreateThread(function()
        while ESX == nil do
            ESX = exports['es_extended']:getSharedObject()
            Citizen.Wait(100)
        end
        Framework = ESX
    end)
elseif Config.Framework == 'QB' then
    Framework = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'QBX' then
    Framework = exports.qbx_core
end

function SetupInteraction(shop)
    if Config.Interaction == 'target' then
        SetupTargetInteraction(shop)
    else
        SetupTextUIInteraction(shop)
    end
end

function SetupTargetInteraction(shop)
    local targetFramework = Config.Target == 'ox_target' and 'ox_target' or 'qb-target'

    if targetFramework == 'ox_target' then
        exports.ox_target:addLocalEntity(shop.ped, {
            {
                name = 'neon_sellshop',
                icon = 'fa-solid fa-shop',
                label = shop.targetLabel,
                onSelect = function()
                    OpenSellMenu(shop)
                end
            }
        })
    elseif targetFramework == 'qb-target' then
        exports['qb-target']:AddTargetEntity(shop.ped, {
            options = {
                {
                    type = "client",
                    event = "neon_sellshop:sell",
                    icon = 'fa-solid fa-shop',
                    label = shop.targetLabel
                }
            },
            distance = 2.5
        })
    end
end

function SetupTextUIInteraction(shop)
    CreateThread(function()
        local isShowingTextUI = false

        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local pedCoords = shop.pedCoords
            local dist = #(playerCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z))

            if dist <= 1.5 then
                if not isShowingTextUI then
                    lib.showTextUI('[E] ' .. shop.targetLabel)
                    isShowingTextUI = true
                end

                if IsControlJustPressed(0, 38) then
                    OpenSellMenu(shop)
                end

                Wait(0)
            else
                if isShowingTextUI then
                    lib.hideTextUI()
                    isShowingTextUI = false
                end

                Wait(500)
            end
        end
    end)
end

function CreateShop(shop)
    local pedHash = GetHashKey(shop.pedModel)
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        Wait(1)
    end

    shop.ped = CreatePed(4, pedHash, shop.pedCoords.x, shop.pedCoords.y, shop.pedCoords.z, shop.pedCoords.w, false, true)
    FreezeEntityPosition(shop.ped, true)
    SetEntityInvincible(shop.ped, true)
    SetBlockingOfNonTemporaryEvents(shop.ped, true)

    if shop.blip then
        local blip = AddBlipForCoord(shop.pedCoords.x, shop.pedCoords.y, shop.pedCoords.z)
        SetBlipSprite(blip, shop.blipSettings.sprite)
        SetBlipDisplay(blip, shop.blipSettings.display)
        SetBlipScale(blip, shop.blipSettings.scale)
        SetBlipColour(blip, shop.blipSettings.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.blipSettings.label)
        EndTextCommandSetBlipName(blip)
    end

    SetupInteraction(shop)
end

RegisterNetEvent('neon_sellshop:receiveShopData', function(serverShops)
    Config.Shops = serverShops
    for _, shop in pairs(Config.Shops) do
        CreateShop(shop)
    end
end)

CreateThread(function()
    TriggerServerEvent('neon_sellshop:requestShopData')
end)

function OpenSellMenu(shop)
    local elements = {}
    local playerInventory = GetPlayerInventory()

    for item, data in pairs(shop.materials) do
        local count = playerInventory[item] and playerInventory[item].count or 0

        if count > 0 then
            local price = data.price
            table.insert(elements, {
                title = data.name,
                description = 'Total: ' .. count .. ' | Price: $' .. price,
                event = 'neon_sellshop:sell',
                args = {
                    item = item,
                    count = count,
                    price = price,
                    moneyType = shop.moneyType,
                    shopLabel = shop.label
                }
            })
        end
    end

    if #elements == 0 then
        Notify('You don\'t have any materials to sell.', 'error')
        return
    end

    lib.registerContext({
        id = 'sell_materials_menu',
        title = shop.label,
        options = elements,
    })

    lib.showContext('sell_materials_menu')
end

function GetPlayerInventory()
    if Config.Inventory == 'OX' then
        return exports.ox_inventory:Items()
    elseif Config.Inventory == 'QB' then
        return GetQBInventory()
    elseif Config.Inventory == 'PS' then
        return GetPSInventory()
    end
end

function GetQBInventory()
    local PlayerData = Framework.Functions.GetPlayerData()
    local inventory = {}

    for _, item in pairs(PlayerData.items) do
        inventory[item.name] = { count = item.amount }
    end

    return inventory
end

function GetPSInventory()
    local PlayerData = exports['ps-inventory']:getPlayerInventory()
    local inventory = {}

    for _, item in pairs(PlayerData) do
        inventory[item.name] = { count = item.amount }
    end

    return inventory
end

function Notify(message, type)
    if Config.Framework == 'ESX' then
        ESX.ShowNotification(message)
    elseif Config.Framework == 'QB' then
        Framework.Functions.Notify(message, type)
    elseif Config.Framework == 'QBX' then
        exports.qbx_core:Notify(message, type)
    end
end

RegisterNetEvent('neon_sellshop:sell', function(data)
    local input = nil

    if Config.InputType == 'input' then
        input = lib.inputDialog('Sell Amount', {
            { label = 'Enter amount to sell', type = 'input' }
        })
    elseif Config.InputType == 'slider' then
        input = lib.inputDialog('Sell Amount', {
            { label = 'Select amount to sell', type = 'slider', min = 1, max = data.count }
        })
    end

    if not input or not tonumber(input[1]) then
        Notify('Invalid amount entered.', 'error')
        return
    end

    local amountToSell = tonumber(input[1])

    if amountToSell > data.count then
        Notify('You don\'t have enough materials.', 'error')
        return
    end

    local payload = {
        item = data.item,
        amount = amountToSell,
        shopLabel = data.shopLabel,
        price = data.price,
        moneyType = data.moneyType
    }

    TriggerServerEvent('neon_sellshop:sellMaterial', payload)
end)