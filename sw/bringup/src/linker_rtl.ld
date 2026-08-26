/* linker.ld
 * Minimal bare-metal linker script for the custom RV32IM core.
 * Matches main_memory.sv: single RAM region, 0x00000000 - 0x00003FFF (16KB).
 */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

ENTRY(_start)

SECTIONS
{
    .text : ALIGN(4)
    {
        *(.text.start)
        *(.text)
        *(.text.*)
    } > RAM

    .rodata : ALIGN(4)
    {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    .data : ALIGN(4)
    {
        _data_start = .;
        *(.data)
        *(.data.*)
        _data_end = .;
    } > RAM

    .bss : ALIGN(4)
    {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    _telemetry_start = ALIGN(4);  /* placed after .bss in the SECTIONS block, before _stack_top */

    _heap_start = ALIGN(4);
    _stack_top  = ORIGIN(RAM) + LENGTH(RAM);

    ASSERT(_stack_top <= ORIGIN(RAM) + LENGTH(RAM), "Error: memory image exceeds RAM size")
}
