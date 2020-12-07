pub const BOOTBOOT_MAGIC = "BOOT";

/// memory mapped IO virtual address
pub const BOOTBOOT_MMIO = 0xfffffffff8000000;

/// frame buffer virtual address
pub const BOOTBOOT_FB = 0xfffffffffc000000;

/// bootboot struct virtual address
pub const BOOTBOOT_INFO = 0xffffffffffe00000;

/// environment string virtual address
pub const BOOTBOOT_ENV = 0xffffffffffe01000;

/// core loadable segment start
pub const BOOTBOOT_CORE = 0xffffffffffe02000;

/// hardcoded kernel name, static kernel memory addresses
pub const PROTOCOL_MINIMAL = 0;

/// kernel name parsed from environment, static kernel memory addresses
pub const PROTOCOL_STATIC = 1;

/// kernel name parsed, kernel memory addresses from ELF or PE symbols
pub const PROTOCOL_DYNAMIC = 2;

/// big-endian flag
pub const PROTOCOL_BIGENDIAN = 0x80;

// loader types, just informational
pub const LOADER_BIOS = 0 << 2;
pub const LOADER_UEFI = 1 << 2;
pub const LOADER_RPI = 2 << 2;
pub const LOADER_COREBOOT = 3 << 2;

/// framebuffer pixel format, only 32 bits supported
pub const FramebufferFormat = extern enum(u8) {
    ARGB, RGBA, ABGR, BGRA
};

/// don't use. Reserved or unknown regions
pub const MMAP_USED = 0;

/// usable memory
pub const MMAP_FREE = 1;

/// acpi memory, volatile and non-volatile as well
pub const MMAP_ACPI = 2;

/// memory mapped IO region
pub const MMAP_MMIO = 3;

/// mmap entry, type is stored in least significant tetrad (half byte) of size
/// this means size described in 16 byte units (not a problem, most modern
/// firmware report memory in pages, 4096 byte units anyway).
pub const MMapEnt = packed struct {
    ptr: u64,
    size: u64,

    pub inline fn getPtr(mmapEnt: MMapEnt) u64 {
        return mmapEnt.ptr;
    }

    pub inline fn getSize(mmapEnt: MMapEnt) u64 {
        return mmapEnt.size & 0xFFFFFFFFFFFFFFF0;
    }

    pub inline fn getType(mmapEnt: MMapEnt) u16 {
        return mmapEnt.size & 0xF;
    }

    pub inline fn isFree(mmapEnt: MMapEnt) bool {
        return (mmapEnt.size & 0xF) == 1;
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
};

pub const Arch = extern union {
    x86_64: x86_64,
    aarch64: Aarch64,
};

extern var fb: u32;

pub inline fn getFramebuffer() [*]volatile u32 {
    return @ptrCast([*]volatile u32, &fb);
}

pub inline fn getFramebufferSlice() []volatile u32 {
    return getFramebuffer()[0..(bootboot.fb_width * bootboot.fb_height)];
}

extern const environment: u8;

pub inline fn getEnvironment() [*:0]const u8 {
    return @ptrCast([*:0]const u8, &environment);
}

pub extern const bootboot: BOOTBOOT;

/// first 64 bytes is platform independent
pub const BOOTBOOT = packed struct {
    /// 'BOOT' magic
    magic: [4]u8,

    /// length of bootboot structure, minimum 128
    size: u32,

    /// 1, static addresses, see PROTOCOL_* and LOADER_* above
    protocol: u8,

    /// framebuffer type, see FB_* above
    fb_type: FramebufferFormat,

    /// number of processor cores
    numcores: u16,

    /// Bootsrap processor ID (Local APIC Id on x86_64)
    bspid: u16,

    /// in minutes -1440..1440
    timezone: i16,

    /// in BCD yyyymmddhhiiss UTC (independent to timezone)
    datetime: [8]u8,

    /// ramdisk image position
    initrd_ptr: u64,

    /// ramdisk image size
    initrd_size: u64,

    /// framebuffer pointer
    fb_ptr: u64,

    /// framebuffer size
    fb_size: u32,

    /// framebuffer width
    fb_width: u32,

    /// framebuffer height
    fb_height: u32,

    /// framebuffer scanline
    fb_scanline: u32,

    /// the rest (64 bytes) is platform specific
    arch: Arch,

    /// from 128th byte, MMapEnt[], more records may follow
    mmap: MMapEnt,
};
