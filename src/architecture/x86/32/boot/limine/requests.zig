const protocol = @import("protocol.zig");

const LIMINE_REQUESTS_START_MARKER = .{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};

const LIMINE_REQUESTS_END_MARKER = .{
    0xadc0e0531bb10d03,
    0x9572709f31764c62,
};

pub export var requests_start_marker: [LIMINE_REQUESTS_START_MARKER.len]u64 linksection(".limine_requests_start") = LIMINE_REQUESTS_START_MARKER;

pub export var hhdm_request: protocol.HhdmRequest linksection(".limine_requests") = .{};
pub export var memory_map_request: protocol.MemoryMapRequest linksection(".limine_requests") = .{};
pub export var module_request: protocol.ModuleRequest linksection(".limine_requests") = .{};
pub export var framebuffer_request: protocol.FramebufferRequest linksection(".limine_requests") = .{};

pub export var requests_end_marker: [LIMINE_REQUESTS_END_MARKER.len]u64 linksection(".limine_requests_end") = LIMINE_REQUESTS_END_MARKER;

pub fn hhdmOffset() usize {
    const response = hhdm_request.response orelse return 0;
    return @intCast(response.offset);
}

pub fn memoryMapResponse() ?*protocol.MemoryMapResponse {
    return memory_map_request.response;
}

pub fn moduleResponse() ?*protocol.ModuleResponse {
    return module_request.response;
}

pub fn framebufferResponse() ?*protocol.FramebufferResponse {
    return framebuffer_request.response;
}
