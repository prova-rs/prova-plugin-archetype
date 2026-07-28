---@meta {{ name }}
--- prova-{{ name }} — {{ description }}.
---
--- Editor-only type stub for `require("{{ name }}")`: it gives consumers completion and signatures
--- and ships nothing at runtime. Keep it in sync with init.lua's public API as the plugin grows.

local {{ ident }} = {}

--- Greet someone. Replace this with the plugin's real API.
---@param who string
---@return string
function {{ ident }}.greet(who) end

return {{ ident }}
