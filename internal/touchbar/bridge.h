#ifndef SMACBAR_BRIDGE_H
#define SMACBAR_BRIDGE_H

void TB_Run(void);
void TB_DumpAPI(void);

// Registers a widget button in the dashboard, in registration order.
// Must be called before TB_PresentDashboard.
void TB_RegisterWidget(const char *identifier, const char *sfSymbolName,
                        const char *initialTitle);

// Presents (or re-presents) the dashboard containing all registered widgets.
void TB_PresentDashboard(void);

// Updates a previously registered widget's badge count, overlaid on its
// icon (Dock-badge style). Pass "" to clear the badge. Safe to call from any
// thread.
void TB_UpdateWidgetBadge(const char *identifier, const char *count);

// Renders the current dashboard widgets to a PNG file at outputPath, for
// debugging/preview purposes (not a real hardware screenshot).
void TB_CaptureDashboard(const char *outputPath);

// Registers a widget that renders arbitrary HTML/CSS (and GIF/video via
// normal <img>/<video> tags) at the given width, filling extra dashboard
// space. Must be called before TB_PresentDashboard.
void TB_RegisterWebWidget(const char *identifier, const char *html,
                           double width);

void TB_RegisterWebWidgetWithBaseURL(const char *identifier, const char *html,
                                      const char *baseURL, double width);

void TB_RegisterWebWidgetURL(const char *identifier, const char *url,
                              double width);

#endif
