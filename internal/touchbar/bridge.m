#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import <WebKit/WebKit.h>
#import "bridge.h"
#import "_cgo_export.h"

extern void DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier,
                                                             BOOL);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL);
extern void DFREnableSystemAppModal(BOOL);

@interface NSTouchBarItem ()
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
@end

@interface NSTouchBar ()
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
           systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier
    NS_AVAILABLE_MAC(10.14);
@end

static NSImage *SMBTintedImage(NSImage *symbol, NSColor *color) {
  NSSize size = symbol.size;
  if (size.width < 1 || size.height < 1) {
    return symbol;
  }
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx =
      CGBitmapContextCreate(NULL, (size_t)ceil(size.width),
                             (size_t)ceil(size.height), 8, 0, colorSpace,
                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(colorSpace);

  NSGraphicsContext *nsContext =
      [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
  NSRect rect = NSMakeRect(0, 0, size.width, size.height);

  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:nsContext];
  [symbol drawInRect:rect
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
  [color set];
  NSRectFillUsingOperation(rect, NSCompositingOperationSourceAtop);
  [NSGraphicsContext restoreGraphicsState];

  CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
  CGContextRelease(ctx);
  NSImage *result = [[NSImage alloc] initWithCGImage:cgImage size:size];
  CGImageRelease(cgImage);
  return result;
}

static NSString *const kTrayIdentifier = @"dev.smacbar.tray";

static NSWindow *gOffscreenWindow;

@interface SMBAppDelegate : NSObject <NSApplicationDelegate, NSTouchBarDelegate, WKNavigationDelegate>
@property(nonatomic, strong) NSCustomTouchBarItem *trayItem;
@property(nonatomic, strong) NSTouchBar *dashboardBar;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSButton *> *widgetButtons;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *widgetIcons;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSView *> *webViews;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSTimer *> *webTimers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSCustomTouchBarItem *> *touchBarItems;
@property(nonatomic, strong) NSMutableArray<NSString *> *widgetOrder;
@end

static NSImage *SMBBadgedImage(NSString *sfSymbolName, NSString *count) {
  NSImage *symbol = [NSImage imageWithSystemSymbolName:sfSymbolName
                               accessibilityDescription:nil];
  if (!symbol) {
    return nil;
  }
  NSImage *base = SMBTintedImage(symbol, [NSColor whiteColor]);
  if (count.length == 0) {
    return base;
  }

  NSSize canvas = NSMakeSize(28, 24);
  NSImage *result = [[NSImage alloc] initWithSize:canvas];
  [result lockFocus];

  NSSize baseSize = base.size;
  NSRect iconRect = NSMakeRect(0, (canvas.height - baseSize.height) / 2.0,
                                baseSize.width, baseSize.height);
  [base drawInRect:iconRect
            fromRect:NSZeroRect
           operation:NSCompositingOperationSourceOver
            fraction:1.0];

  CGFloat badgeDiameter = 13;
  NSRect badgeRect =
      NSMakeRect(canvas.width - badgeDiameter, canvas.height - badgeDiameter,
                 badgeDiameter, badgeDiameter);
  NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:badgeRect];
  [[NSColor systemRedColor] setFill];
  [circle fill];

  NSDictionary *attrs = @{
    NSFontAttributeName : [NSFont boldSystemFontOfSize:9],
    NSForegroundColorAttributeName : [NSColor whiteColor]
  };
  NSSize textSize = [count sizeWithAttributes:attrs];
  NSPoint textPoint =
      NSMakePoint(NSMidX(badgeRect) - textSize.width / 2.0,
                  NSMidY(badgeRect) - textSize.height / 2.0);
  [count drawAtPoint:textPoint withAttributes:attrs];

  [result unlockFocus];
  return result;
}

static SMBAppDelegate *gDelegate;

@implementation SMBAppDelegate

- (instancetype)init {
  self = [super init];
  if (self) {
    _widgetButtons = [NSMutableDictionary dictionary];
    _widgetIcons = [NSMutableDictionary dictionary];
    _webViews = [NSMutableDictionary dictionary];
    _webTimers = [NSMutableDictionary dictionary];
    _touchBarItems = [NSMutableDictionary dictionary];
    _widgetOrder = [NSMutableArray array];
  }
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  DFRSystemModalShowsCloseBoxWhenFrontMost(NO);

  gOffscreenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
                                                 styleMask:NSWindowStyleMaskBorderless
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  [gOffscreenWindow setOpaque:NO];
  [gOffscreenWindow setBackgroundColor:[NSColor clearColor]];
  [gOffscreenWindow setAlphaValue:0.01];
  [gOffscreenWindow setIgnoresMouseEvents:YES];
  gOffscreenWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                         NSWindowCollectionBehaviorStationary |
                                         NSWindowCollectionBehaviorIgnoresCycle;
  gOffscreenWindow.level = NSStatusWindowLevel;
  [gOffscreenWindow orderFront:nil];

  NSButton *trayButton = [NSButton buttonWithTitle:@"\U0001F43C"
                                             target:self
                                             action:@selector(trayTapped:)];
  self.trayItem =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:kTrayIdentifier];
  self.trayItem.view = trayButton;
  [NSTouchBarItem addSystemTrayItem:self.trayItem];
  DFRElementSetControlStripPresenceForIdentifier(kTrayIdentifier, YES);

  NSLog(@"smacbar: tray icon registered");
  goAppReady();
}

