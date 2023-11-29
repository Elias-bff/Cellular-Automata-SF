--@name 3D cellular test
--@author Elias
--@client

http.get("https://raw.githubusercontent.com/Elias-bff/SF-linker/main/linker.lua",function(data)
    loadstring(data)()
    
    load({
        ["https://raw.githubusercontent.com/Elias-bff/3D-Space-Renderer-SF/main/libs/3D_Space_renderer.lua"]=function()
            space=render.createRenderer:new({
                type="3d",
                size=5,
                scale=6,
                pos=chip():getPos(),
            },chip())
        end
    })
end)

local thread=nil
local rules={
    survive={4},
    spawn={4},
    states=5,
    neighbor="M",
    
    spawnType="random",
    spawnAmount=20,
    seed="random",
    size=4,
    color=0
}

rules.pretty=table.toString(rules.survive).." / "..table.toString(rules.spawn).." / "..rules.states

local structs={
    m={
        Vector(-1,-1,-1),
        Vector(-1,0,-1),
        Vector(-1,1,-1),
        Vector(-1,-1,0),
        Vector(-1,0,0),
        Vector(-1,1,0),
        Vector(-1,-1,1),
        Vector(-1,0,1),
        Vector(-1,1,1),
        
        Vector(0,-1,-1),
        Vector(0,0,-1),
        Vector(0,1,-1),
        Vector(0,-1,0),
        Vector(0,0,0),
        Vector(0,1,0),
        Vector(0,-1,1),
        Vector(0,0,1),
        Vector(0,1,1),
        
        Vector(1,-1,-1),
        Vector(1,0,-1),
        Vector(1,1,-1),
        Vector(1,-1,0),
        Vector(1,0,0),
        Vector(1,1,0),
        Vector(1,-1,1),
        Vector(1,0,1),
        Vector(1,1,1)
    },
    
    nm={
        Vector(1,0,0),
        Vector(-1,0,0),
        Vector(0,1,0),
        Vector(0,-1,0),
        Vector(0,0,1),
        Vector(0,0,-1)
    }
}

local cells={
    pool={}
}

function cells.get(pos)
    return cells.pool[pos[3]*rules.size*rules.size+pos[1]*rules.size+pos[2]]
end

function cells.set(pos,state)
    if !pos:withinAABox(Vector(-rules.size),Vector(rules.size)) then
        return
    end
    
    cells.pool[pos[3]*rules.size*rules.size+pos[1]*rules.size+pos[2]]={
        state=state,
        pos=pos
    }
end

function cells.remove(pos)
    cells.pool[pos[3]*rules.size*rules.size+pos[1]*rules.size+pos[2]]=nil
end

function cells.countNeighbours(pos)
    local count=0
    
    for _,vec in pairs(string.lower(rules.neighbor)=="m" and structs.m or structs.nm) do
        local cell=cells.get(vec+pos)
        
        if cell and cell.state==rules.states then
            count=count+1
        end
    end
    
    return count
end

