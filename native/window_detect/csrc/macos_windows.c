// macOS window-geometry bridge for the WindowDetect Layer-3 module.
//
// Uses CGWindowList, which returns every on-screen window's bounds + owner with NO
// permission grant. (Only window *titles* require Screen Recording; window-riding needs
// only geometry, so this path is permission-free.) See spike 3 doc §7.1.

#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Returns a malloc'd CSV string the caller must release with window_detect_macos_free().
// One line per normal application window: owner,pid,layer,x,y,w,h
// (Layer 0 = normal app windows; tiny/utility surfaces are filtered out.)
char* window_detect_macos_csv(void) {
    CGWindowListOption opt = kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements;
    CFArrayRef list = CGWindowListCopyWindowInfo(opt, kCGNullWindowID);

    size_t cap = 4096, len = 0;
    char* buf = (char*)malloc(cap);
    buf[0] = 0;
    if (!list) return buf;

    CFIndex n = CFArrayGetCount(list);
    for (CFIndex i = 0; i < n; i++) {
        CFDictionaryRef d = (CFDictionaryRef)CFArrayGetValueAtIndex(list, i);

        int layer = -999;
        CFNumberRef ln = (CFNumberRef)CFDictionaryGetValue(d, kCGWindowLayer);
        if (ln) CFNumberGetValue(ln, kCFNumberIntType, &layer);
        if (layer != 0) continue;

        CFDictionaryRef bd = (CFDictionaryRef)CFDictionaryGetValue(d, kCGWindowBounds);
        if (!bd) continue;
        CGRect r;
        if (!CGRectMakeWithDictionaryRepresentation(bd, &r)) continue;
        if (r.size.width < 60 || r.size.height < 60) continue;

        int pid = -1;
        CFNumberRef pn = (CFNumberRef)CFDictionaryGetValue(d, kCGWindowOwnerPID);
        if (pn) CFNumberGetValue(pn, kCFNumberIntType, &pid);

        char owner[256] = "?";
        CFStringRef on = (CFStringRef)CFDictionaryGetValue(d, kCGWindowOwnerName);
        if (on) CFStringGetCString(on, owner, sizeof(owner), kCFStringEncodingUTF8);
        // keep the CSV well-formed regardless of owner name
        for (char* p = owner; *p; p++) if (*p == ',' || *p == '\n') *p = ' ';

        char line[512];
        int m = snprintf(line, sizeof(line), "%s,%d,%d,%d,%d,%d,%d\n",
            owner, pid, layer,
            (int)r.origin.x, (int)r.origin.y,
            (int)r.size.width, (int)r.size.height);

        if (len + (size_t)m + 1 > cap) {
            cap = (len + (size_t)m + 1) * 2;
            buf = (char*)realloc(buf, cap);
        }
        memcpy(buf + len, line, m);
        len += m;
        buf[len] = 0;
    }

    CFRelease(list);
    return buf;
}

void window_detect_macos_free(char* p) {
    free(p);
}