- (void)registerWidgetWithIdentifier:(NSString *)identifier
                                 icon:(NSString *)sfSymbolName
                                title:(NSString *)title {
  NSButton *button = [NSButton buttonWithTitle:@""
                                         target:self
                                         action:@selector(widgetTapped:)];
  self.widgetIcons[identifier] = sfSymbolName;
  NSImage *image = SMBBadgedImage(sfSymbolName, title);
  if (image) {
    button.image = image;
    button.imagePosition = NSImageOnly;
  } else {
    button.title = title;
  }
  button.identifier = identifier;
  self.widgetButtons[identifier] = button;
  [self.widgetOrder addObject:identifier];
}

- (void)updateWidgetWithIdentifier:(NSString *)identifier count:(NSString *)count {
  NSString *icon = self.widgetIcons[identifier];
  NSButton *button = self.widgetButtons[identifier];
  if (!button) {
    return;
  }
  NSImage *image = SMBBadgedImage(icon, count);
  if (image) {
    button.image = image;
    button.imagePosition = NSImageOnly;
  } else {
    button.title = count;
  }
}

- (void)registerWebWidgetWithIdentifier:(NSString *)identifier
                                    html:(NSString *)html
                                   width:(CGFloat)width {
  [self registerWebWidgetWithIdentifier:identifier html:html baseURL:nil width:width];
}

- (void)registerWebWidgetWithIdentifier:(NSString *)identifier
                                    html:(NSString *)html
                                 baseURL:(NSString *)baseURLStr
                                   width:(CGFloat)width {
  NSButton *button = [NSButton buttonWithTitle:@""
                                         target:self
                                         action:@selector(widgetTapped:)];
  button.identifier = identifier;
  button.bordered = NO;
  self.widgetButtons[identifier] = button;

  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.mediaTypesRequiringUserActionForPlayback = 0;
  @try {
    [config.preferences setValue:@NO forKey:@"pageVisibilityBasedProcessSuppressionEnabled"];
  } @catch (NSException *e) {}
  WKWebView *webView =
      [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, 30)
                          configuration:config];
  webView.identifier = identifier;
  webView.navigationDelegate = self;
  [gOffscreenWindow.contentView addSubview:webView];

  NSURL *baseURL = baseURLStr.length > 0 ? [NSURL fileURLWithPath:baseURLStr] : nil;
  [webView loadHTMLString:html baseURL:baseURL];
  self.webViews[identifier] = webView;
  [self.widgetOrder addObject:identifier];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
    [self captureWebWidgetNextFrame:identifier];
  });
}

