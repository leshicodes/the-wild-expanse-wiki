# How to Create Watercolor D&D Tokens in GIMP

This guide creates a "cutout" style image where your character art appears only inside a watercolor splash shape, with a transparent background.

## Prerequisites
* **GIMP** installed and open.
* **Character Art** file (PNG or JPG).
* **Stain/Splash Mask** file (PNG with transparency or Black/White image).

---

## Phase 1: Setup the "Layer Sandwich"
1.  Open GIMP.
2.  Open your **Character Art** first (`File > Open...`).
3.  Add your **Stain Image** as a new layer on top:
    * Go to `File > Open as Layers...`
    * Select your stain image.
    * *Note: You should now see the stain covering your character.*
4.  **Position the Stain:**
    * Use the **Move Tool** (M) or **Scale Tool** (Shift+S) on the stain layer to place it exactly where you want the border to be.

## Phase 2: Create the Selection Shape
1.  **Select the Stain Layer** in the Layers panel (bottom right).
2.  **Convert to Selection:**
    * **If your stain is transparent:** Right-click the Stain Layer and choose **Alpha to Selection**.
    * **If your stain is Black/White:**
        1.  Go to `Colors > Color to Alpha...` (ensure White is selected).
        2.  Right-click the layer and choose **Alpha to Selection**.
3.  **Visual Check:** You should see "marching ants" (dotted lines) matching the shape of the stain.
4.  **Hide the Stain:** Click the **Eye Icon** next to the stain layer to hide it. You don't need the visible layer anymore, just the selection shape.

## Phase 3: Apply the Mask
1.  Click on your **Character Art Layer** to select it.
2.  Right-click the Character Layer and choose **Add Layer Mask...**
3.  In the dialog box, choose **Selection**.
4.  Click **Add**.

## Phase 4: The Invert Fix (Critical Step)
*Look at your image on the canvas.*

* **Scenario A (Perfect):** You see your character *inside* the stain, with a checkerboard background. -> **Skip to Phase 5.**
* **Scenario B (Inverted/Hole):** You see a hole where the stain should be, or the character is outside the stain.
    1.  Click the **Layer Mask Thumbnail** (the black/white square next to your character image).
    2.  Go to the top menu: `Colors > Invert`.
    3.  *Result:* The mask flips, and your character should now be visible inside the stain.

## Phase 5: Final Export
1.  Right-click the **Layer Mask Thumbnail** and select **Apply Layer Mask**.
    * *The mask icon merges into the image layer.*
2.  Go to `File > Export As...`
3.  Name your file (must end in **.png**, e.g., `character_token.png`).
4.  Click **Export**, then **Export** again in the settings popup.

---

### Troubleshooting
* **Yellow Dotted Line:** This is just the layer boundary marker. It will not save in the final image.
* **Checkerboard Pattern:** This represents transparency. If you see this around your character, you succeeded!
* **Moving the Character Inside the Stain:**
    * If you need to adjust the position *after* masking, **unlink** the mask (click the chain icon between the image and mask thumbnails).
    * Select the **Image Thumbnail** (not the mask) and use the **Move Tool**.
    * *Remember to relink them when done.*