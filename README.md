to add dep to build.zig.zon
run `zig fetch --save git+https://github.com/allyourcodebase/sdl#main`
(https://discord.com/channels/605571803288698900/634812978994085888/1244299177471643689)

## To run on mac:

`brew install sdl2 sdl2_image watchexec`
then
`watchexec -e zig -r -- zig build` and run the executable
