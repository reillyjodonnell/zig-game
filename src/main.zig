const c = @cImport({
    @cInclude("SDL2/SDL.h"); // Import core SDL
    @cInclude("SDL2/SDL_image.h"); // Import SDL_image
});
const std = @import("std");
const assert = @import("std").debug.assert;

const FPS: usize = 60;
const FRAME_TARGET_TIME: f32 = @divExact(1.0, FPS);

const ball = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

const Camera = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    zoom: f32 = 10.0, // Default zoom level is 1.0 (100%)

};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var game = try Game.init(allocator, "zig game", 0, 0, 400, 140, false);
    defer game.deinit();

    while (game.isRunning()) {
        try game.handleEvents();
        try game.update();
        try game.render();
    }
}

const GameStatus = enum {
    RUNNING,
    PAUSED,
    QUIT,
};

const Game = struct {
    allocator: std.mem.Allocator,
    window: *c.SDL_Window,

    renderer: *c.SDL_Renderer,
    last_frame_time: u32 = 0,

    status: GameStatus = .RUNNING,

    assets: Assets,

    pub fn init(allocator: std.mem.Allocator, title: [*c]const u8, x: c_int, y: c_int, width: c_int, height: c_int, fullscreen: bool) !Game {
        // Initialize SDL
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }

        // Set window flags
        var flags: c_uint = c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE;
        if (fullscreen) {
            flags |= c.SDL_WINDOW_FULLSCREEN;
        }

        // Create SDL window
        const window = c.SDL_CreateWindow(title, x, y, width, height, flags);
        if (window == null) {
            c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
            c.SDL_Quit();
            return error.WindowCreationFailed;
        }

        // Create SDL renderer
        const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);
        if (renderer == null) {
            c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.RendererCreationFailed;
        }

        var assets = Assets.init(allocator, renderer.?);

        // Load the assets
        try assets.loadTexture(0, "src/grass.bmp");
        try assets.loadTexture(1, "src/character_1.bmp");

        const player_sprite = Sprite.init(assets.getTexture(1).?, 50, 50, 32, 64);
        try assets.sprites.put(0, player_sprite);

        const instance = Game{
            .window = window.?,
            .renderer = renderer.?,
            .allocator = allocator,
            .assets = assets,
        };

        // Initialize and return the Game struct instance
        return instance;
    }

    // Clean up resources
    pub fn deinit(self: *Game) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn isRunning(self: *Game) bool {
        return self.status == .RUNNING;
    }

    pub fn handleEvents(self: *Game) !void {
        var event: c.SDL_Event = undefined;
        _ = c.SDL_PollEvent(&event);

        switch (event.type) {
            c.SDL_QUIT => {
                self.status = .QUIT;
            },
            // c.SDL_KEYDOWN => {
            //     const keySym = event.key.keysym.sym;
            //     switch (keySym) {
            //         c.SDLK_UP, c.SDLK_w => moving_up = true,
            //         c.SDLK_DOWN, c.SDLK_s => moving_down = true,
            //         c.SDLK_LEFT, c.SDLK_a => moving_left = true,
            //         c.SDLK_RIGHT, c.SDLK_d => moving_right = true,
            //         else => {},
            //     }
            // },
            // c.SDL_KEYUP => {
            //     const keySym = event.key.keysym.sym;
            //     switch (keySym) {
            //         c.SDLK_UP, c.SDLK_w => moving_up = false,
            //         c.SDLK_DOWN, c.SDLK_s => moving_down = false,
            //         c.SDLK_LEFT, c.SDLK_a => moving_left = false,
            //         c.SDLK_RIGHT, c.SDLK_d => moving_right = false,
            //         else => {},
            //     }
            // },
            else => {},
        }
    }

    pub fn update(self: *Game) !void {
        const delta_time = @divFloor((c.SDL_GetTicks() - self.last_frame_time), @as(u32, 1000.0));
        // Store the milliseconds of the current frame to be used in the next one
        self.last_frame_time = c.SDL_GetTicks();

        // Update all game objects based off the delta time
        _ = delta_time;
    }

    pub fn render(self: *Game) !void {
        _ = c.SDL_RenderClear(self.renderer);
        try renderGrid(self.renderer, self.assets.getTexture(0).?);
        var sprites_iterator = self.assets.sprites.iterator();
        while (sprites_iterator.next()) |entry| {
            try renderPlayer(self.renderer, entry.value_ptr);
        }
        c.SDL_RenderPresent(self.renderer);
    }
};

const Sprite = struct {
    texture: *c.SDL_Texture,
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn init(texture: *c.SDL_Texture, x: i32, y: i32, width: i32, height: i32) Sprite {
        return Sprite{
            .texture = texture,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
};

const Assets = struct {
    allocator: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    tiles: std.hash_map.AutoHashMap(u32, *c.SDL_Texture),
    sprites: std.hash_map.AutoHashMap(u32, Sprite),
    assets: std.hash_map.AutoHashMap(u32, *c.SDL_Texture),

    pub fn init(allocator: std.mem.Allocator, renderer: *c.SDL_Renderer) Assets {
        return Assets{
            .allocator = allocator,
            .renderer = renderer,
            .tiles = std.hash_map.AutoHashMap(u32, *c.SDL_Texture).init(allocator),
            .sprites = std.hash_map.AutoHashMap(u32, Sprite).init(allocator),
            .assets = std.hash_map.AutoHashMap(u32, *c.SDL_Texture).init(allocator),
        };
    }

    pub fn deinit(self: *Assets) void {
        // Free each texture and then the hash maps themselves
        for (self.tiles.items) |*entry| {
            c.SDL_DestroyTexture(entry.value);
        }
        self.tiles.deinit();

        for (self.sprites.items) |*entry| {
            c.SDL_DestroyTexture(entry.value);
        }
        self.sprites.deinit();

        for (self.assets.items) |*entry| {
            c.SDL_DestroyTexture(entry.value);
        }
        self.assets.deinit();
    }

    pub fn loadTexture(self: *Assets, id: u32, path: [*c]const u8) !void {
        // Load the image
        const surface = c.IMG_Load(path);
        if (surface == null) {
            c.SDL_Log("Unable to load texture: %s", c.SDL_GetError());
            return error.TextureLoadFailed;
        }
        defer c.SDL_FreeSurface(surface);

        // Create the texture from the surface
        const texture = c.SDL_CreateTextureFromSurface(self.renderer, surface);
        if (texture == null) {
            c.SDL_Log("Unable to create texture from surface: %s", c.SDL_GetError());
            return error.TextureCreationFailed;
        }

        // Insert the texture into the assets hashmap with the given ID
        try self.assets.put(id, texture.?);
    }

    pub fn getTexture(self: *Assets, id: u32) ?*c.SDL_Texture {
        return self.assets.get(id);
    }
};

pub fn renderPlayer(
    renderer: *c.SDL_Renderer,
    ref: *Sprite,
) !void {
    var playerRect = c.SDL_Rect{
        .x = ref.x,
        .y = ref.y,
        .w = ref.width,
        .h = ref.height,
    };

    if (c.SDL_RenderCopy(renderer, ref.texture, null, &playerRect) != 0) {
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
            const screen_x: i32 = grid_x * TILE_WIDTH;
            const screen_y: i32 = grid_y * TILE_HEIGHT;

            var destRect = c.SDL_Rect{
                .x = screen_x,
                .y = screen_y,
                .w = TILE_WIDTH,
                .h = TILE_HEIGHT,
            };

            if (c.SDL_RenderCopy(renderer, tileTexture, null, &destRect) != 0) {
                return error.RenderCopyFailed;
            }
        }
    }
}