function intRange(ints)
    local range={}
    
    for i,v in pairs(ints) do
        if string.find(tostring(v),"-") then
            local ints=string.split(tostring(v),"-")
            ints[1]=tonumber(ints[1])
            ints[2]=tonumber(ints[2])
            
            for ii=ints[1],ints[2] do
                range[#range+1]=tonumber(ii)
            end
        else
            range[#range+1]=tonumber(v)
        end
    end
    
    return range
end

function math.random(seed,min,max)
    return math.sharedRandom(tostring(seed),min,max)
end

function init()
    local seed=rules.seed=="random" and timer.systime() or rules.seed
    
    if string.lower(rules.spawnType)=="random" then
        for i=1,rules.spawnAmount do
            cells.set(Vector(math.random(seed+i,0,rules.size*2)-rules.size,math.random(seed+i*2,0,rules.size*2)-rules.size,math.random(seed+i*3,0,rules.size*2)-rules.size),rules.states)
        end
    else
        for i,vec in pairs(string.lower(rules.neighbor)=="m" and structs.m or structs.nm) do
            if math.random(seed+i,0,1)>0.5 then
                cells.set(vec,rules.states)
            end
        end
    end
    
    rules._color=rules.color=="random" and math.random(timer.systime()%255,0,255) or rules.color
end

init()

timer.create("",0.1,0,function()
    if quotaAverage()<0.006*0.3 and step then
        for _,cell in pairs(table.copy(cells.pool)) do
            for _,vec in pairs(string.lower(rules.neighbor)=="m" and structs.m or structs.nm) do
                local neighbours=cells.countNeighbours(vec+cell.pos)
                local neighbourCell=cells.get(vec+cell.pos)
                
                if !neighbourCell and table.hasValue(rules.spawn,neighbours) then
                    cells.set(vec+cell.pos,rules.states)
                end
                
                if neighbourCell and neighbourCell.state>rules.states-2 and #rules.survive!=0 and !table.hasValue(rules.survive,neighbours) then
                    cells.set(neighbourCell.pos,rules.states-1)
                end
            end
            
            if cell.state<=0 then
                cells.remove(cell.pos)
            else
                if cell.state!=rules.states then
                    cells.set(cell.pos,cell.state-1)
                end
            end
        end
        
        if table.count(cells.pool)==0 then
            init()
        end
        
        step=false
    end
end)

hook.add("renderoffscreen","",function()
    if !space then
        return
    end
    
    if !thread then
        thread=coroutine.create(function()
            space:draw(function()
                render.clear(Color(0,0,0,0))
                
                for _, cell in pairs(cells.pool) do                    
                    render.setColor(Color(rules._color,1/math.abs(cell.state-rules.states),1):hsvToRGB())
                    render.draw3DBox(localToWorld(cell.pos,Angle(),chip():getPos(),chip():getAngles()),chip():getAngles(),Vector(-rules.size/(rules.size*2)),Vector(rules.size/(rules.size*2)))
                end
                
                render.setColor(Color(210,210,210))
                render.draw3DWireframeBox(chip():getPos(),chip():getAngles(),Vector(-(rules.size+rules.size/(rules.size*2))),Vector(rules.size+rules.size/(rules.size*2)))

                render.popViewMatrix()
                
                local display={
                    space:toScreen(chip():getPos()+Vector(0,0,rules.size*2+4)),
                    space:toScreen(chip():getPos()+Vector(0,0,rules.size*2+2))
                }
                
                render.setColor(Color(255,255,255))
                render.setFont("DermaLarge")
                render.drawText(display[1].x,display[1].y,table.count(cells.pool),1)
                render.drawText(display[2].x,display[2].y,rules.pretty,1)
                
                coroutine.yield()
            end)
        end)
    end

    if coroutine.status(thread)=="suspended" and quotaAverage()<0.006*0.2 then
        coroutine.resume(thread)
    end
    
    if coroutine.status(thread)=="dead" and player():getPos():getDistance(chip():getPos())<100 then
        thread=nil
        step=true
    end
end)

hook.add("PlayerChat","",function(ply,text)
    local packet=string.split(text," ")
    
    if ply==owner() and packet[1]=="!rmatrix" then
        local _rules=string.split(string.replace(text,"!rmatrix ",""),"/")
        local survive=string.split(_rules[1],",") or {4}
        local spawn=string.split(_rules[2],",") or {4}
        cells.pool={}
        
        rules={
            survive=intRange(survive),
            spawn=intRange(spawn),
            states=tonumber(_rules[3]) or rules.states,
            neighbor=_rules[4][1] or rules.neighbor,

            seed=(packet[3]=="random" and packet[3] or tonumber(packet[3])) or rules.seed,
            spawnType=packet[4] or rules.spawnType,
            spawnAmount=packet[5] and (string.find(packet[5],"%%") and ((tonumber(packet[6]) or rules.size)*2)^3*tonumber(string.replace(packet[5],"%",""))/100 or packet[5]) or rules.spawnAmount,
            size=tonumber(packet[6]) or rules.size,
            color=(packet[7]=="random" and "random" or tonumber(packet[7])) or rules.color
        }
        
        rules.pretty=table.toString(rules.survive).." / "..table.toString(rules.spawn).." / "..rules.states
    end
end)

hook.add("inputPressed","",function(key)
    if key==15 and player():getEyeTrace().Entity==chip() then
        cells.pool={}
    end
end)