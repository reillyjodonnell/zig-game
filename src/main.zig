const c = @cImport({
    @cInclude("SDL2/SDL.h"); // Import core SDL
    @cInclude("SDL2/SDL_image.h"); // Import SDL_image
});
const std = @import("std");
const assert = @import("std").debug.assert;

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    if (c.IMG_Init(c.IMG_INIT_PNG) == 0) {
        c.SDL_Log("Unable to initialize SDL_image: %s", c.SDL_GetError());
        return error.ImageInitializationFailed;
    }
    defer c.IMG_Quit();

    const screen = c.SDL_CreateWindow("zig game", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 400, 140, (c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE)) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const lettuce_surface = c.IMG_Load("src/lettuce.png") orelse {
        c.SDL_Log("Unable to load png: %s", c.SDL_GetError());
        return error.ImageLoadFailed;
    };

    defer c.SDL_FreeSurface(lettuce_surface);

    const lettuce_texture = c.SDL_CreateTextureFromSurface(renderer, lettuce_surface) orelse {
        c.SDL_Log("Unable to create texture from surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyTexture(lettuce_texture);

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_RenderCopy(renderer, lettuce_texture, null, null);
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(17);
    }
}
