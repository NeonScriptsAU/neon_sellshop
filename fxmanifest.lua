fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Custard Sellshop'
description 'Sell Shop System'
version '1.0.6'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/*'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*'
}


dependencies {
    'ox_lib'
}
