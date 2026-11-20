# Bubbles

Translucent bubbles in Roc's purples rise from the bottom of a dark violet
screen, wobbling side to side, and near the top each one fades away or pops
into droplets, while new ones keep coming, forever. It is one module
(`BubblesApp.roc`) and its two roots.

## The bubbles

Bubbles are born at a steady rate. Each one's look comes from a hash of its
number (`BubblesApp.numbered_bubble`):

- **Size and speed:** half are small and quick, a third middling, and the rest
  large and slow.
- **Wobble:** each sways about its own line, with its own width and period.
- **Colour:** one of a few purples, from Roc's logo's violet to a pale lilac,
  drawn as a translucent disc with a darker middle, which leaves a rim, and a
  white glint.
- **Ending:** some pop near the top, their droplets flying out and fading; the
  rest fade out.

`BubblesApp.roc` holds the numbers. The model is a count of steps and whether
it plays, and every frame is worked out from that count, so the frames are the
same on every run and the model stays small. The screen starts full: the frame
at step 0 is drawn as if the bubbles had been rising for a while.

## The keys

The app reads its keys from its step's `Input.Snapshot`, so they work the same
on the page and in the Windows window. Each acts on the step it is struck.

- **Space** pauses, holding every bubble still, and a second Space resumes.
- **R** starts again from the first frame and plays, even from a pause.

## Natively

Every shape is a disc with a flat fill, over one linear gradient for the
backdrop, so the native painter draws each as it is, and every fill is flat or
`Linear`. An expect holds the frames to that.

## The page

`web.roc` holds Steve's skin, as lanterns' does: the warming-up pill and the
keyboard help on, and the links Home (https://roc.lynrummy.com) and Code (this
repo). `?step=N` shows the frame after N steps and stops there.
