// Pure finger-gesture classifier for the reading shell — no Qt, no device deps, so it is unit-tested
// off-device (tests/gesture_test.cpp). TouchReader feeds it the contact's travel + dwell and turns the
// result into a page-turn (swipe) or a tap / long-press (link peek) for the C++ tap router in main().
#pragma once
namespace rmweb {

enum class Gesture { None, SwipeUp, SwipeDown, SwipeLeft, SwipeRight, Tap, LongPress };

struct GestureParams {
    int swipeMinDy    = 240;  // vertical travel (panel px) to count as a page turn (~11% of height)
    int swipeMaxDx    = 200;  // keep a swipe roughly vertical (reject diagonals)
    int hSwipeMinDx   = 200;  // horizontal travel (panel px) for a sideways swipe (paginated web readers)
    int hSwipeMaxDy   = 150;  // keep a sideways swipe roughly horizontal (reject diagonals)
    int tapMaxMove    = 40;   // max travel (panel px) for a contact to still be a tap
    int tapMaxDwellMs = 700;  // max contact duration (ms) for a tap — longer is a long-press (link peek)
    // Quick flicks: a swipe that starts on the bezel is only seen once the finger reaches the glass,
    // so it covers much less screen than the motion really was. A short, fast, clearly one-way
    // stroke still counts.
    int flickMaxDwellMs = 350;  // contact no longer than this ...
    int flickMinTravel  = 90;   // ... travelling at least this far (panel px) ...
                                // ... and at least twice as far along its axis as across it.
};

// Distances scaled to the panel: the defaults above were tuned on the Paper Pro (1620x2160), and on
// the narrower Move (954x1696) a fixed 200 px sideways swipe is over a fifth of the screen.
inline GestureParams gestureParamsFor(int panelW, int panelH) {
    GestureParams p;
    if (panelW <= 0 || panelH <= 0) return p;
    p.swipeMinDy  = panelH * 11 / 100;   // 1696 -> 186, 2160 -> 237
    p.hSwipeMinDx = panelW * 13 / 100;   //  954 -> 124, 1620 -> 210
    p.swipeMaxDx  = panelW * 12 / 100;   //  954 -> 114, 1620 -> 194
    p.hSwipeMaxDy = panelH * 7 / 100;    // 1696 -> 118, 2160 -> 151
    p.flickMinTravel = panelW * 9 / 100; //  954 ->  85, 1620 -> 145
    return p;
}

// dx,dy = lift - down position (panel px); dwellMs = contact duration. A near-stationary, short contact
// is a Tap; a near-stationary LONG one is a LongPress (link peek); a long, mostly-vertical contact is a
// Swipe; a long, mostly-horizontal one is a SwipeLeft/SwipeRight (only paginated readers act on it);
// a short but quick one-way stroke (flick) is a swipe too; everything else (diagonal, tiny drift over
// a long hold past the move cap, a slow short drag) is None.
inline Gesture classifyGesture(int dx, int dy, int dwellMs, const GestureParams& p = {}) {
    const int adx = dx < 0 ? -dx : dx;
    const int ady = dy < 0 ? -dy : dy;
    if (adx <= p.tapMaxMove && ady <= p.tapMaxMove)
        return dwellMs <= p.tapMaxDwellMs ? Gesture::Tap : Gesture::LongPress;
    if (adx < p.swipeMaxDx && ady >= p.swipeMinDy)
        return dy < 0 ? Gesture::SwipeUp : Gesture::SwipeDown;
    if (ady < p.hSwipeMaxDy && adx >= p.hSwipeMinDx)
        return dx < 0 ? Gesture::SwipeLeft : Gesture::SwipeRight;
    if (dwellMs <= p.flickMaxDwellMs) {
        if (adx >= p.flickMinTravel && adx >= 2 * ady) return dx < 0 ? Gesture::SwipeLeft : Gesture::SwipeRight;
        if (ady >= p.flickMinTravel && ady >= 2 * adx) return dy < 0 ? Gesture::SwipeUp : Gesture::SwipeDown;
    }
    return Gesture::None;
}

} // namespace rmweb
