-- B42.21 SP: select the actual upstream file using getModFileReader.
-- Only transform an exact reviewed source; otherwise run current upstream
-- unchanged, with the bundled reviewed source as an unmodified last resort.
CodexStimSource = CodexStimSource or {}
local S=CodexStimSource
local function read(mod, path)
    local ok, result = pcall(function()
        local reader=getModFileReader(mod,path,false)
        if not reader then return nil end
        local parts={}
        while true do local line=reader:readLine(); if line==nil then break end; parts[#parts+1]=line end
        reader:close(); return table.concat(parts,"\n")
    end)
    return ok and result or nil
end
local function replaceAll(text, old, new, expected)
    local out, at, count={},1,0
    while true do
        local first,last=string.find(text,old,at,true)
        if not first then out[#out+1]=string.sub(text,at);break end
        count=count+1;out[#out+1]=string.sub(text,at,first-1);out[#out+1]=new;at=last+1
    end
    if count~=expected then return nil end
    return table.concat(out)
end
function S.Run(mod, path, ref, transformations, label, guards)
    local upstream=read(mod,path)
    local pinned=read("Codex_StimCompatibility_4221",ref)
    local chosen=upstream or pinned
    if not chosen then error("[CodexStimCompat] unable to read upstream or fallback: "..label) end
    local transformed=false
    local guardsMatch=true
    for _, guard in ipairs(guards or {}) do
        local current=read(guard[1],guard[2])
        local expected=read("Codex_StimCompatibility_4221",guard[3])
        if not current or not expected or current~=expected then guardsMatch=false;break end
    end
    if upstream and pinned and upstream==pinned and guardsMatch then
        local candidate=upstream
        for _,spec in ipairs(transformations) do
            candidate=replaceAll(candidate,spec[1],spec[2],spec[3])
            if not candidate then break end
        end
        if candidate then chosen=candidate;transformed=true end
    end
    local chunk,err=loadstring(chosen,"@"..mod.."/"..path)
    if not chunk then error("[CodexStimCompat] source compile failed: "..tostring(err)) end
    print("[CodexStimCompat] "..label.." "..(transformed and "adapted" or "original fallback"))
    return chunk()
end
return S
