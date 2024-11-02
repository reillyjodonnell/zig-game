const c = @cImport({
    @cInclude("SDL2/SDL.h"); // Import core SDL
    @cInclude("SDL2/SDL_image.h"); // Import SDL_image
});
const std = @import("std");
const assert = @import("std").debug.assert;

const ball = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

const player = struct {
    x: i32,
    y: i32,
    width: i32 = 16,
    height: i32 = 16,

    pub fn move(self: *player, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }
};

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

    // Load the tile texture (example BMP file path)
    const tileSurface = c.SDL_LoadBMP("src/grass.bmp");
    if (tileSurface == null) return error.SurfaceLoadFailed;
    defer c.SDL_FreeSurface(tileSurface);

    const tileTexture = c.SDL_CreateTextureFromSurface(renderer, tileSurface);
    if (tileTexture == null) return error.TextureCreationFailed;
    defer c.SDL_DestroyTexture(tileTexture.?);

    var player_instance = player{ .x = 50, .y = 50 };

    // This is the game loop
    var quit = false;

    const MOVE_SPEED: i32 = 5;
    const multiplier: f32 = 1.414;
    const DIAGONAL_SPEED: i32 = @intFromFloat(MOVE_SPEED / multiplier); // Adjust speed for diagonals    var moving_down = false;

    var moving_up = false;
    var moving_down = false;
    var moving_left = false;
    var moving_right = false;

    while (!quit) {

        // process input
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    const keySym = event.key.keysym.sym;
                    switch (keySym) {
                        c.SDLK_UP, c.SDLK_w => moving_up = true,
                        c.SDLK_DOWN, c.SDLK_s => moving_down = true,
                        c.SDLK_LEFT, c.SDLK_a => moving_left = true,
                        c.SDLK_RIGHT, c.SDLK_d => moving_right = true,
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    const keySym = event.key.keysym.sym;
                    switch (keySym) {
                        c.SDLK_UP, c.SDLK_w => moving_up = false,
                        c.SDLK_DOWN, c.SDLK_s => moving_down = false,
                        c.SDLK_LEFT, c.SDLK_a => moving_left = false,
                        c.SDLK_RIGHT, c.SDLK_d => moving_right = false,
                        else => {},
                    }
                },
                else => {},
            }
        }

        // After processing events, update player position based on flags
        if (moving_up and !moving_down and !moving_left and !moving_right) player.move(&player_instance, 0, -MOVE_SPEED);
        if (moving_down and !moving_up and !moving_left and !moving_right) player.move(&player_instance, 0, MOVE_SPEED);
        if (moving_left and !moving_right and !moving_up and !moving_down) player.move(&player_instance, -MOVE_SPEED, 0);
        if (moving_right and !moving_left and !moving_up and !moving_down) player.move(&player_instance, MOVE_SPEED, 0);

        // Handle diagonal movement with adjusted speed
        if (moving_up and moving_left) player.move(&player_instance, -DIAGONAL_SPEED, -DIAGONAL_SPEED);
        if (moving_up and moving_right) player.move(&player_instance, DIAGONAL_SPEED, -DIAGONAL_SPEED);
        if (moving_down and moving_left) player.move(&player_instance, -DIAGONAL_SPEED, DIAGONAL_SPEED);
        if (moving_down and moving_right) player.move(&player_instance, DIAGONAL_SPEED, DIAGONAL_SPEED);
        // Clear the renderer
        _ = c.SDL_RenderClear(renderer);
        // Render the isometric grid
        try renderGrid(renderer, tileTexture.?);

        // Render the player
        try renderPlayer(renderer, &player_instance);

        // Present the rendered frame
        c.SDL_RenderPresent(renderer);
        // render

        c.SDL_Delay(17);
    }
}

pub fn renderPlayer(renderer: *c.SDL_Renderer, playerRef: *player) !void {
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    var playerRect = c.SDL_Rect{
        .x = playerRef.x,
        .y = playerRef.y,
        .w = playerRef.width,
        .h = playerRef.height,
    };
    if (c.SDL_RenderFillRect(renderer, &playerRect) != 0) {
        return error.RenderCopyFailed;
    }
}

const TILE_WIDTH = 32;
const TILE_HEIGHT = 32; // Update height to match width for non-isometric grid
const GRID_WIDTH = 200;
const GRID_HEIGHT = 200;

pub fn renderGrid(renderer: *c.SDL_Renderer, tileTexture: *c.SDL_Texture) !void {
    var grid_y: i32 = 0;
    while (grid_y < GRID_HEIGHT) : (grid_y += 1) {
        var grid_x: i32 = 0;
        while (grid_x < GRID_WIDTH) : (grid_x += 1) {
            // Calculate screen position for non-isometric projection
            const screen_x: i32 = grid_x * TILE_WIDTH;
            const screen_y: i32 = grid_y * TILE_HEIGHT;

            // Define the destination rectangle for SDL_RenderCopy
            var destRect = c.SDL_Rect{
                .x = screen_x,
                .y = screen_y,
                .w = TILE_WIDTH,
                .h = TILE_HEIGHT,
            };

            // Render the tile
            if (c.SDL_RenderCopy(renderer, tileTexture, null, &destRect) != 0) {
                return error.RenderCopyFailed;
            }
        }
    }
}

fn render(renderer: *c.SDL_Renderer) !void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderClear(renderer);

    var tile: c.SDL_Rect = c.SDL_Rect{ .x = 0, .y = 0, .w = 20, .h = 20 }; // x, y, width, height
    var tile_2: c.SDL_Rect = c.SDL_Rect{ .x = 30, .y = 0, .w = 20, .h = 20 }; // x, y, width, height
    var tile_3: c.SDL_Rect = c.SDL_Rect{ .x = 0, .y = 60, .w = 50, .h = 50 }; // x, y, width, height
    var tile_4: c.SDL_Rect = c.SDL_Rect{ .x = 60, .y = 60, .w = 50, .h = 50 }; // x, y, width, height

    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &tile);

    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &tile_2);

    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &tile_3);

    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &tile_4);

    // We need to swap the buffer to see the changes
    _ = c.SDL_RenderPresent(renderer);
}
