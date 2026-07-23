#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "bridge.h"

static void DumpMethods(const char *label, Class cls, BOOL classMethods) {
  Class target = classMethods ? object_getClass(cls) : cls;
  unsigned int count = 0;
  Method *methods = class_copyMethodList(target, &count);
  NSLog(@"---- %s (%s methods, %u total) ----", label,
        classMethods ? "class" : "instance", count);
  for (unsigned int i = 0; i < count; i++) {
    SEL sel = method_getName(methods[i]);
    NSLog(@"  %@", NSStringFromSelector(sel));
  }
  free(methods);
}

void TB_DumpAPI(void) {
  @autoreleasepool {
    DumpMethods("NSTouchBar", [NSTouchBar class], YES);
    DumpMethods("NSTouchBarItem", [NSTouchBarItem class], YES);
    DumpMethods("NSApplication", [NSApplication class], YES);
  }
}
