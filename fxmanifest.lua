fx_version 'cerulean'
games { 'gta5' }
name 'murderface-pets'
author 'FMRP Development Team'
description 'Pet companion system for FMRP'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/namevalidation.lua',
    'shared/variations.lua',
    'shared/animations.lua',
    'config.lua',
    'locales/en.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/functions.lua',
    'client/client.lua',
    'client/leash.lua',
    'client/guard.lua',
    'client/strays.lua',
    'client/doghouse.lua',
    'client/menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/functions.lua',
    'server/server.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
}
