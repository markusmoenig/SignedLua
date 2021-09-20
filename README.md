# Signed - A 3D modeling language

![screenshot](images/screen.png)

## Abstract

*Signed* is a Lua based 3D modeling language, it provides a unique way to create high quality 3D content for your game or visualization.

Artist driven workflows of the major 3D editing packages are great, for artists. Developers still have a hard time creating high quality content for their games and *Signed* hopes to fill this gap.

*Signed* itself is a development language, but it will over time provide tools to dynamically visualize for example paths and areas while typing.

*Signed* will be available for macOS and iPad OS and is heavily optimized for Metal.

## How it works

*Signed* executes SDF modeling and material commands into a 3D texture utilizing Disney BSDF materials. A full featured BSDF path tracer is included. The content of the 3D texture will later be able to be exported to polygons.

*Signed* is based on Lua, a fast and easy to learn scripting language which provides the foundation for the Signed workflow.

You can create objects, materials and modules (language extensions) in your project and even share them in the public database (thus expanding the available language).

## Modeling Commands

The following code creates a slightly rounded, reflective red box at the center of your available 3D space.

```lua
local bbox = bbox:new()

local box = command:newShape("Box")
box:set("position", bbox.center)
box:set("size", 1, 1, 1)
box:set("rounding", 0.1)
box:set("color", 1, 0, 0)
box:set("roughness", 0.2)
box:execute(0)
```

The execute call models the box, the parameter for execute is the material index for the modeling call. You can later re-use this material id to stack any amount of material layers.

Different shapes support different geometry parameters, selecting the shape icon in *Signed* will show a list of the supported parameters of the shape.

Use setMode() to change the boolean mode of the command:

```lua
box:setMode("subtract")
box:set("smoothing", 0.1)
```

This would subtract the shape from the content in the 3D texture, other modes are "add" (the default) and "intersect". The smoothing parameter allows for smooth boolean operations.

## Coordinates and Bounding Boxes

The coordinate 0, 0, 0 is the center of the 3D texture, with positive *X* and *Y* coordinates pointing right and up and positive *Z* pointing away from the observer. 

The extent of the available modeling space is the 3D texture size divided by the pixel per meter parameter. Both can be changed in the settings of the current scene. A 3D texture size of 500x500x500 and 100 pixels per meter would give a total available modeling space of 5 meters.

The bounding box (bbox) module helps to provide more context as it provides a lot of helper functions and members like left, right, top, bottom, front and back (all numbers) and center, size and the rotation (all vec3).

The default bounding box can be created with

```lua
local bbox = bbox:new()
```

and encapsulates the available 3D modeling space. Bounding boxes are heavily used by objects.

All functionality in *Signed* is available via public modules, selecting a module will show the implementation and detailed help in the source code.

## Objects

Objects help to bundle a set of modeling commands into re-usable components called objects. Adding objects to your project and sharing them with the community is one the core functions of *Signed*.

Let's consider this simple example object, called Sphere:

```lua
function buildObject(index, bbox, options)
    -- options
    local radius = options.radius or 1.0

    local cmd = command:newShape("Sphere")
    cmd:set("position", bbox.center)
    cmd:set("radius", radius)

    bbox:execute(cmd, index)
end

-- Default size for preview rendering
function defaultSize()
    return vec3(1, 1, 1)
end
```

You will note that an object definition gets it's own bounding box, together with the base material index and the options table.

Important here is to note that we do not call the cmd:execute() function but the execute function of the bbox and pass it the command and material index. We do this so that rotated bounding boxes can modify the rotation parameters of the cmd to correctly rotate around the center of the bounding box.

To instantiate an object (from either your project or an arbitrary object from the public database) use something like this:

```lua
local bbox = bbox:new()

local pos = vec3(bbox.center.x + (bbox.right - bbox.center.x) / 2, bbox.center.y, bbox.center.z)
local size = vec3(bbox.right - bbox.center.x, bbox.size.y, bbox.size.z)

local obj = command:newObject("Sphere", bbox:new(pos, size, vec3(0, 0, 0)))
obj:execute(0, { radius: 1.5 })
```

This models tbhe Sphere object in the right half of the global bounding box. We create the bounding box and pass it to the newObject() function of the command class. 

We then execute the object with the material index and the options we want to pass.

The bounding box is created by passing three vec3, the first one is the position (or center) of the bbox, the second parameter is the size. The third parameter is the rotation of the bbox which is here just a 0 vector (and could be omitted).

As with the modules, selecting an object will show it's source code and clicking the "Build" button will build the preview of the object. Examining the source code of object's is a good way to learn more about *Signed* (and Lua if you are not yet familiar with the language).

## Materials

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