- (void)registerWebWidgetWithIdentifier:(NSString *)identifier
                                     url:(NSString *)urlStr
                                   width:(CGFloat)width {
  NSButton *button = [NSButton buttonWithTitle:@""
                                         target:self
                                         action:@selector(widgetTapped:)];
  button.identifier = identifier;
  button.bordered = NO;
  self.widgetButtons[identifier] = button;

  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.mediaTypesRequiringUserActionForPlayback = 0;
  @try {
    [config.preferences setValue:@NO forKey:@"pageVisibilityBasedProcessSuppressionEnabled"];
  } @catch (NSException *e) {}
  WKWebView *webView =
      [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, width, 30)
                          configuration:config];
  webView.identifier = identifier;
  webView.navigationDelegate = self;
  [gOffscreenWindow.contentView addSubview:webView];

  NSURL *url = [NSURL URLWithString:urlStr];
  if (!url.scheme || [url.scheme isEqualToString:@"file"]) {
    if (!url.scheme) {
      url = [NSURL fileURLWithPath:urlStr];
    }
    NSURL *dirURL = [url URLByDeletingLastPathComponent];
    [webView loadFileURL:url allowingReadAccessToURL:dirURL];
  } else {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];
  }
  self.webViews[identifier] = webView;
  [self.widgetOrder addObject:identifier];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
    [self captureWebWidgetNextFrame:identifier];
  });
}

- (void)captureWebWidgetNextFrame:(NSString *)identifier {
  WKWebView *webView = (WKWebView *)self.webViews[identifier];
  NSButton *button = self.widgetButtons[identifier];
  if (!webView || !button) {
    return;
  }

  WKSnapshotConfiguration *snapConfig = [[WKSnapshotConfiguration alloc] init];
  snapConfig.rect = webView.bounds;
  [webView takeSnapshotWithConfiguration:snapConfig
                        completionHandler:^(NSImage *snapshot, NSError *error) {
    if (snapshot && !error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        button.image = snapshot;
        button.imagePosition = NSImageOnly;
        button.needsDisplay = YES;
      });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(16 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
      [self captureWebWidgetNextFrame:identifier];
    });
  }];
}

- (void)presentDashboard {
  DFREnableSystemAppModal(YES);
  DFRSystemModalShowsCloseBoxWhenFrontMost(NO);

  NSTouchBar *bar = [[NSTouchBar alloc] init];
  bar.delegate = self;
  bar.defaultItemIdentifiers = [self.widgetOrder copy];
  self.dashboardBar = bar;

  @try {
    [NSTouchBar presentSystemModalTouchBar:self.dashboardBar
                  systemTrayItemIdentifier:kTrayIdentifier];
    NSLog(@"smacbar: dashboard presented with %lu widgets: %@",
          (unsigned long)self.widgetOrder.count, self.widgetOrder);
  } @catch (NSException *exception) {
    NSLog(@"smacbar: EXCEPTION presenting dashboard: %@ - %@",
          exception.name, exception.reason);
  }
}

- (void)trayTapped:(id)sender {
  [self presentDashboard];
}

- (void)widgetTapped:(NSButton *)sender {
  goWidgetTapped((char *)sender.identifier.UTF8String);
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
        makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
  NSCustomTouchBarItem *cached = self.touchBarItems[identifier];
  if (cached) {
    return cached;
  }
  NSView *view = self.widgetButtons[identifier];
  if (!view) {
    return nil;
  }
  NSCustomTouchBarItem *item =
      [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
  item.view = view;
  self.touchBarItems[identifier] = item;
  return item;
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  NSLog(@"smacbar: web view process terminated for %@, reloading...", webView.identifier);
  [webView reload];
}

@end

void TB_Run(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    SMBAppDelegate *delegate = [[SMBAppDelegate alloc] init];
    gDelegate = delegate;
    app.delegate = delegate;
    [app run];
  }
}

void TB_RegisterWidget(const char *identifier, const char *sfSymbolName,
                        const char *initialTitle) {
  NSString *nsIdentifier = [NSString stringWithUTF8String:identifier];
  NSString *nsIcon = [NSString stringWithUTF8String:sfSymbolName];
  NSString *nsTitle = [NSString stringWithUTF8String:initialTitle];
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate registerWidgetWithIdentifier:nsIdentifier
                                        icon:nsIcon
                                       title:nsTitle];
  });
}

