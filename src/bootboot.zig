const std = @import("std");

pub const BOOTBOOT_MAGIC = "BOOT";

/// memory mapped IO virtual address
pub const BOOTBOOT_MMIO: u64 = 0xfffffffff8000000;

/// frame buffer virtual address
pub const BOOTBOOT_FB: u64 = 0xfffffffffc000000;

/// bootboot struct virtual address
pub const BOOTBOOT_INFO: u64 = 0xffffffffffe00000;

/// environment string virtual address
pub const BOOTBOOT_ENV: u64 = 0xffffffffffe01000;

/// core loadable segment start
pub const BOOTBOOT_CORE: u64 = 0xffffffffffe02000;

/// hardcoded kernel name, static kernel memory addresses
pub const PROTOCOL_MINIMAL: u8 = 0;

/// kernel name parsed from environment, static kernel memory addresses
pub const PROTOCOL_STATIC: u8 = 1;

/// kernel name parsed, kernel memory addresses from ELF or PE symbols
pub const PROTOCOL_DYNAMIC: u8 = 2;

/// big-endian flag
pub const PROTOCOL_BIGENDIAN: u8 = 0x80;

// loader types, just informational
pub const LOADER_BIOS: u8 = 0 << 2;
pub const LOADER_UEFI: u8 = 1 << 2;
pub const LOADER_RPI: u8 = 2 << 2;
pub const LOADER_COREBOOT: u8 = 3 << 2;

/// framebuffer pixel format, only 32 bits supported
pub const FramebufferFormat = enum(u8) {
    ARGB = 0,
    RGBA = 1,
    ABGR = 2,
    BGRA = 3,
};

pub const MMapType = enum(u4) {
    /// don't use. Reserved or unknown regions
    MMAP_USED = 0,

    /// usable memory
    MMAP_FREE = 1,

    /// acpi memory, volatile and non-volatile as well
    MMAP_ACPI = 2,

    /// memory mapped IO region
    MMAP_MMIO = 3,
};

/// mmap entry, type is stored in least significant tetrad (half byte) of size
/// this means size described in 16 byte units (not a problem, most modern
/// firmware report memory in pages, 4096 byte units anyway).
pub const MMapEnt = extern struct {
    ptr: u64,
    size: u64,

    pub inline fn getPtr(mmapEnt: MMapEnt) u64 {
        return mmapEnt.ptr;
    }

    pub inline fn getSizeInBytes(mmapEnt: MMapEnt) u64 {
        return mmapEnt.size & 0xFFFFFFFFFFFFFFF0;
    }

    pub inline fn getSizeIn4KiBPages(mmapEnt: MMapEnt) u64 {
        return mmapEnt.getSizeInBytes() / 4096;
    }

    pub inline fn getType(mmapEnt: MMapEnt) MMapType {
        return @intToEnum(MMapType, @truncate(u4, mmapEnt.size));
    }

    pub inline fn isFree(mmapEnt: MMapEnt) bool {
        return (mmapEnt.size & 0xF) == 1;
    }

    comptime {
        std.debug.assert(@sizeOf(u64) * 2 == @sizeOf(MMapEnt));
    }
};

pub const INITRD_MAXSIZE = 16;

pub const x86_64 = extern struct {
    acpi_ptr: u64,
    smbi_ptr: u64,
    efi_ptr: u64,
    mp_ptr: u64,
    unused0: u64,
    unused1: u64,
    unused2: u64,
    unused3: u64,

    comptime {
        std.debug.assert(@sizeOf(u64) * 8 == @sizeOf(x86_64));
    }
};

pub const Aarch64 = extern struct {
    acpi_ptr: u64,
    mmio_ptr: u64,
    efi_ptr: u64,
    unused0: u64,
    unused1: u64,
    unused2: u64,
    unused3: u64,
    unused4: u64,

    comptime {
        std.debug.assert(@sizeOf(u64) * 8 == @sizeOf(Aarch64));
    }
};

pub const Arch = extern union {
    x86_64: x86_64,
    aarch64: Aarch64,

    comptime {
        std.debug.assert(@sizeOf(Arch) == @sizeOf(x86_64) and @sizeOf(Arch) == @sizeOf(x86_64));
    }
};

const provide_symbols_during_testing = if (@import("builtin").is_test) struct {
    export var fb: u32 = 0;
    export const environment: u8 = 0;
    export const bootboot: Bootboot = undefined;
} else struct {};

const externs = struct {
    extern var fb: u32;
    extern const environment: u8;
    extern const bootboot: Bootboot;
};

pub inline fn getBootboot() Bootboot {
    return externs.bootboot;
}

pub inline fn getFramebuffer() [*]volatile u32 {
    return @ptrCast([*]volatile u32, &externs.fb);
}

pub inline fn getFramebufferSlice() []volatile u32 {
    return getFramebuffer()[0..(externs.bootboot.fb_width * externs.bootboot.fb_height)];
}

pub inline fn getEnvironment() [*:0]const u8 {
    return @ptrCast([*:0]const u8, &externs.environment);
}

/// first 64 bytes is platform independent
pub const Bootboot = extern struct {
    /// 'BOOT' magic
    magic: u32 align(1),

    /// length of bootboot structure, minimum 128
    size: u32 align(1),

    /// 1, static addresses, see PROTOCOL_* and LOADER_* above
    protocol: u8,

    /// framebuffer type, see FB_* above
    fb_type: FramebufferFormat,

    /// number of processor cores
    numcores: u16 align(1),

    /// Bootsrap processor ID (Local APIC Id on x86_64)
    bspid: u16 align(1),

    /// in minutes -1440..1440
    timezone: i16 align(1),

    /// in BCD yyyymmddhhiiss UTC (independent to timezone)
    datetime: u64 align(1),

    /// ramdisk image position
    initrd_ptr: u64 align(1),

    /// ramdisk image size
    initrd_size: u64 align(1),

    /// framebuffer pointer
    fb_ptr: u64 align(1),

    /// framebuffer size
    fb_size: u32 align(1),

    /// framebuffer width
    fb_width: u32 align(1),

    /// framebuffer height
    fb_height: u32 align(1),

    /// framebuffer scanline
    fb_scanline: u32 align(1),

    /// the rest (64 bytes) is platform specific
    arch: Arch align(1),

    /// from 128th byte, MMapEnt[], more records may follow
    mmap: MMapEnt align(1),

    comptime {
        std.debug.assert(@sizeOf(u64) * 18 == @sizeOf(Bootboot));
    }
};

pub fn getMemoryMap() []const MMapEnt {
    if (externs.bootboot.size <= 128) return &[_]MMapEnt{};
    return @ptrCast([*]const MMapEnt, @alignCast(@alignOf(MMapEnt), &externs.bootboot.mmap))[0..((externs.bootboot.size - 128) / @sizeOf(MMapEnt))];
}

comptime {
    _ = provide_symbols_during_testing;
    std.testing.refAllDeclsRecursive(@This());
}
