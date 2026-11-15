# Bubbles

Translucent bubbles in Roc's purples rise from the bottom of a dark violet
screen, wobbling side to side, and near the top each one fades away or pops
into six droplets, while new ones keep coming, forever. It is a small app,
one module (`BubblesApp.roc`) and its two roots.

## The bubbles

A bubble is born every 10 steps, three a second at 30 steps a second. Each
one's look comes from a hash of its number (`BubblesApp.numbered_bubble`):

- **Size and speed:** half are small and quick (7 to 14 pixels across the
  radius), a third middling, and the rest large and slow (33 to 46).
- **Wobble:** it sways about its own line, each with its own width and
  period, from 60 to 130 steps.
- **Colour:** one of five purples, from Roc's logo's violet to a pale lilac,
  drawn as a translucent disc with a darker middle, which leaves a rim, and
  a white glint.
- **Ending:** two in five pop at a height between 70 and 200 pixels from the
  top, their droplets flying out and fading over 9 steps; the rest fade out
  between 200 and 30 pixels from the top.

The model is only a count of steps and whether it plays, and every frame is
worked out from that count, so the frames are the same on every run and the
model never grows. The screen starts full: the frame at step 0 is drawn as
if the bubbles had been rising for 1000 steps already.

## The keys

The app reads its keys from its step's `Input.Snapshot`, so they work the
same on the page and in the Windows window. Each acts on the step it is
struck.

- **Space** pauses, holding every bubble still, and a second Space resumes.
- **R** starts again from the first frame and plays, even from a pause.

## Natively

Every shape is a disc with a flat fill, over one linear gradient for the
backdrop, so the native painter draws each as it is, and no frame has a
`Radial` fill. An expect holds the frames to that.

## The page

`web.roc` holds Steve's skin, as lanterns' does: the warming-up pill and the
keyboard help on, and the links Home (https://roc.lynrummy.com) and Code
(this repo). `?step=N` shows the frame after N steps and stops there.