void TB_PresentDashboard(void) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate presentDashboard];
  });
}

void TB_UpdateWidgetBadge(const char *identifier, const char *count) {
  NSString *nsIdentifier = [NSString stringWithUTF8String:identifier];
  NSString *nsCount = [NSString stringWithUTF8String:count];
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate updateWidgetWithIdentifier:nsIdentifier count:nsCount];
  });
}

void TB_CaptureDashboard(const char *outputPath) {
  NSString *path = [NSString stringWithUTF8String:outputPath];
  dispatch_async(dispatch_get_main_queue(), ^{
    CGFloat height = 30;
    CGFloat padding = 10;

    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    for (NSString *identifier in gDelegate.widgetOrder) {
      NSButton *button = gDelegate.widgetButtons[identifier];
      if (button) {
        [buttons addObject:button];
      }
    }

    CGFloat totalWidth = padding;
    for (NSButton *button in buttons) {
      NSSize size = button.image ? button.image.size : NSMakeSize(60, height);
      totalWidth += size.width + padding;
    }
    if (totalWidth < 100) {
      totalWidth = 100;
    }

    NSLog(@"smacbar: capturing %lu buttons, canvas=%.0fx%.0f",
          (unsigned long)buttons.count, totalWidth, height);
    for (NSButton *button in buttons) {
      NSLog(@"smacbar:   button id=%@ image=%@", button.identifier, button.image);
    }

    CGFloat scale = 2.0;
    size_t pxWidth = (size_t)(totalWidth * scale);
    size_t pxHeight = (size_t)(height * scale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, pxWidth, pxHeight, 8, 0,
                                              colorSpace,
                                              kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextScaleCTM(ctx, scale, scale);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, totalWidth, height));

    NSGraphicsContext *nsContext =
        [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];

    CGFloat x = padding;
    for (NSButton *button in buttons) {
      NSImage *img = button.image;
      if (img) {
        NSSize size = img.size;
        NSRect rect = NSMakeRect(x, (height - size.height) / 2.0, size.width,
                                  size.height);
        [img drawInRect:rect
                fromRect:NSZeroRect
               operation:NSCompositingOperationSourceOver
                fraction:1.0];
        x += size.width + padding;
      }
    }
    [NSGraphicsContext restoreGraphicsState];

    CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);

    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef dest =
        CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(dest, cgImage, NULL);
    CGImageDestinationFinalize(dest);
    CFRelease(dest);
    CGImageRelease(cgImage);

    NSLog(@"smacbar: dashboard capture saved to %@", path);
  });
}

void TB_RegisterWebWidget(const char *identifier, const char *html,
                           double width) {
  NSString *nsIdentifier = [NSString stringWithUTF8String:identifier];
  NSString *nsHtml = [NSString stringWithUTF8String:html];
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate registerWebWidgetWithIdentifier:nsIdentifier
                                           html:nsHtml
                                          width:(CGFloat)width];
  });
}

void TB_RegisterWebWidgetWithBaseURL(const char *identifier, const char *html,
                                      const char *baseURL, double width) {
  NSString *nsIdentifier = [NSString stringWithUTF8String:identifier];
  NSString *nsHtml = [NSString stringWithUTF8String:html];
  NSString *nsBaseURL = baseURL ? [NSString stringWithUTF8String:baseURL] : nil;
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate registerWebWidgetWithIdentifier:nsIdentifier
                                           html:nsHtml
                                        baseURL:nsBaseURL
                                          width:(CGFloat)width];
  });
}

void TB_RegisterWebWidgetURL(const char *identifier, const char *url,
                              double width) {
  NSString *nsIdentifier = [NSString stringWithUTF8String:identifier];
  NSString *nsUrl = [NSString stringWithUTF8String:url];
  dispatch_async(dispatch_get_main_queue(), ^{
    [gDelegate registerWebWidgetWithIdentifier:nsIdentifier
                                            url:nsUrl
                                          width:(CGFloat)width];
  });
}
