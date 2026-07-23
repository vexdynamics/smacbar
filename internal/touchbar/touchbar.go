// Package touchbar wraps the private DFRFoundation/NSTouchBar APIs needed to
// present a persistent, system-wide Touch Bar dashboard.
package touchbar

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Cocoa -framework ImageIO -framework WebKit -F/System/Library/PrivateFrameworks -framework DFRFoundation
#include <stdlib.h>
#include "bridge.h"
*/
import "C"

import (
	"runtime"
	"unsafe"
)

var (
	ready      = make(chan struct{})
	tapHandler func(id string)
)

//export goAppReady
func goAppReady() {
	close(ready)
}

//export goWidgetTapped
func goWidgetTapped(identifier *C.char) {
	if tapHandler == nil {
		return
	}
	tapHandler(C.GoString(identifier))
}

// SetTapHandler registers the callback invoked when any widget is tapped,
// with the widget's identifier.
func SetTapHandler(fn func(id string)) {
	tapHandler = fn
}

// RegisterWidget adds a widget button to the dashboard. Call before Present.
// icon is an SF Symbol name (e.g. "terminal", "message"); pass "" for none.
func RegisterWidget(id, icon, initialTitle string) {
	cID := C.CString(id)
	cIcon := C.CString(icon)
	cTitle := C.CString(initialTitle)
	defer C.free(unsafe.Pointer(cID))
	defer C.free(unsafe.Pointer(cIcon))
	defer C.free(unsafe.Pointer(cTitle))
	C.TB_RegisterWidget(cID, cIcon, cTitle)
}

// UpdateWidgetBadge updates a registered widget's badge count, overlaid on
// its icon. Pass "" to clear the badge. Safe to call from any goroutine.
func UpdateWidgetBadge(id, count string) {
	cID := C.CString(id)
	cCount := C.CString(count)
	defer C.free(unsafe.Pointer(cID))
	defer C.free(unsafe.Pointer(cCount))
	C.TB_UpdateWidgetBadge(cID, cCount)
}

// Present shows (or re-shows) the dashboard with all registered widgets.
func Present() {
	C.TB_PresentDashboard()
}

// CaptureDashboard renders the current widgets to a PNG at path, for preview
// purposes (not a real hardware screenshot).
func CaptureDashboard(path string) {
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))
	C.TB_CaptureDashboard(cPath)
}

// RegisterWebWidget adds a widget rendering arbitrary HTML/CSS/GIF/video at
// the given width (points). Call before Present.
func RegisterWebWidget(id, html string, width float64) {
	cID := C.CString(id)
	cHTML := C.CString(html)
	defer C.free(unsafe.Pointer(cID))
	defer C.free(unsafe.Pointer(cHTML))
	C.TB_RegisterWebWidget(cID, cHTML, C.double(width))
}

// RegisterWebWidgetWithBaseURL registers a web widget with a base URL for resolving relative links/assets.
func RegisterWebWidgetWithBaseURL(id, html, baseURL string, width float64) {
	cID := C.CString(id)
	cHTML := C.CString(html)
	cBase := C.CString(baseURL)
	defer C.free(unsafe.Pointer(cID))
	defer C.free(unsafe.Pointer(cHTML))
	defer C.free(unsafe.Pointer(cBase))
	C.TB_RegisterWebWidgetWithBaseURL(cID, cHTML, cBase, C.double(width))
}

// RegisterWebWidgetURL registers a web widget that loads from a URL or file path.
func RegisterWebWidgetURL(id, url string, width float64) {
	cID := C.CString(id)
	cURL := C.CString(url)
	defer C.free(unsafe.Pointer(cID))
	defer C.free(unsafe.Pointer(cURL))
	C.TB_RegisterWebWidgetURL(cID, cURL, C.double(width))
}

// Run starts the Touch Bar app. onReady is invoked, on a separate goroutine,
// once the app has finished launching and the Control Strip icon is
// registered — that's when RegisterWidget/Present are safe to call. Run
// blocks forever on the calling goroutine's OS thread, which must be the
// process's real main thread, so it should be called directly from main().
func Run(onReady func()) {
	runtime.LockOSThread()
	go func() {
		<-ready
		onReady()
	}()
	C.TB_Run()
}
