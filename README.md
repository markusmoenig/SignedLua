# Signed - A 3D modeling language

![screenshot](images/screen.png)

## Abstract

Signed is a Lua based 3D modeling and construction language and will be a unique way to create 3D content, objects as well as whole scenes, in high detail.

I believe that the artist driven workflow of the major 3D editing packages is great, for artists. Developers still have a hard time creating high quality content for their games and Signed hopes to fill this gap.

Signed itself is a development language, but it will over time provide tools to dynamically visualize for example paths and areas while typing.

Signed will be available for macOS and iPad OS and is heavily optimized for Metal.

## How it works

Signed executes SDF modeling and material commands into a 3D metal texture utilizing Disney BSDF materials. A full featured BSDF path tracer is included. The content of the 3D texture will later be able to be exported to polygons.

Signed is based on Lua, a fast and easy to learn scripting language which provides the foundation for the Signed workflow.

You can create objects, materials and modules in your project and share them in the public database, and therefore help expanding the Signed language.

Modules are an important part of Signed. For example the above screenshot has a 2D path defined by the *path2d* module which is than fed into the *wallbuilder* module to create walls (brick by brick) based on the given path.

## Examples

The following code creates a slightly rounded red box. In Signed you can select any given shape and the info window will show the available options for the shape.

```lua
local box = command:newShape("Box")
box:set("position", 0, 0, 0)
box:set("size", 5,0.2,5)
box:set("rounding", 0.1)
box:set("color", 1,0,0)
box:execute(0)
```

The call to execute draws the box, the parameter for execute is the material index for the modeling call. You can later re-use this material parameter to stack any amount of material layers.

```lua
local material = command:newMaterial("Gold")
material:setBlendMode("valuenoise", {
    offset = vec3(0,0,0);
    frequency = 3;
    smoothing = 6; -- octaves
})
material:execute(0)
```

The above would load the gold material from the database and apply it to all shapes which have an material index of 0. This particular command uses a value noise to blend the gold material to the existing material, you could also use linear blending:

```lua
material:setBlendMode("linear", {
    value = 0.6;
})
```
For shapes you can also define the boolean mode via setMode like

```lua
local sphere = command:newShape("Sphere")
sphere:setMode("add") -- "subtract", "intersect" etc
sphere:set("smoothing", 0.2)
sphere:set("radius", 1.2)
sphere:execute(1)
```

which would smoothly blend the sphere with the box. Signed has many options for modeling shapes and materials.

**Modules** are an important part of Signed in that they provide a shareable way to extend the language.

To create a wall with Signed, you can do something like

```lua
require("path2d")
require("wallbuilder")

local backPath = path2d:new() -- Create a line
backPath:moveTo(vec2(-2.3, -2))
backPath:lineTo(vec2(2.5, -2))

local builder = wallbuilder:new(backPath) -- Create a wall builder based on the given path
builder.brickSize = vec3(0.40, 0.30, 0.30) -- Adjust the brickSize and height of the wall.
builder.height = 4.6
builder:build((function(cmd, column, row)
    --[[ When building the wall this function is called with the modeling command and the brick
    column and row number of the current brick. We can use the modeling command to modify any aspect of the shape on a per brick basis.
    Here we slightly rotate the brick randomly around the Y axis to make it look a bit less uniform, modify it's color randomly a bit and set its roughness and specular options.
    --]]
    local rotation = cmd:getVec3("rotation")
    rotation.y = rotation.y + 40 * (math.random() - 0.5)
    cmd:setVec3("rotation", rotation)
    local rand = math.random() / 2
    local color = vec3(0.9 * rand,0.9 * rand,0.9 * rand)
    cmd:setVec3("color", color)
    cmd:setNumber("roughness", 0.2)
    cmd:setNumber("specular", 1)
    cmd:execute(5)
end
))
```

Over time many convenience modules will be added to Signed to make building complex objects and structures easier.

## Sponsors

Corporate sponsors for Signed are very welcome. If you company is involved in 3D, Signed would be a great project for you to sponsor.

## Status

Signed is currently in development. Although the basics are done, working out the APIs and UI, providing comprehensive (context) help, working out the modules and providing example projects will take some more months. I hope to provide a v1 on the AppStore within the year.

The APIs and modules provided by Signed may and will change until a v1 is released.

## License

Signed is licensed under the GPL, this is mostly to prevent others uploading copies to the AppStore. Everything you create inside Signed is of course under your copyright. 

I only ask to make objects, materials and modules you may upload to the public database free of any proprietory licenses and free to use and consume for everybody.

## Acknowledgements

* [Inigo Quilez](https://twitter.com/iquilezles) was my original inspiration for starting with signed distance functions, you can see his amazing work on [Shadertoy](https://www.shadertoy.com) and his research on his [website](https://www.iquilezles.org/www/index.htm).

* [Fabrice Neyret](https://twitter.com/FabriceNEYRET) and his shaders were a great learning resource as well, he was also extremely helpful in answering questions. His research is [here](http://evasion.imag.fr/~Fabrice.Neyret/).

* The Disney BSDF path tracer in Signed is based on [GLSL-PathTracer](https://github.com/knightcrawler25/GLSL-PathTracer) from [Asif](https://twitter.com/knightcrawler25).
