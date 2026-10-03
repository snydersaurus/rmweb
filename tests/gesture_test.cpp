// Host unit test for the pure tap/swipe classifier (no Qt, no device). Build+run on the dev host:
//   clang++ -std=c++17 -o build/gesture_test tests/gesture_test.cpp && ./build/gesture_test
#include "../engine/wpeqt/gesture.h"
#include <cstdio>
using namespace rmweb;

static int fails = 0;
#define CHECK(c) do { if(!(c)) { std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); ++fails; } } while(0)

int main() {
    CHECK(classifyGesture(0, -300, 200) == Gesture::SwipeUp);    // finger up   = next page
    CHECK(classifyGesture(10, 300, 200) == Gesture::SwipeDown);  // finger down = prev page
    CHECK(classifyGesture(5, 5, 120)    == Gesture::Tap);        // small move, short dwell
    CHECK(classifyGesture(5, 5, 2000)   == Gesture::LongPress);  // long stationary hold = peek
    CHECK(classifyGesture(300, 300, 200) == Gesture::None);      // diagonal -> nothing
    CHECK(classifyGesture(0, 100, 500)   == Gesture::None);      // short, slow vertical -> nothing

    // Exact swipe boundaries (defaults: swipeMinDy=240 inclusive, swipeMaxDx=200 exclusive)
    CHECK(classifyGesture(0, 240, 200)   == Gesture::SwipeDown); // dy == swipeMinDy -> swipe
    CHECK(classifyGesture(0, 239, 500)   == Gesture::None);      // dy one px short (slow: not a flick)
    CHECK(classifyGesture(0, -240, 200)  == Gesture::SwipeUp);   // same boundary upwards
    CHECK(classifyGesture(199, 300, 200) == Gesture::SwipeDown); // dx < swipeMaxDx: vertical enough
    CHECK(classifyGesture(200, 300, 200) == Gesture::None);      // dx == swipeMaxDx: diagonal, rejected

    // Exact tap boundaries (tapMaxMove=40 and tapMaxDwellMs=700, both inclusive)
    CHECK(classifyGesture(40, 40, 700) == Gesture::Tap);         // all maxima hit exactly
    CHECK(classifyGesture(41, 0, 100)  == Gesture::None);        // 1px over tap move, short of a swipe
    CHECK(classifyGesture(0, 0, 701)   == Gesture::LongPress);   // 1ms over tap dwell -> long-press

    // Horizontal swipes (defaults: hSwipeMinDx=200 inclusive, hSwipeMaxDy=150 exclusive)
    CHECK(classifyGesture(-300, 0, 200)   == Gesture::SwipeLeft);  // finger left  = next page (paginated readers)
    CHECK(classifyGesture(300, 20, 200)   == Gesture::SwipeRight); // finger right = prev page
    CHECK(classifyGesture(-200, 149, 200) == Gesture::SwipeLeft);  // both boundaries hit exactly
    CHECK(classifyGesture(-199, 0, 500)   == Gesture::None);       // dx one px short (slow: not a flick)
    CHECK(classifyGesture(-300, 150, 500) == Gesture::None);       // dy == hSwipeMaxDy: diagonal, rejected

    // Quick flicks (defaults: flickMinTravel=90, flickMaxDwellMs=350, 2:1 along:across)
    CHECK(classifyGesture(-120, 10, 180) == Gesture::SwipeLeft);   // short sideways flick from the bezel
    CHECK(classifyGesture(110, -20, 250) == Gesture::SwipeRight);
    CHECK(classifyGesture(0, -120, 200)  == Gesture::SwipeUp);     // short vertical flick
    CHECK(classifyGesture(-120, 10, 600) == Gesture::None);        // same distance, slow drag: not a turn
    CHECK(classifyGesture(-89, 0, 150)   == Gesture::None);        // one px short of a flick
    CHECK(classifyGesture(-100, 60, 150) == Gesture::None);        // too diagonal for a flick
    CHECK(classifyGesture(-90, 45, 350)  == Gesture::SwipeLeft);   // all flick boundaries hit exactly
    CHECK(classifyGesture(30, 30, 100)   == Gesture::Tap);         // a quick tap is still a tap

    // Panel-scaled distances
    {
        const GestureParams move = gestureParamsFor(954, 1696);
        CHECK(move.hSwipeMinDx == 124 && move.swipeMinDy == 186);
        CHECK(classifyGesture(-130, 20, 500, move) == Gesture::SwipeLeft);   // 13.6% of the Move's width
        CHECK(classifyGesture(-130, 20, 500)       == Gesture::None);        // the Paper Pro default refuses it
        const GestureParams pp = gestureParamsFor(1620, 2160);
        CHECK(pp.hSwipeMinDx == 210 && pp.swipeMinDy == 237);
        CHECK(gestureParamsFor(0, 0).hSwipeMinDx == GestureParams{}.hSwipeMinDx);   // degenerate size: defaults
    }

    // Dwell gates only taps, not swipes
    CHECK(classifyGesture(0, 300, 5000) == Gesture::SwipeDown);  // slow swipe still turns the page

    if (fails == 0) std::printf("gesture_test: OK\n");
    return fails ? 1 : 0;
}
