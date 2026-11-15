## Conifer is a kind of tree. It sets the tree's height, from the ground to its
## tip, and its color, and ConiferShapes draws it.
##
## This file is adapted from roc-apps (`canvas_apps/safari/Conifer.roc`) on
## 2026-11-15, and it is allowed to drift from it. The kinds, heights and colors
## are Safari's; heights are plain metres here, because nothing else in the
## screensaver needs Safari's `Distance`.
import lib.RgbColor

Conifer := [Green, SmallGreen, Red, Gold].{

	## A red tree is twice a small one's height and a gold one three times,
	## sizes chosen by eye.
	height_metres : Conifer -> F64
	height_metres = |conifer|
		match conifer {
			Green => green_height
			SmallGreen => small_height
			Red => small_height * 2.0
			Gold => small_height * 3.0
		}

	## A conifer's foliage color.
	foliage_color : Conifer -> RgbColor
	foliage_color = |conifer|
		match conifer {
			Green | SmallGreen => green_color
			Gold => gold_color
			Red => red_color
		}

	is_eq : _
}

## A small green tree's height in metres, chosen by eye.
small_height : F64
small_height = 4.896

## A green tree's height, 1.3 times a small one's, a size chosen by eye.
green_height : F64
green_height = small_height * 1.3

green_color : RgbColor
green_color = RgbColor.of(0x1C5A22)

gold_color : RgbColor
gold_color = RgbColor.of(0xCF9A18)

red_color : RgbColor
red_color = RgbColor.of(0xB23A2A)

expect Conifer.Gold.height_metres() == Conifer.SmallGreen.height_metres() * 3.0
expect Conifer.Red.foliage_color() == red_color
expect Conifer.SmallGreen.foliage_color() == Conifer.Green.foliage_color()
